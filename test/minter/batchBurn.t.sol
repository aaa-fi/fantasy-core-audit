pragma solidity ^0.8.20;

import "../base/BaseTest.t.sol";

contract BatchBurn is BaseTest {
    function setUp() public override {
        super.setUp();
        cheats.startPrank(address(executionDelegate));
        for (uint256 i = 0; i < 15; i++) {
            fantasyCards.safeMint(user1);
        }
        cheats.stopPrank();
    }

    function test_successful_batchBurn() public {
        uint256[] memory tokenIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            tokenIds[i] = i;
        }
        address collection = address(fantasyCards);
        
        cheats.startPrank(user1);
        minter.batchBurn(collection, tokenIds);
        cheats.stopPrank();

        // Verify all tokens are burned
        for (uint256 i = 0; i < 5; i++) {
            cheats.expectRevert(); // Token should not exist after burn
            fantasyCards.ownerOf(i);
        }
    }

    function test_unsuccessful_batchBurn_userNotOwner() public {
        uint256[] memory tokenIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            tokenIds[i] = i;
        }
        address collection = address(fantasyCards);
        
        cheats.startPrank(user2);
        cheats.expectRevert("caller does not own one of the tokens");
        minter.batchBurn(collection, tokenIds);
        cheats.stopPrank();
    }

    function test_unsuccessful_batchBurn_emptyArray() public {
        uint256[] memory tokenIds = new uint256[](0);
        address collection = address(fantasyCards);
        
        cheats.startPrank(user1);
        cheats.expectRevert("no tokens to burn");
        minter.batchBurn(collection, tokenIds);
        cheats.stopPrank();
    }

    function test_unsuccessful_batchBurn_collection_not_whitelisted() public {
        uint256[] memory tokenIds = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            tokenIds[i] = i;
        }

        cheats.startPrank(user1);
        cheats.expectRevert("Collection is not whitelisted");
        minter.batchBurn(address(0), tokenIds);
        cheats.stopPrank();
    }
}
