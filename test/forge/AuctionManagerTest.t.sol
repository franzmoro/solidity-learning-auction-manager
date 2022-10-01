// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";
import "forge-std/VM.sol";
import "forge-std/console2.sol";

import "src/AuctionManager.sol";

contract AuctionManagerTest {
    AuctionManager public auction;
    address public vmAddress = 0x7109709ECfa91a80626fF3989D68f67F5b1DD12D;
    Vm public vm = Vm(vmAddress);
    address public owner = address(this);

    // Setup Params
    address public minter = 0xC990bE25e60291b017E084dc73F2A32a5bb95C64;
    uint256 public initialPrice = 0.1 ether;
    uint64 public offsetToEnd = 10;

    address public addr1 = 0x6F22855e9103dC3b170c08764DAE86E40D702C89;

    function setUp() public {
        auction = new AuctionManager(initialPrice, offsetToEnd, minter);
    }

    function test_CannotSetMinterForNonOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(addr1);
        auction.setMinter(addr1);
    }
}
