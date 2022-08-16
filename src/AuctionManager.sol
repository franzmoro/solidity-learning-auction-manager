// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

contract AuctionManager {
    address private owner;
    uint64 public endTime;
    uint256 public startingPrice;
    uint256 public highestBid;
    address private highestBidder;

    mapping(address => uint256) bids;

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

    function withdraw() public payable {
        require(block.timestamp > endTime, "Auction not ended");
        require(msg.sender != highestBidder, "winner cannot withdraw");

        uint256 amount = bids[msg.sender];
        require(amount > 0, "no funds to withdraw");

        bids[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
        // handle payment failure?
    }

    function getPrize() public view {
        require(block.timestamp > endTime, "Auction not ended");
        require(msg.sender == highestBidder, "not the winner");
        // TODO: mint item
    }
}
