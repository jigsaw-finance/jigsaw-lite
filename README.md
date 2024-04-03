
# Jigsaw

[![test](https://github.com/groksmith/jigsaw-lite/actions/workflows/test.yml/badge.svg)](https://github.com/groksmith/jigsaw-lite/actions/workflows/test.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/groksmith/jigsaw-lite/blob/main/LICENSE)

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview


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

| Command | Action |
|---|---|
| `clean-all` | Description |
| `install-vyper` | Install the Vyper venv |
| `install` | Install the Modules |
| `update` | Update Dependencies |
| `build` | Build |
| `format` | Format code |
| `remap` | Update remappings.txt |
| `clean` | Clean artifacts, caches |


### Test Commands

| Command | Description |
|---|---|
| `test-all` | Run all tests |
| `coverage-all` | Run coverage |

Specific tests can be run using `forge test` conventions, specified in more detail in the Foundry [Book](https://book.getfoundry.sh/reference/forge/forge-test#test-options).


## Audit Reports

### XXXX Release

| Auditor | Report Link |
|---|---|

## Bug Bounty

## About Jigsaw

---

<p align="center">
</p>
