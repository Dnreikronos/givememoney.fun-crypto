.PHONY: deploy-testnet build test

# Load .env if present (RPC_URL for deploy)
-include .env
export

build:
	forge build

test:
	forge test

# Deploy to Sepolia via Alchemy. Requires .env with PRIVATE_KEY and RPC_URL.
deploy-testnet:
	@if [ -z "$$RPC_URL" ]; then echo "Error: RPC_URL not set. Copy .env.example to .env and set RPC_URL (e.g. Alchemy Sepolia URL)."; exit 1; fi
	forge script script/StreamerDonations.s.sol:DeployStreamerDonations \
		--rpc-url $$RPC_URL \
		--broadcast
