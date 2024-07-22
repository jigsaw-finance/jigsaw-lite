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
	#!/usr/bin/env bash
	rm -rf coverage
	rm -f lcov.info
	forge coverage --report lcov --ffi

	delete=false

	while read -r line; do
		if [[ $line == TN* ]]; then
			read -r line
			if [[ $line == SF* ]]; then
				path=$(echo "$line" | cut -d':' -f2)
				if [[ $path == test* || $path == script* ]]; then
					delete=true
					continue
				fi
			fi
		fi

		if [[ $delete == false ]]; then
			if [[ $line == SF* ]]; then
				echo "TN:" >>lcov.info.pruned
			fi
			echo "$line" >>lcov.info.pruned
		fi

		if [[ $delete == true && $line == end_of_record* ]]; then
			delete=false
		fi

	done <lcov.info
	mv lcov.info.pruned lcov.info

	genhtml --branch-coverage --output "coverage" lcov.info
	open coverage/index.html


doc: && _timer
	forge doc --build

mt test: && _timer
	forge test -vvvvvv --match-test {{test}}

mp verbosity path: && _timer
	forge test -{{verbosity}} --match-path test/{{path}}

anvil-fork: && _timer 
	anvil --fork-url $MAINNET_RPC_URL --chain-id 31337

# Deploy Jigsaw Points Contract and StakingManager Contract
# Deploys using $CHAIN, $CHAIN_ID and ETHERSCAN set in .env
deploy-all:
	just deploy-jPoints
	just deploy-holdingManager
	just deploy-stakingManager
		
# Deploy Jigsaw Points Contract
# Deploys using $CHAIN, $CHAIN_ID and ETHERSCAN set in .env
deploy-jPoints: && _timer
	#!/usr/bin/env bash
	echo "Deploying Jigsaw Points to $CHAIN..."

	# Deploy Jigsaw Points Contract using DeployJigsawPointsScript.s.sol
	eval "forge script DeployJigsawPointsScript --rpc-url \"\${${CHAIN}_RPC_URL}\" --slow --broadcast -vvvv --etherscan-api-key \"\${${CHAIN}_ETHERSCAN_API_KEY}\" --verify"

	# Save the deployment address to StakingManagerConfig.json to use when deployoing Staking Manager
	jPoints_address=$(jq '.returns.jPoints.value' "broadcast/DeployJigsawPoints.s.sol/$CHAIN_ID/run-latest.json" | xargs)
	jq --arg address "$jPoints_address" '. + { "jPointsAddress": $address }' deployment-config/StakingManagerConfig.json >temp.json && mv temp.json deployment-config/StakingManagerConfig.json

	# Save the deployment address to deploymentAddresses.json
	jq --arg address "$jPoints_address" --arg chain "$CHAIN" '.[$chain] |= . + { "jPointsAddress": $address }' ./deploymentAddresses.json > temp.json && mv temp.json deploymentAddresses.json

# Deploy Jigsaw Points Contract
# Deploys using $CHAIN, $CHAIN_ID and ETHERSCAN set in .env
deploy-holdingManager: && _timer
	#!/usr/bin/env bash
	echo "Deploying Holding Manager to $CHAIN..."

	# Deploy Holding Manager Contract using DeployHoldingManagerScript.s.sol
	eval "forge script DeployHoldingManagerScript --rpc-url \"\${${CHAIN}_RPC_URL}\" --slow --broadcast -vvvv --etherscan-api-key \"\${${CHAIN}_ETHERSCAN_API_KEY}\" --verify"

	# Save the deployment address to StakingManagerConfig.json to use when deployoing Staking Manager
	holdingManager_address=$(jq '.returns.holdingManager.value' "broadcast/DeployHoldingManager.s.sol/$CHAIN_ID/run-latest.json" | xargs)
	jq --arg address "$holdingManager_address" '. + { "holdingManager": $address }' deployment-config/StakingManagerConfig.json >temp.json && mv temp.json deployment-config/StakingManagerConfig.json

	# Save the deployment address to deploymentAddresses.json
	jq --arg address "$holdingManager_address" --arg chain "$CHAIN" '.[$chain] |= . + { "holdingManager": $address }' ./deploymentAddresses.json > temp.json && mv temp.json deploymentAddresses.json


# Deploy StakingManager Contract
# Deploys using $CHAIN, $CHAIN_ID and ETHERSCAN set in .env
deploy-stakingManager:  && _timer
	#!/usr/bin/env bash
	echo "Deploying Staking Manager to $CHAIN..."

	# Deploy Staking Manager Contract using DeployStakingManagerScript.s.sol
	eval "forge script DeployStakingManagerScript --rpc-url \"\${${CHAIN}_RPC_URL}\" --slow --broadcast -vvvv --etherscan-api-key \"\${${CHAIN}_ETHERSCAN_API_KEY}\" --verify"

	# Save the deployment address to StakingManagerConfig.json to use when granting Staking Manager role 
	stakingManager_address=$(jq '.returns.stakingManager.value' "broadcast/DeployStakingManager.s.sol/$CHAIN_ID/run-latest.json" | xargs)
	jq --arg address "$stakingManager_address" '. + { "stakingManager_address": $address }' deployment-config/StakingManagerConfig.json >temp.json && mv temp.json deployment-config/StakingManagerConfig.json

	# Save the deployment address to deploymentAddresses.json
	jq --arg address "$stakingManager_address" --arg chain "$CHAIN" '.[$chain] |= . + { "stakingManagerAddress": $address }' ./deploymentAddresses.json > temp.json && mv temp.json ./deploymentAddresses.json

grant-stakingManagerRole: && _timer
	eval "forge script GrantRoleToStakingManager --rpc-url \"\${${CHAIN}_RPC_URL}\" --slow --broadcast -vvvv"