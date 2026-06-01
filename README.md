# StealthOps: Hardened DevSecOps & Web3 Auditing Workspace
### Identity Focus: architec-shadow

## Overview
**StealthOps** is a containerized, defensively isolated, and highly automated local infrastructure designed for high-stakes Web3 security operations, smart contract auditing, and sensitive financial management. 

Operating under strict Operational Security (OpSec) protocols, this workspace enforces behavioral and systemic compartmentalization. It segregates volatile development execution tools, static application security testing (SAST) runtimes, and local ledger simulations from high-visibility transaction execution boundaries.

---

## Architecture & Toolchain Rationale

The architecture implements Compartmentalization by Design, splitting workflows into three distinct isolation domains to mitigate cross-contamination, session hijacking, and metadata leakage:
```text

            +---------------------------------------+
            |        HOST (Parrot OS / Debian)      |
            +---------------------------------------+
                                |
   +----------------------------+----------------------------+
   |                            |                            |
+---------------+            +---------------+            +-----------------+
| GREEN ZONE    |            | BLUE ZONE     |            | BLACK BOX       |
| Finance Node  |            | Prod Node     |            | Docker Network  |
+-------------- +            +---------------+            +-----------------+
| - Brave (FP)  |            | - Brave (FP)  |            | - VS Codium IDE |
| - Cold Wallets|            | - Web3 Apps   |            | - Foundry Anvil |
| - DeFi Ops    |            | - Git Tracking|            | - Slither SAST  |
+---------------+            +---------------+            +-----------------+
```
### 1. The Financial Vault (Green Zone)
* Engine: Flatpak-isolated Brave Browser instance running over strict non-persistent, incognito parameters.
* Purpose: Exclusively dedicated to interaction with smart contract protocols, private key orchestration, protocol governance, and capital execution. 
* The "Why" (OpSec Rationale): Total isolation from the development layer blocks malicious npm/pip dependencies or local scripts running on localhost from extracting sensitive wallet sessions or browser memory states.

### 2. The Production & Deployment Node (Dark Blue Zone)
* Engine: Parallel Flatpak-isolated Brave Browser instance mapped to a segregated configuration volume.
* Purpose: Tracking deployment states, frontend interactions, continuous integration parameters, and general research.
* The "Why" (OpSec Rationale): Isolates daily workspace research footprints, social media, and web browsing history from the capital management interface.

### 3. The Decoupled Audit & Dev Backend (Black Box Network)
* Engine: Docker-engineered environment running isolated tools over bridged networks (stealth_net).
* Components:
    * OpenVSCode-Server: Web-accessible IDE running inside a containerized sandbox. Blocks host-level file enumeration vulnerabilities during audit sessions.
    * Foundry Toolkit: High-performance local Ethereum execution engine (anvil, forge). Permits dynamic assertions and fuzzing attacks without interacting with external RPC nodes.
    * Eth-Security-Toolbox (Trail of Bits): Native compilation environment for Slither and Python-based bytecode analysis engines.

---

## 🛡️ Hardened Security Architecture ((Senior Red Team Review)

This environment goes beyond mere tool isolation; it features specific countermeasures designed to mitigate real-world attack vectors used by threat actors to drain developer and auditor wallets.

### 1. Principle of Least Privilege (No Root Execution)
* What it does: Both the Makefile and docker-compose.yml force containers to run under your standard local user's UID/GID (1000:1000), completely removing the --user root flag.
* Why it matters: If an auditing tool or a malicious Python/Node dependency attempts to exploit a vulnerability to break out of the container (Container Escape), it will find itself restricted without root privileges on the host system. This blocks an attacker from gaining full control of your machine.

### 2. Kernel Capability Stripping (cap_drop: - ALL)
* What it does: By default, Docker grants containers certain privileges to interface with your host's system kernel. In stealth_foundry and stealth_audit, we have surgically stripped away ALL of these capabilities.
* Why it matters: Compiling Solidity or running static analysis with Slither requires no low-level network modifications or hardware clock access. Turning off these permissions closes the door on advanced kernel-level exploitation techniques.

### 3. Browser Credential Leakage Mitigation
* What it does: The Brave nodes launch with the flags --password-store=detect, --disable-save-password-bubble, and --incognito.
* Why it matters: Chromium-based browsers natively store history, cookies, and sessions in plaintext or with weak local encryption. If your machine gets compromised, an automated script can harvest your Web3 sessions in milliseconds. This configuration destroys session cookies upon closing the browser and suppresses password retention prompts, enforcing the use of external hardware wallets.

