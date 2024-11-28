pragma solidity ^0.8.20;

import "../base/BaseTest.t.sol";
import "../../src/libraries/OrderLib.sol";
import "../helpers/HashLib.sol";
import "../helpers/TraderContract.sol";

contract Buy is BaseTest {
    function setUp() public override {
        super.setUp();

        cheats.startPrank(address(executionDelegate));
        fantasyCards.safeMint(user1);
        fantasyCards.safeMint(user1);
        cheats.stopPrank();

        cheats.startPrank(user1);
        fantasyCards.approve(address(executionDelegate), 0);
        fantasyCards.approve(address(executionDelegate), 1);
        cheats.stopPrank();
    }

    function test_successfull_batchBuy_ETH() public {
        // Create first sell order
        OrderLib.Order memory sellOrder1 = OrderLib.Order(
            user1,
            OrderLib.Side.Sell,
            address(fantasyCards),
            0,
            address(0),
            1 ether,
            999999999999999999999,
            bytes32(0),
            100_001
        );

        // Sign order
        bytes32 orderHash1 = HashLib.getTypedDataHash(sellOrder1, exchange.domainSeparator());
        (uint8 vSeller1, bytes32 rSeller1, bytes32 sSeller1) = vm.sign(user1PrivateKey, orderHash1);
        bytes memory sellerSignature1 = abi.encodePacked(rSeller1, sSeller1, vSeller1);

        // Create second sell order
        OrderLib.Order memory sellOrder2 = OrderLib.Order(
            user1,
            OrderLib.Side.Sell,
            address(fantasyCards),
            1,
            address(0),
            2 ether,
            999999999999999999999,
            bytes32(0),
            100_001
        );

        // Sign order
        bytes32 orderHash2 = HashLib.getTypedDataHash(sellOrder2, exchange.domainSeparator());
        (uint8 vSeller2, bytes32 rSeller2, bytes32 sSeller2) = vm.sign(user1PrivateKey, orderHash2);
        bytes memory sellerSignature2 = abi.encodePacked(rSeller2, sSeller2, vSeller2);

        uint256 totalPrice = sellOrder1.price + sellOrder2.price;

        cheats.deal(user2, totalPrice);

        OrderLib.Order[] memory sellOrders = new OrderLib.Order[](2);
        sellOrders[0] = sellOrder1;
        sellOrders[1] = sellOrder2;
        bytes[] memory sellerSignatures = new bytes[](2);
        sellerSignatures[0] = sellerSignature1;
        sellerSignatures[1] = sellerSignature2;

        // Execute buy
        cheats.startPrank(user2, user2);
        exchange.batchBuy{value: totalPrice}(sellOrders, sellerSignatures, false);
        cheats.stopPrank();

        assertEq(treasury.balance, (totalPrice * exchange.protocolFeeBps()) / exchange.INVERSE_BASIS_POINT());
        assertEq(user1.balance, totalPrice - treasury.balance);
        assertEq(user2.balance, 0);
        assertEq(fantasyCards.balanceOf(user1), 0);
        assertEq(fantasyCards.balanceOf(user2), 2);
    }

    function test_successfull_batchBuy_WETH() public {
        // Create first sell order
        OrderLib.Order memory sellOrder1 = OrderLib.Order(
            user1,
            OrderLib.Side.Sell,
            address(fantasyCards),
            0,
            address(weth),
            1 ether,
            999999999999999999999,
            bytes32(0),
            100_001
        );

        // Sign order
        bytes32 orderHash1 = HashLib.getTypedDataHash(sellOrder1, exchange.domainSeparator());
        (uint8 vSeller1, bytes32 rSeller1, bytes32 sSeller1) = vm.sign(user1PrivateKey, orderHash1);
        bytes memory sellerSignature1 = abi.encodePacked(rSeller1, sSeller1, vSeller1);

        // Create second sell order
        OrderLib.Order memory sellOrder2 = OrderLib.Order(
            user1,
            OrderLib.Side.Sell,
            address(fantasyCards),
            1,
            address(weth),
            2 ether,
            999999999999999999999,
            bytes32(0),
            100_001
        );

        // Sign order
        bytes32 orderHash2 = HashLib.getTypedDataHash(sellOrder2, exchange.domainSeparator());
        (uint8 vSeller2, bytes32 rSeller2, bytes32 sSeller2) = vm.sign(user1PrivateKey, orderHash2);
        bytes memory sellerSignature2 = abi.encodePacked(rSeller2, sSeller2, vSeller2);

        uint256 totalPrice = sellOrder1.price + sellOrder2.price;

        // Give WETH allowance
        cheats.startPrank(user2);
        weth.getFaucet(totalPrice);
        weth.approve(address(executionDelegate), totalPrice);
        cheats.stopPrank();

        OrderLib.Order[] memory sellOrders = new OrderLib.Order[](2);
        sellOrders[0] = sellOrder1;
        sellOrders[1] = sellOrder2;
        bytes[] memory sellerSignatures = new bytes[](2);
        sellerSignatures[0] = sellerSignature1;
        sellerSignatures[1] = sellerSignature2;

        // Execute buy
        cheats.startPrank(user2, user2);
        exchange.batchBuy(sellOrders, sellerSignatures, false);
        cheats.stopPrank();

        assertEq(weth.balanceOf(treasury), (totalPrice * exchange.protocolFeeBps()) / exchange.INVERSE_BASIS_POINT());
        assertEq(weth.balanceOf(user1), totalPrice - weth.balanceOf(treasury));
        assertEq(weth.balanceOf(user2), 0);
        assertEq(fantasyCards.balanceOf(user1), 0);
        assertEq(fantasyCards.balanceOf(user2), 2);
    }

    function test_successfull_batchBuy_WETH_and_ETH() public {
        // Create first sell order
        OrderLib.Order memory sellOrder1 = OrderLib.Order(
            user1,
            OrderLib.Side.Sell,
            address(fantasyCards),
            0,
            address(0),
            1 ether,
            999999999999999999999,
            bytes32(0),
            100_001
        );

        // Sign order
        bytes32 orderHash1 = HashLib.getTypedDataHash(sellOrder1, exchange.domainSeparator());
        (uint8 vSeller1, bytes32 rSeller1, bytes32 sSeller1) = vm.sign(user1PrivateKey, orderHash1);
        bytes memory sellerSignature1 = abi.encodePacked(rSeller1, sSeller1, vSeller1);

        // Create second sell order
        OrderLib.Order memory sellOrder2 = OrderLib.Order(
            user1,
            OrderLib.Side.Sell,
            address(fantasyCards),
            1,
            address(weth),
            2 ether,
            999999999999999999999,
            bytes32(0),
            100_001
        );

        // Sign order
        bytes32 orderHash2 = HashLib.getTypedDataHash(sellOrder2, exchange.domainSeparator());
        (uint8 vSeller2, bytes32 rSeller2, bytes32 sSeller2) = vm.sign(user1PrivateKey, orderHash2);
        bytes memory sellerSignature2 = abi.encodePacked(rSeller2, sSeller2, vSeller2);

        cheats.deal(user2, 1 ether);

        // Give WETH allowance
        cheats.startPrank(user2);
        weth.getFaucet(2 ether);
        weth.approve(address(executionDelegate), 2 ether);
        cheats.stopPrank();

        OrderLib.Order[] memory sellOrders = new OrderLib.Order[](2);
        sellOrders[0] = sellOrder1;
        sellOrders[1] = sellOrder2;
        bytes[] memory sellerSignatures = new bytes[](2);
        sellerSignatures[0] = sellerSignature1;
        sellerSignatures[1] = sellerSignature2;

        // Execute buy
        cheats.startPrank(user2, user2);
        exchange.batchBuy{value: 1 ether}(sellOrders, sellerSignatures, false);
        cheats.stopPrank();

        assertEq(treasury.balance, (1 ether * exchange.protocolFeeBps()) / exchange.INVERSE_BASIS_POINT());
        assertEq(weth.balanceOf(treasury), (2 ether * exchange.protocolFeeBps()) / exchange.INVERSE_BASIS_POINT());
        assertEq(user1.balance, 1 ether - treasury.balance);
        assertEq(weth.balanceOf(user1), 2 ether - weth.balanceOf(treasury));
        assertEq(user2.balance, 0);
        assertEq(weth.balanceOf(user2), 0);
        assertEq(fantasyCards.balanceOf(user1), 0);
        assertEq(fantasyCards.balanceOf(user2), 2);
    }

    function test_unsuccessfull_batchBuy_ETH_not_enough_eth_sent() public {
        // Create first sell order
        OrderLib.Order memory sellOrder1 = OrderLib.Order(
            user1,
            OrderLib.Side.Sell,
            address(fantasyCards),
            0,
            address(0),
            1 ether,
            999999999999999999999,
            bytes32(0),
            100_001
        );

        // Sign order
        bytes32 orderHash1 = HashLib.getTypedDataHash(sellOrder1, exchange.domainSeparator());
        (uint8 vSeller1, bytes32 rSeller1, bytes32 sSeller1) = vm.sign(user1PrivateKey, orderHash1);
        bytes memory sellerSignature1 = abi.encodePacked(rSeller1, sSeller1, vSeller1);

        // Create second sell order
        OrderLib.Order memory sellOrder2 = OrderLib.Order(
            user1,
            OrderLib.Side.Sell,
            address(fantasyCards),
            1,
            address(0),
            2 ether,
            999999999999999999999,
            bytes32(0),
            100_001
        );

        // Sign order
        bytes32 orderHash2 = HashLib.getTypedDataHash(sellOrder2, exchange.domainSeparator());
        (uint8 vSeller2, bytes32 rSeller2, bytes32 sSeller2) = vm.sign(user1PrivateKey, orderHash2);
        bytes memory sellerSignature2 = abi.encodePacked(rSeller2, sSeller2, vSeller2);

        uint256 totalPrice = sellOrder1.price + sellOrder2.price;

        cheats.deal(user2, totalPrice - 1);

        OrderLib.Order[] memory sellOrders = new OrderLib.Order[](2);
        sellOrders[0] = sellOrder1;
        sellOrders[1] = sellOrder2;
        bytes[] memory sellerSignatures = new bytes[](2);
        sellerSignatures[0] = sellerSignature1;
        sellerSignatures[1] = sellerSignature2;

        // Execute buy
        cheats.startPrank(user2, user2);
        cheats.expectRevert("Insufficient ETH sent");
        exchange.batchBuy{value: totalPrice - 1}(sellOrders, sellerSignatures, false);
        cheats.stopPrank();
    }

    function test_unsuccessfull_batchBuy_not_enough_weth_allowance() public {
        // Create first sell order
        OrderLib.Order memory sellOrder1 = OrderLib.Order(
            user1,
            OrderLib.Side.Sell,
            address(fantasyCards),
            0,
            address(weth),
            1 ether,
            999999999999999999999,
            bytes32(0),
            100_001
        );

        // Sign order
        bytes32 orderHash1 = HashLib.getTypedDataHash(sellOrder1, exchange.domainSeparator());
        (uint8 vSeller1, bytes32 rSeller1, bytes32 sSeller1) = vm.sign(user1PrivateKey, orderHash1);
        bytes memory sellerSignature1 = abi.encodePacked(rSeller1, sSeller1, vSeller1);

        // Create second sell order
        OrderLib.Order memory sellOrder2 = OrderLib.Order(
            user1,
            OrderLib.Side.Sell,
            address(fantasyCards),
            1,
            address(weth),
            2 ether,
            999999999999999999999,
            bytes32(0),
            100_001
        );

        // Sign order
        bytes32 orderHash2 = HashLib.getTypedDataHash(sellOrder2, exchange.domainSeparator());
        (uint8 vSeller2, bytes32 rSeller2, bytes32 sSeller2) = vm.sign(user1PrivateKey, orderHash2);
        bytes memory sellerSignature2 = abi.encodePacked(rSeller2, sSeller2, vSeller2);

        uint256 totalPrice = sellOrder1.price + sellOrder2.price;

        // Give WETH allowance
        cheats.startPrank(user2);
        weth.getFaucet(totalPrice);
        weth.approve(address(executionDelegate), totalPrice - 1);
        cheats.stopPrank();

        OrderLib.Order[] memory sellOrders = new OrderLib.Order[](2);
        sellOrders[0] = sellOrder1;
        sellOrders[1] = sellOrder2;
        bytes[] memory sellerSignatures = new bytes[](2);
        sellerSignatures[0] = sellerSignature1;
        sellerSignatures[1] = sellerSignature2;

        // Execute buy
        cheats.startPrank(user2, user2);
        cheats.expectRevert(); // REVIEW: proper error message
        exchange.batchBuy(sellOrders, sellerSignatures, false);
        cheats.stopPrank();
    }

    function test_unsuccessfull_batchBuy_not_EOA() public {
        OrderLib.Order[] memory sellOrders = new OrderLib.Order[](2);
        bytes[] memory sellerSignatures = new bytes[](2);

        // DEPLOY TRADER CONTRACT
        TraderContract traderContract = new TraderContract(address(exchange), address(minter));

        // Execute buy
        cheats.startPrank(user2, user2);
        cheats.expectRevert("Function can only be called by an EOA"); // REVIEW: proper error message
        traderContract.batchBuyOnExchange(sellOrders, sellerSignatures);
        cheats.stopPrank();
    }

    function test_unsuccessfull_batchBuy_signature_order_mismatch() public {
        OrderLib.Order[] memory sellOrders = new OrderLib.Order[](3);
        bytes[] memory sellerSignatures = new bytes[](2);

        // Execute buy
        cheats.startPrank(user2, user2);
        cheats.expectRevert("Array length mismatch");
        exchange.batchBuy(sellOrders, sellerSignatures, false);
        cheats.stopPrank();
    }
}
