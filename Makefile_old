# =====================================================================
# STEALTHOPS MASTER ORCHESTRATOR
# IDENTITY: architec-shadow
# =====================================================================

.PHONY: help up down finanzas prod docker audit audit-json foundry-init

#inyection sure of environmete local state
ifneq ($(wildcard .env),)
    include .env
    export
endif

# Clean white spaces
PROYECTO_CLEAN = $(strip $(PROYECTO))

# Dynamic Subdirectory Routing (e.g., make audit PROYECTO=DeFiLab)
SUBDIR = $(if $(PROYECTO_CLEAN),/$(PROYECTO_CLEAN),)

help:
	@echo "===================================================="
	@echo "          STEALTHOPS OPERATIONAL COMMANDS           "
	@echo "===================================================="
	@echo "make up           : Spin up full environment (Docker + Nodes)"
	@echo "make down         : Securely shutdown and purge environment"
	@echo "make finanzas     : Launch isolated Finance Node exclusively"
	@echo "make prod         : Launch Production Node + Docker Backend"
	@echo "make docker       : Launch Development Containers only"
	@echo "----------------------------------------------------"
	@echo "make audit        : Run Slither Static Analysis on target folder"
	@echo "make audit-json   : Export full structured Slither report to JSON"
	@echo "make foundry-init : Force clean initialization of Foundry on target"
	@echo "make clean-anvil  : Reset state of blockchain of Anvil"
	@echo "===================================================="

up:
	@chmod +x stealthops.sh
	@./stealthops.sh --start-all

down:
	@chmod +x stealthops.sh
	@./stealthops.sh --stop

finanzas:
	@chmod +x stealthops.sh
	@./stealthops.sh --finanzas

prod:
	@chmod +x stealthops.sh
	@./stealthops.sh --prod

docker:
	@chmod +x stealthops.sh
	@./stealthops.sh --docker

audit:
	@echo "[*] Running Slither static analysis on: /share/work$(SUBDIR)"
	docker exec -it --user root stealth_audit bash -c "cd /share/work$(SUBDIR) && slither ."
	@docker exec -it --user root stealth_audit bash -c "chown -R 1000:1000 /share/work$(SUBDIR)" 2>/dev/null || true	

audit-json:
	@echo "[*] Exporting structured Slither report to JSON..."
	docker exec -it --user root stealth_audit bash -c "cd /share/work$(SUBDIR) && slither . --json reporte_slither.json"
	@docker exec -it --user root stealth_audit bash -c "chown -R 1000:1000 /share/work$(SUBDIR)" 2>/dev/null || true
	@echo "[+] Report generated at infrastructure/work_data/work$(SUBDIR)/reporte_slither.json"

foundry-init:
	@echo "[*] Initializing clean Foundry workspace at: /app$(SUBDIR)"
	docker exec -it stealth_foundry sh -c "cd /app$(SUBDIR) && forge init --vscode --force"
	@docker exec -it --user root stealth_foundry sh -c "chown -R ${USER_UID}:${USER_GID} /app$(SUBDIR)" 2>/dev/null || true

clean-anvil:
	@echo "[*] Send signal to reset to blockchain of Anvil..."
	docker exec -it  stealth_foundry sh -c "cast rpc anvil_reset --rpc-url http://stealth-anvil:8545"
	@echo "[+] State of simulation in Anvil reset to zero (block 0)."
