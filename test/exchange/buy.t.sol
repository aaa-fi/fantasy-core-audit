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
        cheats.stopPrank();

        cheats.startPrank(user1);
        fantasyCards.approve(address(executionDelegate), 0);
        cheats.stopPrank();
    }

    function test_successful_buy_WETH() public {
        // Create order
        OrderLib.Order memory sellOrder = OrderLib.Order(
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
        bytes32 orderHash = HashLib.getTypedDataHash(sellOrder, exchange.domainSeparator());
        (uint8 vSeller, bytes32 rSeller, bytes32 sSeller) = vm.sign(user1PrivateKey, orderHash);
        bytes memory sellerSignature = abi.encodePacked(rSeller, sSeller, vSeller);

        // Give WETH allowance
        cheats.startPrank(user2);
        weth.getFaucet(1 ether);
        weth.approve(address(executionDelegate), 1 ether);
        cheats.stopPrank();

        // Execute buy
        cheats.startPrank(user2, user2);
        exchange.buy(sellOrder, sellerSignature, false);
        cheats.stopPrank();

        // Check balances
        assertEq(
            weth.balanceOf(treasury),
            (sellOrder.price * exchange.protocolFeeBps()) / exchange.INVERSE_BASIS_POINT()
        );
        assertEq(weth.balanceOf(user1), 1 ether - weth.balanceOf(treasury));
        assertEq(weth.balanceOf(user2), 0);
        assertEq(fantasyCards.balanceOf(user1), 0);
        assertEq(fantasyCards.balanceOf(user2), 1);
    }

    function test_successful_buy_ETH() public {
        // Create order
        OrderLib.Order memory sellOrder = OrderLib.Order(
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
        bytes32 orderHash = HashLib.getTypedDataHash(sellOrder, exchange.domainSeparator());
        (uint8 vSeller, bytes32 rSeller, bytes32 sSeller) = vm.sign(user1PrivateKey, orderHash);
        bytes memory sellerSignature = abi.encodePacked(rSeller, sSeller, vSeller);

        cheats.deal(user2, 1 ether);

        // Execute buy
        cheats.startPrank(user2, user2);
        exchange.buy{value: 1 ether}(sellOrder, sellerSignature, false);
        cheats.stopPrank();

        // Check balances
        assertEq(treasury.balance, (sellOrder.price * exchange.protocolFeeBps()) / exchange.INVERSE_BASIS_POINT());
        assertEq(user1.balance, 1 ether - treasury.balance);
        assertEq(user2.balance, 0);
        assertEq(fantasyCards.balanceOf(user1), 0);
        assertEq(fantasyCards.balanceOf(user2), 1);
    }

    function test_unsuccessful_buy_paymentToken_not_whitelisted() public {
        // Create order
        OrderLib.Order memory sellOrder = OrderLib.Order(
            user1,
            OrderLib.Side.Sell,
            address(fantasyCards),
            0,
            address(1),
            1 ether,
            999999999999999999999,
            bytes32(0),
            100_001
        );

        // Sign order
        bytes32 orderHash = HashLib.getTypedDataHash(sellOrder, exchange.domainSeparator());
        (uint8 vSeller, bytes32 rSeller, bytes32 sSeller) = vm.sign(user1PrivateKey, orderHash);
        bytes memory sellerSignature = abi.encodePacked(rSeller, sSeller, vSeller);

        cheats.deal(user2, 1 ether);

        cheats.startPrank(user2, user2);
        cheats.expectRevert("Invalid payment token");
        exchange.buy{value: 1 ether}(sellOrder, sellerSignature, false);
        cheats.stopPrank();
    }

    function test_unsuccesful_buy_collection_not_whitelisted() public {
        // Create order
        OrderLib.Order memory sellOrder = OrderLib.Order(
            user1,
            OrderLib.Side.Sell,
            address(1),
            0,
            address(0),
            1 ether,
            999999999999999999999,
            bytes32(0),
            100_001
        );

        // Sign order
        bytes32 orderHash = HashLib.getTypedDataHash(sellOrder, exchange.domainSeparator());
        (uint8 vSeller, bytes32 rSeller, bytes32 sSeller) = vm.sign(user1PrivateKey, orderHash);
        bytes memory sellerSignature = abi.encodePacked(rSeller, sSeller, vSeller);

        cheats.deal(user2, 1 ether);

        cheats.startPrank(user2, user2);
        cheats.expectRevert("Collection is not whitelisted");
        exchange.buy{value: 1 ether}(sellOrder, sellerSignature, false);
        cheats.stopPrank();
    }

    function test_unsuccessful_buy_invalid_order_side() public {
        // Create order
        OrderLib.Order memory sellOrder = OrderLib.Order(
            user1,
            OrderLib.Side.Buy,
            address(fantasyCards),
            0,
            address(0),
            1 ether,
            999999999999999999999,
            bytes32(0),
            100_001
        );

        // Sign order
        bytes32 orderHash = HashLib.getTypedDataHash(sellOrder, exchange.domainSeparator());
        (uint8 vSeller, bytes32 rSeller, bytes32 sSeller) = vm.sign(user1PrivateKey, orderHash);
        bytes memory sellerSignature = abi.encodePacked(rSeller, sSeller, vSeller);

        cheats.deal(user2, 1 ether);

        cheats.startPrank(user2, user2);
        cheats.expectRevert("order must be a sell");
        exchange.buy{value: 1 ether}(sellOrder, sellerSignature, false);
        cheats.stopPrank();
    }

    function test_unsuccessful_buy_expired_order() public {
        // Create order
        OrderLib.Order memory sellOrder = OrderLib.Order(
            user1,
            OrderLib.Side.Sell,
            address(fantasyCards),
            0,
            address(0),
            1 ether,
            0,
            bytes32(0),
            100_001
        );

        // Sign order
        bytes32 orderHash = HashLib.getTypedDataHash(sellOrder, exchange.domainSeparator());
        (uint8 vSeller, bytes32 rSeller, bytes32 sSeller) = vm.sign(user1PrivateKey, orderHash);
        bytes memory sellerSignature = abi.encodePacked(rSeller, sSeller, vSeller);

        cheats.deal(user2, 1 ether);

        cheats.startPrank(user2, user2);
        cheats.expectRevert("order expired");
        exchange.buy{value: 1 ether}(sellOrder, sellerSignature, false);
        cheats.stopPrank();
    }

    function test_unsuccessful_buy_invalid_trader() public {
        // Create order
        OrderLib.Order memory sellOrder = OrderLib.Order(
            address(0),
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
        bytes32 orderHash = HashLib.getTypedDataHash(sellOrder, exchange.domainSeparator());
        (uint8 vSeller, bytes32 rSeller, bytes32 sSeller) = vm.sign(user1PrivateKey, orderHash);
        bytes memory sellerSignature = abi.encodePacked(rSeller, sSeller, vSeller);

        cheats.deal(user2, 1 ether);

        // Execute buy
        cheats.startPrank(user2, user2);
        cheats.expectRevert("order trader is 0");
        exchange.buy{value: 1 ether}(sellOrder, sellerSignature, false);
        cheats.stopPrank();
    }

    function test_unsuccessful_buy_canceled_order() public {
        // Create order
        OrderLib.Order memory sellOrder = OrderLib.Order(
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
        bytes32 orderHash = HashLib.getTypedDataHash(sellOrder, exchange.domainSeparator());
        (uint8 vSeller, bytes32 rSeller, bytes32 sSeller) = vm.sign(user1PrivateKey, orderHash);
        bytes memory sellerSignature = abi.encodePacked(rSeller, sSeller, vSeller);

        cheats.deal(user2, 1 ether);

        cheats.startPrank(user1);
        exchange.cancelOrder(sellOrder);
        cheats.stopPrank();

        cheats.startPrank(user2, user2);
        cheats.expectRevert("sell order cancelled or filled");
        exchange.buy{value: 1 ether}(sellOrder, sellerSignature, false);
        cheats.stopPrank();
    }

    function test_unsuccessful_buy_filled_order() public {
        // Create order
        OrderLib.Order memory sellOrder = OrderLib.Order(
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
        bytes32 orderHash = HashLib.getTypedDataHash(sellOrder, exchange.domainSeparator());
        (uint8 vSeller, bytes32 rSeller, bytes32 sSeller) = vm.sign(user1PrivateKey, orderHash);
        bytes memory sellerSignature = abi.encodePacked(rSeller, sSeller, vSeller);

        cheats.deal(user2, 2 ether);

        cheats.startPrank(user2, user2);
        exchange.buy{value: 1 ether}(sellOrder, sellerSignature, false);
        cheats.expectRevert("sell order cancelled or filled");
        exchange.buy{value: 1 ether}(sellOrder, sellerSignature, false);
        cheats.stopPrank();
    }

    function test_unsuccessful_buy_invalid_signature() public {
        // Create order
        OrderLib.Order memory sellOrder = OrderLib.Order(
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
        bytes32 orderHash = HashLib.getTypedDataHash(sellOrder, exchange.domainSeparator());
        (uint8 vSeller, bytes32 rSeller, bytes32 sSeller) = vm.sign(user2PrivateKey, orderHash);
        bytes memory sellerSignature = abi.encodePacked(rSeller, sSeller, vSeller);

        cheats.deal(user2, 1 ether);

        cheats.startPrank(user2, user2);
        cheats.expectRevert("invalid signature");
        exchange.buy{value: 1 ether}(sellOrder, sellerSignature, false);
        cheats.stopPrank();
    }

    function test_unsuccessful_buy_not_EOA() public {
        // Create order
        OrderLib.Order memory sellOrder = OrderLib.Order(
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
        bytes32 orderHash = HashLib.getTypedDataHash(sellOrder, exchange.domainSeparator());
        (uint8 vSeller, bytes32 rSeller, bytes32 sSeller) = vm.sign(user1PrivateKey, orderHash);
        bytes memory sellerSignature = abi.encodePacked(rSeller, sSeller, vSeller);

        // DEPLOY TRADER CONTRACT
        TraderContract traderContract = new TraderContract(address(exchange), address(minter));

        cheats.deal(user2, 1 ether);

        cheats.startPrank(user2, user2);
        cheats.expectRevert("Function can only be called by an EOA");
        traderContract.buyOnExchange{value: 1 ether}(sellOrder, sellerSignature);
        cheats.stopPrank();
    }

    function test_unsuccessful_buy_price_bellow_minimumPrice() public {
        // Create order
        OrderLib.Order memory sellOrder = OrderLib.Order(
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
        bytes32 orderHash = HashLib.getTypedDataHash(sellOrder, exchange.domainSeparator());
        (uint8 vSeller, bytes32 rSeller, bytes32 sSeller) = vm.sign(user1PrivateKey, orderHash);
        bytes memory sellerSignature = abi.encodePacked(rSeller, sSeller, vSeller);

        exchange.whiteListPaymentToken(address(0), sellOrder.price + 1);

        cheats.deal(user2, 1 ether);

        cheats.startPrank(user2, user2);
        cheats.expectRevert("price bellow minimumPrice");
        exchange.buy{value: 1 ether}(sellOrder, sellerSignature, false);
        cheats.stopPrank();
    }

    function test_unsuccessful_buy_salt_bellow_100_000() public {
        // Create order
        OrderLib.Order memory sellOrder = OrderLib.Order(
            user1,
            OrderLib.Side.Sell,
            address(fantasyCards),
            0,
            address(0),
            1 ether,
            999999999999999999999,
            bytes32(0),
            100_000
        );

        // Sign order
        bytes32 orderHash = HashLib.getTypedDataHash(sellOrder, exchange.domainSeparator());
        (uint8 vSeller, bytes32 rSeller, bytes32 sSeller) = vm.sign(user1PrivateKey, orderHash);
        bytes memory sellerSignature = abi.encodePacked(rSeller, sSeller, vSeller);

        cheats.deal(user2, 1 ether);

        cheats.startPrank(user2, user2);
        cheats.expectRevert("salt should be above 100_000");
        exchange.buy{value: 1 ether}(sellOrder, sellerSignature, false);
        cheats.stopPrank();
    }

    function test_successful_buy_WETH_with_burn() public {
        // Create order
        OrderLib.Order memory sellOrder = OrderLib.Order(
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
        bytes32 orderHash = HashLib.getTypedDataHash(sellOrder, exchange.domainSeparator());
        (uint8 vSeller, bytes32 rSeller, bytes32 sSeller) = vm.sign(user1PrivateKey, orderHash);
        bytes memory sellerSignature = abi.encodePacked(rSeller, sSeller, vSeller);

        // Give WETH allowance
        cheats.startPrank(user2);
        weth.getFaucet(1 ether);
        weth.approve(address(executionDelegate), 1 ether);
        cheats.stopPrank();

        // Execute buy with burn=true
        cheats.startPrank(user2, user2);
        exchange.buy(sellOrder, sellerSignature, true);
        cheats.stopPrank();

        // Check balances
        assertEq(
            weth.balanceOf(treasury),
            (sellOrder.price * exchange.protocolFeeBps()) / exchange.INVERSE_BASIS_POINT()
        );
        assertEq(weth.balanceOf(user1), 1 ether - weth.balanceOf(treasury));
        assertEq(weth.balanceOf(user2), 0);
        assertEq(fantasyCards.balanceOf(user1), 0);
        // Check that the NFT was burned (neither user1 nor user2 should have it)
        assertEq(fantasyCards.balanceOf(user2), 0);
        // Verify that the token doesn't exist anymore
        vm.expectRevert(abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 0));
        fantasyCards.ownerOf(0);
    }
}
