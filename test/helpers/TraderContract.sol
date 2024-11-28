pragma solidity 0.8.20;

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/Exchange.sol"; // Import the Exchange contract interface
import "../../src/ExecutionDelegate.sol"; // Import the ExecutionDelegate contract interface
import "../../src/Minter.sol";
import "../../src/libraries/OrderLib.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol"; // For NFT transfers
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; // For ERC20 token operations

// Contract to simulate the bypassing of the fees on the Exchange contract
// Building this contract for testing is overkill.
contract TraderContract {
    Exchange public exchange;
    Minter public minter;

    constructor(address _exchangeAddress, address _minterAddress) {
        require(_exchangeAddress != address(0), "Exchange address cannot be zero.");
        require(_minterAddress != address(0), "Minter address cannot be zero.");

        exchange = Exchange(_exchangeAddress);
        minter = Minter(_minterAddress);
    }

    // Function to initiate a buy on the Exchange contract
    function buyOnExchange(OrderLib.Order calldata sellOrder, bytes calldata sellerSignature) external payable {
        // Directly call the buy function of the Exchange contract
        exchange.buy{value: msg.value}(sellOrder, sellerSignature, false);
    }

    function batchBuyOnExchange(
        OrderLib.Order[] calldata sellOrders,
        bytes[] calldata sellerSignatures
    ) external payable {
        // Directly call the batchBuy function of the Exchange contract
        exchange.batchBuy{value: msg.value}(sellOrders, sellerSignatures, new bool[](sellOrders.length));
    }

    // Function to initiate a sell on the Exchange contract
    function sellOnExchange(
        OrderLib.Order calldata buyOrder,
        bytes calldata buyerSignature,
        uint256 tokenId,
        bytes32[] calldata merkleProof
    ) external {
        // Some logic would go here to ensure that the NFT is in this contract's possession
        // Probably by doing a buy threw the Exchange contract at 0 price

        // Call the sell function of the Exchange contract
        exchange.sell(buyOrder, buyerSignature, tokenId, merkleProof);
    }

    function mintOnMinter(uint256 configId, bytes32[] calldata merkleProof, uint256 maxPrice) public {
        minter.mint(configId, merkleProof, maxPrice);
    }
}
