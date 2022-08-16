// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

contract AuctionManager {
    address private owner;
    uint64 public endTime;
    bool private closed;
    uint256 public startingPrice;
    uint256 public highestBid;
    address private highestBidder;

    mapping(address => uint256) bids;

    event AuctionClosed(address _highestBidder, uint256 _highestBid);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner allowed");
        _;
    }

    // not using `initialize` function, as we don't need a proxy for the exercise
    constructor(uint256 _initialPrice, uint64 _numBlocksToEnd) {
        owner = msg.sender;
        startingPrice = _initialPrice;
        endTime = uint64(block.timestamp) + _numBlocksToEnd;
    }

    function getHighestBid() public view returns (uint256) {
        return highestBid;
    }

    function getBid(address _user) public view returns (uint256) {
        return bids[_user];
    }

    function bid() public payable {
        require(block.timestamp <= endTime, "Auction ended");
        require(
            bids[msg.sender] + msg.value > highestBid,
            "Must outbid current highest bid"
        );
        // allow users to outbid themselves in case of last-minute bids

        bids[msg.sender] += msg.value;

        if (bids[msg.sender] > highestBid) {
            highestBid = bids[msg.sender];
            highestBidder = msg.sender;
        }
    }

    function getAuctionEnd() public view returns (uint128) {
        return endTime;
    }

    function closeAuction() public onlyOwner {
        require(!closed, "Auction already closed");
        require(block.timestamp > endTime, "Auction not ended");

        closed = true;

        emit AuctionClosed(highestBidder, highestBid);

        // TODO: refund all losers
        // TODO: mint item
    }
}
