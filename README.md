# PropertyRentToken

ERC-20 smart contract for real estate tokenization, distributing rental income
proportionally to token holders in USDC.

This project models a real-world asset (RWA) use case: a real estate developer
tokenizes a property into fungible shares, and investors receive rental income
proportional to their holdings — without the contract ever iterating over a
holder list on-chain.

## Key design decisions

- **Fixed supply, minted once.** `NUM_TOKENS = 50,000` shares are minted in the
  constructor and never again, preventing silent dilution of existing holders.
- **Reward-per-token accumulator (pull over push).** Rent income updates a
  single global accumulator (`rewardPerTokenStored`); holders pull their share
  on demand via `claimRent()`. This avoids unbounded `for` loops over holders,
  which would eventually exceed the block gas limit and permanently lock the
  distribution function.
- **Oracle-reported price with circuit breaker.** `updatePrice()` is restricted
  to `ORACLE_ROLE` and limited to a maximum ±10% change per call, reducing the
  blast radius of a compromised or mistaken oracle update.
- **Duplicate-period protection.** `reportRentIncome()` requires a unique
  `periodId` per call, preventing accidental double-reporting of the same
  month's rent.
- **Checks-Effects-Interactions in `claimRent()`.** State is updated (`rewards`
  zeroed) before the external USDC transfer, preventing reentrancy.
- **USDC payouts, not token minting.** Rent is paid in USDC rather than newly
  minted property tokens, avoiding dilution of ownership percentages.

## Project structure

```
contracts/
  PropertyRentToken.sol   Main contract
  mocks/MockUSDC.sol       Test-only ERC-20 mock, standing in for USDC
test/
  PropertyRentToken.test.js
hardhat.config.js
```

## Getting started

```bash
npm install
npx hardhat compile
npx hardhat test
```

## Known limitations / next steps

- `Pausable` is inherited but not yet wired into any function — a deliberate
  placeholder for a future emergency-stop mechanism.
- The oracle role is currently a single address; a production deployment
  should use a multisig (e.g. Gnosis Safe) to reduce centralization risk.
- `transferFrom` in `depositRent()` does not yet use `safeTransferFrom`; this
  is planned as a follow-up alongside the `Pausable` integration.
- No on-chain marketplace yet — buying/selling shares is out of scope for this
  version and is planned as a separate module.

## License

MIT
