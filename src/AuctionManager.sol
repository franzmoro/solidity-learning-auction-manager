// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

// TODO: spend less gas - increase bid & return funds only when auction closed...

contract AuctionManager {
    address private owner;
    uint64 public endTime;
    bool private closed;
    uint256 public startingPrice;
    uint256 public highestBid;
    address payable private highestBidder;

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
        require(msg.sender != highestBidder, "Already highest bidder");
        require(msg.value > highestBid, "Must outbid current highest bid");

        uint256 previousHighestBid = highestBid;
        address payable previousHighestBidder = highestBidder;

        highestBid = msg.value;
        highestBidder = payable(msg.sender);

        // allows to view users' bids
        bids[msg.sender] = msg.value;

        // return funds to previous highest bidder???
        previousHighestBidder.transfer(previousHighestBid);
    }

    function getAuctionEnd() public view returns (uint128) {
        return endTime;
    }

    function closeAuction() public onlyOwner {
        require(!closed, "Auction already closed");
        require(block.timestamp > endTime, "Auction not ended");

        closed = true;

        emit AuctionClosed(highestBidder, highestBid);
        // TODO: mint item
    }
}
