pragma solidity ^0.8.20;

import "../base/BaseTest.t.sol";

contract NewMintConfig is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_successful_newMintConfig() public {
        minter.whiteListCollection(address(0x1));
        // Act
        cheats.startPrank(mintConfigMaster);
        minter.newMintConfig(
            address(0x1),
            10,
            100,
            address(0x2),
            100,
            12,
            true,
            0x3000000000000000000000000000000000000000000000000000000000000000,
            block.timestamp,
            block.timestamp + 7 days
        );
        cheats.stopPrank();

        // Assert
        (
            address actualCollection,
            uint256 actualCardsPerPack,
            uint256 actualMaxPacks,
            address actualPaymentToken,
            uint256 actualPrice,
            uint256 actualMaxPacksPerAddress,
            bool actualRequiresWhitelist,
            bytes32 actualMerkleRoot,
            uint256 actualStartTimestamp,
            uint256 actualExpirationTimestamp,
            uint256 actualTotalMintedPacks,
            bool actualCancelled
        ) = minter.getMintConfig(0);

        assertEq(actualCollection, address(0x1));
        assertEq(actualCardsPerPack, 10);
        assertEq(actualMaxPacks, 100);
        assertEq(actualPaymentToken, address(0x2));
        assertEq(actualPrice, 100);
        assertEq(actualMaxPacksPerAddress, 12);
        assertEq(actualRequiresWhitelist, true);
        assertEq(actualMerkleRoot, 0x3000000000000000000000000000000000000000000000000000000000000000);
        assertEq(actualStartTimestamp, block.timestamp);
        assertEq(actualExpirationTimestamp, block.timestamp + 7 days);
        assertEq(actualTotalMintedPacks, 0);
        assertEq(actualCancelled, false);
    }

    function test_mintConfigIdCounter() public {
        minter.whiteListCollection(address(0x1));
        // Arrange
        address collection = address(0x1);
        uint256 cardsPerPack = 10;
        uint256 maxPacks = 100;
        address paymentToken = address(0x2);
        uint256 fixedPrice = 100;
        uint256 maxPacksPerAddress = 0;
        bool requiresWhitelist = true;
        bytes32 merkleRoot = 0x3000000000000000000000000000000000000000000000000000000000000000;
        uint256 startTimestamp = block.timestamp;
        uint256 expirationTimestamp = block.timestamp + 7 days;

        // Act
        cheats.startPrank(mintConfigMaster);
        minter.newMintConfig(
            collection,
            cardsPerPack,
            maxPacks,
            paymentToken,
            fixedPrice,
            maxPacksPerAddress,
            requiresWhitelist,
            merkleRoot,
            startTimestamp,
            expirationTimestamp
        );
        cheats.stopPrank();

        // Assert
        assertEq(minter.mintConfigIdCounter(), 1);
    }

    function test_unauthorized_newMintConfig() public {
        // Arrange
        address collection = address(0x1);
        uint256 cardsPerPack = 10;
        uint256 maxPacks = 100;
        address paymentToken = address(0x2);
        uint256 fixedPrice = 100;
        uint256 maxPacksPerAddress = 0;
        bool requiresWhitelist = true;
        bytes32 merkleRoot = 0x3000000000000000000000000000000000000000000000000000000000000000;
        uint256 startTimestamp = block.timestamp;
        uint256 expirationTimestamp = block.timestamp + 7 days;

        cheats.startPrank(user1);
        cheats.expectRevert(); // REVIEW: proper error message?
        minter.newMintConfig(
            collection,
            cardsPerPack,
            maxPacks,
            paymentToken,
            fixedPrice,
            maxPacksPerAddress,
            requiresWhitelist,
            merkleRoot,
            startTimestamp,
            expirationTimestamp
        );
        cheats.stopPrank();
    }
}
