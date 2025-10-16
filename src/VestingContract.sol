// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VestingContract is Ownable2Step, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public USDCAddress;

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
    mapping(address => uint256) public revokeTimestamp;

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

    constructor(address usdc) Ownable(msg.sender) {
        USDCAddress = IERC20(usdc);
    }

    //pause functions
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // modifier whenNotPaused() {
    //     require(!paused(), "Pausable: paused");
    //     _;
    // }

    // modifier vestingNotRevokedForBeneficiary(address beneficiary) {
    //     require(!vestingSchedules[beneficiary].revoked, "Vesting already revoked");
    //     _;
    // }

    function changeOwner(address newOwner) public onlyOwner {
        transferOwnership(newOwner);
    }

    function fundContract(uint256 amount) public whenNotPaused nonReentrant onlyOwner {
        USDCAddress.safeTransferFrom(msg.sender, address(this), amount);
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
        // require(cliffDuration > 0, "Cliff duration must be greater than 0");
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

    function releasableAmount(address beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];

        // If no vesting schedule exists, return 0
        if (!hasVesting[beneficiary]) {
            return 0;
        }

        // Calculate total vested amount up to now
        uint256 vested = vestedAmount(beneficiary);

        // Subtract what's already been released
        return vested - schedule.released;
    }

    function vestedAmount(address beneficiary) public view returns (uint256) {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];
        uint256 timeElapsed;
        uint256 vestedAmount;

        // If no schedule, return 0
        if (!hasVesting[beneficiary]) {
            return 0;
        }

        // If before cliff, nothing is vested yet
        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        //if revoked
        if (schedule.revoked) {
            //get revoke timestamp
            timeElapsed = revokeTimestamp[beneficiary] - schedule.startTime;
            vestedAmount = (schedule.totalAmount * timeElapsed) / schedule.vestingDuration;
            return vestedAmount;
        }

        // If past the full vesting duration, everything is vested and if not revoked
        if (block.timestamp >= schedule.startTime + schedule.vestingDuration) {
            return schedule.totalAmount;
        }

        // Otherwise, calculate linear vesting
        timeElapsed = block.timestamp - schedule.startTime;
        vestedAmount = (schedule.totalAmount * timeElapsed) / schedule.vestingDuration;

        return vestedAmount;
    }

    function claim() public whenNotPaused nonReentrant {
        uint256 releasable = releasableAmount(msg.sender);
        require(releasable > 0, "No releasable amount");
        vestingSchedules[msg.sender].released += releasable;
        USDCAddress.safeTransfer(msg.sender, releasable);
        emit TokensReleased(msg.sender, releasable);
    }

    function revoke(address beneficiary) public whenNotPaused nonReentrant onlyOwner {
        require(hasVesting[beneficiary], "No vesting schedule");
        vestingSchedules[beneficiary].revoked = true;
        revokeTimestamp[beneficiary] = block.timestamp;
        emit VestingScheduleRevoked(beneficiary);
    }

    function withdrawExcessFunds(uint256 amount) public onlyOwner nonReentrant {
        uint256 contractBalance = USDCAddress.balanceOf(address(this));
        uint256 availableToWithdraw = contractBalance - (totalAllocated - getTotalReleased());

        require(amount <= availableToWithdraw, "Insufficient excess funds");
        USDCAddress.safeTransfer(msg.sender, amount);
    }

    // Helper function
    function getTotalReleased() public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            total += vestingSchedules[beneficiaries[i]].released;
        }
        return total;
    }

    receive() external payable {}
    fallback() external payable {}
}
