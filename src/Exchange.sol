/**                                                                                                                                     
    ______            __                  
   / ____/___ _____  / /_____ ________  __
  / /_  / __ `/ __ \/ __/ __ `/ ___/ / / /
 / __/ / /_/ / / / / /_/ /_/ (__  ) /_/ / 
/_/    \__,_/_/ /_/\__/\__,_/____/\__, /  
                                 /____/   

**/
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./interfaces/IBlast.sol";
import "./interfaces/IBlastPoints.sol";
import "./interfaces/IExecutionDelegate.sol";
import "./interfaces/IExchange.sol";
import "./libraries/OrderLib.sol";

contract Exchange is IExchange, EIP712, Ownable2Step, ReentrancyGuard {
    /* Constants */
    uint256 public constant INVERSE_BASIS_POINT = 10000;

    /* Variables */
    mapping(bytes32 orderHash => bool) public cancelledOrFilled;
    mapping(address collection => bool) public whitelistedCollections;
    mapping(address paymentToken => bool) public whitelistedPaymentTokens;
    mapping(address paymentToken => uint256 minimumPrice) public minimumPricePerPaymentToken;
    uint256 public protocolFeeBps;
    address public protocolFeeRecipient;
    IExecutionDelegate public executionDelegate;

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "Function can only be called by an EOA");
        _;
    }

    /**
     * @notice Contract constructor
     * @param _protocolFeeRecipient Address to receive protocol fees
     * @param _protocolFeeBps Protocol fee basis points
     * @param _executionDelegate Address of the execution delegate contract
     */
    constructor(
        address _protocolFeeRecipient,
        uint256 _protocolFeeBps,
        address _executionDelegate
    ) EIP712("Exchange", "1") Ownable(msg.sender) {
        IBlast(0x4300000000000000000000000000000000000002).configureClaimableGas();
        IBlast(0x4300000000000000000000000000000000000002).configureGovernor(msg.sender);
        IBlastPoints(0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800).configurePointsOperator(msg.sender);

        _setProtocolFeeRecipient(_protocolFeeRecipient);
        _setProtocolFeeBps(_protocolFeeBps);
        _setExecutionDelegate(_executionDelegate);
    }

    /**
     * @notice Executes a buy operation for a sell order
     * @dev Verifies the validity of the sell order and executes funds and token transfer
     * @param sellOrder The sell order to match with
     * @param sellerSignature Signature of the seller to validate the order
     */
    function buy(
        OrderLib.Order calldata sellOrder,
        bytes calldata sellerSignature,
        bool burnAfterPurchase
    ) public payable nonReentrant onlyEOA {
        _buy(sellOrder, sellerSignature, burnAfterPurchase);
    }

    /**
     * @notice Executes multiple buy transactions in one call.
     * @dev Iterates over `sellOrders` and `sellerSignatures`, executing each through `_buy`.
     * @param sellOrders Array of sell orders, each following `OrderLib.Order` structure.
     * @param sellerSignatures Array of signatures, each corresponding to a sell order in `sellOrders`.
     * @param burnAfterPurchase Whether to burn the NFT(s) after the purchase
     */
    function batchBuy(
        OrderLib.Order[] calldata sellOrders,
        bytes[] calldata sellerSignatures,
        bool burnAfterPurchase
    ) public payable nonReentrant onlyEOA {
        require(sellOrders.length == sellerSignatures.length, "Array length mismatch");

        uint256 totalEthSpending;
        for (uint256 i = 0; i < sellOrders.length; i++) {
            // REVIEW: not a huge fan of this, let see if we can find a better way.
            // This also involves changing _executeFundsTransfer require from == to >=
            if (sellOrders[i].paymentToken == address(0)) {
                totalEthSpending += sellOrders[i].price;
                require(totalEthSpending <= msg.value, "Insufficient ETH sent");
            }
            _buy(sellOrders[i], sellerSignatures[i], burnAfterPurchase);
        }

        if (burnAfterPurchase) {
            emit BatchBuyAndBurn(msg.sender, sellOrders, sellerSignatures);
        } else {
            emit BatchBuy(msg.sender, sellOrders, sellerSignatures);
        }
    }

    /**
     * @notice Allows a seller to execute a sell operation for a buy order
     * @dev Verifies the validity of the buy order and executes funds and token transfer
     * @param buyOrder The buy order to match with
     * @param buyerSignature Signature of the buyer to validate the order
     * @param tokenId The ID of the token being sold
     * @param merkleProof The merkle proof verifying the tokenId belongs to the merkle root in the buy order
     */
    function sell(
        OrderLib.Order calldata buyOrder,
        bytes calldata buyerSignature,
        uint256 tokenId,
        bytes32[] calldata merkleProof
    ) public payable nonReentrant onlyEOA {
        _sell(buyOrder, buyerSignature, tokenId, merkleProof);
    }


    /**
     * @notice Executes multiple sell transactions in one call.
     * @dev Iterates over `buyOrders`, `buyerSignatures`, `tokenIds`, and `merkleProofs`, executing each through `_sell`.
     * @param buyOrders Array of buy orders, each following `OrderLib.Order` structure.
     * @param buyerSignatures Array of signatures, each corresponding to a buy order in `buyOrders`.
     * @param tokenIds Array of token IDs, each corresponding to a buy order in `buyOrders`.
     * @param merkleProofs Array of merkle proofs, each corresponding to a token ID in `tokenIds`.
     */
    function batchSell(
        OrderLib.Order[] calldata buyOrders,
        bytes[] calldata buyerSignatures,
        uint256[] calldata tokenIds,
        bytes32[][] calldata merkleProofs
    ) public payable nonReentrant onlyEOA {
        require(buyOrders.length == buyerSignatures.length, "Array length mismatch");
        require(buyOrders.length == tokenIds.length, "Array length mismatch");
        require(buyOrders.length == merkleProofs.length, "Array length mismatch");

        for (uint256 i = 0; i < buyOrders.length; i++) {
            _sell(buyOrders[i], buyerSignatures[i], tokenIds[i], merkleProofs[i]);
        }

        emit BatchSell(msg.sender, buyOrders, tokenIds, merkleProofs);
    }

    /**
     * @notice Cancels an order, preventing it from being executed. This function is provided for backward compatibility and convenience, although similar functionality can be achieved using
     * `batchCancelOrders` with an array containing a single order.
     * @dev Sets the order's hash in the `cancelledOrFilled` mapping to true
     * @param order The order to cancel
     */
    function cancelOrder(OrderLib.Order calldata order) public {
        _cancelOrder(order);
    }


    /**
     * @notice Cancels multiple orders in a single transaction to save gas and streamline order management.
     * @dev Iterates through the list of orders and calls the internal _cancelOrder function for each order
     * @param orders The array of orders to be cancelled
     */
    function batchCancelOrders(OrderLib.Order[] calldata orders) public {
        for (uint256 i = 0; i < orders.length; i++) {
            _cancelOrder(orders[i]);
        }
    }

    /**
     * @notice Whitelists a payment token, allowing it to be used in transactions
     * @dev Only callable by the contract owner. This function adds a payment token to the list of tokens
     * that can be used for buying and selling on the exchange. Emits a `NewWhitelistedPaymentToken` event on success.
     * @param _paymentToken The address of the ERC-20 payment token to whitelist
     */
    function whiteListPaymentToken(address _paymentToken, uint256 _minimumPrice) public onlyOwner {
        whitelistedPaymentTokens[_paymentToken] = true;
        _setMinimumPricePerPaymentToken(_paymentToken, _minimumPrice);

        emit NewWhitelistedPaymentToken(_paymentToken);
    }

    /**
     * @notice Removes a payment token from the whitelist, preventing it from being used in future transactions
     * @dev Only callable by the contract owner. This function removes a payment token from the list of tokens
     * that are allowed for transactions. Emits an `UnWhitelistedPaymentToken` event on success.
     * @param _paymentToken The address of the ERC-20 payment token to remove from the whitelist
     */
    function unWhiteListPaymentToken(address _paymentToken) public onlyOwner {
        whitelistedPaymentTokens[_paymentToken] = false;

        emit UnWhitelistedPaymentToken(_paymentToken);
    }

    /**
     * @notice Whitelists a collection, allowing its tokens to be traded on the exchange
     * @dev Only callable by the contract owner. This function adds a collection to the list of NFT collections
     * that can be bought and sold on the exchange. Emits a `NewWhitelistedCollection` event on success.
     * @param _collection The address of the ERC-721 token collection to whitelist
     */
    function whiteListCollection(address _collection) public onlyOwner {
        whitelistedCollections[_collection] = true;

        emit NewWhitelistedCollection(_collection);
    }

    /**
     * @notice Removes a collection from the whitelist, preventing its tokens from being traded on the exchange
     * @dev Only callable by the contract owner. This function removes a collection from the list of collections
     * that are allowed to be traded. Emits an `UnWhitelistedCollection` event on success.
     * @param _collection The address of the ERC-721 token collection to remove from the whitelist
     */
    function unWhiteListCollection(address _collection) public onlyOwner {
        whitelistedCollections[_collection] = false;

        emit UnWhitelistedCollection(_collection);
    }

    /**
     * @notice Sets a new protocol fee in basis points
     * @param _protocolFeeBps The new protocol fee in basis points
     */
    function setProtocolFeeBps(uint256 _protocolFeeBps) public onlyOwner {
        _setProtocolFeeBps(_protocolFeeBps);
    }

    /**
     * @notice Sets a new protocol fee recipient address
     * @param _protocolFeeRecipient The address of the new protocol fee recipient
     */
    function setProtocolFeeRecipient(address _protocolFeeRecipient) public onlyOwner {
        _setProtocolFeeRecipient(_protocolFeeRecipient);
    }

    /**
     * @notice Sets a new execution delegate address
     * @param _executionDelegate The address of the new execution delegate
     */
    function setExecutionDelegate(address _executionDelegate) public onlyOwner {
        _setExecutionDelegate(_executionDelegate);
    }

    /**
     * @notice Sets a new minimum price for a certain payment token
     * @param paymentToken The address of the payment token
     * @param minimuPrice The new minimum price
     */
    function setMinimumPricePerPaymentToken(address paymentToken, uint256 minimuPrice) public onlyOwner {
        _setMinimumPricePerPaymentToken(paymentToken, minimuPrice);
    }

    /**
     * @notice Function to get the Domain Separator
     * @return bytes32: EIP712 Domain Separator
     */
    function domainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev Function to retrieve funds mistakenly sent to the mint contract.
     * @param paymentToken ERC20 token address, or zero for Ether.
     * @param to Recipient's address.
     * @param amount Transfer amount.
     */
    function saveFunds(address paymentToken, address to, uint256 amount) public onlyOwner {
        if (paymentToken == address(0)) {
            payable(to).transfer(amount);
        } else {
            IERC20(paymentToken).transfer(to, amount);
        }
    }

    /**
     * @notice Internal function that executes a buy operation for a sell order
     * @dev Verifies the validity of the sell order and executes funds and token transfer
     * @param sellOrder The sell order to match with
     * @param sellerSignature Signature of the seller to validate the order
     * @param burnAfterPurchase Whether to burn the NFT after the purchase
     */
    function _buy(OrderLib.Order calldata sellOrder, bytes calldata sellerSignature, bool burnAfterPurchase) internal {
        require(sellOrder.side == OrderLib.Side.Sell, "order must be a sell");
        require(sellOrder.expirationTime > block.timestamp, "order expired");
        require(sellOrder.trader != address(0), "order trader is 0");
        require(sellOrder.price >= minimumPricePerPaymentToken[sellOrder.paymentToken], "price bellow minimumPrice");
        require(sellOrder.salt > 100_000, "salt should be above 100_000");

        bytes32 sellOrderHash = OrderLib._hashOrder(sellOrder);
        require(cancelledOrFilled[sellOrderHash] == false, "sell order cancelled or filled");

        bytes32 sellOrderDigest = _hashTypedDataV4(sellOrderHash);
        address sellOrderSigner = ECDSA.recover(sellOrderDigest, sellerSignature);
        require(sellOrderSigner == sellOrder.trader, "invalid signature");

        cancelledOrFilled[sellOrderHash] = true;

        _executeFundsTransfer(msg.sender, sellOrder.trader, sellOrder.paymentToken, sellOrder.price);

        if (burnAfterPurchase) {
            executionDelegate.burnFantasyCard(sellOrder.collection, sellOrder.tokenId);
        } else {
            _executeTokenTransfer(sellOrder.collection, sellOrder.trader, msg.sender, sellOrder.tokenId);
        }

        emit Buy(msg.sender, sellOrder, sellOrderHash);
    }

    /**
     * @notice Internal function that executes a sell operation for a buy order
     * @dev Verifies the validity of the buy order and executes funds and token transfer
     * @param buyOrder The buy order to match with
     * @param buyerSignature Signature of the buyer to validate the order
     * @param tokenId The ID of the token being sold
     * @param merkleProof The merkle proof verifying the tokenId belongs to the merkle root in the buy order
     */
    function _sell(
        OrderLib.Order calldata buyOrder, 
        bytes calldata buyerSignature, 
        uint256 tokenId, 
        bytes32[] calldata merkleProof
    ) internal {
        require(buyOrder.paymentToken != address(0), "payment token can not be ETH for buy order");
        require(buyOrder.side == OrderLib.Side.Buy, "order must be a buy");
        require(buyOrder.expirationTime > block.timestamp, "order expired");
        require(buyOrder.trader != address(0), "order trader is 0");
        require(buyOrder.price >= minimumPricePerPaymentToken[buyOrder.paymentToken], "price bellow minimumPrice");
        require(buyOrder.salt > 100_000, "salt should be above 100_000");

        bytes32 buyOrderHash = OrderLib._hashOrder(buyOrder);
        require(cancelledOrFilled[buyOrderHash] == false, "buy order cancelled or filled");

        bytes32 buyOrderDigest = _hashTypedDataV4(buyOrderHash);
        address buyOrderSigner = ECDSA.recover(buyOrderDigest, buyerSignature);
        require(buyOrderSigner == buyOrder.trader, "invalid signature");

        require(_verifyTokenId(buyOrder.merkleRoot, merkleProof, tokenId), "invalid tokenId");

        cancelledOrFilled[buyOrderHash] = true;

        _executeFundsTransfer(buyOrder.trader, msg.sender, buyOrder.paymentToken, buyOrder.price);

        _executeTokenTransfer(buyOrder.collection, msg.sender, buyOrder.trader, tokenId);

        emit Sell(
            msg.sender, // Seller's address
            buyOrder, // The buy order details
            tokenId, // The ID of the token being sold
            buyOrderHash // The hash of the buy order
        );
    }

    /**
     * @notice Internal function that cancels an order
     * @dev Requires that the caller is the trader specified in the order. Marks the order as cancelled or filled and emits a CancelOrder event.
     * @param order The order to be cancelled
     */
    function _cancelOrder(OrderLib.Order calldata order) internal {
        require(order.trader == msg.sender, "msg.sender is not the trader");

        bytes32 orderHash = OrderLib._hashOrder(order);
        cancelledOrFilled[orderHash] = true;

        emit CancelOrder(orderHash);
    }

    /**
     * @notice Internal function to set a new protocol fee in basis points
     * @param _protocolFeeBps The new protocol fee in basis points
     */
    function _setProtocolFeeBps(uint256 _protocolFeeBps) internal {
        require(_protocolFeeBps <= INVERSE_BASIS_POINT, "protocol fee above 100%");
        protocolFeeBps = _protocolFeeBps;

        emit NewProtocolFeeBps(_protocolFeeBps);
    }

    /**
     * @notice Internal function to set a new protocol fee recipient address
     * @param _protocolFeeRecipient The address of the new protocol fee recipient
     */
    function _setProtocolFeeRecipient(address _protocolFeeRecipient) internal {
        require(_protocolFeeRecipient != address(0), "protocol fee recipient can't be address 0");
        protocolFeeRecipient = _protocolFeeRecipient;

        emit NewProtocolFeeRecipient(_protocolFeeRecipient);
    }

    /**
     * @notice Internal function to set a new execution delegate address
     * @param _executionDelegate The address of the new execution delegate
     */
    function _setExecutionDelegate(address _executionDelegate) internal {
        require(_executionDelegate != address(0), "excution delegate can't be address 0");
        executionDelegate = IExecutionDelegate(_executionDelegate);

        emit NewExecutionDelegate(_executionDelegate);
    }

    /**
     * @notice Internal function to set a new minimum price for a certain payment token
     * @param paymentToken The address of the payment token
     * @param minimuPrice The new minimum price
     */
    function _setMinimumPricePerPaymentToken(address paymentToken, uint256 minimuPrice) internal {
        minimumPricePerPaymentToken[paymentToken] = minimuPrice;

        emit NewMinimumPricePerPaymentToken(paymentToken, minimuPrice);
    }

    /**
     * @dev Execute all ERC20 token / ETH transfers associated with an order match (fees and buyer => seller transfer)
     * @param from from
     * @param to to
     * @param paymentToken payment token
     * @param price price
     */
    function _executeFundsTransfer(address from, address to, address paymentToken, uint256 price) internal {
        if (paymentToken == address(0)) {
            require(msg.value >= price, "Incorrect ETH amount");
        }

        /* Take fee. */
        uint256 receiveAmount = _transferFees(paymentToken, from, price);

        /* Transfer remainder to seller. */
        _transferTo(paymentToken, from, to, receiveAmount);
    }

    /**
     * @dev fee is paid in the payment token specified in the order
     * @param paymentToken address of token to pay in
     * @param from address to charge fees
     * @param price price of token
     */
    function _transferFees(address paymentToken, address from, uint256 price) internal returns (uint256) {
        uint256 protocolFee = (price * protocolFeeBps) / INVERSE_BASIS_POINT;
        _transferTo(paymentToken, from, protocolFeeRecipient, protocolFee);

        require(protocolFee <= price, "Total amount of fees are more than the price");

        /* Amount that will be received by seller. */
        uint256 receiveAmount = price - protocolFee;
        return (receiveAmount);
    }

    /**
     * @dev Transfer amount in ETH or ERC20
     * @param paymentToken address of token to pay in
     * @param from token sender
     * @param to token recipient
     * @param amount amount to transfer
     */
    function _transferTo(address paymentToken, address from, address to, uint256 amount) internal {
        if (amount == 0) {
            return;
        }

        if (paymentToken == address(0)) {
            /* Transfer funds in ETH. */
            payable(to).transfer(amount);
        } else if (whitelistedPaymentTokens[paymentToken]) {
            /* Transfer ERC20. */
            executionDelegate.transferERC20(paymentToken, from, to, amount);
        } else {
            revert("Invalid payment token");
        }
    }

    /**
     * @dev Execute call through delegate proxy
     * @param collection collection contract address
     * @param from from
     * @param to to
     * @param tokenId tokenId
     */
    function _executeTokenTransfer(address collection, address from, address to, uint256 tokenId) internal {
        /* Assert collection is whitelisted */
        require(whitelistedCollections[collection], "Collection is not whitelisted");

        /* Call execution delegate. */
        executionDelegate.transferERC721Unsafe(collection, from, to, tokenId);
    }

    /**
     * @dev Verifies the validity of a token ID against a given Merkle root using a Merkle proof.
     * @param merkleRoot The root of the Merkle tree.
     * @param merkleProof An array of bytes32 values that represent the Merkle proof.
     * @param tokenId The token ID to verify.
     * @return bool Returns true if the token ID is valid and belongs to the Merkle tree defined by the root, otherwise false.
     */
    function _verifyTokenId(
        bytes32 merkleRoot,
        bytes32[] calldata merkleProof,
        uint256 tokenId
    ) internal pure returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(tokenId));
        return MerkleProof.verify(merkleProof, merkleRoot, leaf);
    }
}
