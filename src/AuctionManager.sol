// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Minter.sol";

contract AuctionManager is Ownable {
    address private minter;
    uint64 public endTime;
    uint256 public startingPrice;
    uint256 public highestBid;
    address private highestBidder;
    bool private prizeWithdrawn = false;

    mapping(address => uint256) bids;

    event UserBid(address user, uint256 amount);

    // not using `initialize` function, as we don't need a proxy for the exercise
    constructor(
        uint256 _initialPrice,
        uint64 _offsetToEnd,
        address _minter
    ) {
        minter = _minter;
        startingPrice = _initialPrice;
        endTime = uint64(block.timestamp) + _offsetToEnd;
    }

    function setMinter(address _newMinter) public onlyOwner {
        minter = _newMinter;
    }

    function getBid(address _user) public view returns (uint256) {
        return bids[_user];
    }

    function bid() public payable {
        require(block.timestamp <= endTime, "Auction ended");
        require(
            bids[msg.sender] + msg.value > startingPrice,
            "Must be higher than startingPrice"
        );
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
        // emit UserBid(highestBidder, highestBid);
        emit UserBid(msg.sender, bids[msg.sender]);
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

    function getPrize(uint256 tokenId) public {
        require(block.timestamp > endTime, "Auction not ended");
        require(msg.sender == highestBidder, "not the winner");
        require(prizeWithdrawn == false, "Already got prize");

        prizeWithdrawn = true;

        Minter m = Minter(minter);

        m.mint(highestBidder, tokenId);
    }
}
