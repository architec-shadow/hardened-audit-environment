# =====================================================================
# STEALTHOPS HARDENED MASTER ORCHESTRATOR
# IDENTITY: architec-shadow
# OPERATIONAL SECURITY: FAIL-CLOSED & HARDENED RUNTIME
# ARCHITECTURAL RED TEAM BLUEPRINT: SecOps Infrastructure Mapping
# =====================================================================

# RED TEAM SKILL MAPPING: Ingeniería Fail-Closed & Determinismo Operativo
# Forzar Bash evita comportamientos erráticos de sh (Dash), asegurando que 
# las estructuras de control reaccionen exactamente igual en cualquier host.
SHELL := /bin/bash

# RED TEAM SKILL MAPPING: Ejecución de Alta Fiabilidad (Fail-Closed Runtime)
# -e          : Aborta inmediatamente si algún comando retorna código != 0 (Evita brechas parciales).
# -u          : Bloquea si se intenta leer una variable ausente.
# -o pipefail : Propaga fallos en tuberías (|) impidiendo que errores oculten su estado real.
# -c          : Ejecuta la cadena de comandos de forma controlada.
.SHELLFLAGS := -eu -o pipefail -c

# RED TEAM SKILL MAPPING: Compartimentación de Entornos
# Inyecta `.env` solo si existe, exportando variables sin exponerlas globalmente en el sistema.
ifneq ($(wildcard .env),)
	include .env
	export
endif

# RED TEAM SKILL MAPPING: Gestión de Privilegios Cruzados Host-Contenedor
# Obtiene el UID/GID real del operador. Evita que los contenedores escriban artefactos
# propiedad de 'root' en volúmenes compartidos, previniendo bloqueos de archivos locales.
CURRENT_UID ?= $(shell id -u)
CURRENT_GID ?= $(shell id -g)

# RED TEAM SKILL MAPPING: Adaptabilidad Operativa Cero-Dobleces
# Detecta si la terminal es interactiva [ -t 0 ]. Asigna -it para control manual
# o -i para automatización silenciosa (CI/CD / despliegues desatendidos).
INTERACTIVE := $(shell [ -t 0 ] && echo "-it" || echo "-i")

# RED TEAM SKILL MAPPING: Rutas y Nombres de Contenedores Compartimentados
SCRIPT_EXEC       := ./stealthops.sh
CONTAINER_AUDIT   ?= stealth_audit
CONTAINER_FOUNDRY ?= stealth_foundry
ANVIL_RPC_URL     ?= http://stealth-anvil:8545

# RED TEAM SKILL MAPPING: Sanitización contra Inyección y Path Traversal
# Utiliza una Whitelist estricta ([a-zA-Z0-9_\-]) procesada mediante printf y subshells
# aislados, inmunizando la infraestructura ante comandos maliciosos inyectados por parámetros.
PROYECTO_RAW   := $(strip $(PROYECTO))
PROYECTO_CLEAN := $(shell PROY_ENV='$(subst ','\'',$(PROYECTO_RAW))'; printf '%s\n' "$$PROY_ENV" | sed -E 's/[^a-zA-Z0-9_\-]//g')
SUBDIR         := $(if $(PROYECTO_CLEAN),/$(PROYECTO_CLEAN),)

# Declaración explícita de Objetivos Ficticios (Evita colisiones con archivos locales)
.PHONY: help check-script check-opsec status up down core dev fuzz finanzas prod docker \
        audit audit-json foundry-init clean-anvil purge

# ---------------------------------------------------------------------
# MENÚ OPERATIVO OPSEC
# ---------------------------------------------------------------------

