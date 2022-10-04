// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import "src/AuctionManager.sol";
import "src/DropMinter.sol";

contract AuctionManagerTest is Test {
    AuctionManager public auction;
    DropMinter public minter;

    address public owner = address(this);

    event UserBid(address user, uint256 dropId, uint256 amount);

    // Setup Params
    uint256 public initialPrice = 0.1 ether;
    uint256 public offsetToEnd = 10;

    address public addr1 = address(2);
    address public addr2 = address(3);

    uint256 dropId = 2;
    uint256 endTime = 20;

    function setUp() public {
        minter = new DropMinter();
        auction = new AuctionManager(address(minter));
        minter.setAuthorizer(address(auction));
    }

    function test_CannotSetMinterForNonOwner() public {
        vm.prank(addr1);
        vm.expectRevert("Ownable: caller is not the owner");
        auction.setMinter(addr1);
    }

    function test_AuctionManager_CannotCreateAuctionIfRegularUser() public {
        vm.prank(addr1);
        vm.expectRevert("Ownable: caller is not the owner");

        auction.createAuction(dropId, endTime, 0.1 ether);
    }

    function test_AuctionManager_CreatesAuctions() public {
        auction.createAuction(dropId, endTime, 0.1 ether);
        assertEq(auction.auctionExists(dropId), true);
    }

    // TODO: does not create multiple auctions for the same drop

    function test_AuctionManager_CreatesMultipleAuctions() public {
        // Auction 1
        auction.createAuction(dropId, endTime, 0.1 ether);
        assertEq(auction.auctionExists(dropId), true);

        // Auction 2
        uint256 newDropId = 3;
        auction.createAuction(newDropId, endTime, 0.1 ether);
        assertEq(auction.auctionExists(newDropId), true);
    }

    function test_UserBidAllowed() public {
        auction.createAuction(dropId, endTime, 0.1 ether);

        hoax(addr1);
        auction.bid{value: 0.2 ether}(dropId);
        assertEq(auction.highestBids(dropId), 0.2 ether);
    }

    function test_CannotBidBelowStartPrice() public {
        auction.createAuction(dropId, endTime, 0.1 ether);

        hoax(addr1);
        vm.expectRevert("must be greater than starting price");
        auction.bid{value: 0.02 ether}(dropId);
    }

    function test_CannotBidBelowCurrentBid() public {
        auction.createAuction(dropId, endTime, 0.1 ether);

        hoax(addr1);
        auction.bid{value: 0.2 ether}(dropId);

        hoax(addr2);
        vm.expectRevert("must be greater than highest bid");
        auction.bid{value: 0.15 ether}(dropId);
    }

    function test_EmitsUserBidEvent() public {
        auction.createAuction(dropId, endTime, 0.1 ether);

        hoax(addr1);
        uint256 bidAmount = 0.2 ether;

        vm.expectEmit(true, true, true, true);
        emit UserBid(addr1, dropId, bidAmount);

        auction.bid{value: bidAmount}(dropId);
    }

    function test_ReturnsPreviousBidFundsToPreviousBidder() public {
        auction.createAuction(dropId, endTime, 0.1 ether);

        hoax(addr1);
        auction.bid{value: 0.2 ether}(dropId);

        uint256 balanceAfterBid = addr1.balance;
        vm.stopPrank();

        hoax(addr2);
        auction.bid{value: 0.5 ether}(dropId);

        uint256 balanceAfterOutbid = addr1.balance;
        assertEq(balanceAfterOutbid, (balanceAfterBid + 0.2 ether));
    }

    function test_CannotBidIfAuctionEnded() public {
        auction.createAuction(dropId, endTime, 0.1 ether);

        hoax(addr1);
        auction.bid{value: 0.2 ether}(dropId);

        vm.warp(endTime + 10);

        hoax(addr2);
        vm.expectRevert("Auction ended");
        auction.bid{value: 0.5 ether}(dropId);
    }

    function test_CannotGetPrizeIfDidNotParticipate() public {
        auction.createAuction(dropId, endTime, 0.1 ether);

        hoax(addr1);
        auction.bid{value: 0.2 ether}(dropId);

        hoax(addr2);
        auction.bid{value: 0.5 ether}(dropId);

        vm.warp(endTime + 10);

        vm.prank(address(391));
        vm.expectRevert("not the winner");
        auction.getPrize(dropId);
    }

    function test_CannotGetPrizeIfLoser() public {
        auction.createAuction(dropId, endTime, 0.1 ether);

        hoax(addr1);
        auction.bid{value: 0.2 ether}(dropId);

        hoax(addr2);
        auction.bid{value: 0.5 ether}(dropId);

        vm.warp(endTime + 10);

        vm.prank(addr1);
        vm.expectRevert("not the winner");
        auction.getPrize(dropId);
    }

    function test_CanWithdrawPrizeIfWinner() public {
        auction.createAuction(dropId, endTime, 0.1 ether);

        hoax(addr1);
        auction.bid{value: 0.2 ether}(dropId);

        hoax(addr2);
        auction.bid{value: 0.5 ether}(dropId);

        vm.prank(addr2);
        vm.warp(endTime + 10);
        auction.getPrize(dropId);

        // TODO: modify tokenId
        assertEq(minter.ownerOf(dropId), addr2);
        assertEq(minter.balanceOf(addr2), 1);
    }

    function test_CannotWithdrawPrizeTwice() public {
        auction.createAuction(dropId, endTime, 0.1 ether);

        hoax(addr1);
        auction.bid{value: 0.2 ether}(dropId);

        hoax(addr2);
        auction.bid{value: 0.5 ether}(dropId);

        vm.prank(addr2);
        vm.warp(endTime + 10);
        auction.getPrize(dropId);

        assertEq(minter.ownerOf(dropId), addr2);
        assertEq(minter.balanceOf(addr2), 1);

        vm.prank(addr2);
        vm.expectRevert("Already got prize");
        auction.getPrize(dropId);

        assertEq(minter.balanceOf(addr2), 1);
    }
}
