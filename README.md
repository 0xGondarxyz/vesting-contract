# Token Vesting Protocol

A secure and flexible vesting protocol for distributing ERC20 tokens (USDC) to team members, investors, or contributors over time with cliff periods and revocation capabilities.

## 🎯 Protocol Overview

This protocol allows administrators to:

- Create time-based vesting schedules for multiple beneficiaries
- Set cliff periods to prevent early token access
- Revoke unvested tokens if beneficiaries leave
- Manage excess funds safely
- Pause operations in emergencies

**Key Feature:** Uses a cliff mechanism to ensure long-term commitment before any tokens become available.

## 📊 Core Mechanics

### Vesting Calculation

- **Linear vesting**: Tokens unlock gradually over time after cliff period
- **Formula**: `vestedAmount = (totalAmount × timeElapsed) / vestingDuration`
- **Example**: 100,000 USDC vesting over 4 years with 1-year cliff
  - Year 0-1: 0 USDC available (cliff period)
  - Year 1: 25,000 USDC becomes claimable instantly when cliff ends
  - Year 2: 50,000 USDC total claimable
  - Year 3: 75,000 USDC total claimable
  - Year 4: 100,000 USDC fully vested

### Cliff System (The Key Protection)

**Problem Solved:** Without a cliff, employees could leave after a few months and still claim proportional tokens, reducing long-term commitment incentives.

**Solution:** No tokens vest during the cliff period. Once the cliff passes, tokens that would have vested during that period become immediately available.

**Example Flow:**

```
Day 0:   Admin creates schedule: 100K USDC, 1-year cliff, 4-year vesting
         └─ Employee gets 0 USDC immediately

Day 180: Employee tries to claim
         └─ Transaction reverts: "Still in cliff period" ❌

Day 365: Cliff ends!
         └─ Employee can now claim 25K USDC (1 year worth) ✅

Day 730: Employee claims again
         └─ Gets additional 25K USDC (total: 50K claimed)

Day 500: Admin revokes vesting (employee left)
         └─ Employee keeps ~34K USDC earned, loses remaining 66K
```

## 🔧 Main Functions

### Admin Functions

| Function                  | Description                      | Key Logic                                                           |
| ------------------------- | -------------------------------- | ------------------------------------------------------------------- |
| `createVestingSchedule()` | Set up vesting for a beneficiary | Allocates tokens, tracks in `totalAllocated`                        |
| `revoke()`                | Cancel unvested tokens           | Freezes vesting at current timestamp, employee keeps earned portion |
| `fundContract()`          | Deposit USDC into contract       | Admin must fund before creating schedules                           |
| `withdrawExcessFunds()`   | Withdraw unallocated USDC        | Can only withdraw: `balance - (allocated - released)`               |
| `pause()` / `unpause()`   | Emergency stop mechanism         | Prevents claims and new schedules during pause                      |

### Beneficiary Functions

| Function             | Description                          | Key Logic                                                        |
| -------------------- | ------------------------------------ | ---------------------------------------------------------------- |
| `claim()`            | Withdraw vested tokens               | Calculates claimable amount, updates `released`, transfers USDC  |
| `releasableAmount()` | View claimable tokens (read-only)    | Returns `vestedAmount - released`                                |
| `vestedAmount()`     | View total vested tokens (read-only) | Calculates based on time elapsed, considers cliff and revocation |

## 🔐 Security Features

- **ReentrancyGuard**: Prevents reentrancy attacks on claim/fund operations
- **Pausable**: Owner can pause in emergencies
- **Ownable2Step**: Safer ownership transfer (requires acceptance)
- **SafeERC20**: Handles ERC20 edge cases properly
- **Revocation Protection**: Only unvested tokens can be revoked
- **Excess Fund Protection**: `withdrawExcessFunds` can't touch allocated tokens
- **Cliff Validation**: Claims blocked until cliff period passes

## 📈 State Variables

### Per-Beneficiary Storage (VestingSchedule struct)

```solidity
struct VestingSchedule {
    uint256 totalAmount;        // Total USDC allocated
    uint256 startTime;          // When vesting begins
    uint256 cliffDuration;      // Cliff period (e.g., 365 days)
    uint256 vestingDuration;    // Total vesting period (e.g., 1460 days)
    uint256 released;           // Amount already claimed
    bool revoked;               // Whether admin canceled vesting
}
```

### Global State

- `totalAllocated`: Total USDC committed to all vesting schedules
- `hasVesting`: Quick lookup if address has a schedule
- `revokeTimestamp`: Timestamp when vesting was revoked (for calculating final vested amount)
- `beneficiaries[]`: Array of all beneficiary addresses
- `USDCAddress`: The ERC20 token being vested

## 🎬 User Journey Examples

### Standard Employee Vesting

