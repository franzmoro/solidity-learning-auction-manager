// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "src/MultiSigWallet.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet multiSig;

    uint256 private addr1PK = 1234567;
    uint256 private addr2PK = 2345678;
    uint256 private addr3PK = 3456789;
    address private addr1;
    address private addr2;
    address private addr3;

    address private depositor = address(123);
    address private beneficiary = address(567);

    address[] private owners;

    event TransferCreated(
        uint256 transferId,
        address to,
        uint256 amount,
        address proposer
    );
    event TransferApproved(uint256 transferId, address approver);
    event TransferSent(uint256 transferId, address to, uint256 amount);

    function setUp() public {
        addr1 = vm.addr(addr1PK);
        addr2 = vm.addr(addr2PK);
        addr3 = vm.addr(addr3PK);

        owners = [addr1, addr2, addr3];

        multiSig = new MultiSigWallet(owners, 2);

        vm.deal(address(multiSig), 10 ether);
    }

    function test_MultiSigWallet_Deposit_AllowsUsersToDeposit() public {
        assertEq(multiSig.balances(depositor), 0);

        hoax(depositor);
        multiSig.deposit{value: 1 ether}();

        assertEq(multiSig.balances(depositor), 1 ether);
    }

    function test_MultiSigWallet_CreateTransfer_ErrorsIfNotAuthorized() public {
        vm.prank(depositor);
        vm.expectRevert(Unauthorized.selector);
        multiSig.createTransfer(beneficiary, 0.1 ether);
    }

    function test_MultiSigWallet_CreateTransfer_ErrorsIfSendsToZeroAddress()
        public
    {
        vm.prank(addr1);
        vm.expectRevert(InvalidRecipient.selector);
        multiSig.createTransfer(address(0), 0.1 ether);
    }

    function test_MultiSigWallet_CreateTransfer_ErrorsIfSendsZero() public {
        vm.prank(addr2);
        vm.expectRevert("Must be above 0");
        multiSig.createTransfer(beneficiary, 0 ether);
    }

    function test_MultiSigWallet_CreateTransfer_CreatesATransferRequest()
        public
    {
        vm.prank(addr2);
        vm.expectEmit(true, true, true, true);
        emit TransferCreated(1, beneficiary, 1 ether, addr2);
        multiSig.createTransfer(beneficiary, 1 ether);

        (
            address to1,
            uint256 amount1,
            bool sent1,
            address[] memory approvals1
        ) = multiSig.getTransfer(1);

        assertEq(to1, beneficiary);
        assertEq(amount1, 1 ether);
        assertEq(sent1, false);
        assertEq(approvals1.length, 1);
        assertEq(approvals1[0], addr2);

        vm.prank(addr3);
        vm.expectEmit(true, true, true, true);
        emit TransferCreated(2, beneficiary, 3 ether, addr3);
        multiSig.createTransfer(beneficiary, 3 ether);

        (
            address to2,
            uint256 amount2,
            bool sent2,
            address[] memory approvals2
        ) = multiSig.getTransfer(2);

        assertEq(to2, beneficiary);
        assertEq(amount2, 3 ether);
        assertEq(sent2, false);
        assertEq(approvals2.length, 1);
        assertEq(approvals2[0], addr3);
    }

    function test_MultiSigWallet_Approve_ErrorsIfTransferDoesNotExist() public {
        vm.prank(addr2);
        vm.expectRevert(NotFound.selector);
        multiSig.approve(1);
    }

    function test_MultiSigWallet_Approve_ErrorsIfUnauthorized() public {
        vm.prank(addr2);
        multiSig.createTransfer(beneficiary, 1 ether);

        vm.prank(beneficiary);
        vm.expectRevert(Unauthorized.selector);
        multiSig.approve(1);
    }

    function test_MultiSigWallet_Approve_DoesNotDuplicateApproval() public {
        vm.prank(addr2);
        multiSig.createTransfer(beneficiary, 1 ether);

        (
            address to,
            uint256 amount,
            bool sent,
            address[] memory approvals
        ) = multiSig.getTransfer(1);

        assertEq(approvals.length, 1);

        vm.prank(addr2);
        vm.expectRevert(AlreadyApproved.selector);
        multiSig.approve(1);
    }

    function test_MultiSigWallet_Approve_IncreasesNumberOfApprovals() public {
        vm.prank(addr2);
        multiSig.createTransfer(beneficiary, 1 ether);

        vm.prank(addr1);
        vm.expectEmit(true, true, true, true);
        emit TransferApproved(1, addr1);
        multiSig.approve(1);

        (
            address to,
            uint256 amount,
            bool sent,
            address[] memory approvals
        ) = multiSig.getTransfer(1);

        assertEq(approvals.length, 2);
        assertEq(sent, false);
        assertEq(approvals[0], addr2);
        assertEq(approvals[1], addr1);
    }

    function test_MultiSigWallet_SendTransfer_ErrorsIfNotFound() public {
        vm.prank(addr1);
        multiSig.createTransfer(beneficiary, 1 ether);

        vm.prank(addr2);
        multiSig.approve(1);

        vm.prank(addr3);
        vm.expectRevert(NotFound.selector);
        multiSig.sendTransfer(2);
    }

    function test_MultiSigWallet_SendTransfer_ErrorsIfNotAuthorized() public {
        vm.prank(addr1);
        multiSig.createTransfer(beneficiary, 1 ether);

        vm.prank(addr2);
        multiSig.approve(1);

        vm.prank(beneficiary);
        vm.expectRevert(Unauthorized.selector);
        multiSig.sendTransfer(2);
    }

    function test_MultiSigWallet_SendTransfer_ErrorsIfNotEnoughApprovals()
        public
    {
        vm.prank(addr1);
        multiSig.createTransfer(beneficiary, 1 ether);

        vm.prank(addr3);
        vm.expectRevert(NotFound.selector);
        multiSig.sendTransfer(2);
    }

    function test_MultiSigWallet_SendTransfer_SendsFundsToRecipient() public {
        vm.prank(addr1);
        multiSig.createTransfer(beneficiary, 1 ether);

        vm.prank(addr3);
        multiSig.approve(1);

        vm.prank(addr2);
        vm.expectEmit(true, true, true, true);
        emit TransferSent(1, beneficiary, 1 ether);
        multiSig.sendTransfer(1);

        (
            address to,
            uint256 amount,
            bool sent,
            address[] memory approvals
        ) = multiSig.getTransfer(1);

        assertEq(sent, true);
    }

    function test_MultiSigWallet_SendTransfer_ErrorsIfAlreadySent() public {
        vm.prank(addr1);
        multiSig.createTransfer(beneficiary, 1 ether);

        vm.prank(addr3);
        multiSig.approve(1);

        vm.prank(addr2);
        multiSig.sendTransfer(1);

        vm.prank(addr2);
        vm.expectRevert(AlreadySent.selector);
        multiSig.sendTransfer(1);
    }

    function test_MultiSigWallet_Approve_ErrorsIfAlreadySent() public {
        vm.prank(addr1);
        multiSig.createTransfer(beneficiary, 1 ether);

        vm.prank(addr3);
        multiSig.approve(1);

        vm.prank(addr2);
        multiSig.sendTransfer(1);

        vm.prank(addr2);
        vm.expectRevert(AlreadySent.selector);
        multiSig.approve(1);
    }
}
