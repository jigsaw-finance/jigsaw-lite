# Jigsaw lite

<p align="center">
  <img src="https://github.com/jigsaw-finance/jigsaw-lite/assets/102415071/894b1ec7-dcbd-4b2d-ac5d-0a9d0df26313" alt="jigsaw 2"><br>
  <a href="https://github.com/jigsaw-finance/jigsaw-lite/actions/workflows/test.yml">
    <img src="https://github.com/jigsaw-finance/jigsaw-lite/actions/workflows/test.yml/badge.svg" alt="test">
  </a>
  <a href="https://github.com/jigsaw-finance/jigsaw-lite/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT">
  </a>
  <img alt="GitHub commit activity (branch)" src="https://img.shields.io/github/commit-activity/m/jigsaw-finance/jigsaw-lite">
</p>

 
[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview

Jigsaw Lite is a protocol designed to incentivize early users of the Jigsaw protocol by rewarding their interactions with the protocol before its full launch.

Utilizing the [Ion protocol](https://ionprotocol.io), Jigsaw Lite offers users the opportunity to earn yield by staking whitelisted underlying assets to Ion's pools.

Beyond yield generation through the Ion protocol, participants receive rewards in the form of jPoints, the protocol's reward token. These jPoints will later be exchangeable for $Jig tokens, the governance token of Jigsaw.

For further details, please consult the documentation.

## Setup

This project uses [just](https://just.systems/man/en/) to run project-specific commands. Refer to installation instructions [here](https://github.com/casey/just?tab=readme-ov-file#installation).

Certain project-specific commands involve working with JSON files. To facilitate this, we utilize [jq](https://jqlang.github.io/jq/), a command-line JSON processor. If you haven't installed jq yet, refer to installation instructions [here](https://jqlang.github.io/jq/download/).

Project was built using [Foundry](https://book.getfoundry.sh/). Refer to installation instructions [here](https://github.com/foundry-rs/foundry#installation).

```sh
git clone git@github.com:groksmith/jigsaw-lite.git
cd jigsaw-lite
forge install
```

## Commands

To make it easier to perform some tasks within the repo, a few commands are available through a justfile:

### Build Commands

| Command         | Action                                           |
| --------------- | ------------------------------------------------ |
| `clean-all`     | Description                                      |
| `install-vyper` | Install the Vyper venv                           |
| `install`       | Install the Modules                              |
| `update`        | Update Dependencies                              |
| `build`         | Build                                            |
| `format`        | Format code                                      |
| `remap`         | Update remappings.txt                            |
| `clean`         | Clean artifacts, caches                          |
| `doc`           | Generate documentation for Solidity source files |

### Test Commands

| Command        | Description   |
| -------------- | ------------- |
| `test-all`     | Run all tests |
| `coverage-all` | Run coverage  |

Specific tests can be run using `forge test` conventions, specified in more detail in the Foundry [Book](https://book.getfoundry.sh/reference/forge/forge-test#test-options).

### Deploy Commands

| Command                 | Description                                                                                                    |
| ----------------------- | -------------------------------------------------------------------------------------------------------------- |
| `anvil-fork`            | Launch a local testnet forked from the mainnet                                                                 |
| `deploy-all`            | Deploy both the Jigsaw Points Contract and Staking Manager Contract to a blockchain specified in the .env file |
| `deploy-jPoints`        | Deploy only the Jigsaw Points Contract to a blockchain specified in the .env file                              |
| `deploy-stakingManager` | Deploy only the Staking Manager Contract to a blockchain specified in the .env file.                           |

## Audit Reports

### Upcoming Release

| Auditor | Report Link                                                        |
| ------- | ------------------------------------------------------------------ |
| Halborn | [Audit](https://www.halborn.com/audits/jigsaw-finance/jigsaw-lite) |

## About Jigsaw

Jigsaw is a CDP-based stablecoin protocol that brings full flexibility and composability to your collateral through the concept of “dynamic collateral”.

Jigsaw leverages crypto’s unique permissionless composability to enable dynamic collateral in a fully non-custodial way.
Dynamic collateral is the missing piece of DeFi for unlocking unparalleled flexibility and capital efficiency by boosting your yield.

---

<p align="center">
</p>
