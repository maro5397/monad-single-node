#!/bin/bash

# ==============================================================================
# Monad Development Environment Management Script
#
# USAGE:
#   ./setup.sh init   : Initializes the development environment.
#   ./setup.sh del    : Deletes the created data directory.
#   ./setup.sh copy   : Copies necessary binaries from build directories.
# ==============================================================================

# --- Common Variables ---
# Set MONAD_ROOT to the current directory where the script is executed
export MONAD_ROOT=$(pwd)
# Set the path for the top-level data directory
export VOL_ROOT="$MONAD_ROOT/data"


# --- Function Definitions ---

# Displays the script's usage instructions
show_usage() {
  echo "Invalid usage."
  echo "Usage: $0 [init|del|copy]"
  echo "  init: Initialize and set up the Monad development environment."
  echo "  del:  Delete the created 'data' directory."
  echo "  copy: Copy Monad binaries from the build output directories."
  exit 1
}

# Helper function to safely copy a binary
copy_binary() {
  local src_file="$1"
  local dest_dir="$2"
  if [ -f "$src_file" ]; then
    cp "$src_file" "$dest_dir"
    echo "  - Copied $(basename "$src_file")"
  else
    echo "  - WARNING: Binary not found at '$src_file'. Skipping."
  fi
}

# Function to run the 'init' command
run_init() {
  # ... (init function remains unchanged) ...
  echo "Starting Monad development environment initialization..."
  echo "=========================================================="
  echo "1. Setting up environment variables and directory paths."
  echo " - Monad root directory: $MONAD_ROOT"
  echo " - Data directory: $VOL_ROOT"
  echo ""
  echo "2. Creating data directories and copying config file."
  mkdir -p "$VOL_ROOT/node/ledger"
  mkdir -p "$VOL_ROOT/node/triedb"
  mkdir -p "$VOL_ROOT/forkpoint"
  mkdir -p "$VOL_ROOT/validators"
  echo " - '$VOL_ROOT/node/ledger' created."
  echo " - '$VOL_ROOT/node/triedb' created."
  echo " - '$VOL_ROOT/forkpoint' created."
  echo " - '$VOL_ROOT/validators' created."
  cp "$MONAD_ROOT/config/forkpoint.genesis.toml" "$VOL_ROOT/forkpoint/forkpoint.toml"
  cp "$MONAD_ROOT/config/validators.toml" "$VOL_ROOT/validators/validators.toml"
  echo " - Genesis config file prepared at '$VOL_ROOT/forkpoint/forkpoint.toml', '$VOL_ROOT/validators/validators.toml'."
  echo ""
  DB_PATH="$VOL_ROOT/node/triedb/test.db"
  echo "3. Creating a 100GB sparse file for the TrieDB."
  if [ ! -f "$DB_PATH" ]; then
      truncate -s 100G "$DB_PATH"
      echo " - '$DB_PATH' (100GB) created."
  else
      echo " - File '$DB_PATH' already exists, skipping creation."
  fi
  echo ""
  echo "4. Initializing the TrieDB using monad_mpt..."
  MONAD_MPT_BIN="./monad_mpt"
  if [ ! -f "$MONAD_MPT_BIN" ]; then echo "Error: '$MONAD_MPT_BIN' not found. Did you run './setup.sh copy'?"; exit 1; fi
  "$MONAD_MPT_BIN" --storage "$DB_PATH" --create
  echo " - TrieDB initialization complete."
  echo ""
  echo "5. Writing the genesis state using monad..."
  MONAD_BIN="./monad"
  if [ ! -f "$MONAD_BIN" ]; then echo "Error: '$MONAD_BIN' not found. Did you run './setup.sh copy'?"; exit 1; fi
  "$MONAD_BIN" --chain monad_devnet --db "$DB_PATH" --block_db "$VOL_ROOT/node/ledger" --nblocks 0 --log_level ERROR
  echo " - Genesis state written successfully."
  echo ""
  echo "Monad development environment has been set up successfully."
}

# Function to run the 'del' command
run_del() {
  # ... (del function remains unchanged) ...
  echo "Starting deletion of the 'data' directory..."
  if [ -d "$VOL_ROOT" ]; then
    read -p "Are you sure you want to permanently delete the '$VOL_ROOT' directory and all its contents? (y/N): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
      echo "Deleting the '$VOL_ROOT' directory..."
      rm -rf "$VOL_ROOT"
      echo "Deletion complete."
    else
      echo "Deletion canceled."
    fi
  else
    echo "The '$VOL_ROOT' directory does not exist. Nothing to do."
  fi
}

# Function to run the 'copy' command
run_copy() {
  echo "Starting to copy binaries..."
  echo "==================================="

  # --- 1. Determine monad-bft source directory (debug or release) ---
  local BFT_SRC_PATH=""
  local BFT_DEBUG_PATH="$MONAD_ROOT/../monad-bft/target/debug"
  local BFT_RELEASE_PATH="$MONAD_ROOT/../monad-bft/target/release"

  if [ -d "$BFT_DEBUG_PATH" ]; then
    BFT_SRC_PATH="$BFT_DEBUG_PATH"
    echo "Found 'debug' build directory. Copying from debug path."
  elif [ -d "$BFT_RELEASE_PATH" ]; then
    BFT_SRC_PATH="$BFT_RELEASE_PATH"
    echo "Found 'release' build directory. Copying from release path."
  else
    echo "Error: Could not find 'debug' or 'release' build directories in '$MONAD_ROOT/../monad-bft/target/'."
    echo "Please build the monad-bft project first."
    exit 1
  fi
  echo ""

  # --- 2. Copy binaries from monad-bft ---
  echo "2. Copying binaries from monad-bft..."
  copy_binary "$BFT_SRC_PATH/monad-keystore" "$MONAD_ROOT"
  copy_binary "$BFT_SRC_PATH/monad-rpc" "$MONAD_ROOT"
  copy_binary "$BFT_SRC_PATH/monad-node" "$MONAD_ROOT"
  copy_binary "$BFT_SRC_PATH/examples/sign-name-record" "$MONAD_ROOT"
  echo ""

  # --- 3. Copy binaries from monad-cxx ---
  echo "3. Copying binaries from monad-cxx..."
  local CXX_BUILD_PATH="$MONAD_ROOT/../monad-bft/monad-cxx/monad-execution/build"
  copy_binary "$CXX_BUILD_PATH/cmd/monad" "$MONAD_ROOT"
  copy_binary "$CXX_BUILD_PATH/cmd/monad-cli" "$MONAD_ROOT"
  copy_binary "$CXX_BUILD_PATH/category/mpt/monad-mpt" "$MONAD_ROOT"
  echo ""

  echo "Binary copy process completed."
}


# --- Main Logic ---

# If no argument is provided, display usage instructions
if [ -z "$1" ]; then
  show_usage
fi

# Execute the appropriate function based on the first argument
case "$1" in
  init)
    run_init
    ;;
  del)
    run_del
    ;;
  copy)
    run_copy
    ;;
  *)
    show_usage
    ;;
esac
