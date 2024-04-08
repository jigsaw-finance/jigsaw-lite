#!/usr/bin/env just --justfile

# load .env file
set dotenv-load

# pass recipe args as positional arguments to commands
set positional-arguments

set export

_default:
  just --list

# utility functions
start_time := `date +%s`
_timer:
    @echo "Task executed in $(($(date +%s) - {{ start_time }})) seconds"

clean-all: && _timer
	forge clean
	rm -rf coverage_report
	rm -rf lcov.info
	rm -rf typechain-types
	rm -rf artifacts
	rm -rf out

remove-modules: && _timer
	rm -rf .gitmodules
	rm -rf .git/modules/*
	rm -rf lib/forge-std
	touch .gitmodules
	git add .
	git commit -m "modules"

# Install the Vyper venv
install-vyper: && _timer
    pip install virtualenv
    virtualenv -p python3 venv
    source venv/bin/activate
    pip install vyper==0.2.16
    vyper --version

# Install the Modules
install: && _timer
	forge install foundry-rs/forge-std

# Update Dependencies
update: && _timer
	forge update

remap: && _timer
	forge remappings > remappings.txt

# Builds
build: && _timer
	forge clean
	forge remappings > remappings.txt
	forge build --names --sizes

format: && _timer
	forge fmt

test-all: && _timer
	forge test -vvv

test-gas: && _timer
    forge test --gas-report

coverage-all: && _timer
	forge coverage --report lcov
	genhtml -o coverage --branch-coverage lcov.info --ignore-errors category

doc: && _timer
	forge doc --build

mt test: && _timer
	forge test -vvvvvv --match-test {{test}}

mp verbosity path: && _timer
	forge test -{{verbosity}} --match-path test/{{path}}

anvil-fork: && _timer 
	anvil --fork-url $MAINNET_RPC_URL --chain-id 31337

deploy-all chain: 
	just deploy-jPoints "$chain"
	just deploy-stakingManager "$chain"

deploy-stakingManager chain:
	#!/usr/bin/env bash

	chain=$(echo "$chain" | tr '[:lower:]' '[:upper:]')

	if [ "$chain" == 'ANVIL' ]; then
		chainId=31337
	elif [ "$chain" == 'SEPOLIA' ]; then
		chainId=11155111
	elif [ "$chain" == 'MAINNET' ]; then
		chainId=1
	else
		chainId=0
	fi

	rpc_url_var="${chain}_RPC_URL"
	ethscan_api_key_var="${chain}_ETHERSCAN_API_KEY"

	forge script DeployStakingManagerScript --rpc-url "${!rpc_url_var}" --slow --broadcast -vvvv --etherscan-api-key "${!ethscan_api_key_var}" --verify 

	# Save the deployment address to deployment addresses
	stakingManager_address=$(jq '.returns.stakingManager.value' "broadcast/DeployStakingManager.s.sol/$chainId/run-latest.json" | xargs)
	jq --arg address "$stakingManager_address" --arg chain "$chain" '.[$chain] |= . + { "stakingManagerAddress": $address }' ./deploymentAddresses.json > temp.json && mv temp.json ./deploymentAddresses.json

	# jq --arg address "$stakingManager_address" --arg chain "$chain" '. + { ($chain): { "stakingManagerAddress": $address } }' ./deploymentAddresses.json > temp.json && mv temp.json deploymentAddresses.json


# Deploy Jigsaw Points Contract
deploy-jPoints chain: && _timer
	#!/usr/bin/env bash
	chain=$(echo "$chain" | tr '[:lower:]' '[:upper:]')

	if [ "$chain" == 'ANVIL' ]; then
		chainId=31337
	elif [ "$chain" == 'SEPOLIA' ]; then
		chainId=11155111
	elif [ "$chain" == 'MAINNET' ]; then
		chainId=1
	else
		chainId=0
	fi

	rpc_url_var="${chain}_RPC_URL"
	ethscan_api_key_var="${chain}_ETHERSCAN_API_KEY"

	forge script DeployJigsawPointsScript --rpc-url "${!rpc_url_var}" --slow --broadcast -vvvv --etherscan-api-key "${!ethscan_api_key_var}" --verify 

	# Save the deployment address to StakingManagerConfig.json
	jPoints_address=$(jq '.returns.jPoints.value' "broadcast/DeployJigsawPoints.s.sol/$chainId/run-latest.json" | xargs)
	jq --arg address "$jPoints_address" '. + { "jPointsAddress": $address }' deployment-config/StakingManagerConfig.json >temp.json && mv temp.json deployment-config/StakingManagerConfig.json

	# Save the deployment address to deployment addresses
	jq --arg address "$jPoints_address" --arg chain "$chain" '.[$chain] |= . + { "jPointsAddress": $address }' ./deploymentAddresses.json > temp.json && mv temp.json deploymentAddresses.json
