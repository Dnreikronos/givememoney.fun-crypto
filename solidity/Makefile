.PHONY: deploy-testnet build test register-streamer-testnet transaction-testnet

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

# Register the streamer on testnet. Must be called with the streamer's own private key (STREAMER_PRIVATE_KEY).
register-streamer-testnet:
	@if [ -z "$$RPC_URL" ]; then echo "Error: RPC_URL not set in .env"; exit 1; fi
	@if [ -z "$$STREAMER_PRIVATE_KEY" ]; then echo "Error: STREAMER_PRIVATE_KEY not set in .env"; exit 1; fi
	@if [ -z "$$CONTRACT_ADDRESS" ]; then echo "Error: CONTRACT_ADDRESS not set in .env"; exit 1; fi
	cast send $$CONTRACT_ADDRESS \
		"registerStreamer()" \
		--rpc-url $$RPC_URL \
		--private-key $$STREAMER_PRIVATE_KEY

# Send a test donate transaction on testnet. Requires .env with PRIVATE_KEY, RPC_URL, CONTRACT_ADDRESS, and STREAMER_ADDRESS.
transaction-testnet:
	@if [ -z "$$RPC_URL" ]; then echo "Error: RPC_URL not set in .env"; exit 1; fi
	@if [ -z "$$PRIVATE_KEY" ]; then echo "Error: PRIVATE_KEY not set in .env"; exit 1; fi
	@if [ -z "$$CONTRACT_ADDRESS" ]; then echo "Error: CONTRACT_ADDRESS not set in .env"; exit 1; fi
	@if [ -z "$$STREAMER_ADDRESS" ]; then echo "Error: STREAMER_ADDRESS not set in .env"; exit 1; fi
	cast send $$CONTRACT_ADDRESS \
		"donate(address,string)" \
		$$STREAMER_ADDRESS \
		"Test donation from foundry" \
		--value 0.001ether \
		--rpc-url $$RPC_URL \
		--private-key $$PRIVATE_KEY
