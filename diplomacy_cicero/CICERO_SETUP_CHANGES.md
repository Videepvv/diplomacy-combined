# Cicero Local Setup - Changes Documentation

This document describes all modifications made to run Cicero locally without Docker, including the `--fast` and `--ultrafast` configuration options.

## Table of Contents
1. [Overview](#overview)
2. [Environment Setup](#environment-setup)
3. [Core File Modifications](#core-file-modifications)
4. [New Configuration Files](#new-configuration-files)
5. [Usage Instructions](#usage-instructions)
6. [Performance Comparison](#performance-comparison)

---

## Overview

The Cicero project was originally designed to run inside Docker containers with hardcoded paths. These modifications enable running Cicero locally with a conda environment, and add `--fast` and `--ultrafast` configuration options for faster testing/development iterations.

### Key Changes Summary
| File | Type | Description |
|------|------|-------------|
| `fairdiplomacy_external/mila_api_advisor.py` | Modified | Added `CICERO_BASE` env var support, `--fast` and `--ultrafast` CLI flags |
| `conf/common/agents/cicero_fast.prototxt` | New | Fast config with 8 rollouts |
| `conf/common/agents/cicero_ultrafast.prototxt` | New | Ultrafast config with 1 rollout |
| `run_cicero_local.sh` | New | Helper script to run advisor locally |

---

## Environment Setup

### Conda Environment: `cicero_engine`
```bash
conda create -n cicero_engine python=3.8.20
conda activate cicero_engine

# PyTorch with CUDA 11.0
pip install torch==1.7.1+cu110 torchvision==0.8.2+cu110 torchaudio==0.7.2 \
    -f https://download.pytorch.org/whl/torch_stable.html

# Key dependencies
pip install protobuf==3.19.6
# ... (see requirements.txt for full list)
```

### Required External Dependencies
- **glog 0.4.0**: Must be installed at system level for dipcc
- **protobuf 3.19.6**: Both Python package and protoc compiler
- **CUDA 11.0**: GPU support

### Model Symlink
```bash
ln -sf /path/to/downloaded/models /home/videep/diplomacy_cicero/models
```

---

## Core File Modifications

### 1. `fairdiplomacy_external/mila_api_advisor.py`

#### Changes Made:

**A. CICERO_BASE Environment Variable (Lines 93-105)**
```python
# Before: Hardcoded Docker paths
# agent_config = heyhi.load_config('/diplomacy_cicero/conf/common/agents/cicero.prototxt')

# After: Dynamic path resolution with config selection
import os
cicero_base = os.environ.get('CICERO_BASE', '/home/videep/diplomacy_cicero')
use_ultrafast = os.environ.get('CICERO_USE_ULTRAFAST_CONFIG', '0') == '1'
use_fast = os.environ.get('CICERO_USE_FAST_CONFIG', '0') == '1'
if use_ultrafast:
    config_name = 'cicero_ultrafast.prototxt'
elif use_fast:
    config_name = 'cicero_fast.prototxt'
else:
    config_name = 'cicero.prototxt'
agent_config = heyhi.load_config(f'{cicero_base}/conf/common/agents/{config_name}')
logger.info(f"Successfully loaded CICERO config: {config_name} (ultrafast={use_ultrafast}, fast={use_fast})")
```

**B. Command Line Arguments (Lines 798-809)**
```python
parser.add_argument(
    "--fast",
    action="store_true",
    help="Use fast config with reduced rollouts for testing. (default: %(default)s)",
)
parser.add_argument(
    "--ultrafast",
    action="store_true",
    help="Use ultrafast config with minimal rollouts for very quick testing. (default: %(default)s)",
)
```

**C. Environment Variable Setting (Lines 815-825)**
```python
use_fast_config: bool = args.fast
use_ultrafast_config: bool = args.ultrafast

# Set environment variable so CiceroAdvisor can pick up the config choice
if use_ultrafast_config:
    os.environ['CICERO_USE_ULTRAFAST_CONFIG'] = '1'
elif use_fast_config:
    os.environ['CICERO_USE_FAST_CONFIG'] = '1'
```

**D. Logging Enhancement (Lines 838-844)**
```python
logger.info(
    "Arguments:\n"
    # ... existing args ...
    f"\tfast_config: {use_fast_config}\n"
    f"\tultrafast_config: {use_ultrafast_config}\n"
)
```

---

## New Configuration Files

### 2. `conf/common/agents/cicero_fast.prototxt`

A faster configuration that reduces computation time by limiting rollouts and search parameters.

**Key Parameter Changes from Original `cicero.prototxt`:**

| Parameter | Original | Fast |
|-----------|----------|------|
| `n_rollouts` | 256 | 8 |
| `n_messages` | 8 | 4 |
| `filter_top_k` | 5 | 3 |
| `n_rescore` | 30 | 10 |
| `parlai_req_size` | 30 | 10 |
| `parlai_batch_size` | 30 | 10 |
| `n_plausible_orders` | 35 | 10 |
| `batch_size` | 512 | 256 |
| `bilateral_search_num_cond_sample` | 20 | 5 |

<details>
<summary>Full cicero_fast.prototxt</summary>

```protobuf
includes { path: "searchbot/qre_rol0_p30.prototxt"; mount: "bqre1p.base_searchbot_cfg" }
includes { path: "orders/20220305_allorderindependentrollout_bilateralprefix.prototxt"; mount: "bqre1p.base_searchbot_cfg.parlai_model_orders" }
includes { path: "dialogue/20220729_dialogue_rolloutevery_replythresh_firstmessagethresh_5m.prototxt"; mount: "bqre1p.base_searchbot_cfg.dialogue" }
includes { path: "dialogue/nonsense_classifiers/20220728_ensemble_nonsense_classifier_speedpress_trial2_90recall.prototxt"; mount: "bqre1p.base_searchbot_cfg.dialogue.ensemble_nonsense_classifier" }

bqre1p {
    base_searchbot_cfg {
      model_path: "models/rl_search_orders.ckpt"
      value_model_path: "models/rl_value_function.ckpt"
      # ... (full content in file)
      n_rollouts: 8
      # ... 
    }
    num_player_types: 6
    agent_type: 2
    agent_type_is_public: false
    # ...
}
```
</details>

### 3. `conf/common/agents/cicero_ultrafast.prototxt`

The minimum viable configuration for rapid testing. Uses absolute minimum rollouts.

**Key Parameter Changes from Original `cicero.prototxt`:**

| Parameter | Original | Ultrafast | Purpose |
|-----------|----------|-----------|---------|
| `n_rollouts` | 256 | **1** | CFR rollouts (main speedup) |
| `n_rescore` | 30 | 10 | Order rescoring |
| `parlai_req_size` | 30 | 10 | ParlAI batch size |
| `parlai_batch_size` | 30 | 10 | ParlAI batch size |
| `n_plausible_orders` | 35 | 10 | Plausible orders to consider |
| `batch_size` | 512 | 256 | NN batch size |
| `bilateral_search_num_cond_sample` | 20 | 5 | Bilateral search samples |
| `exclude_n_holds` | 3 | 0 | Hold order exclusions |

<details>
<summary>Full cicero_ultrafast.prototxt</summary>

```protobuf
# Include the base cicero config
includes { path: "searchbot/qre_rol0_p30.prototxt"; mount: "bqre1p.base_searchbot_cfg" }
includes { path: "orders/20220305_allorderindependentrollout_bilateralprefix.prototxt"; mount: "bqre1p.base_searchbot_cfg.parlai_model_orders" }
includes { path: "dialogue/20220729_dialogue_rolloutevery_replythresh_firstmessagethresh_5m.prototxt"; mount: "bqre1p.base_searchbot_cfg.dialogue" }
includes { path: "dialogue/nonsense_classifiers/20220728_ensemble_nonsense_classifier_speedpress_trial2_90recall.prototxt"; mount: "bqre1p.base_searchbot_cfg.dialogue.ensemble_nonsense_classifier" }

bqre1p {
    base_searchbot_cfg {
      model_path: "models/rl_search_orders.ckpt"
      value_model_path: "models/rl_value_function.ckpt"

      br_corr_bilateral_search {
        enable_for_pseudo_order: True
        enable_for_final_order: True
        use_all_power_for_p_joint: True
        br_regularize_lambda: 3e-3
        min_unnormalized_weight: 0.02
        max_unnormalized_weight: 10
      }

      rollouts_cfg {
          year_spring_prob_of_ending: "1901,0.0;1909,1.0"
      }

      message_search {
        n_messages: 8
        strategy: FILTER
        filter_top_k: 5
      }

      # ULTRAFAST: Reduced plausible orders for speed
      plausible_orders_cfg {
        do_parlai_rescoring: true
        n_rescore: 10
        parlai_req_size: 10
        parlai_batch_size: 10
        n_plausible_orders: 10
        batch_size: 256
        allow_multi_gpu: 1
        exclude_n_holds: 0
      }

      br_corr_bilateral_search {
        bilateral_search_num_cond_sample: 5
      }

      bp_iters: 0
      # ULTRAFAST: Only 1 rollout
      n_rollouts: 1
      loser_bp_value: 0
      loser_bp_iter: 0

      cfr_messages: true
      do_incremental_search: true
      use_truthful_pseudoorders: true
      skip_policy_evaluation_for_truthful_pseudoorders: true
      use_greedy_po_for_rollout: true
      half_precision: true

      bilateral_dialogue {
        strategy: BEST_POP
      }

      parlai_model_orders {
        model_path: "models/cicero_imitation_bilateral_orders_prefix"
      }

      dialogue {
        pseudo_orders_correspondence_threshold: -5e-3
        rating_threshold_first_message: 1.0
        use_pseudoorders_initiate_sleep_heuristic: true
        grounding_last_playable_year: 1908
        initial_message_prompts_path: "models/markus_5m_prompts.json"
        block_initiation_if_pred_value_below: 0.01
        use_last_phase_silence_except_coordination_heuristic: true
      }
    }
    player_types {
      log_uniform {
        min_lambda: 1e-3
        max_lambda: 3e-1
      }
    }
    do_bayesian_updates: False
    num_player_types: 6
    agent_type: 2
    agent_type_is_public: false
    scale_lambdas_1901_spring: 10.0
    dynamic_lambda_stdev_espilon: 0.01
    dynamic_lambda_stdev_baseline: 0.05
    dynamic_lambda_stdev_num_samples: 100
}
```
</details>

### 4. `run_cicero_local.sh`

Helper script to run the advisor locally without Docker.

```bash
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
```

---

## Usage Instructions

### Starting the Game Server (Docker)
```bash
docker compose up
# Web UI: http://localhost:3000
# API: ws://localhost:8433
```

### Running the Advisor

**Standard Configuration (256 rollouts - slowest, best quality)**
```bash
./run_cicero_local.sh advisor --host localhost --port 8433 \
    --game_id <GAME_ID> --human_powers AUSTRIA
```

**Fast Configuration (8 rollouts)**
```bash
./run_cicero_local.sh advisor --host localhost --port 8433 \
    --game_id <GAME_ID> --human_powers AUSTRIA --fast
```

**Ultrafast Configuration (1 rollout - fastest, lower quality)**
```bash
./run_cicero_local.sh advisor --host localhost --port 8433 \
    --game_id <GAME_ID> --human_powers AUSTRIA --ultrafast
```

### Environment Variables
| Variable | Description | Default |
|----------|-------------|---------|
| `CICERO_BASE` | Root path to Cicero installation | `/home/videep/diplomacy_cicero` |
| `CICERO_USE_FAST_CONFIG` | Set to "1" to use fast config | "0" |
| `CICERO_USE_ULTRAFAST_CONFIG` | Set to "1" to use ultrafast config | "0" |
| `TRANSFORMERS_CACHE` | GPT-2 model cache location | - |

---

## Performance Comparison

| Config | n_rollouts | First Phase Time* | Quality |
|--------|------------|-------------------|---------|
| Default | 256 | ~6+ hours | Highest |
| Fast | 8 | ~1-2 hours | Good |
| Ultrafast | 1 | ~30 minutes | Acceptable for testing |

*Times are approximate and depend on hardware (tested on RTX 3090 24GB)

### Resource Usage
- **GPU**: Models loaded on GPU (~23GB VRAM on RTX 3090)
- **CPU**: CFR tree search is CPU-bound (uses `n_threads: 56` from `searchbot.prototxt`)
- **Memory**: ~32GB+ system RAM recommended

### Existing Parallelization Settings
The configs already include multi-threading and multi-GPU support:
- `n_threads: 56` in `rollouts_cfg` (inside `searchbot.prototxt`)
- `allow_multi_gpu: 1` in `plausible_orders_cfg`

---

## Notes

1. **Model Decryption**: Models must be decrypted before use (password required)
2. **GPU Requirement**: While CFR search is CPU-bound, neural network inference requires GPU
3. **Docker Dependency**: Game server still runs in Docker; only the advisor runs locally
4. **Config Priority**: `--ultrafast` takes precedence over `--fast` if both are specified

---

## Troubleshooting

### Common Issues

1. **"No module named 'postman'"**
   - Add postman to PYTHONPATH: `export PYTHONPATH=".../thirdparty/github/fairinternal/postman:$PYTHONPATH"`

2. **"glog version mismatch"**
   - Install glog 0.4.0 from source (not 0.7.x from apt)

3. **"protobuf version mismatch"**
   - Use protobuf 3.19.6: `pip install protobuf==3.19.6`

4. **Config loading errors**
   - Ensure `CICERO_BASE` is set correctly
   - Check that all included prototxt files exist

---

*Document created: Session notes for local Cicero setup*
*Last updated: During initial setup session*
