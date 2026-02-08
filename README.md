# givememoney.fun — Crypto

On-chain programs and contracts for **givememoney.fun**, a cryptocurrency donation platform for streamers. Fans choose how they want to support creators—with **Ethereum (ETH)**, **Solana (SOL)**, **USD Coin (USDC)**, or **Tether (USDT)**—and streamers receive donations directly in crypto (e.g. via MetaMask, Phantom) with real-time alerts in OBS.

This repository holds the smart contracts and programs that power those flows.

## Repository structure

| Package        | Chain / stack     | Status   | Description                                                  |
|----------------|-------------------|----------|--------------------------------------------------------------|
| **solidity/**  | EVM (Ethereum)    | Current  | Streamer donation contract (ETH + ERC-20), built with Foundry |
| **solana/**    | Solana (Anchor)   | Current  | Solana donation program (SOL + SPL tokens), built with Anchor |

- **EVM (Solidity)**: Streamers register and receive ETH and ERC-20 token (e.g. USDC/USDT) donations on-chain. Uses OpenZeppelin for access control, reentrancy protection, and safe token transfers.
- **Solana (Anchor)**: Streamers register and receive SOL and SPL token (e.g. USDC/USDT on Solana) donations on-chain. Uses PDA-based authorization and supports Token-2022.

## Solidity (EVM) — Current

The `solidity/` package contains the **StreamerDonations** contract: streamers register once, then anyone can donate ETH or ERC-20 tokens to them with an optional message. A 5% platform fee is deducted and the remainder is forwarded to the streamer in the same transaction.

**Deployed on Sepolia**: `0xd966c30be2d5baa9c28031ff8126fba6244cfbb5`

### Features

- **Streamer registration**: One-time `registerStreamer()` so an address can receive donations.
- **ETH donations**: `donate(streamer, message)` — payable; enforces minimum amount (0.001 ETH) and max message length (280 chars).
- **ERC-20 token donations**: `donateWithToken(streamer, token, amount, message)` — supports any ERC-20 token (e.g. USDC, USDT) with `SafeERC20` transfers; minimum 1e6 token units.
- **Fee split**: 5% platform fee to the contract owner, 95% forwarded to the streamer.
- **Pause/unpause**: Owner can pause and resume all donations in emergencies.
- **Security**: `ReentrancyGuard`, `Pausable`, `Ownable` (OpenZeppelin).
- **Events**: `StreamerRegistered`, `DonationReceived` (donor, streamer, amount, message, timestamp, token) for indexing and OBS alerts.

### Tech stack

- **Solidity** ^0.8.20
- **Foundry** (Forge, Cast, Anvil) — build, test, deploy, local node
- **OpenZeppelin Contracts** — Ownable, ReentrancyGuard, Pausable, SafeERC20

### Quick start

```bash
cd solidity
forge build
forge test
```

### Scripts and deploy

- **Test**: `forge test` (see `test/StreamerDonations.t.sol`).
- **Deploy**: `PRIVATE_KEY=<key> forge script script/StreamerDonations.s.sol:DeployStreamerDonations --rpc-url <RPC_URL> --broadcast` (uses `PRIVATE_KEY` from env; see script for options).
- **Register streamer**: `make register-streamer-testnet` (requires `.env` with `RPC_URL`, `STREAMER_PRIVATE_KEY`, `CONTRACT_ADDRESS`).
- **Send donation**: `make transaction-testnet` (requires `.env` with `RPC_URL`, `PRIVATE_KEY`, `CONTRACT_ADDRESS`, `STREAMER_ADDRESS`).

See [solidity/README.md](solidity/README.md) for full Foundry usage (fmt, snapshot, anvil, cast).

---

## Solana (Anchor) — Current

The `solana/` package contains the **givememoney.fun** Anchor program: streamers register once, then anyone can donate SOL or SPL tokens to them with an optional message. A 5% platform fee is deducted and the remainder is forwarded to the streamer in the same transaction.

### Features

- **Program initialization**: `initialize()` sets up the global config PDA with authority and fee collector.
- **Streamer registration**: `register_streamer()` creates a PDA per streamer wallet to receive donations.
- **SOL donations**: `donate()` — transfers native SOL; enforces minimum amount (0.001 SOL) and max message length (280 chars).
- **SPL token donations**: `donate_with_token()` — supports any SPL token (e.g. USDC, USDT on Solana) via `transfer_checked`; Token-2022 compatible.
- **Fee split**: 5% platform fee to the fee collector, 95% forwarded to the streamer.
- **Pause/unpause**: Authority can pause and resume all donations in emergencies.
- **On-chain records**: Each donation creates an immutable PDA with donor, streamer, amount, message, timestamp, and token mint.
- **Events**: `StreamerRegistered`, `DonationReceived` for indexing and OBS alerts.
- **Security**: PDA-based authorization, checked arithmetic (overflow protection), signer validation.

### Tech stack

- **Rust** (edition 2021, toolchain 1.89.0)
- **Anchor** 0.32.1
- **Anchor SPL** 0.32.1 (Token-2022 support)
- **TypeScript** — tests with ts-mocha + chai

### Quick start

```bash
cd solana
anchor build
anchor test
```

### Program structure

```
programs/solana/src/
├── lib.rs                  # Program entrypoint (6 instructions)
├── constants.rs            # FEE_PERCENTAGE, MIN_DONATION_AMOUNT, MAX_MESSAGE_LENGTH
├── errors.rs               # Custom error codes
├── events.rs               # DonationReceived, StreamerRegistered
├── instructions/           # Instruction handlers
│   ├── initialize.rs       # Set up global config
│   ├── register_streamer.rs
│   ├── donate.rs           # SOL donations
│   ├── donate_with_token.rs # SPL token donations
│   ├── pause.rs
│   └── unpause.rs
└── state/                  # Account structures
    ├── config.rs           # Global config (authority, fee_collector, paused)
    ├── streamer.rs         # Streamer PDA (wallet, donation_count)
    └── donation.rs         # Donation record PDA
```

---

## Related repositories

- **Backend API**: [givememoney.fun-backend](https://github.com/Dnreikronos/givememoney.fun-backend) — Go API, auth (Twitch/Kick/email), wallets, transactions, WebSocket alerts for OBS.

---

## License

See the repository license file.
