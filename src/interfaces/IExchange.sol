// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../libraries/OrderLib.sol";

interface IExchange {
    /* Events */
    event Buy(address indexed buyer, OrderLib.Order sell, bytes32 sellOrderHash);
    event Sell(address indexed seller, OrderLib.Order buyOrder, uint256 tokenId, bytes32 buyOrderHash);
    event BatchBuy(address indexed buyer, OrderLib.Order[] sellOrders, bytes[] sellerSignatures);
    event BatchBuyAndBurn(address indexed buyer, OrderLib.Order[] sellOrders, bytes[] sellerSignatures);
    event BatchSell(address indexed seller, OrderLib.Order[] buyOrders, uint256[] tokenIds, bytes32[][] merkleProofs);
    event CancelOrder(bytes32 orderHash);
    event NewWhitelistedPaymentToken(address paymentToken);
    event UnWhitelistedPaymentToken(address paymentToken);
    event NewWhitelistedCollection(address collection);
    event UnWhitelistedCollection(address collection);
    event NewProtocolFeeRecipient(address protocolFeeRecipient);
    event NewProtocolFeeBps(uint256 protocolFeeBps);
    event NewExecutionDelegate(address executionDelegate);
    event NewMinimumPricePerPaymentToken(address paymentToken, uint256 minimuPrice);

    /* Functions */
    function buy(OrderLib.Order calldata sellOrder, bytes calldata sellerSignature, bool burnAfterPurchase) external payable;

    function sell(
        OrderLib.Order calldata buyOrder,
        bytes calldata buyerSignature,
        uint256 tokenId,
        bytes32[] calldata merkleProof
    ) external payable;

    function cancelOrder(OrderLib.Order calldata order) external;

    function whiteListPaymentToken(address _paymentToken, uint256 _minimumPrice) external;

    function unWhiteListPaymentToken(address _paymentToken) external;

    function whiteListCollection(address _collection) external;

    function unWhiteListCollection(address _collection) external;

    function setProtocolFeeBps(uint256 _protocolFeeBps) external;

    function setProtocolFeeRecipient(address _protocolFeeRecipient) external;

    function setExecutionDelegate(address _executionDelegate) external;

    function domainSeparator() external view returns (bytes32);

    function saveFunds(address paymentToken, address to, uint256 amount) external;
}
