// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {VestingContract} from "../src/VestingContract.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1_000_000_000 * 1e6);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract VestingTest is Test {
    address public USDC;

    VestingContract public vestingContract;

    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");

    function setUp() public {
        // Create USDC ONCE
        USDC = address(new MockUSDC());

        // Pass the SAME USDC to VestingContract
        vestingContract = new VestingContract(USDC);

        //deal 1 million usdc token to this contract
        deal(USDC, address(this), 1_000_000_000 * 1e6);

        //approval
        IERC20(USDC).approve(address(vestingContract), type(uint256).max);

        //fund contract with 1 million usdc
        vestingContract.fundContract(1_000_000_000 * 1e6);
    }

    function testCreateVestingSchedule() public {
        //create vesting schedule for user1
        vestingContract.createVestingSchedule(user1, 100 * 1e6, block.timestamp, 60 days, 180 days);
    }

    /**
     * scenario: user1 has a vesting schedule of 10_000 usdc and cliff duration of 50 days and vesting duration of 100 days
     * after 50 days cliff, user1 should be able to claim 5000 usdc
     * after 70 days cliff, user1 should be able to claim 7000 usdc
     */
    function testReleasableAmount() public {
        //open vesting schedule for user1
        vestingContract.createVestingSchedule(user1, 10000 * 1e6, block.timestamp, 50 days, 100 days);
        //move time to 50 days
        vm.warp(block.timestamp + 50 days);
        //user1 should be able to claim 5000 usdc
        uint256 releasable = vestingContract.releasableAmount(user1);
        assertEq(releasable, 5000 * 1e6);
        //move time to 70 days
        vm.warp(block.timestamp + 20 days);
        //user1 should be able to claim 7000 usdc
        releasable = vestingContract.releasableAmount(user1);
        assertEq(releasable, 7000 * 1e6);
    }

    /**
     * scenario: user1 has a vesting schedule of 10_000 usdc and cliff duration of 50 days and vesting duration of 100 days
     * after 60 days, user cliams 6000 usdc
     * then on 70 days, user is revoked
     * then on 80 days, user should be able to claim max 10_000 usdc (the amount between 70 - 60 days total of 10 days) and no more
     *
     */
    function testRevoke() public {
        //open vesting schedule for user1
        vestingContract.createVestingSchedule(user1, 10000 * 1e6, block.timestamp, 50 days, 100 days);
        //move time to 60 days
        vm.warp(block.timestamp + 60 days);
        //user1 should be able to claim 6000 usdc
        uint256 releasable = vestingContract.releasableAmount(user1);
        assertEq(releasable, 6000 * 1e6);
        //user claims 6000 usdc
        vm.prank(user1);
        vestingContract.claim();

        //move time to 70 days
        vm.warp(block.timestamp + 10 days);

        //revoke user1
        vestingContract.revoke(user1);
        //user1 should be able to claim max 10_000 usdc (the amount between 70 - 60 days total of 10 days) and no more
        releasable = vestingContract.releasableAmount(user1);
        assertEq(releasable, 1000 * 1e6);
        //user claims 1000 usdc
        vm.prank(user1);
        vestingContract.claim();

        //move time to 80 days
        vm.warp(block.timestamp + 10 days);
        //user1 should be able to claim 0 usdc
        releasable = vestingContract.releasableAmount(user1);
        assertEq(releasable, 0);
    }
}
