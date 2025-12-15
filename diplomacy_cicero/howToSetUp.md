# How to Set Up and Run Cicero Advisor

This guide walks you through setting up and running the Cicero AI advisor for Diplomacy games.

## Prerequisites

- Conda environment `cicero_engine` already set up with all dependencies
- Model files available at `/data2/videep/cicero/models` (symlinked to `./models`)
- Docker installed for running the game server
- The `nest` library from postman (see Troubleshooting if you get `nest.flatten` errors)

---

## Architecture Overview

There are **two separate components** that need to run:

1. **Game Server** (in `/home/videep/diplomacy/`) - Hosts the Diplomacy game via web interface
2. **Cicero Advisor** (in `/home/videep/diplomacy_cicero/`) - AI that connects to games and provides advice

```
┌─────────────────────┐         ┌─────────────────────┐
│   Game Server       │◄───────►│   Cicero Advisor    │
│   (Docker)          │  API    │   (Python)          │
│   Port 3000 (web)   │  :8433  │                     │
│   Port 8433 (API)   │         │                     │
└─────────────────────┘         └─────────────────────┘
        ▲
        │ Browser
        ▼
┌─────────────────────┐
│   You (Human)       │
│   http://localhost  │
│   :3000             │
└─────────────────────┘
```

---

## Step 1: Start the Game Server

The game server runs in Docker and provides both a web interface and API.

### 1.1 Navigate to the diplomacy folder

```bash
cd /home/videep/diplomacy
```

### 1.2 Start the Docker containers

```bash
docker compose up -d
```

**What this does:**
- Starts a PostgreSQL database for storing game state
- Starts the Diplomacy web server
- Exposes port **3000** for the web interface
- Exposes port **8433** for the API (used by Cicero)

### 1.3 Verify the server is running

```bash
docker compose ps
```

You should see containers running. Access the web interface at:
- **http://localhost:3000**

---

## Step 2: Create a New Game

### 2.1 Open the web interface

Go to **http://localhost:3000** in your browser.

### 2.2 Create a game

1. Click on "Create Game" or similar option
2. Set up game parameters:
   - **Game ID**: Choose a memorable ID (e.g., `123`, `test_game`)
   - **Map**: Standard (default 7-player Diplomacy map)
   - **Phase length**: Set time per phase
   - **Players**: Assign powers (Austria, England, France, Germany, Italy, Russia, Turkey)

3. Note down the **Game ID** - you'll need it for the advisor

### 2.3 Join the game as a player (optional)

If you want to play as a human, join one of the powers through the web interface.

---

## Step 3: Start the Cicero Advisor

The advisor connects to an existing game and provides AI recommendations.

### 3.1 Open a new terminal

Keep the game server running in its terminal.

### 3.2 Navigate to the Cicero folder

```bash
cd /home/videep/diplomacy_cicero
```

### 3.3 Activate the conda environment

```bash
source ~/miniconda3/etc/profile.d/conda.sh
conda activate cicero_engine
```

### 3.4 Run the advisor

```bash
./run_cicero_local.sh advisor \
  --host localhost \
  --port 8433 \
  --game_id YOUR_GAME_ID \
  --human_powers POWER_NAME
```

**Parameters explained:**

| Parameter | Description | Example |
|-----------|-------------|---------|
| `--host` | Game server hostname | `localhost` |
| `--port` | Game server API port | `8433` |
| `--game_id` | The ID of the game to connect to | `123` |
| `--human_powers` | Power(s) the human controls (Cicero advises for these) | `AUSTRIA` |

**Example command:**

```bash
./run_cicero_local.sh advisor --host localhost --port 8433 --game_id 123 --human_powers AUSTRIA
```

### 3.5 Wait for initialization

The advisor will:
1. Load all AI models (~2-3 minutes first time)
2. Connect to the game server
3. Display "Waiting for game to start" until the game begins

**What you'll see:**
```
[INFO] Loading existing model params from models/dialogue
[INFO] Loading existing model params from models/draw_classifier
...
[INFO] Connection succeeds.
[INFO] Waiting for game to start
[INFO] Still waiting
```

---

## Step 4: Start the Game

### 4.1 Go back to the web interface

Open **http://localhost:3000** and navigate to your game.

### 4.2 Start the game

