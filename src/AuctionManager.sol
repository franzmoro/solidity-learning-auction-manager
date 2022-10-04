// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./DropMinter.sol";

contract AuctionManager is Ownable {
    address private minter;
    uint256 private nextAuctionId = 1;

    /***********************************************************************
     * Drops Info
     ***********************************************************************/
    mapping(uint256 => bool) public isAuction; // dropId --> isAuction;
    mapping(uint256 => uint256) public startingPrices;

    /***********************************************************************
     * Auctions Info
     ***********************************************************************/
    mapping(uint256 => uint256) public endTimes;
    mapping(uint256 => uint256) public highestBids;
    mapping(uint256 => address) private highestBidders;
    mapping(uint256 => bool) private prizeWithdrawn;
    /***********************************************************************/

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
        require(!isAuction[dropId], "Drop exists");
        isAuction[dropId] = true;
        endTimes[dropId] = block.timestamp + endTime;
        startingPrices[dropId] = startingPrice;

        DropMinter(minter).setMaxSupply(dropId, 1);
    }

    function createFixPriceDrop(
        uint256 dropId,
        uint256 price,
        uint128 supply
    ) public onlyOwner {
        require(startingPrices[dropId] == 0, "Drop exists");

        startingPrices[dropId] = price;

        DropMinter(minter).setMaxSupply(dropId, supply);
    }

    function purchaseDirect(uint256 dropId) public payable {
        require(!isAuction[dropId], "Drop is auction");
        require(msg.value == startingPrices[dropId], "Must pay price");

        DropMinter(minter).mint(msg.sender, dropId);
    }

    function bid(uint256 dropId) public payable {
        require(isAuction[dropId], "Auction not found");
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
        require(isAuction[dropId], "Auction not found");
        require(block.timestamp > endTimes[dropId], "Auction not ended");
        require(msg.sender == highestBidders[dropId], "not the winner");
        require(prizeWithdrawn[dropId] == false, "Already got prize");

        prizeWithdrawn[dropId] = true;

        DropMinter m = DropMinter(minter);

        // get tokenId from dropId
        m.mint(msg.sender, dropId);
    }
}