### 4. Extreme Attack Surface Reduction (Confined Volumes)
* What it does: The security audit container maps exclusively the targeted smart contract codebase path rather than the entire infrastructure tree: ./infrastructure/work_data/work:/share/work.
* Why it matters: If you audit a malicious protocol that runs hidden scripts within its testing suite to enumerate your local files, the container remains completely blind to your production configurations, web caches, or browser histories. Code execution is strictly sandboxed.

### 5. Critical Failure Boundary Control (set -eo pipefail)
* What it does: Immediately halts the execution of the orchestration script stealthops.sh if any intermediate command outputs an error code.
* Why it matters: In standard shell scripts, if a security setup command fails, the script blindly processes subsequent commands. If a secure container network fails to initialize but the script continues, you would be exposed without realizing it. Here, the slightest runtime fault aborts the entire deployment.

---

## Host Prerequisites & System Dependencies

Before orchestrating the infrastructure, the host machine must support the following utilities:

* Docker & Docker Compose (v2.0+): Containerized runtime isolation.
* Flatpak: For containerizing application boundaries at the desktop level.
    * App Dependent: com.brave.Browser must be installed via Flatpak.
* Core Utilities: pgrep and kill for programmatic tracking and memory neutralization.

To set up the host requirements on Debian/Parrot OS architectures, execute:

```bash
    sudo apt update && sudo apt install docker.io docker-compose flatpak pgrep -y
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    flatpak install flathub com.brave.Browser -y
```
---

## Directory Structure

```text
    .
    ├── docker-compose.yml       # Hardened infrastructure container definition
    ├── Makefile                 # Operational control plane macro instructions (Absorbs .env)
    ├── README.md                # Technical documentation & OpSec Manual
    ├── stealthops.sh            # Hardened automation, sandboxing and security script
    └── infrastructure/          # High-isolation volume directory (Restricted via umask 0077)
        ├── brave_data/          # Ephemeral/Isolated Finance state (Git Ignored)
        ├── vscode_config/       # Persistent IDE parameters (Git Ignored)
        └── work_data/
            ├── webconfig/       # Isolated Production node state (Git Ignored)
            └── work/            # Active Smart Contract Audit workspace (Git Ignored)
```
`
---

## Installation & Deployment Guide

### 1. Initialize Git & Enforce OpSec Boundaries

```bash 

    # Initialize repository
    git init

    # Establish environment variables
    cp .env.example .env

    # Edit .env file to configure your security tokens and user IDs
    nano .env
```

### 2. Operational Command Plane (The Makefile)

El Makefile es inteligente: detecta automáticamente si existe un archivo .env y absorbe tus variables globales (como el nombre de tu proyecto actual PROYECTO=prueba_foundry), manteniendo sincronizada toda la infraestructura.

* **make up**: Enciende el backend DevSecOps e inicia de forma aislada los nodos de navegación.
* **make down**: Purga de Seguridad. Aplica un apagado grácil de 3 segundos para evitar corromper bases de datos criptográficas y luego destruye los contenedores y sus volúmenes efímeros.
* **make finanzas**: Lanza exclusivamente la Bóveda Financiera (Zona Verde).
* **make prod**: Lanza el nodo de producción y el backend de Docker.
* **make docker**: Activa únicamente los entornos de desarrollo aislados (IDE, Foundry, Slither).

#### DevSecOps & Audit Execution
Para auditar subproyectos específicos sin moverte de tu terminal, pasa el parámetro PROYECTO:

```bash
    # Inicializar un espacio de trabajo limpio con Foundry
    make foundry-init PROYECTO=MyDeFiAudit

    # Ejecutar el análisis estático de Slither
    make audit PROYECTO=MyDeFiAudit

    # Exportar las evidencias en un reporte JSON estructurado
    make audit-json PROYECTO=MyDeFiAudit
```
---

## 🛡️ Threat Model Mitigation Summary

| Attack Vector / Threat Model | Technical Mitigation in StealthOps | Status |
| :--- | :--- | :---: |
| Supply Chain Attack (Malicious npm/pip package) | Complete network isolation and non-root execution space (UID/GID mapping). | Protected |
| Session Hijacking (Web3 Cookie Theft) | Ephemeral browser profiling inside sandbox containers running on Incognito flags. | Mitigated |
| Repository Data Leakage (Key/Code Exposure) | Strict black-box target rules in .gitignore preserving structural .gitkeep targets. | Blocked |
| Local Privilege Escalation | Complete removal of standard runtime Linux Kernel capabilities (cap_drop). | Hardened |
| Localhost Port Scanning / DNS Rebinding | Explicit binding restrictions forcing internal services directly to loopback interface 127.0.0.1. | Blocked |
