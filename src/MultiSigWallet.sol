// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";

error AlreadySent();
error NotFound();
error Unauthorized();

contract MultiSigWallet is Ownable {
    mapping(address => uint256) public balances;
    mapping(uint256 => Transfer) public transfers;

    uint256 private nextTransferId = 1;
    address[] public admins;
    uint8 public approvalsRequired;

    struct Transfer {
        address to;
        uint256 amount;
        bool sent;
        address[] approvals;
    }

    constructor(address[] memory owners, uint8 numApprovals) {
        admins = owners;
        approvalsRequired = numApprovals;
    }

    modifier onlyAdmin() {
        if (!isAdmin(msg.sender)) revert Unauthorized();
        _;
    }

    function isAdmin(address user) internal view returns (bool) {
        for (uint8 i = 0; i < admins.length; i++) {
            if (user == admins[i]) return true;
        }
        return false;
    }

    function getTransfer(uint256 id)
        public
        view
        returns (
            address,
            uint256,
            bool,
            address[] memory
        )
    {
        Transfer memory transfer = transfers[id];
        return (
            transfer.to,
            transfer.amount,
            transfer.sent,
            transfer.approvals
        );
    }

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function createTransfer(address to, uint256 amount) public onlyAdmin {
        require(to != address(0), "Cannot send to 0 address");
        require(amount > 0, "Must be above 0");

        uint256 transferId = nextTransferId;
        nextTransferId++;

        address[] memory initialApprovals = new address[](1);
        initialApprovals[0] = msg.sender;

        transfers[transferId] = Transfer(to, amount, false, initialApprovals);
    }

    function approve(uint256 id) public onlyAdmin {
        if (transfers[id].amount == 0) revert NotFound();
        if (transfers[id].sent) revert AlreadySent();

        transfers[id].approvals.push(msg.sender);
    }

    function sendTransfer() public onlyAdmin {
        // check found
        // check already sent
        // check num approvals
        // check balance
        // check not zero address
    }

    // TODO: time-delayed
}