help:
	@echo "====================================================================="
	@echo "           STEALTHOPS HARDENED OPERATIONAL COMMANDS                  "
	@echo "====================================================================="
	@echo " [ ORQUESTACIÓN DE ENTORNOS ]"
	@echo "  make up           : Spin up full environment (Docker Full + Both Browsers)"
	@echo "  make down         : Securely shutdown, unmount tmpfs, and purge RAM"
	@echo "  make core         : Launch CORE backend (VSCodium + Anvil + Foundry)"
	@echo "  make dev          : Launch DEV backend (CORE + Rust & TS Suites)"
	@echo "  make fuzz         : Launch Security Fuzzers (Echidna + Medusa)"
	@echo "  make finanzas     : Launch isolated Finance Vault in RAM exclusively"
	@echo "  make prod         : Launch Production Node + DEV Backend"
	@echo "  make docker       : Launch Development Containers only"
	@echo "  make status       : Audit active containers and service status"
	@echo "---------------------------------------------------------------------"
	@echo " [ HARDENING & AUDITORÍA OPSEC ]"
	@echo "  make check-opsec  : Audita sintaxis de shell, permisos y dependencias"
	@echo "  make audit        : Run Slither Static Analysis on /share/work$(SUBDIR)"
	@echo "  make audit-json   : Export full structured Slither report to JSON"
	@echo "  make foundry-init : Initialize clean Foundry workspace at /app$(SUBDIR)"
	@echo "  make clean-anvil  : Send RPC signal to reset Anvil state to block 0"
	@echo "  make purge        : Alias for 'down' (Emergency RAM & process destruction)"
	@echo "====================================================================="

# ---------------------------------------------------------------------
# SANIDAD, SEGURIDAD Y AUDITORÍA OPSEC INLINE
# ---------------------------------------------------------------------

# Verificación de existencia del script orquestador y forzado de permisos mínimos.
check-script:
	@if [ ! -f $(SCRIPT_EXEC) ]; then \
		echo "[-] ERROR CRÍTICO: $(SCRIPT_EXEC) no existe en $(CURDIR)."; \
		exit 1; \
	fi
	@chmod 700 $(SCRIPT_EXEC)

# RED TEAM SKILL MAPPING: Validación Pre-Despliegue Fail-Closed
# Verifica de manera robusta (sin depender de tuberías frágiles) que el contenedor objetivo
# se encuentre activo antes de permitir la ejecución de operaciones en su interior.
check-container-%:
	@RUNNING=$$(docker inspect -f '{{.State.Running}}' $* 2>/dev/null || echo "false"); \
	if [ "$$RUNNING" != "true" ]; then \
		echo "[-] ERROR OPSEC: El contenedor '$*' no está en ejecución. Inícielo primero con 'make up' o 'make docker'."; \
		exit 1; \
	fi

# RED TEAM SKILL MAPPING: Auditoría de Postura y Dependencias del Host
# 1. Analiza la sintaxis estricta del script mediante ShellCheck o bash -n.
# 2. Valida la presencia de herramientas críticas de borrado seguro y control de procesos (shred, fuser).
# 3. Restringe de manera absoluta los permisos del orquestador (chmod 700).
check-opsec: check-script
	@echo "[*] Iniciando auditoría de postura OPSEC (Entorno de Alta Seguridad)..."
	@echo "[1/3] Validando sintaxis del script orquestador..."
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -s bash $(SCRIPT_EXEC) && echo "[+] ShellCheck: Sintaxis limpia sin advertencias."; \
	else \
		bash -n $(SCRIPT_EXEC) && echo "[+] Validado con bash -n (Atención: Instale 'shellcheck' para análisis profundo)."; \
	fi
	@echo "[2/3] Verificando presencia de dependencias críticas del Host..."
	@MISSING_TOOLS=0; \
	for tool in docker flatpak shred fuser; do \
		if ! command -v $$tool >/dev/null 2>&1; then \
			echo "[-] ERROR FATAL OPSEC: Herramienta requerida '$$tool' NO encontrada en el PATH del Host."; \
			MISSING_TOOLS=1; \
		else \
			echo "[+] Herramienta '$$tool': Presente."; \
		fi; \
	done; \
	if [ $$MISSING_TOOLS -eq 1 ]; then \
		echo "[-] POSTURA RECHAZADA: Instale las herramientas faltantes para prevenir fallos en la purga de memoria."; \
		exit 1; \
	fi
	@echo "[3/3] Asegurando permisos restrictivos de ejecutable (chmod 700)..."
	@chmod 700 $(SCRIPT_EXEC)
	@echo "[+] Permisos verificados y asegurados (rwx------)."
	@echo "[+] Auditoría OPSEC completada con éxito. Postura Aprobada."

