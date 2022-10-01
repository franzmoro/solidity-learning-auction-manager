// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "src/AuctionManager.sol";

contract AuctionManagerTest is Test {
    AuctionManager public auction;
    address public owner = address(this);

    event UserBid(address user, uint256 amount);

    // Setup Params
    address public minter = address(1);
    uint256 public initialPrice = 0.1 ether;
    uint64 public offsetToEnd = 10;

    address public addr1 = address(2);
    address public addr2 = address(3);

    function setUp() public {
        auction = new AuctionManager(initialPrice, offsetToEnd, minter);
    }

    function test_CannotSetMinterForNonOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(addr1);
        auction.setMinter(addr1);
    }

    function test_UserBidAllowed() public {
        hoax(addr1);
        auction.bid{value: 0.2 ether}();
        assertEq(auction.getBid(addr1), 0.2 ether);
    }

    function test_CannotBidBelowStartPrice() public {
        hoax(addr1);
        vm.expectRevert("Must be higher than startingPrice");
        auction.bid{value: 0.02 ether}();
    }

    function test_CannotBidBelowCurrentBid() public {
        hoax(addr1);
        auction.bid{value: 0.2 ether}();

        hoax(addr2);
        vm.expectRevert("Must outbid current highest bid");
        auction.bid{value: 0.15 ether}();
    }

    function test_EmitsUserBidEvent() public {
        hoax(addr1);
        uint256 bidAmount = 0.2 ether;

        vm.expectEmit(true, true, true, true);
        emit UserBid(addr1, bidAmount);

        auction.bid{value: bidAmount}();
    }
}
