# Cicero Setup Fix Guide

This document details all the fixes and steps required to get the Cicero Diplomacy AI running locally without Docker. These fixes address dependency issues, version incompatibilities, and missing components in the original setup.

---

## Table of Contents

1. [Environment Setup](#1-environment-setup)
2. [System Dependencies](#2-system-dependencies)
3. [Building the dipcc C++ Module](#3-building-the-dipcc-c-module)
4. [Installing Python Dependencies](#4-installing-python-dependencies)
5. [Fixing Dependency Issues](#5-fixing-dependency-issues)
6. [Compiling Protobuf Files](#6-compiling-protobuf-files)
7. [Installing the nest Library](#7-installing-the-nest-library)
8. [Fixing Hardcoded Paths](#8-fixing-hardcoded-paths)
9. [Model Files Setup](#9-model-files-setup)
10. [Running the Advisor](#10-running-the-advisor)
11. [Version Reference](#11-version-reference)

---

## 1. Environment Setup

### Create a new conda environment with Python 3.8

Python 3.8 is required for compatibility with spacy 3.7.5 and thinc 8.2.5 (Python 3.7 is too old).

```bash
conda create -n cicero_engine python=3.8 -y
conda activate cicero_engine
```

### Install PyTorch 1.7.1 with CUDA 11.0

The codebase requires PyTorch 1.7.1 specifically:

```bash
conda install pytorch==1.7.1 torchvision==0.8.2 torchaudio==0.7.2 cudatoolkit=11.0 -c pytorch -y
```

### Install cuDNN

Required for CUDA operations:

```bash
conda install -c conda-forge cudnn=8.0 -y
```

---

## 2. System Dependencies

### Install CMake 3.26+

The dipcc build requires CMake 3.16+, but system CMake may be too old:

```bash
conda install -c conda-forge cmake=3.26 -y
```

### Install glog 0.4.0

**Important:** Use glog 0.4.0, NOT 0.7.x. The newer versions have incompatible C++ API changes.

```bash
# Remove newer versions if installed
conda remove glog -y 2>/dev/null

# Install correct version
conda install -c conda-forge glog=0.4.0 -y
```

### Install other build dependencies

```bash
conda install -c conda-forge gflags pybind11 -y
```

---

## 3. Building the dipcc C++ Module

The dipcc module is the C++ game engine for Diplomacy.

```bash
cd /home/videep/diplomacy_cicero

# Create build directory
mkdir -p dipcc/build
cd dipcc/build

# Configure with CMake
# Use Debug mode to avoid optimization issues
cmake .. \
  -DCMAKE_BUILD_TYPE=Debug \
  -DPYTHON_EXECUTABLE=$(which python) \
  -DCMAKE_PREFIX_PATH=$CONDA_PREFIX

# Build (use available cores)
make -j$(nproc)

# Copy the built module to fairdiplomacy
cp dipcc/python/pydipcc.cpython-38-x86_64-linux-gnu.so ../../fairdiplomacy/
```

### Verify the build

```bash
cd /home/videep/diplomacy_cicero
python -c "from fairdiplomacy import pydipcc; print('dipcc loaded successfully')"
```

---

## 4. Installing Python Dependencies

### Install from requirements-lock.txt

```bash
cd /home/videep/diplomacy_cicero
pip install -r requirements-lock.txt
```

### Install the fairdiplomacy package

```bash
pip install -e .
```

---

## 5. Fixing Dependency Issues

### Fix importlib-metadata for chiron_utils

The chiron_utils package uses `packages_distributions()` which isn't available in older importlib.metadata:

```bash
pip install importlib_metadata>=3.6
```

Then fix the chiron_utils package:

Edit `/home/videep/miniconda3/envs/cicero_engine/lib/python3.8/site-packages/chiron_utils/bots/__init__.py`:

Change:
```python
from importlib.metadata import packages_distributions
```

To:
```python
try:
    from importlib.metadata import packages_distributions
except ImportError:
    from importlib_metadata import packages_distributions
```

### Fix protobuf version

Use protobuf 3.19.x for compatibility:

```bash
pip install protobuf==3.19.6
```

---

## 6. Compiling Protobuf Files

The protobuf files need to be regenerated with a compatible protoc version.

### Download protoc 3.19.6

The system protoc or newer versions generate incompatible code. Use protoc 3.19.6:

```bash
cd /tmp
wget https://github.com/protocolbuffers/protobuf/releases/download/v3.19.6/protoc-3.19.6-linux-x86_64.zip
mkdir -p protoc319
unzip protoc-3.19.6-linux-x86_64.zip -d protoc319
```

### Regenerate protobuf files

```bash
cd /home/videep/diplomacy_cicero

# Set PATH to use the correct protoc
export PATH="/tmp/protoc319/bin:$PATH"

# Verify protoc version
protoc --version  # Should show: libprotoc 3.19.6

# Generate the protobuf Python files
make protos
```

### Verify protobuf files

Check that the generated files have the correct format:

```bash
grep "protoc_insertion_point(class_scope" conf/agents_pb2.py
```

This should return matches. If not, the protoc version was wrong.

---

## 7. Installing the nest Library

The codebase uses a custom `nest` library for tensor operations. **Do NOT install `nest` from PyPI** - that's a different package.

### Install from postman

```bash
cd /home/videep/diplomacy_cicero/thirdparty/github/fairinternal/postman
pip install nest/
```

### Verify installation

```bash
python -c "import nest; print('flatten' in dir(nest))"  # Should print: True
```

---

## 8. Fixing Hardcoded Paths

The code has hardcoded Docker paths that need to be fixed for local execution.

### Edit mila_api_advisor.py

Edit `/home/videep/diplomacy_cicero/fairdiplomacy_external/mila_api_advisor.py`:

Find (around line 93):
```python
agent_config = heyhi_utils.load_config(f"/diplomacy_cicero/conf/common/agents/cicero.prototxt")
```

Replace with:
```python
cicero_base = os.environ.get("CICERO_BASE", "/diplomacy_cicero")
agent_config = heyhi_utils.load_config(f"{cicero_base}/conf/common/agents/cicero.prototxt")
```

---

## 9. Model Files Setup

### Download models (if not already done)

The models can be downloaded using the provided script:

```bash
cd /home/videep/diplomacy_cicero
bash bin/download_model_files.sh 'dbEmG*yo@fuWzb79cx_pN7.TRm4cqk'
```

### Or extract from cicero.zip

If you have the cicero.zip file:

```bash
cd /data2/videep
unzip cicero.zip
```

### Symlink models directory

```bash
cd /home/videep/diplomacy_cicero
ln -sf /data2/videep/cicero/models models
```

### Fix corrupted model files

If any model file is corrupted (filled with zeros), re-download it:

```bash
cd /data2/videep

# Example: fix corrupted draw_classifier
wget https://dl.fbaipublicfiles.com/diplomacy_cicero/models/draw_classifier.gpg
gpg --batch --yes --passphrase 'dbEmG*yo@fuWzb79cx_pN7.TRm4cqk' \
    --output cicero/models/draw_classifier -d draw_classifier.gpg
```

### Verify model files

Check that model files are valid (should show PK header for .zip format):

```bash
for f in /data2/videep/cicero/models/*; do
    if [[ -f "$f" && ! "$f" =~ \.(dict|opt|json)$ ]]; then
        header=$(head -c 2 "$f" | xxd -p)
        if [[ "$header" == "504b" ]]; then
            echo "OK: $(basename $f)"
        elif [[ "$header" == "0000" ]]; then
            echo "CORRUPTED: $(basename $f)"
        fi
    fi
done
```

---

## 10. Running the Advisor

### Create the run script

Create `/home/videep/diplomacy_cicero/run_cicero_local.sh`:

```bash
#!/bin/bash
# Run Cicero locally without Docker

# Set environment variables
export CICERO_BASE="/home/videep/diplomacy_cicero"
export PYTHONPATH="${CICERO_BASE}:${CICERO_BASE}/thirdparty/github/fairinternal/postman:${PYTHONPATH}"
export TRANSFORMERS_CACHE="${CICERO_BASE}/.cache/huggingface"

# Change to Cicero directory
cd "${CICERO_BASE}"

# Parse command
CMD=$1
shift

echo "Running $CMD with args: $@"
echo "Logging to: logs/$(date +%Y_%m_%d_%H_%M_%S).txt"

if [ "$CMD" == "advisor" ]; then
    python fairdiplomacy_external/mila_api_advisor.py "$@"
elif [ "$CMD" == "player" ]; then
    python fairdiplomacy_external/mila_api_player.py "$@"
else
    echo "Unknown command: $CMD"
    echo "Usage: $0 [advisor|player] [args...]"
    exit 1
fi
```

Make it executable:

```bash
chmod +x /home/videep/diplomacy_cicero/run_cicero_local.sh
```

### Start the game server

In a separate terminal:

```bash
cd /home/videep/diplomacy
docker compose up -d
```

### Run the advisor

```bash
cd /home/videep/diplomacy_cicero
source ~/miniconda3/etc/profile.d/conda.sh
conda activate cicero_engine

./run_cicero_local.sh advisor \
    --host localhost \
    --port 8433 \
    --game_id YOUR_GAME_ID \
    --human_powers AUSTRIA
```

---

## 11. Version Reference

### Critical Package Versions

| Package | Version | Notes |
|---------|---------|-------|
| Python | 3.8.x | Required for spacy/thinc compatibility |
| PyTorch | 1.7.1 | Specific version required |
| CUDA Toolkit | 11.0 | Must match PyTorch build |
| cuDNN | 8.0.x | Required for CUDA operations |
| protobuf | 3.19.6 | Both pip package AND protoc binary |
| glog | 0.4.0 | NOT 0.7.x (API incompatible) |
| CMake | 3.16+ | 3.26 recommended |
| pybind11 | 3.0.1 | For C++ bindings |
| nest | 0.0.6 | From postman, NOT PyPI |

### Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| CICERO_BASE | /home/videep/diplomacy_cicero | Base directory |
| PYTHONPATH | Includes postman | For nest module |
| TRANSFORMERS_CACHE | .cache/huggingface | HuggingFace cache |

---

## Common Errors and Solutions

### Error: `module 'nest' has no attribute 'flatten'`

**Cause:** Wrong `nest` package installed or not installed at all.

**Solution:**
```bash
pip uninstall nest -y  # Remove wrong package if installed
cd /home/videep/diplomacy_cicero/thirdparty/github/fairinternal/postman
pip install nest/
```

### Error: `KeyError: 'storages'` when loading models

**Cause:** Corrupted model file (filled with zeros).

**Solution:** Re-download the specific model file (see Section 9).

### Error: `No module named 'conf.agents_pb2'`

**Cause:** Protobuf files not generated.

**Solution:** Run `make protos` with protoc 3.19.6 (see Section 6).

### Error: `glog` related C++ errors during dipcc build

**Cause:** glog 0.7.x has incompatible API.

**Solution:** Downgrade to glog 0.4.0 (see Section 2).

### Error: `importlib.metadata has no attribute 'packages_distributions'`

**Cause:** Python 3.8's importlib.metadata is too old.

**Solution:** Install importlib_metadata and fix chiron_utils (see Section 5).

---

## File Locations Summary

| Component | Path |
|-----------|------|
| Cicero Code | `/home/videep/diplomacy_cicero/` |
| Game Server | `/home/videep/diplomacy/` |
| Model Files | `/data2/videep/cicero/models/` |
| Models Symlink | `/home/videep/diplomacy_cicero/models` → above |
| Conda Environment | `/home/videep/miniconda3/envs/cicero_engine/` |
| Run Script | `/home/videep/diplomacy_cicero/run_cicero_local.sh` |
| Protoc 3.19.6 | `/tmp/protoc319/bin/protoc` |
| dipcc Build | `/home/videep/diplomacy_cicero/dipcc/build/` |

---

## Quick Start (After Setup)

```bash
# Terminal 1: Start game server
cd /home/videep/diplomacy
docker compose up -d

# Terminal 2: Run advisor
cd /home/videep/diplomacy_cicero
source ~/miniconda3/etc/profile.d/conda.sh
conda activate cicero_engine
./run_cicero_local.sh advisor --host localhost --port 8433 --game_id 123 --human_powers AUSTRIA

# Browser: Go to http://localhost:3000, create/join game, start playing
```