Once all players have joined (or you're ready to play with AI), start the game.

### 4.3 Cicero activates

Once the game starts, Cicero will:
- Analyze the current game state
- Suggest moves for the power(s) you specified
- Provide diplomatic message suggestions
- Update recommendations as the game progresses

### ⚠️ Important: CFR Search Takes Time!

**Cicero uses a computationally intensive CFR (Counterfactual Regret Minimization) search** to determine optimal moves. This is the same algorithm used in the original research paper.

**Expected wait times per move suggestion:**
- **2-5 minutes** per phase on a modern GPU
- The search runs **256 rollouts** by default (configured in `conf/common/agents/cicero.prototxt`)
- You'll see heavy C++ adjudicator output in the logs during this time

**What to expect in logs during search:**
```
[INFO] suggest_move called for AUSTRIA
I1127 23:11:37... adjudicator.cc:269]  ... (many lines of CFR rollout output)
I1127 23:12:54... adjudicator.cc:269]  ...
```

**After the search completes**, you'll see:
```
[INFO] Got agent_orders: ['A VIE - TYR', 'A BUD - GAL', ...]
[INFO] NEW suggested orders!
```

This is normal behavior - Cicero is doing extensive game-theoretic analysis to provide high-quality move suggestions.

---

## Command Reference

### Game Server Commands

```bash
# Start the game server
cd /home/videep/diplomacy
docker compose up -d

# Stop the game server
docker compose down

# View server logs
docker compose logs -f

# Check running containers
docker compose ps
```

### Cicero Advisor Commands

```bash
# Activate environment
source ~/miniconda3/etc/profile.d/conda.sh
conda activate cicero_engine

# Run advisor (basic)
./run_cicero_local.sh advisor --host localhost --port 8433 --game_id GAME_ID --human_powers POWER

# Run advisor with multiple human powers
./run_cicero_local.sh advisor --host localhost --port 8433 --game_id 123 --human_powers AUSTRIA ENGLAND

# Run as a player (Cicero plays autonomously)
./run_cicero_local.sh player --host localhost --port 8433 --game_id 123 --power FRANCE
```

### Power Names

Use these exact names for `--human_powers` or `--power`:
- `AUSTRIA`
- `ENGLAND`
- `FRANCE`
- `GERMANY`
- `ITALY`
- `RUSSIA`
- `TURKEY`

---

## Troubleshooting

### "Connection refused" error

**Problem:** Advisor can't connect to game server.

**Solution:**
```bash
# Check if Docker containers are running
cd /home/videep/diplomacy
docker compose ps

# Restart if needed
docker compose down
docker compose up -d
```

### "Waiting for game to start" indefinitely

**Problem:** Advisor connected but game hasn't started.

**Solution:** Go to the web interface and start the game.

### Model loading errors

**Problem:** Models fail to load or show corruption errors.

**Solution:** Re-download the corrupted model:
```bash
cd /data2/videep
wget https://dl.fbaipublicfiles.com/diplomacy_cicero/models/MODEL_NAME.gpg
gpg --batch --yes --passphrase 'dbEmG*yo@fuWzb79cx_pN7.TRm4cqk' --output cicero/models/MODEL_NAME -d MODEL_NAME.gpg
```

### Out of GPU memory

**Problem:** CUDA out of memory errors.

**Solution:** The models require significant GPU memory. Ensure no other GPU processes are running:
```bash
nvidia-smi  # Check GPU usage
```

### "module 'nest' has no attribute 'flatten'"

**Problem:** The `nest` module isn't installed or the wrong package is installed.

**Solution:** Install the correct `nest` library from postman:
```bash
conda activate cicero_engine
cd /home/videep/diplomacy_cicero/thirdparty/github/fairinternal/postman
pip install nest/
```

This installs the correct `nest` library (v0.0.6) with `flatten`, `map`, `map_many` functions needed for tensor operations.

---

## Quick Start Checklist

- [ ] Terminal 1: Start game server (`docker compose up -d` in `/home/videep/diplomacy`)
- [ ] Browser: Create game at http://localhost:3000
- [ ] Note the Game ID
- [ ] Terminal 2: Activate conda (`conda activate cicero_engine`)
- [ ] Terminal 2: Run advisor with your game ID
- [ ] Browser: Start the game
- [ ] Cicero provides advice!

---

## File Locations

| Component | Path |
|-----------|------|
| Game Server | `/home/videep/diplomacy/` |
| Cicero Code | `/home/videep/diplomacy_cicero/` |
| Model Files | `/data2/videep/cicero/models/` (symlinked to `./models`) |
| Cicero Config | `/home/videep/diplomacy_cicero/conf/common/agents/cicero.prototxt` |
| Run Script | `/home/videep/diplomacy_cicero/run_cicero_local.sh` |
