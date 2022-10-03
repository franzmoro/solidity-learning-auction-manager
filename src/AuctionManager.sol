// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./DropMinter.sol";

contract AuctionManager is Ownable {
    address private minter;
    uint256 private nextAuctionId = 1;

    /*****************************************
     * DropInfo
     *****************************************/
    mapping(uint256 => bool) public auctionExists; // dropId --> isAuctioned;

    mapping(uint256 => uint256) public endTimes;
    mapping(uint256 => uint256) public startingPrices;
    mapping(uint256 => uint256) public highestBids;
    mapping(uint256 => address) private highestBidders;
    mapping(uint256 => bool) private prizeWithdrawn;
    /*****************************************/

    event UserBid(address user, uint256 dropId, uint256 amount);
    event RefundedBid(address user, uint256 amount);

    // not using `initialize` function, as we don't need a proxy for the exercise
    constructor(address _minter) {
        minter = _minter;
    }

    function setMinter(address _newMinter) public onlyOwner {
        minter = _newMinter;
    }

    function createAuction(
        uint256 dropId,
        uint256 endTime,
        uint256 startingPrice
    )
        public
        // TODO: manager role
        onlyOwner
    {
        require(!auctionExists[dropId], "Auction for drop exists");

        endTimes[dropId] = block.timestamp + endTime;
        startingPrices[dropId] = startingPrice;
        auctionExists[dropId] = true;
    }

    function bid(uint256 dropId) public payable {
        require(auctionExists[dropId], "Auction not found");
        require(block.timestamp <= endTimes[dropId], "Auction ended");
        require(
            msg.value > startingPrices[dropId],
            "must be greater than starting price"
        );
        require(
            msg.value > highestBids[dropId],
            "must be greater than highest bid"
        );

        uint256 previousBid = highestBids[dropId];
        address previousBidder = highestBidders[dropId];

        highestBids[dropId] = msg.value;
        highestBidders[dropId] = msg.sender;

        payable(previousBidder).transfer(previousBid);

        emit UserBid(msg.sender, dropId, msg.value);
        emit RefundedBid(previousBidder, previousBid);
    }

    function getPrize(uint256 dropId) public {
        require(block.timestamp > endTimes[dropId], "Auction not ended");
        require(msg.sender == highestBidders[dropId], "not the winner");
        require(prizeWithdrawn[dropId] == false, "Already got prize");

        prizeWithdrawn[dropId] = true;

        DropMinter m = DropMinter(minter);

        // get tokenId from dropIf
        // m.mint(msg.sender, tokenId);
    }
}