status: check-script
	@$(SCRIPT_EXEC) --status

# ---------------------------------------------------------------------
# DESPLIEGUE Y ORQUESTACIÓN (Delegado a stealthops.sh previo check-opsec)
# ---------------------------------------------------------------------

up: check-opsec
	@$(SCRIPT_EXEC) --start-all

down: check-script
	@$(SCRIPT_EXEC) --stop

core: check-opsec
	@$(SCRIPT_EXEC) --core

dev: check-opsec
	@$(SCRIPT_EXEC) --dev

fuzz: check-opsec
	@$(SCRIPT_EXEC) --fuzz

finanzas: check-opsec
	@$(SCRIPT_EXEC) --finances

prod: check-opsec
	@$(SCRIPT_EXEC) --prod

docker: check-opsec
	@$(SCRIPT_EXEC) --docker

purge: down

# ---------------------------------------------------------------------
# AUDITORÍA ESTÁTICA Y SMART CONTRACTS (Aislamiento de Procesos en Docker)
# ---------------------------------------------------------------------

# RED TEAM SKILL MAPPING: Higiene Forense y Prevención de Bloqueo de Root
# Ejecuta Slither garantizando creación dinámica del directorio y utilizando una trampa
# de salida (trap EXIT) para reasignar automáticamente la propiedad de los archivos
# generados al UID:GID del host, incluso si ocurre un fallo o interrupción abrupta.
audit: check-container-$(CONTAINER_AUDIT)
	@echo "[*] Ejecutando análisis estático Slither en: /share/work$(SUBDIR)"
	@docker exec $(INTERACTIVE) --user root $(CONTAINER_AUDIT) bash -c \
		"trap 'chown -R $(CURRENT_UID):$(CURRENT_GID) \"/share/work$(SUBDIR)\" 2>/dev/null || true' EXIT; mkdir -p \"/share/work$(SUBDIR)\" && cd \"/share/work$(SUBDIR)\" && slither ."

audit-json: check-container-$(CONTAINER_AUDIT)
	@echo "[*] Exportando reporte Slither en formato JSON..."
	@docker exec $(INTERACTIVE) --user root $(CONTAINER_AUDIT) bash -c \
		"trap 'chown -R $(CURRENT_UID):$(CURRENT_GID) \"/share/work$(SUBDIR)\" 2>/dev/null || true' EXIT; mkdir -p \"/share/work$(SUBDIR)\" && cd \"/share/work$(SUBDIR)\" && slither . --json reporte_slither.json"
	@echo "[+] Reporte JSON generado en: infrastructure/work_data/work$(SUBDIR)/reporte_slither.json"

foundry-init: check-container-$(CONTAINER_FOUNDRY)
	@echo "[*] Inicializando entorno Foundry en: /app$(SUBDIR)"
	@docker exec $(INTERACTIVE) $(CONTAINER_FOUNDRY) sh -c \
		"trap 'chown -R $(CURRENT_UID):$(CURRENT_GID) \"/app$(SUBDIR)\" 2>/dev/null || true' EXIT; mkdir -p \"/app$(SUBDIR)\" && cd \"/app$(SUBDIR)\" && forge init --vscode --force"

# Envía señal RPC interna para purgar el estado de simulación en Anvil (retorno al bloque 0).
clean-anvil: check-container-$(CONTAINER_FOUNDRY)
	@echo "[*] Enviando señal RPC de reseteo a Anvil..."
	@docker exec $(INTERACTIVE) $(CONTAINER_FOUNDRY) sh -c "cast rpc anvil_reset --rpc-url $(ANVIL_RPC_URL)"
	@echo "[+] Estado de simulación en Anvil reseteado a bloque 0."
