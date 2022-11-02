// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "src/DropMinter.sol";

contract AuctionManagerTest is Test {
    DropMinter public minter;

    uint256 public dropId = 1;
    address public user1 = address(1);
    address public user2 = address(2);

    function setUp() public {
        minter = new DropMinter();
        minter.setAuthorizer(address(this));
    }

    function test_cannotSetMaxSupplyIfNotAuthorized() public {
        vm.prank(user1);
        vm.expectRevert("Unauthorized");
        minter.setMaxSupply(dropId, 10);
    }

    function test_cannotMintIfMaxSupplyNotSet() public {
        vm.expectRevert("Supply not set");
        minter.mint(user1, dropId);
    }

    function test_canMintSingleItem() public {
        minter.createDrop(1);
        minter.mint(user1, dropId);

        assertEq(minter.ownerOf(10000), user1);
        assertEq(minter.balanceOf(user1), 1);
    }

    function test_cannotMintMoreThanMaxSupplyOne() public {
        minter.createDrop(1);
        minter.mint(user1, dropId);

        vm.expectRevert("Sold out");
        minter.mint(user1, dropId);
    }

    function test_canMintMultipleItems() public {
        minter.createDrop(3);

        minter.mint(user1, dropId);
        minter.mint(user2, dropId);
        minter.mint(user1, dropId);

        assertEq(minter.ownerOf(10000), user1);
        assertEq(minter.ownerOf(10001), user2);
        assertEq(minter.ownerOf(10002), user1);

        assertEq(minter.balanceOf(user1), 2);
        assertEq(minter.balanceOf(user2), 1);
        assertEq(minter.circulating(dropId), 3);
    }

    function test_cannotMintMoreThanMaxSupplyMultiple() public {
        minter.createDrop(2);

        minter.mint(user1, dropId);
        minter.mint(user2, dropId);

        vm.expectRevert("Sold out");
        minter.mint(user1, dropId);
    }
}
