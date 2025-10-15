# Monad Environment Management Script

This document describes the usage of the `setup.sh` script, a tool designed to automate the setup and teardown of a local Monad development environment. It simplifies the process of initializing the necessary directory structure and data files, as well as cleaning them up.

## Prerequisites

Before running this script, ensure that:

- You have compiled binaries below.
> `monad`, `monad_mpt`, `monad_cli`, `monad-keystore`, `monad-node`, `monad-rpc`, `sign-name-record`
- Or put monad-bft repository at same position of this repository then use copy command

## Usage

First, you need to make the script executable. You only need to do this once.

```Bash
chmod +x setup.sh
```

After that, you can run the script with one of the available commands.

### General Syntax

```Bash
./setup.sh [command]
```
## Commands

The script provides three main commands: `copy`, `init`, and `del`.

### `copy`

This command finds and copies all required Monad binaries from the `monad-bft` project into your current project directory. This should be the first step in setting up the environment.

**Action:**

```Bash
./setup.sh copy
```

**What it does:**

1. Automatically detects if you have a `debug` or `release` build in the `../monad-bft/target` directory.
2. Copies the Rust-based binaries (`monad-node`, `monad-rpc`, etc.) from the detected build path.
3. Copies the C++ based binaries (`monad`, `monad-mpt`, etc.) from the `../monad-bft/monad-cxx/monad-execution/build` directory.
4. Places all binaries in the root of the current project, making them ready for the `init` command.

### `init`

This command sets up the entire development environment from scratch. It is the ideal starting point for a new setup.

**Action:**

```Bash
`./setup.sh init`
```

**What it does:**

1. Sets the project's root directory (`MONAD_ROOT`) to the current directory.
2. Creates a `data` directory to store all blockchain data and configurations.
3. Creates the required subdirectories (`node/ledger`, `node/triedb`).
4. Copies the genesis configuration file (`config/forkpoint.genesis.toml`) into `data/forkpoint` and renames it to `forkpoint.toml`.
5. Copies the genesis configuration file (`config/validators.toml`) into `data/validators` and renames it to `validators.toml`.
6. Pre-allocates a 100GB sparse file for the TrieDB to ensure sufficient space.
7. Initializes the TrieDB using the `monad_mpt` binary.
8. Writes the genesis state to the database using the `monad` binary.

### `del`

This command completely removes the data directory (`data`) and all its contents. Use this to reset your local environment.

⚠️ **Warning:** This action is irreversible and will delete all blockchain data, logs, and configuration files created by the `init` command.

**Action:**

```Bash
`./setup.sh del`
```

**What it does:**

1. Checks if the `data` directory exists.
2. Prompts you for confirmation to prevent accidental deletion.
3. If you confirm by typing `y` and pressing Enter, it permanently deletes the entire `data` directory.

## execution monad clients

### monad-execution

```bash
./monad \
  --chain monad_devnet \
  --db ./data/node/triedb/test.db \
  --block_db ./data/node/ledger \
  --statesync ./data/node/statesync.sock \
  --log_level INFO
```

### monad-consensus

```bash
./monad-node \
  --secp-identity ./config/id-secp \
  --bls-identity ./config/id-bls \
  --node-config ./config/node.toml \
  --devnet-chain-config-override ./config/devnet_chain_config.toml \
  --forkpoint-config ./data/forkpoint/forkpoint.toml \
  --validators-path ./data/validators/validators.toml \
  --statesync-ipc-path ./data/node/statesync.sock \
  --wal-path ./data/node/wal \
  --mempool-ipc-path ./data/node/mempool.sock \
  --control-panel-ipc-path ./data/node/controlpanel.sock \
  --ledger-path ./data/node/ledger \
  --triedb-path ./data/node/triedb
```

### monad-rpc

```bash
./monad-rpc \
	--node-config ./config/node.toml \
	--ipc-path ./data/node/mempool.sock \
	--triedb-path ./data/node/triedb \
  --otel-endpoint http://localhost:4317
```