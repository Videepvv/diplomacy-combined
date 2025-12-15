#!/usr/bin/env bash

set -euo pipefail

# Activate conda environment
source ~/miniconda3/etc/profile.d/conda.sh
conda activate cicero_engine

# Set paths
export CICERO_BASE="/home/videep/diplomacy_cicero"
CICERO_DIR=/data2/videep/cicero

# Add thirdparty modules to PYTHONPATH
export PYTHONPATH="/home/videep/diplomacy_cicero/thirdparty/github/fairinternal/postman:${PYTHONPATH:-}"

# GPT2 data path
export TRANSFORMERS_CACHE="$CICERO_DIR/gpt2"

BOT_TYPE=$1
shift

cd /home/videep/diplomacy_cicero

mkdir -p logs/
NOW=$(date -u +'%Y_%m_%d_%H_%M_%S')
LOG_FILE=logs/$NOW.txt

echo "Running $BOT_TYPE with args: $@"
echo "Logging to: $LOG_FILE"

python fairdiplomacy_external/mila_api_"$BOT_TYPE".py "$@" 2>&1 | tee "$LOG_FILE"
