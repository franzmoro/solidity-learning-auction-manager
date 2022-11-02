// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./DropMinter.sol";

// rename from AuctionManager to BidManager or something more related to its more versatile functionality
contract AuctionManager is Ownable {
    address private minter;

    /***********************************************************************
     * AUCTION DATA
     ***********************************************************************/

    struct StandardAuction {
        uint256 startingPrice;
        uint256 startTime;
        uint256 endTime;
        uint256 highestBid;
        address highestBidder;
        bool prizeWithdrawn;
    }
    struct FixedPrice {
        uint256 price;
        uint256 startTime;
    }

    // TODO: refactor to reduce number of mappings needed
    mapping(uint256 => uint32) public dropType; // dropId ==> 1--> 'standardAuction' | 2 --> 'fixedPrice'
    mapping(uint256 => StandardAuction) public standardAuctions; // auctionId to auction
    mapping(uint256 => FixedPrice) public fixedPriceDrops; // auctionId to fixed price auction

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
        uint256 startTime,
        uint256 endTime,
        uint256 startingPrice
    )
        public
        // TODO: manager role
        onlyOwner
        returns (uint256)
    {
        // fixed supply of 1
        uint256 dropId = DropMinter(minter).createDrop(1);

        standardAuctions[dropId] = StandardAuction(
            startingPrice,
            block.timestamp + startTime,
            block.timestamp + endTime,
            0,
            address(0),
            false
        );
        dropType[dropId] = 1;

        return dropId;
    }

    function createFixPriceDrop(
        uint256 startTime,
        uint256 price,
        uint128 supply
    ) public onlyOwner returns (uint256) {
        uint256 dropId = DropMinter(minter).createDrop(supply);

        fixedPriceDrops[dropId] = FixedPrice(
            price,
            block.timestamp + startTime
        );
        dropType[dropId] = 2;

        return dropId;
    }

    function purchaseDirect(uint256 dropId) public payable {
        require(dropType[dropId] == 2, "Not fixed price");

        FixedPrice memory fixedPriceDrop = fixedPriceDrops[dropId];

        require(
            block.timestamp > fixedPriceDrop.startTime,
            "Auction not started"
        );

        uint256 price = fixedPriceDrop.price;

        require(price > 0, "price not set");
        require(msg.value == price, "Must pay price");

        DropMinter(minter).mint(msg.sender, dropId);
    }

    function highestBid(uint256 dropId) public view returns (uint256) {
        return standardAuctions[dropId].highestBid;
    }

    function highestBidder(uint256 dropId) public view returns (address) {
        return standardAuctions[dropId].highestBidder;
    }

    function bid(uint256 dropId) public payable {
        require(dropType[dropId] == 1, "Auction not found");

        StandardAuction memory auction = standardAuctions[dropId];

        require(block.timestamp > auction.startTime, "Auction not started");
        require(block.timestamp <= auction.endTime, "Auction ended");
        require(msg.value > auction.startingPrice, "must be gt starting price");
        require(msg.value > auction.highestBid, "must be gt highest bid");

        uint256 previousBid = auction.highestBid;
        address previousBidder = auction.highestBidder;

        standardAuctions[dropId].highestBid = msg.value;
        standardAuctions[dropId].highestBidder = msg.sender;

        payable(previousBidder).transfer(previousBid);

        emit UserBid(msg.sender, dropId, msg.value);
        emit RefundedBid(previousBidder, previousBid);
    }

    function getPrize(uint256 dropId) public {
        require(dropType[dropId] == 1, "Auction not found");

        StandardAuction memory auction = standardAuctions[dropId];

        require(block.timestamp > auction.endTime, "Auction not ended");

        require(msg.sender == auction.highestBidder, "not the winner");
        require(auction.prizeWithdrawn == false, "Already got prize");

        standardAuctions[dropId].prizeWithdrawn = true;

        DropMinter m = DropMinter(minter);

        // get tokenId from dropId
        m.mint(msg.sender, dropId);
    }
}
