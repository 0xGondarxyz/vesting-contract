// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract VestingContract is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; //6 decimals

    struct VestingSchedule {
        uint256 totalAmount; // Total USDC allocated to this employee
        uint256 startTime; // When vesting starts
        uint256 cliffDuration; // Cliff period in seconds (e.g., 365 days)
        uint256 vestingDuration; // Total vesting period in seconds (e.g., 4 years)
        uint256 released; // Amount already claimed by employee
        bool revoked; // Whether admin revoked this schedule
    }

    // Employee address => their vesting schedule
    mapping(address => VestingSchedule) public vestingSchedules;

    // Track total USDC locked in contract for all employees
    uint256 public totalAllocated;

    // Track which addresses have active vesting schedules
    mapping(address => bool) public hasVesting;

    // Optional: array to iterate through all beneficiaries if needed
    address[] public beneficiaries;

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    );
    event VestingScheduleRevoked(address indexed beneficiary);
    event TokensReleased(address indexed beneficiary, uint256 amount);

    constructor() Ownable(msg.sender) {
        // That's it! Keep it minimal
    }

    //pause functions
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    function changeOwner(address newOwner) public onlyOwner {
        transferOwnership(newOwner);
    }

    function fundContract(uint256 amount) public whenNotPaused nonReentrant onlyOwner {
        IERC20(USDC).safeTransferFrom(msg.sender, address(this), amount);
    }

    function createVestingSchedule(
        address beneficiary,
        uint256 totalAmount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    ) public whenNotPaused nonReentrant onlyOwner {
        require(totalAmount > 0, "Total amount must be greater than 0");
        // require(startTime > block.timestamp, "Start time must be in the future");
        require(cliffDuration > 0, "Cliff duration must be greater than 0");
        require(vestingDuration > 0, "Vesting duration must be greater than 0");
        require(beneficiary != address(0), "Beneficiary address cannot be zero");

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: totalAmount,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            released: 0,
            revoked: false
        });

        totalAllocated += totalAmount;
        hasVesting[beneficiary] = true;
        beneficiaries.push(beneficiary);

        emit VestingScheduleCreated(beneficiary, totalAmount, startTime, cliffDuration, vestingDuration);
    }
}
