# Solidity learning - Auction Manager

## Approach 1:

- User 1 bids 0.1 eth, pays funds to contract
- User 2 bids 0.2 eth, pays funds to contract. Contract returns 0.1 eth to user 1.
- User 3 bids 0.3 eth, pays funds to contract. Contract returns 0.1 eth to user 2.
- User 1 bids 0.4 eth, pays funds to contract. Contract returns 0.2 eth to user 3.
- User 2 bids 0.5 eth, pays funds to contract. Contract returns 0.3 eth to user 1.
- User 3 bids 0.6 eth, pays funds to contract. Contract returns 0.3 eth to user 2.
- Auction ends & is closed. Nothing to return. User 3 won.

This is a simple approach. However, the contract would consume gas for each bid. In this particular case where users submit multiple bids, the contract pays the gas 5 times, where N is the number of bids.

Let's see if we can make this cheaper with another approach.

## Approach 2:

Same bids:

- User 1 bids 0.1 eth, pays funds to contract
- User 2 bids 0.2 eth, pays funds to contract.
- User 3 bids 0.3 eth, pays funds to contract.
- User 1 increases bid by 0.3 eth. Current highest bid: 0.4 eth.
- User 2 increases bid by 0.3 eth. Current highest bid: 0.5 eth.
- User 3 increases bid by 0.3 eth. Current highest bid: 0.6 eth.
- Auction ends & is closed:
  - Only 2 refunds necessary:
    - User 1 is refunded 0.5 eth
    - User 2 is refunded 0.4 eth

## Setup

- `yarn` to install dependencies
- `yarn test`
