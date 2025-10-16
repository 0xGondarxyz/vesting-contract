// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {VestingContract} from "../src/VestingContract.sol";

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
        // usdc = IERC20(USDC);
        vestingContract = new VestingContract(address(new MockUSDC()));
        USDC = address(new MockUSDC());

        //deal 1 million usdc token to this contract
        deal(USDC, address(this), 1_000_000_000 * 1e6);
    }

    function testCreateVestingSchedule() public {
        //create vesting schedule for user1
        vestingContract.createVestingSchedule(user1, 100 * 1e6, block.timestamp, 60 days, 180 days);
    }
}
