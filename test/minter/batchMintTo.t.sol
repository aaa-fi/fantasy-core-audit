pragma solidity ^0.8.20;

import "../base/BaseTest.t.sol";
import "../helpers/TraderContract.sol";

contract BatchMintTo is BaseTest {
    struct MintConfig {
        address collection;
        uint256 cardsPerPack;
        uint256 maxPacks;
        address paymentToken;
        uint256 fixedPrice;
        uint256 maxPacksPerAddress;
        bool requiresWhitelist;
        bytes32 merkleRoot;
        uint256 startTimestamp;
        uint256 expirationTimestamp;
    }

    function setUp() public override {
        super.setUp();
    }

    function test_batchMintTo() public {
        address[] memory recipients = new address[](2);
        recipients[0] = user1;
        recipients[1] = user2;

        MintConfig memory mintConfig;
        mintConfig.collection = address(fantasyCards);
        mintConfig.cardsPerPack = 80;
        mintConfig.maxPacks = 10;
        mintConfig.paymentToken = address(weth);
        mintConfig.fixedPrice = 0;
        mintConfig.maxPacksPerAddress = 0;
        mintConfig.requiresWhitelist = false;
        mintConfig.merkleRoot = bytes32(0);
        mintConfig.startTimestamp = block.timestamp;
        mintConfig.expirationTimestamp = 0;

        cheats.startPrank(mintConfigMaster, mintConfigMaster);
        minter.newMintConfig(
            mintConfig.collection,
            mintConfig.cardsPerPack,
            mintConfig.maxPacks,
            mintConfig.paymentToken,
            mintConfig.fixedPrice,
            mintConfig.maxPacksPerAddress,
            mintConfig.requiresWhitelist,
            mintConfig.merkleRoot,
            mintConfig.startTimestamp,
            mintConfig.expirationTimestamp
        );
        
        minter.batchMintCardsTo(0, new bytes32[](0), 1 ether, recipients);
        cheats.stopPrank();

        assertEq(fantasyCards.balanceOf(user1), mintConfig.cardsPerPack);
        assertEq(fantasyCards.balanceOf(user2), mintConfig.cardsPerPack);
    }
}