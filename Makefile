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
	@echo "===================================================="

up:
	@chmod +x stealthops.sh
	@./stealthops.sh --start-all

down:
	@./stealthops.sh --stop

finanzas:
	@./stealthops.sh --finanzas

prod:
	@./stealthops.sh --prod

docker:
	@./stealthops.sh --docker

audit:
	@echo "[*] Running Slither static analysis on: /share/work$(SUBDIR)"
	docker exec -it --user root stealth_audit bash -c "cd /share/work$(SUBDIR) && slither ."

audit-json:
	@echo "[*] Exporting structured Slither report to JSON..."
	docker exec -it --user root stealth_audit bash -c "cd /share/work$(SUBDIR) && slither . --json reporte_slither.json"
	@echo "[+] Report generated at infrastructure/work_data/work$(SUBDIR)/reporte_slither.json"

foundry-init:
	@echo "[*] Initializing clean Foundry workspace at: /app$(SUBDIR)"
	docker exec -it stealth_foundry sh -c "cd /app$(SUBDIR) && forge init --vscode --force"
