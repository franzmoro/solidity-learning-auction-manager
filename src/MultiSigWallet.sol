// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";

error AlreadyApproved();
error AlreadySent();
error InvalidRecipient();
error NotEnoughApprovals();
error NotFound();
error Unauthorized();

contract MultiSigWallet is Ownable {
    mapping(address => uint256) public balances;
    mapping(uint256 => Transfer) public transfers;

    uint256 private nextTransferId = 1;
    address[] public admins;
    uint8 public approvalsRequired;

    event TransferCreated(
        uint256 transferId,
        address to,
        uint256 amount,
        address proposer
    );
    event TransferApproved(uint256 transferId, address approver);
    event TransferSent(uint256 transferId, address to, uint256 amount);

    struct Transfer {
        address payable to;
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
        if (to == address(0)) revert InvalidRecipient();
        require(amount > 0, "Must be above 0");

        uint256 transferId = nextTransferId;
        nextTransferId++;

        address[] memory initialApprovals = new address[](1);
        initialApprovals[0] = msg.sender;

        transfers[transferId] = Transfer(
            payable(to),
            amount,
            false,
            initialApprovals
        );

        emit TransferCreated(transferId, to, amount, msg.sender);
        emit TransferApproved(transferId, msg.sender);
    }

    function approve(uint256 id) public onlyAdmin {
        Transfer memory transfer = transfers[id];

        if (transfer.amount == 0) revert NotFound();
        if (transfer.sent) revert AlreadySent();

        for (uint8 i; i < transfer.approvals.length; i++) {
            if (transfer.approvals[i] == msg.sender) revert AlreadyApproved();
        }

        transfers[id].approvals.push(msg.sender);

        emit TransferApproved(id, msg.sender);
    }

    function sendTransfer(uint256 id) public onlyAdmin {
        Transfer memory transfer = transfers[id];

        if (transfer.amount == 0) revert NotFound();
        if (transfer.approvals.length < approvalsRequired)
            revert NotEnoughApprovals();

        if (transfer.to == address(0)) revert InvalidRecipient();
        if (transfer.sent) revert AlreadySent();

        transfers[id].sent = true;

        (transfer.to).transfer(transfer.amount);

        emit TransferSent(id, transfer.to, transfer.amount);
    }

    // TODO: time-delayed
}
