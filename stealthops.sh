#!/bin/bash

# =====================================================================
# STEALTHOPS CORE ORCHESTRATOR Script
# HARDENED OPSEC ENVIRONMENT RUNTIME
# =====================================================================

# exit if error in a moment process
set -eo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#load enviorement variables without injection and dataleaks
if [ -f "$BASE_DIR/.env" ];then
    #available automatic export of assign variables
    set -a
    source "$BASE_DIR/.env"
    set +a
else
    export USER_UID=$(id -u)
    export USER_GID=$(id -g)
fi


DIR_FINANCE="$BASE_DIR/infrastructure/brave_data"
DIR_PRODUCTION="$BASE_DIR/infrastructure/work_data/webconfig"
DIR_WORK="$BASE_DIR/infrastructure/work_data/work"
DIR_VSCODE="$BASE_DIR/infrastructure/vscode_config"

# Initialization with restrictive permisions (just owner user can read/write)
umask 0077
# Ensure precise local directory structures exist with tight permissions
mkdir -p "$DIR_FINANCE" "$DIR_PRODUCTION" "$DIR_WORK" "$DIR_VSCODE"

turnoff_all() {
    echo "[*] Auditing and identifying active StealthOps processes..."
    PIDS_FINANCE=$(pgrep -f "$DIR_FINANCE" || true)
    PIDS_PRODUCTION=$(pgrep -f "$DIR_PRODUCTION" || true)
    
    if [ -n "$PIDS_FINANCE" ]; then
        echo "[*] Sending SIGTERM to Finance-Vault..."
        echo "$PIDS_FINANCE" | xargs kill -15 > /dev/null 2>&1 || true
    fi    
    if [ -n "$PIDS_PRODUCTION" ]; then
        echo "[*] Sending SIGTERM to Production-Node..."
        echo "$PIDS_PRODUCTION" | xargs kill -15 > /dev/null 2>&1 || true
    fi

    if [ -n "$PIDS_FINANCE" ] || [ -n "$PIDS_PRODUCTION"]; then
        echo "[*] Allowing Runtime to flush cache to disk security (3s)..."
        sleep 3
    fi

    echo "[*] Tearing down Docker infrastructure..."
    cd "$BASE_DIR" && docker compose down --remove-orphans 
    echo "[+] StealthOps environment completely deactivated and neutralized."
}

up_docker() {
    echo "[*] Deploying DevSecOps Backend (VS Codium, Anvil, Foundry, Slither)..."
    cd "$BASE_DIR" && docker compose up -d
    #fast verify  of local node  to OpSec internal
    echo "[*] Awaiting  local simulation node consensus (Anvil)..."
    sleep 2
    if curl -s -X POST -H "Content-Type: application/json" \
    	--data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    	http://127.0.0.1:8545 > /dev/null; then
    	echo "{+] Local simulation node sucessfully running on http://127.0.0.1:8545"
    else
    	echo "[!] Warning: Simulation node did not respond on local port 8545."
    fi
}


# Flags of high hardering to Chronium
# --disable-encryption-assets: without telemetry and keys of operating system host
# --incognit: Don't save session in chromium 

BRAVE_HARDENED_FLAGS=(
    "--new-window"
    "--incognito"
    "--no-first-run"
    "--password-store=detect"
    "--disabled-sharing-features"
    "--disabled-save-password-bubble"
    "--disabled-ntp-most-liked"
    "--disabled-sync"
  )

up_finances() {
    echo "[*] Spawning Isolated Finance Vault [GREEN ZONE]..."
    flatpak run com.brave.Browser \
        --user-data-dir="$DIR_FINANCE" \
        --name="Finance-Vault" \
        --class="Finance-Vault" \
        --theme-color="#006400" \
        "${BRAVE_HARDENED_FLAGS[@]}" > /dev/null 2>&1 &
}

up_production() {
    echo "[*] Spawning Isolated Production Node [DARK BLUE ZONE]..."
    flatpak run com.brave.Browser \
        --user-data-dir="$DIR_PRODUCTION" \
        --name="Production-Node" \
        --class="Production-Node" \
        --theme-color="#0b3c5d" \
        "${BRAVE_HARDENED_FLAGS[@]}" > /dev/null 2>&1 &
}

case "$1" in
    --start-all)
        up_docker; up_finances; up_production ;;
    --finances)
        up_finances ;;
    --prod)
        up_docker; up_production ;;
    --docker)
        up_docker ;;
    --stop)
        turnoff_all ;;
    *)
        clear
        echo "===================================================="
        echo "          STEALTHOPS OPERATIONAL CENTER             "
        echo "===================================================="
        echo "1) Launch FULL Environment (Docker + Both Browser Nodes)"
        echo "2) Launch ISOLATED Finance Vault Only (Finance-Vault)"
        echo "3) Launch PRODUCTION Node + Docker DevSecOps Backend"
        echo "4) Launch DOCKER Containers Only"
        echo "----------------------------------------------------"
        echo "5) SECURE SHUTDOWN AND PURGE ALL RUNTIMES"
        echo "===================================================="
        read -p "Select operational target: " opcion
        
        case $opcion in
            1) up_docker; up_finances; up_production ;;
            2) up_finances ;;
            3) up_docker; up_production ;;
            4) up_docker ;;
            5) turnoff_all ;;
            *) echo "[!] Invalid selection." ;;
        esac
        ;;
esac