```
1. Admin funds contract with 1M USDC
2. Admin creates schedule for Alice:
   - 100K USDC
   - Start: Now
   - Cliff: 1 year
   - Duration: 4 years

3. Month 6: Alice tries to claim → ❌ "Still in cliff"

4. Month 12: Alice claims
   → ✅ Receives 25K USDC (1 year worth)

5. Month 24: Alice claims
   → ✅ Receives 25K USDC (year 2)

6. Month 48: Alice claims final amount
   → ✅ Receives 50K USDC (years 3-4)
   → Total received: 100K USDC ✅
```

### Early Departure with Revocation

```
1. Admin creates schedule for Bob:
   - 100K USDC
   - Start: Jan 1, 2024
   - Cliff: 1 year
   - Duration: 4 years

2. Bob works for 18 months, claims 25K USDC after cliff

3. Month 18: Bob leaves, admin revokes
   → Bob keeps 25K already claimed
   → Bob can claim an additional ~12.5K (vested in 6 months since cliff)
   → Unvested 62.5K returns to admin's control

4. Admin can use withdrawExcessFunds() to recover the revoked tokens
```

### Multiple Beneficiaries

```
1. Admin funds contract with 1M USDC

2. Admin creates schedules:
   - Alice: 200K USDC (4-year vest, 1-year cliff)
   - Bob: 150K USDC (3-year vest, 6-month cliff)
   - Carol: 100K USDC (2-year vest, no cliff)

   → totalAllocated = 450K USDC
   → Available to withdraw: 1M - 450K = 550K USDC

3. Each beneficiary claims independently on their own schedule

4. Admin can withdraw the 550K excess at any time
```

## ⚠️ Important Considerations

### Admin Responsibilities

1. **Fund before creating schedules**: Ensure contract has enough USDC
2. **Track allocations**: Monitor `totalAllocated` vs contract balance
3. **Handle revocations carefully**: Consider legal implications
4. **Use pause wisely**: Only for genuine emergencies

### Beneficiary Notes

1. **Claim regularly**: Tokens vest continuously, but you must claim manually
2. **Understand your cliff**: No tokens available until cliff passes
3. **Check `releasableAmount()`**: View claimable tokens before claiming
4. **Gas costs**: You pay gas for claims, batch if possible

### Technical Limitations

1. **Loop in `getTotalReleased()`**: Gas cost increases with more beneficiaries (use cautiously for large-scale deployments)
2. **No re-vesting**: Once revoked, schedule cannot be reinstated
3. **Single schedule per address**: Can't have multiple concurrent schedules for same beneficiary
4. **No schedule modification**: Cannot change amounts/duration after creation (must revoke and recreate)

## 🚀 Deployment Checklist

- [ ] Deploy contract with correct USDC address
- [ ] Transfer ownership to proper admin address (if not deployer)
- [ ] Fund contract with sufficient USDC
- [ ] Create vesting schedules for beneficiaries
- [ ] Verify schedules using `vestingSchedules()` view function
- [ ] Test claim functionality with small schedule
- [ ] Document all schedules off-chain for record-keeping

## 📝 Common Patterns

### Typical Team Vesting

- **Duration**: 4 years
- **Cliff**: 1 year
- **Reason**: Industry standard, ensures long-term commitment

### Advisor Vesting

- **Duration**: 2 years
- **Cliff**: 6 months
- **Reason**: Shorter commitment, earlier value delivery

### Investor Vesting

- **Duration**: 1-2 years
- **Cliff**: 3-6 months
- **Reason**: Market stability, prevent immediate dumps

## 🔍 Monitoring & Analytics

### Key Metrics to Track

```solidity
// Total USDC committed
totalAllocated

// Currently locked (not yet vested)
totalAllocated - getTotalReleased()

// Contract health check
USDCAddress.balanceOf(address(this)) >= (totalAllocated - getTotalReleased())
```

### Per-Beneficiary Status

```solidity
// For address 0x123...
vestingSchedules[0x123...]      // Full schedule details
releasableAmount(0x123...)      // Claimable now
vestedAmount(0x123...)          // Total vested (including claimed)
```

## 🛡️ Security Best Practices

1. **Use multi-sig for owner**: Critical operations should require multiple approvals
2. **Audit before mainnet**: Get professional security audit
3. **Test thoroughly**: Cover edge cases (cliff boundaries, full vesting, revocations)
4. **Monitor events**: Track all VestingScheduleCreated, TokensReleased, VestingScheduleRevoked events
5. **Keep excess funds minimal**: Only fund what's allocated to reduce risk
6. **Document off-chain**: Maintain legal agreements matching on-chain schedules

## 📜 License

UNLICENSED

---

**Built with:**

- OpenZeppelin Contracts (Security-audited standards)
- Solidity ^0.8.13
- Foundry (Development framework)
