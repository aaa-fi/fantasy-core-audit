pragma solidity ^0.8.20;

import "../base/BaseTest.t.sol";

contract BatchBurnToDraw is BaseTest {
    function setUp() public override {
        super.setUp();
        cheats.startPrank(address(executionDelegate));
        for (uint256 i = 0; i < 30; i++) {
            fantasyCards.safeMint(user1);
        }
        cheats.stopPrank();
    }

    function test_successful_batchBurnToDraw() public {
        uint256 cardsRequiredForBurnToDraw = minter.cardsRequiredForBurnToDraw();
        console.log("cardsRequiredForBurnToDraw", cardsRequiredForBurnToDraw);
        uint256[][] memory tokenIdsBatch = new uint256[][](2);
        tokenIdsBatch[0] = new uint256[](cardsRequiredForBurnToDraw);
        tokenIdsBatch[1] = new uint256[](cardsRequiredForBurnToDraw);

        for (uint256 i = 0; i < cardsRequiredForBurnToDraw; i++) {
            tokenIdsBatch[0][i] = i;
            tokenIdsBatch[1][i] = i + cardsRequiredForBurnToDraw;
        }

        address collection = address(fantasyCards);
        cheats.startPrank(user1, user1);
        minter.batchBurnToDraw(tokenIdsBatch, collection);
        cheats.stopPrank();

        // Verify that the tokens have been burned and new ones minted
        for (uint256 j = 0; j < 2; j++) {
            for (uint256 i = 0; i < cardsRequiredForBurnToDraw; i++) {
                cheats.expectRevert(); // TODO: proper revert message
                fantasyCards.ownerOf(i + (j * cardsRequiredForBurnToDraw));
            }
        }
        assertEq(fantasyCards.ownerOf(cardsRequiredForBurnToDraw * 2), user1);
        assertEq(fantasyCards.ownerOf(cardsRequiredForBurnToDraw * 2 + 1), user1);
        assertEq(fantasyCards.tokenCounter(), cardsRequiredForBurnToDraw * 2 + 2);
    }

    function test_unsuccessful_batchBurnToDraw_wrongCardNumber() public {
        uint256 cardsRequiredForBurnToDraw = minter.cardsRequiredForBurnToDraw();
        uint256[][] memory tokenIdsBatch = new uint256[][](1);
        uint256[] memory tokenIds = new uint256[](cardsRequiredForBurnToDraw - 1);

        for (uint256 i = 0; i < cardsRequiredForBurnToDraw - 1; i++) {
            tokenIds[i] = i;
        }

        tokenIdsBatch[0] = tokenIds;
        address collection = address(fantasyCards);
        cheats.startPrank(user1);
        cheats.expectRevert("wrong amount of cards to draw new cards");
        minter.batchBurnToDraw(tokenIdsBatch, collection);
        cheats.stopPrank();
    }

    function test_unsuccessful_batchBurnToDraw_userNotOwner() public {
        uint256 cardsRequiredForBurnToDraw = minter.cardsRequiredForBurnToDraw();
        uint256[][] memory tokenIdsBatch = new uint256[][](1);
        uint256[] memory tokenIds = new uint256[](cardsRequiredForBurnToDraw);

        for (uint256 i = 0; i < cardsRequiredForBurnToDraw; i++) {
            tokenIds[i] = i;
        }

        tokenIdsBatch[0] = tokenIds;
        address collection = address(fantasyCards);
        cheats.startPrank(user2);
        cheats.expectRevert("caller does not own one of the tokens");
        minter.batchBurnToDraw(tokenIdsBatch, collection);
        cheats.stopPrank();
    }

    function test_unsuccessful_batchBurnToDraw_collection_not_whitelisted() public {
        uint256 cardsRequiredForBurnToDraw = minter.cardsRequiredForBurnToDraw();
        uint256[][] memory tokenIdsBatch = new uint256[][](1);
        uint256[] memory tokenIds = new uint256[](cardsRequiredForBurnToDraw);

        for (uint256 i = 0; i < cardsRequiredForBurnToDraw; i++) {
            tokenIds[i] = i;
        }

        tokenIdsBatch[0] = tokenIds;
        cheats.startPrank(user1);
        cheats.expectRevert("Collection is not whitelisted");
        minter.batchBurnToDraw(tokenIdsBatch, address(0));
        cheats.stopPrank();
    }

    function test_unsuccessful_batchBurnToDraw_different_array_lengths() public {
        uint256 cardsRequiredForBurnToDraw = minter.cardsRequiredForBurnToDraw();
        uint256[][] memory tokenIdsBatch = new uint256[][](2);
        tokenIdsBatch[0] = new uint256[](cardsRequiredForBurnToDraw);
        tokenIdsBatch[1] = new uint256[](cardsRequiredForBurnToDraw - 1); // Different length

        for (uint256 i = 0; i < cardsRequiredForBurnToDraw - 1; i++) {
            tokenIdsBatch[0][i] = i;
            tokenIdsBatch[1][i] = i + cardsRequiredForBurnToDraw;
        }
        // Add the last element to the first array
        tokenIdsBatch[0][cardsRequiredForBurnToDraw - 1] = cardsRequiredForBurnToDraw - 1;

        address collection = address(fantasyCards);
        cheats.startPrank(user1);
        cheats.expectRevert("wrong amount of cards to draw new cards");
        minter.batchBurnToDraw(tokenIdsBatch, collection);
        cheats.stopPrank();
    }
}
