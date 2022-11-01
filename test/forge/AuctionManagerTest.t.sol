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

    // by default every first drop is created with id 1, and add 1 after
    uint256 dropId = 1;
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

        auction.createAuction(endTime, 0.1 ether);
    }

    function test_AuctionManager_CreatesAuctions() public {
        auction.createAuction(endTime, 0.1 ether);

        assertEq(auction.isAuction(dropId), true);

        assertEq(minter.maxSupply(dropId), 1);
        assertEq(minter.circulating(dropId), 0);
    }

    function test_AuctionManager_CreatesMultipleAuctions() public {
        assertEq(auction.isAuction(1), false);

        // Auction 1
        auction.createAuction(endTime, 0.1 ether);
        assertEq(auction.isAuction(1), true);

        assertEq(DropMinter(minter).maxSupply(1), 1);
        assertEq(DropMinter(minter).circulating(1), 0);

        assertEq(auction.isAuction(2), false);

        // Auction 2
        uint256 newDropId = 2;
        auction.createAuction(endTime, 0.1 ether);
        assertEq(auction.isAuction(2), true);

        assertEq(DropMinter(minter).maxSupply(2), 1);
        assertEq(DropMinter(minter).circulating(2), 0);
    }

    function test_UserBidAllowed() public {
        auction.createAuction(endTime, 0.1 ether);

        hoax(addr1);
        auction.bid{value: 0.2 ether}(dropId);
        assertEq(auction.highestBids(dropId), 0.2 ether);
    }

    function test_CannotBidBelowStartPrice() public {
        auction.createAuction(endTime, 0.1 ether);

        hoax(addr1);
        vm.expectRevert("must be gt starting price");
        auction.bid{value: 0.02 ether}(dropId);
    }

    function test_CannotBidBelowCurrentBid() public {
        auction.createAuction(endTime, 0.1 ether);

        hoax(addr1);
        auction.bid{value: 0.2 ether}(dropId);

        hoax(addr2);
        vm.expectRevert("must be gt highest bid");
        auction.bid{value: 0.15 ether}(dropId);
    }

    function test_EmitsUserBidEvent() public {
        auction.createAuction(endTime, 0.1 ether);

        hoax(addr1);
        uint256 bidAmount = 0.2 ether;

        vm.expectEmit(true, true, true, true);
        emit UserBid(addr1, dropId, bidAmount);

        auction.bid{value: bidAmount}(dropId);
    }

    function test_ReturnsPreviousBidFundsToPreviousBidder() public {
        auction.createAuction(endTime, 0.1 ether);

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
        auction.createAuction(endTime, 0.1 ether);

        hoax(addr1);
        auction.bid{value: 0.2 ether}(dropId);

        vm.warp(endTime + 10);

        hoax(addr2);
        vm.expectRevert("Auction ended");
        auction.bid{value: 0.5 ether}(dropId);
    }

    function test_CannotGetPrizeIfDidNotParticipate() public {
        auction.createAuction(endTime, 0.1 ether);

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
        auction.createAuction(endTime, 0.1 ether);

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
        auction.createAuction(endTime, 0.1 ether);

        hoax(addr1);
        auction.bid{value: 0.2 ether}(dropId);

        hoax(addr2);
        auction.bid{value: 0.5 ether}(dropId);

        assertEq(minter.circulating(dropId), 0);

        vm.prank(addr2);
        vm.warp(endTime + 10);
        auction.getPrize(dropId);

        assertEq(minter.ownerOf(10000), addr2);
        assertEq(minter.balanceOf(addr2), 1);
        assertEq(minter.circulating(dropId), 1);
    }

    function test_CannotWithdrawPrizeTwice() public {
        auction.createAuction(endTime, 0.1 ether);

        hoax(addr1);
        auction.bid{value: 0.2 ether}(dropId);

        hoax(addr2);
        auction.bid{value: 0.5 ether}(dropId);

        vm.prank(addr2);
        vm.warp(endTime + 10);
        auction.getPrize(dropId);

        assertEq(minter.ownerOf(10000), addr2);
        assertEq(minter.balanceOf(addr2), 1);
        assertEq(minter.circulating(dropId), 1);

        vm.prank(addr2);
        vm.expectRevert("Already got prize");
        auction.getPrize(dropId);

        assertEq(minter.balanceOf(addr2), 1);
        assertEq(minter.circulating(dropId), 1);
    }

    function test_CannotCreateFixedPriceDropIfNotAuthorized() public {
        vm.prank(addr1);
        vm.expectRevert("Ownable: caller is not the owner");
        auction.createFixPriceDrop(1.5 ether, 10);
    }

    function test_CanCreateFixedPriceDrop() public {
        auction.createFixPriceDrop(1.5 ether, 10);

        assertEq(auction.startingPrices(dropId), 1.5 ether);
        assertEq(minter.maxSupply(dropId), 10);
    }

    function test_CannotPurchaseBelowFixedPrice() public {
        auction.createFixPriceDrop(1.5 ether, 10);

        hoax(addr1);
        vm.expectRevert("Must pay price");
        auction.purchaseDirect{value: 1 ether}(dropId);
    }

    function test_CannotCallPurchaseIfAuction() public {
        auction.createAuction(endTime, 1 ether);

        hoax(addr1);
        vm.expectRevert("Drop is auction");
        auction.purchaseDirect{value: 1 ether}(dropId);
    }

    function test_CanPurchaseFixedDropDirectly() public {
        auction.createFixPriceDrop(1 ether, 10);

        assertEq(minter.maxSupply(dropId), 10);
        assertEq(minter.circulating(dropId), 0);

        hoax(addr1);
        auction.purchaseDirect{value: 1 ether}(dropId);

        assertEq(minter.circulating(dropId), 1);
        assertEq(minter.ownerOf(10000), addr1);

        hoax(addr2);
        auction.purchaseDirect{value: 1 ether}(dropId);

        assertEq(minter.circulating(dropId), 2);
        assertEq(minter.ownerOf(10001), addr2);
    }

    function test_CannotBidForFixedPriceDrop() public {
        auction.createFixPriceDrop(1 ether, 10);

        hoax(addr1);
        vm.expectRevert("Auction not found");
        auction.bid{value: 1.5 ether}(dropId);
    }

    function test_CannotGetPrizeForFixedPriceDrop() public {
        auction.createFixPriceDrop(1 ether, 10);
        vm.prank(addr1);
        vm.expectRevert("Auction not found");
        auction.getPrize(dropId);
    }
}
