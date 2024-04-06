# Jigsaw lite

[![test](https://github.com/groksmith/jigsaw-lite/actions/workflows/test.yml/badge.svg)](https://github.com/groksmith/jigsaw-lite/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/groksmith/jigsaw-lite/blob/main/LICENSE)

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview

Jigsaw Lite is a protocol designed to incentivize early users of the Jigsaw protocol by rewarding their interactions with the protocol before its full launch.

Utilizing the [Ion protocol](https://ionprotocol.io), Jigsaw Lite offers users the opportunity to earn yield by staking wstETH to Ion's [wstETH/weETH](https://www.app.ionprotocol.io/lend?collateralAsset=weETH&lenderAsset=wstETH&marketId=0) pool.

Beyond yield generation through the Ion protocol, participants receive rewards in the form of jPoints, the protocol's reward token. These jPoints will later be exchangeable for $Jig tokens, the governance token of Jigsaw.

For further details, please consult the documentation.

## Setup

This project uses [just](https://just.systems/man/en/) to run project-specific commands. Refer to installation instructions [here](https://github.com/casey/just?tab=readme-ov-file#installation).

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

## Audit Reports

### Upcoming Release

| Auditor | Report Link |
| ------- | ----------- |
| N/A     | N/A         |

## About Jigsaw

Jigsaw is a CDP-based stablecoin protocol that brings full flexibility and composability to your collateral through the concept of “dynamic collateral”.

Jigsaw leverages crypto’s unique permissionless composability to enable dynamic collateral in a fully non-custodial way.
Dynamic collateral is the missing piece of DeFi for unlocking unparalleled flexibility and capital efficiency by boosting your yield.

---

<p align="center">
</p>
