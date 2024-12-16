pragma solidity ^0.8.20;

import "../base/BaseTest.t.sol";
import "../../src/libraries/OrderLib.sol";
import "../helpers/HashLib.sol";
import "../helpers/TraderContract.sol";

contract Sell is BaseTest {
    function setUp() public override {
        super.setUp();

        cheats.startPrank(address(executionDelegate));
        fantasyCards.safeMint(user2); // 0
        fantasyCards.safeMint(user2); // 1
        cheats.stopPrank();

        cheats.startPrank(user2);
        fantasyCards.setApprovalForAll(address(executionDelegate), true);
        cheats.stopPrank();
    }

    function _createMerkleRootAndProof(uint256[] memory tokenIds) internal pure returns (bytes32, bytes32[][] memory) {
        bytes32[] memory leaves = new bytes32[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(tokenIds[i]));
        }
        
        bytes32 merkleRoot;
        bytes32[][] memory proofs = new bytes32[][](tokenIds.length);
        
        if (tokenIds.length == 1) {
            // For single token, the merkle root is just the hash of the token ID
            merkleRoot = leaves[0];
            proofs[0] = new bytes32[](0); // Empty proof for single token
        } else {
            // For multiple tokens, create merkle root and proofs as before
            merkleRoot = keccak256(abi.encodePacked(leaves[0], leaves[1]));
            
            proofs[0] = new bytes32[](1);
            proofs[0][0] = leaves[1];
            proofs[1] = new bytes32[](1);
            proofs[1][0] = leaves[0];
        }
        
        return (merkleRoot, proofs);
    }

    function _createBuyOrder(
        uint256 _tokenId,
        uint256 _price,
        bytes32 _merkleRoot
    ) internal view returns (OrderLib.Order memory, bytes memory) {
        OrderLib.Order memory buyOrder = OrderLib.Order(
            user1,
            OrderLib.Side.Buy,
            address(fantasyCards),
            _tokenId,
            address(weth),
            _price,
            999999999999999999999,
            _merkleRoot,
            100_001
        );

        bytes32 orderHash = HashLib.getTypedDataHash(buyOrder, exchange.domainSeparator());
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user1PrivateKey, orderHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        return (buyOrder, signature);
    }

    function test_successful_batchSell_WETH() public {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        
        (bytes32 merkleRoot, bytes32[][] memory merkleProofs) = _createMerkleRootAndProof(tokenIds);
        
        // Create orders with the merkle root
        (OrderLib.Order memory buyOrder1, bytes memory buyerSignature1) = _createBuyOrder(0, 1 ether, merkleRoot);
        (OrderLib.Order memory buyOrder2, bytes memory buyerSignature2) = _createBuyOrder(1, 2 ether, merkleRoot);

        uint256 totalPrice = buyOrder1.price + buyOrder2.price;

        // Setup WETH for buyer
        cheats.startPrank(user1);
        weth.getFaucet(totalPrice);
        weth.approve(address(executionDelegate), totalPrice);
        cheats.stopPrank();

        // Setup arrays for batch sell
        OrderLib.Order[] memory buyOrders = new OrderLib.Order[](2);
        buyOrders[0] = buyOrder1;
        buyOrders[1] = buyOrder2;

        bytes[] memory buyerSignatures = new bytes[](2);
        buyerSignatures[0] = buyerSignature1;
        buyerSignatures[1] = buyerSignature2;

        // Execute sell
        cheats.startPrank(user2, user2);
        exchange.batchSell(buyOrders, buyerSignatures, tokenIds, merkleProofs);
        cheats.stopPrank();

        // Assertions
        assertEq(weth.balanceOf(treasury), (totalPrice * exchange.protocolFeeBps()) / exchange.INVERSE_BASIS_POINT());
        assertEq(weth.balanceOf(user2), totalPrice - weth.balanceOf(treasury));
        assertEq(weth.balanceOf(user1), 0);
        assertEq(fantasyCards.balanceOf(user2), 0);
        assertEq(fantasyCards.balanceOf(user1), 2);
    }

    function test_unsuccessful_batchSell_ETH_payment_token() public {
        bytes32[] memory proof1 = new bytes32[](0);

        // Create buy order with ETH as payment token (not allowed)
        OrderLib.Order memory buyOrder1 = OrderLib.Order(
            user1,
            OrderLib.Side.Buy,
            address(fantasyCards),
            0,
            address(0), // ETH address
            1 ether,
            999999999999999999999,
            bytes32(0),
            100_001
        );

        // Sign order
        bytes32 orderHash1 = HashLib.getTypedDataHash(buyOrder1, exchange.domainSeparator());
        (uint8 vBuyer1, bytes32 rBuyer1, bytes32 sBuyer1) = vm.sign(user1PrivateKey, orderHash1);
        bytes memory buyerSignature1 = abi.encodePacked(rBuyer1, sBuyer1, vBuyer1);

        OrderLib.Order[] memory buyOrders = new OrderLib.Order[](1);
        buyOrders[0] = buyOrder1;
        bytes[] memory buyerSignatures = new bytes[](1);
        buyerSignatures[0] = buyerSignature1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        bytes32[][] memory merkleProofs = new bytes32[][](1);
        merkleProofs[0] = proof1;

        // Execute sell
        cheats.startPrank(user2, user2);
        cheats.expectRevert("payment token can not be ETH for buy order");
        exchange.batchSell(buyOrders, buyerSignatures, tokenIds, merkleProofs);
        cheats.stopPrank();
    }

    function test_unsuccessful_batchSell_array_length_mismatch() public {
        OrderLib.Order[] memory buyOrders = new OrderLib.Order[](3);
        bytes[] memory buyerSignatures = new bytes[](2);
        uint256[] memory tokenIds = new uint256[](2);
        bytes32[][] memory merkleProofs = new bytes32[][](2);

        // Execute sell
        cheats.startPrank(user2, user2);
        cheats.expectRevert("Array length mismatch");
        exchange.batchSell(buyOrders, buyerSignatures, tokenIds, merkleProofs);
        cheats.stopPrank();
    }

    function test_unsuccessful_batchSell_expired_order() public {
        bytes32[] memory proof1 = new bytes32[](0);

        // Create expired buy order
        OrderLib.Order memory buyOrder1 = OrderLib.Order(
            user1,
            OrderLib.Side.Buy,
            address(fantasyCards),
            0,
            address(weth),
            1 ether,
            block.timestamp - 1, // expired
            bytes32(0),
            100_001
        );

        // Sign order
        bytes32 orderHash1 = HashLib.getTypedDataHash(buyOrder1, exchange.domainSeparator());
        (uint8 vBuyer1, bytes32 rBuyer1, bytes32 sBuyer1) = vm.sign(user1PrivateKey, orderHash1);
        bytes memory buyerSignature1 = abi.encodePacked(rBuyer1, sBuyer1, vBuyer1);

        OrderLib.Order[] memory buyOrders = new OrderLib.Order[](1);
        buyOrders[0] = buyOrder1;
        bytes[] memory buyerSignatures = new bytes[](1);
        buyerSignatures[0] = buyerSignature1;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        bytes32[][] memory merkleProofs = new bytes32[][](1);
        merkleProofs[0] = proof1;

        // Execute sell
        cheats.startPrank(user2, user2);
        cheats.expectRevert("order expired");
        exchange.batchSell(buyOrders, buyerSignatures, tokenIds, merkleProofs);
        cheats.stopPrank();
    }

    function test_unsuccessful_batchSell_invalid_merkle_proof() public {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 0;
        tokenIds[1] = 1;
        
        (bytes32 merkleRoot, bytes32[][] memory merkleProofs) = _createMerkleRootAndProof(tokenIds);
        
        // Create orders with the merkle root
        (OrderLib.Order memory buyOrder1, bytes memory buyerSignature1) = _createBuyOrder(0, 1 ether, merkleRoot);
        (OrderLib.Order memory buyOrder2, bytes memory buyerSignature2) = _createBuyOrder(1, 2 ether, merkleRoot);

        uint256 totalPrice = buyOrder1.price + buyOrder2.price;

        // Setup WETH for buyer
        cheats.startPrank(user1, user1);
        weth.getFaucet(totalPrice);
        weth.approve(address(executionDelegate), totalPrice);
        cheats.stopPrank();

        OrderLib.Order[] memory buyOrders = new OrderLib.Order[](2);
        buyOrders[0] = buyOrder1;
        buyOrders[1] = buyOrder2;

        bytes[] memory buyerSignatures = new bytes[](2);
        buyerSignatures[0] = buyerSignature1;
        buyerSignatures[1] = buyerSignature2;

        // Tamper with merkle proofs
        merkleProofs[0][0] = bytes32(uint256(1234));

        cheats.startPrank(user2, user2);
        cheats.expectRevert("invalid tokenId");
        exchange.batchSell(buyOrders, buyerSignatures, tokenIds, merkleProofs);
        cheats.stopPrank();
    }

    function test_unsuccessful_batchSell_unauthorized_seller() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        
        (bytes32 merkleRoot, bytes32[][] memory merkleProofs) = _createMerkleRootAndProof(tokenIds);
        
        (OrderLib.Order memory buyOrder, bytes memory buyerSignature) = _createBuyOrder(0, 1 ether, merkleRoot);

        // Setup WETH for buyer
        cheats.startPrank(user1, user1);
        weth.getFaucet(1 ether);
        weth.approve(address(executionDelegate), 1 ether);
        cheats.stopPrank();

        OrderLib.Order[] memory buyOrders = new OrderLib.Order[](1);
        buyOrders[0] = buyOrder;

        bytes[] memory buyerSignatures = new bytes[](1);
        buyerSignatures[0] = buyerSignature;

        cheats.startPrank(user3, user3);
        cheats.expectRevert(abi.encodeWithSignature(
            "ERC721IncorrectOwner(address,uint256,address)",
            user3,  // from address (incorrect owner)
            0,      // tokenId
            user2   // actual owner
        ));
        exchange.batchSell(buyOrders, buyerSignatures, tokenIds, merkleProofs);
        cheats.stopPrank();
    }

    function test_unsuccessful_batchSell_insufficient_buyer_balance() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        
        bytes32[][] memory merkleProofs = new bytes32[][](1);
        merkleProofs[0] = new bytes32[](0);
        
        // Create order with high price
        (OrderLib.Order memory buyOrder, bytes memory buyerSignature) = _createBuyOrder(0, 1000000 ether, bytes32(0));

        OrderLib.Order[] memory buyOrders = new OrderLib.Order[](1);
        buyOrders[0] = buyOrder;

        bytes[] memory buyerSignatures = new bytes[](1);
        buyerSignatures[0] = buyerSignature;

        // Don't fund the buyer with enough WETH
        cheats.startPrank(user1);
        weth.getFaucet(1 ether);
        weth.approve(address(executionDelegate), 1000000 ether);
        cheats.stopPrank();

        cheats.startPrank(user2, user2);
        cheats.expectRevert();  // ERC20 transfer will fail
        exchange.batchSell(buyOrders, buyerSignatures, tokenIds, merkleProofs);
        cheats.stopPrank();
    }

    function test_successful_batchSell_single_token() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        
        // bytes32[][] memory merkleProofs = new bytes32[][](1);
        // merkleProofs[0] = new bytes32[](0);

        (bytes32 merkleRoot, bytes32[][] memory merkleProofs) = _createMerkleRootAndProof(tokenIds);
        
        (OrderLib.Order memory buyOrder, bytes memory buyerSignature) = _createBuyOrder(0, 1 ether,merkleRoot);

        // Setup WETH for buyer
        cheats.startPrank(user1);
        weth.getFaucet(1 ether);
        weth.approve(address(executionDelegate), 1 ether);
        cheats.stopPrank();

        OrderLib.Order[] memory buyOrders = new OrderLib.Order[](1);
        buyOrders[0] = buyOrder;

        bytes[] memory buyerSignatures = new bytes[](1);
        buyerSignatures[0] = buyerSignature;

        uint256 initialBalance = weth.balanceOf(user2);

        cheats.startPrank(user2, user2);
        exchange.batchSell(buyOrders, buyerSignatures, tokenIds, merkleProofs);
        cheats.stopPrank();

        assertEq(fantasyCards.ownerOf(0), user1);
        assertEq(weth.balanceOf(user2), initialBalance + 1 ether - (1 ether * exchange.protocolFeeBps()) / exchange.INVERSE_BASIS_POINT());
    }

    function test_unsuccessful_batchSell_reused_order() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;
        
        bytes32[][] memory merkleProofs = new bytes32[][](1);
        merkleProofs[0] = new bytes32[](0);

        (bytes32 merkleRoot,) = _createMerkleRootAndProof(tokenIds);
        
        (OrderLib.Order memory buyOrder, bytes memory buyerSignature) = _createBuyOrder(0, 1 ether, merkleRoot);

        // Setup WETH for buyer
        cheats.startPrank(user1);
        weth.getFaucet(2 ether); // Extra WETH for potential second transaction
        weth.approve(address(executionDelegate), 2 ether);
        cheats.stopPrank();

        OrderLib.Order[] memory buyOrders = new OrderLib.Order[](1);
        buyOrders[0] = buyOrder;

        bytes[] memory buyerSignatures = new bytes[](1);
        buyerSignatures[0] = buyerSignature;

        // First execution
        cheats.startPrank(user2, user2);
        exchange.batchSell(buyOrders, buyerSignatures, tokenIds, merkleProofs);
        
        // Try to execute the same order again
        cheats.expectRevert("buy order cancelled or filled");
        exchange.batchSell(buyOrders, buyerSignatures, tokenIds, merkleProofs);
        cheats.stopPrank();
    }
}
