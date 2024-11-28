pragma solidity ^0.8.20;

import "../base/BaseTest.t.sol";
import "../../src/libraries/OrderLib.sol";
import "../helpers/HashLib.sol";

contract Buy_fuzz is BaseTest {
    function setUp() public override {
        super.setUp();

        cheats.startPrank(address(executionDelegate));
        fantasyCards.safeMint(user1);
        cheats.stopPrank();

        cheats.startPrank(user1);
        fantasyCards.approve(address(executionDelegate), 0);
        cheats.stopPrank();
    }

    function test_successful_buy_WETH_fuzz(uint256 _price) public {
        if (_price > 120000000 ether) return;

        // Create order
        OrderLib.Order memory sellOrder = OrderLib.Order(
            user1,
            OrderLib.Side.Sell,
            address(fantasyCards),
            0,
            address(weth),
            _price,
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
        weth.getFaucet(sellOrder.price);
        weth.approve(address(executionDelegate), sellOrder.price);
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
        assertEq(weth.balanceOf(user1), sellOrder.price - weth.balanceOf(treasury));
        assertEq(weth.balanceOf(user2), 0);
        assertEq(fantasyCards.balanceOf(user1), 0);
        assertEq(fantasyCards.balanceOf(user2), 1);
    }

    function test_successful_buy_ETH_fuzz(uint256 _price) public {
        if (_price > 120000000 ether) return;

        // Create order
        OrderLib.Order memory sellOrder = OrderLib.Order(
            user1,
            OrderLib.Side.Sell,
            address(fantasyCards),
            0,
            address(0),
            _price,
            999999999999999999999,
            bytes32(0),
            100_001
        );

        // Sign order
        bytes32 orderHash = HashLib.getTypedDataHash(sellOrder, exchange.domainSeparator());
        (uint8 vSeller, bytes32 rSeller, bytes32 sSeller) = vm.sign(user1PrivateKey, orderHash);
        bytes memory sellerSignature = abi.encodePacked(rSeller, sSeller, vSeller);

        cheats.deal(user2, sellOrder.price);

        // Execute buy
        cheats.startPrank(user2, user2);
        exchange.buy{value: sellOrder.price}(sellOrder, sellerSignature, false);
        cheats.stopPrank();

        // Check balances
        assertEq(treasury.balance, (sellOrder.price * exchange.protocolFeeBps()) / exchange.INVERSE_BASIS_POINT());
        assertEq(user1.balance, sellOrder.price - treasury.balance);
        assertEq(user2.balance, 0);
        assertEq(fantasyCards.balanceOf(user1), 0);
        assertEq(fantasyCards.balanceOf(user2), 1);
    }
}
