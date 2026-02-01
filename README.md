# givememoney.fun — Crypto

On-chain programs and contracts for **givememoney.fun**, a cryptocurrency donation platform for streamers. Fans choose how they want to support creators—with **Ethereum (ETH)**, **Solana (SOL)**, **USD Coin (USDC)**, or **Tether (USDT)**—and streamers receive donations directly in crypto (e.g. via MetaMask, Phantom) with real-time alerts in OBS.

This repository holds the smart contracts and programs that power those flows.

## Repository structure

| Package        | Chain / stack     | Status   | Description                                      |
|----------------|-------------------|----------|--------------------------------------------------|
| **solidity/**  | EVM (Ethereum)    | Current  | Streamer donation contract (ETH), built with Foundry |
| **solana/**    | Solana (Anchor)   | Planned  | Solana donation program (SOL, SPL tokens)       |

- **EVM (Solidity)**: Streamers register and receive ETH donations on-chain; optional future support for ERC‑20 (e.g. USDC/USDT on Ethereum L2s) can be added here.
- **Solana (Anchor)**: A dedicated Solana package will be added later for SOL and SPL token donations (e.g. USDC on Solana), using [Anchor](https://www.anchor-lang.com/).

## Solidity (EVM) — Current

The `solidity/` package contains the **StreamerDonations** contract: streamers register once, then anyone can donate ETH to them with an optional message. Funds are forwarded to the streamer in the same transaction.

### Features

- **Streamer registration**: One-time `registerStreamer()` so an address can receive donations.
- **Donations**: `donate(streamer, message)` — payable; enforces minimum amount and max message length.
- **Events**: `StreamerRegistered`, `DonationReceived` (donor, streamer, amount, message, timestamp) for indexing and OBS alerts.
- **Constants**: `MIN_DONATION_AMOUNT` (e.g. 0.001 ether), `MAX_MESSAGE_LENGTH` (e.g. 280 chars).

### Tech stack

- **Solidity** ^0.8.20  
- **Foundry** (Forge, Cast, Anvil) — build, test, deploy, local node  

### Quick start

```bash
cd solidity
forge build
forge test
```

### Scripts and deploy

- **Test**: `forge test` (see `test/StreamerDonations.t.sol`).
- **Deploy**: `PRIVATE_KEY=<key> forge script script/StreamerDonations.s.sol:DeployStreamerDonations --rpc-url <RPC_URL> --broadcast` (uses `PRIVATE_KEY` from env; see script for options).

See [solidity/README.md](solidity/README.md) for full Foundry usage (fmt, snapshot, anvil, cast).

---

## Solana (Anchor) — Planned

A **Solana package** will be added to this repo using **Anchor**. It will:

- Implement streamer registration and donation flows on Solana.
- Support **SOL** and **SPL tokens** (e.g. USDC, USDT on Solana).
- Integrate with the same backend and frontend (e.g. Phantom, real-time alerts).

Until that package exists, all Solana-related work is planned under a future `solana/` (or similar) directory in this repository.

---

## Related repositories

- **Backend API**: [givememoney.fun-backend](https://github.com/Dnreikronos/givememoney.fun-backend) — Go API, auth (Twitch/Kick/email), wallets, transactions, WebSocket alerts for OBS.

---

## License

See the repository license file.
