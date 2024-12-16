pragma solidity ^0.8.20;

import "../base/BaseTest.t.sol";
import "../../src/libraries/OrderLib.sol";

contract BatchCancelOrders is BaseTest {
    OrderLib.Order[] orders;

    function setUp() public override {
        super.setUp();

        OrderLib.Order memory order1 = OrderLib.Order(
            user1,
            OrderLib.Side.Sell,
            address(fantasyCards),
            0,
            address(weth),
            1 ether,
            999999999999999999999,
            bytes32(0),
            0
        );

        OrderLib.Order memory order2 = OrderLib.Order(
            user1,
            OrderLib.Side.Sell,
            address(fantasyCards),
            0,
            address(weth),
            2 ether,
            999999999999999999999,
            bytes32(0),
            0
        );

        orders.push(order1);
        orders.push(order2);
    }

    function test_successful_batchCancelOrder() public {
        // cancel order
        cheats.startPrank(user1);
        exchange.batchCancelOrders(orders);
        cheats.stopPrank();

        bytes32 orderHash0 = OrderLib._hashOrder(orders[0]);
        bytes32 orderHash1 = OrderLib._hashOrder(orders[1]);

        assertEq(exchange.cancelledOrFilled(orderHash0), true);
        assertEq(exchange.cancelledOrFilled(orderHash1), true);
    }

    function test_unsuccessful_batchCancelOrder_wrong_trader() public {
        cheats.startPrank(user2);
        cheats.expectRevert("msg.sender is not the trader");
        exchange.batchCancelOrders(orders);
        cheats.stopPrank();
    }
}