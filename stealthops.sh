#!/bin/bash

# =====================================================================
# STEALTHOPS CORE ORCHESTRATOR Script - VERSIÓN FINAL
# HARDENED OPSEC ENVIRONMENT RUNTIME (PRODUCTION READY & FAIL-CLOSED)
# =====================================================================
# DIRECTRIZ OPSEC 1: SANEAMIENTO ASCII Y PORTABILIDAD
# Todo el código utiliza espacios estándar ASCII (0x20). Se eliminaron
# caracteres Unicode no imprimibles (0x00A0) para evitar fallos de
# sintaxis en entornos CI/CD, subshells o sistemas embebidos.
# =====================================================================

set -eo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------
# DIRECTRIZ OPSEC 2: ARQUITECTURA FAIL-CLOSED Y MANEJO DE SEÑALES
# Si ocurre un error no controlado o una interrupción manual (SIGINT/SIGTERM),
# el script invalida la ejecución y fuerza la destrucción inmediata de la RAM.
# ---------------------------------------------------------------------
cleanup_on_error() {
    local exit_code=$?
    trap - ERR INT TERM # Desarmar trampas para prevenir recursión infinita
    set +e
    if [ "$exit_code" -ne 0 ]; then
        echo -e "\n[!] ERROR CRÍTICO DETECTADO (Código de salida: $exit_code)."
        echo "[!] Ejecutando salvaguarda OPSEC y purga de emergencia..."
        turnoff_all
        exit "$exit_code"
    fi
}
trap cleanup_on_error ERR
trap 'trap - ERR INT TERM; set +e; echo -e "\n[!] Interrupción detectada. Apagando..."; turnoff_all; exit 130' INT TERM

# ---------------------------------------------------------------------
# DIRECTRIZ OPSEC 3: AISLAMIENTO DE ARCHIVOS Y PRIVILEGIOS
# Se impone una máscara de permisos estricta (umask 0077: lectura/escritura
# exclusiva para el usuario creador) y validación temprana de sudo.
# ---------------------------------------------------------------------

export USER_UID="${USER_UID:-$(id -u)}"
export USER_GID="${USER_GID:-$(id -g)}"

# Archivo .env para Docker estructurado como Array Seguro
DOCKER_ARGS=()
if [ -f "$BASE_DIR/.env" ]; then
    DOCKER_ARGS=(--env-file "$BASE_DIR/.env")
fi

# Rutas alineadas con docker-compose.yml
DIR_FINANCE="$BASE_DIR/infrastructure/brave_data"
DIR_PRODUCTION="$BASE_DIR/infrastructure/work_data/webconfig"
DIR_WORK="$BASE_DIR/infrastructure/work_data/work"
DIR_VSCODE="$BASE_DIR/infrastructure/work_data/vscode_config"

# Aplicar umask restrictiva (sólo propietario) y crear estructura
umask 0077
mkdir -p "$DIR_FINANCE" "$DIR_PRODUCTION" "$DIR_WORK" "$DIR_VSCODE"

# Validar credenciales sudo al inicio para evitar bloqueos mid-run
if ! sudo -n true 2>/dev/null; then
    echo "[*] Solicitando elevación de privilegios para operaciones tmpfs/SWAP..."
    sudo -v
fi

# ---------------------------------------------------------------------
# DIRECTRIZ OPSEC 4: PREVENCIÓN DE FUGA A DISCO SECUNDARIO (DESACTIVACIÓN SWAP)
# Si la memoria RAM se transfiere al espacio SWAP en el disco duro/SSD, los datos
# volátiles persisten tras el apagado. Se exige la desactivación de SWAP.
# ---------------------------------------------------------------------
check_and_disable_swap() {
    if [ -f /proc/swaps ] && [ "$(wc -l < /proc/swaps)" -gt 1 ]; then
        echo "[!] ADVERTENCIA OPSEC: La memoria SWAP está activa en el host."
        echo "[*] Intentando desactivar SWAP automáticamente por seguridad de tmpfs..."
        if sudo swapoff -a; then
            echo "[+] ÉXITO: Memoria SWAP desactivada correctamente."
        else
            echo "[!] ERROR CRÍTICO: No se pudo desactivar la SWAP (se requieren privilegios elevados)."
            echo "[!] Abortando ejecución por alto riesgo de filtración forense en disco."
            exit 1
        fi
    else
        echo "[+] Verificación OPSEC superada: No hay particiones/archivos SWAP activos."
    fi
}
check_and_disable_swap

# ---------------------------------------------------------------------
# DIRECTRIZ OPSEC 5: MONTAJE EN MEMORIA VOLÁTIL RAM (TMPFS HARDENED)
# Se aplican las banderas 'nosuid', 'nodev' y 'noexec' al RAMDisk para evitar
# escalada de privilegios y ejecución de binarios sospechosos dentro de los datos.
# ---------------------------------------------------------------------
setup_tmpfs() {
    local target_dir="$1"
    if ! mountpoint -q "$target_dir"; then
        echo "[*] Montando volumen volátil tmpfs en $target_dir..."
        if sudo mount -t tmpfs -o "size=512M,mode=0700,uid=$USER_UID,gid=$USER_GID,nosuid,nodev,noexec" tmpfs "$target_dir"; then
            echo "[+] RAMDisk montado exitosamente en $target_dir."
        else
            echo "[!] ERROR CRÍTICO OPSEC: No se logró montar tmpfs en $target_dir."
            echo "[!] Abortando ejecución para prevenir escrituras en disco duro."
            exit 1
        fi
    fi
}

# Grupos de servicios definidos como Arrays Seguros
CORE_SERVICES=(development-ide stealth-anvil foundry-toolkit)
DEV_SERVICES=(development-ide stealth-anvil foundry-toolkit rust-suite typescript-suite)
FUZZ_SERVICES=(echidna-fuzzer medusa-fuzzer)

# ---------------------------------------------------------------------
# DIRECTRIZ OPSEC 6: BANDERAS HARDENED DE NAVEGACIÓN PRIVADA Y ANTI-TELEMETRÍA
# Desactivan WebRTC (fuga de IP real), actualización de componentes, telemetría
# de errores (Breakpad) y almacenamiento de contraseñas.
# ---------------------------------------------------------------------
BRAVE_HARDENED_FLAGS=(
    "--new-window"
    "--incognito"
    "--no-first-run"
    "--password-store=basic"
    "--disabled-sharing-features"
    "--disabled-save-password-bubble"
    "--disabled-ntp-most-liked"
    "--disabled-sync"
    "--force-webrtc-ip-handling-policy=disable_non_proxied_udp"
    "--no-pings"
    "--disable-breakpad"
    "--disable-component-update"
    "--disable-domain-reliability"
)

# ---------------------------------------------------------------------
# FUNCIONES OPERATIVAS
# ---------------------------------------------------------------------

verify_anvil() {
    echo "[*] Verificando consenso del nodo Anvil (RPC http://127.0.0.1:8545)..."
    local retries=5
    local wait_sec=2
    while [ $retries -gt 0 ]; do
        if curl -s -X POST -H "Content-Type: application/json" \
            --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
            http://127.0.0.1:8545 > /dev/null; then
            echo "[+] Nodo Anvil respondiendo correctamente en http://127.0.0.1:8545"
            return 0
        fi
        ((retries--))
        [ $retries -gt 0 ] && sleep $wait_sec
    done
    echo "[!] Advertencia: El nodo Anvil no respondió en el puerto 8545 tras varios intentos."
}

up_core() {
    echo "[*] Desplegando Backend CORE (VSCodium, Anvil Node, Foundry CLI)..."
    (cd "$BASE_DIR" && docker compose "${DOCKER_ARGS[@]}" up -d "${CORE_SERVICES[@]}")
    verify_anvil
}

up_dev() {
    echo "[*] Desplegando Backend DEV (CORE + Suites Rust & TypeScript)..."
    (cd "$BASE_DIR" && docker compose "${DOCKER_ARGS[@]}" up -d "${DEV_SERVICES[@]}")
    verify_anvil
}

up_fuzzing() {
    echo "[*] Desplegando Fuzzers de Seguridad (Echidna + Medusa)..."
    (cd "$BASE_DIR" && docker compose "${DOCKER_ARGS[@]}" up -d "${FUZZ_SERVICES[@]}")
    verify_anvil
}

up_full_docker() {
    echo "[*] Desplegando Infraestructura Docker Completa..."
    (cd "$BASE_DIR" && docker compose "${DOCKER_ARGS[@]}" up -d)
    verify_anvil
}

up_finances() {
    echo "[*] Generando Bóveda Financiera Aislada en RAM [ZONA VERDE]..."
    setup_tmpfs "$DIR_FINANCE"
    flatpak run --filesystem="$DIR_FINANCE" com.brave.Browser \
        --user-data-dir="$DIR_FINANCE" \
        --name="Finance-Vault" \
        --class="Finance-Vault" \
        "${BRAVE_HARDENED_FLAGS[@]}" > /dev/null 2>&1 &
}

up_production() {
    echo "[*] Generando Nodo de Producción Aislado en RAM [ZONA AZUL OSCURO]..."
    setup_tmpfs "$DIR_PRODUCTION"
    flatpak run --filesystem="$DIR_PRODUCTION" com.brave.Browser \
        --user-data-dir="$DIR_PRODUCTION" \
        --name="Production-Node" \
        --class="Production-Node" \
        "${BRAVE_HARDENED_FLAGS[@]}" > /dev/null 2>&1 &
}

show_status() {
    echo "===================================================="
    echo "          ESTADO DE SERVICIOS STEALTHOPS            "
    echo "===================================================="
    (cd "$BASE_DIR" && docker compose ps)
}

# ---------------------------------------------------------------------
# DIRECTRIZ OPSEC 7: SOBREESCRITURA CRIPTOGRÁFICA DE RAM (ANTI-FORENSICS)
# 'rm' borra los punteros de los archivos pero deja los bytes intactos en la RAM.
# Esta función utiliza 'shred' (o truncamiento en cascada) para llenar los datos
# con bytes aleatorios y ceros antes de eliminar las entradas del sistema de archivos.
# ---------------------------------------------------------------------
purge_directory() {
    local dir="$1"
    if [ -n "$dir" ] && [ "$dir" != "/" ] && [ -d "$dir" ]; then
        echo "[*] Destruyendo datos con sobreescritura aleatoria en $dir..."
        if command -v shred >/dev/null 2>&1; then
            # Sobreescritura aleatoria + paso final con ceros + eliminación
            sudo find "$dir" -type f -exec shred -u -n 1 -z {} + 2>/dev/null || true
        else
            # Método alternativo: truncado a cero bytes en caso de ausencia de shred
            sudo find "$dir" -type f -exec truncate -s 0 {} + 2>/dev/null || true
        fi
        # Limpieza residual de directorios vacíos
        sudo find "$dir" -mindepth 1 -delete 2>/dev/null || sudo find "$dir" -mindepth 1 -exec rm -rf {} + 2>/dev/null || true
    fi
}

# ---------------------------------------------------------------------
# DIRECTRIZ OPSEC 8: ORDEN DE DESMANTELAMIENTO Y PURGA DEL KERNEL
# 1. Neutralización de procesos activos (SIGTERM -> SIGKILL -> fuser).
# 2. Destrucción del contenido en RAM (shred).
# 3. Desmontaje de volúmenes volátiles (umount).
# 4. Limpieza de PageCache y dentries en la memoria caché del Kernel (drop_caches).
# ---------------------------------------------------------------------
turnoff_all() {
    set +e
    echo "[*] Auditando y neutralizando procesos activos de StealthOps..."
    
    pkill -15 -u "$USER_UID" -f "$DIR_FINANCE" > /dev/null 2>&1 || true
    pkill -15 -u "$USER_UID" -f "$DIR_PRODUCTION" > /dev/null 2>&1 || true

    sleep 2
    
    pkill -9 -u "$USER_UID" -f "$DIR_FINANCE" > /dev/null 2>&1 || true
    pkill -9 -u "$USER_UID" -f "$DIR_PRODUCTION" > /dev/null 2>&1 || true

    # Liberar descriptores de archivos de forma segura antes de la purga/desmontaje
    if command -v fuser >/dev/null 2>&1; then
        sudo fuser -k -9 "$DIR_FINANCE" > /dev/null 2>&1 || true
        sudo fuser -k -9 "$DIR_PRODUCTION" > /dev/null 2>&1 || true
    fi

    echo "[*] Ejecutando sobreescritura forense previa al desmontaje..."
    purge_directory "$DIR_FINANCE"
    purge_directory "$DIR_PRODUCTION"

    echo "[*] Desmantelando infraestructura Docker y red de contenedores..."
    (cd "$BASE_DIR" && docker compose down --volumes --remove-orphans)

    echo "[*] Desmontando volúmenes RAMDisk (tmpfs)..."
    if mountpoint -q "$DIR_FINANCE"; then
        sudo umount -f "$DIR_FINANCE" 2>/dev/null || sudo umount -l "$DIR_FINANCE" 2>/dev/null
    fi
    if mountpoint -q "$DIR_PRODUCTION"; then
        sudo umount -f "$DIR_PRODUCTION" 2>/dev/null || sudo umount -l "$DIR_PRODUCTION" 2>/dev/null
    fi

    echo "[*] Purga secundaria tras desmontaje..."
    purge_directory "$DIR_FINANCE"
    purge_directory "$DIR_PRODUCTION"

    # Forzar sincronización de discos y vaciado de caché de memoria en Kernel
    echo "[*] Purgando cachés de memoria RAM (PageCache/Dentries) en el Host..."
    sync && echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 || true

    echo "[+] Entorno StealthOps completamente neutralizado, desmontado y purgado."
    set -e
}

# ---------------------------------------------------------------------
# SELECTOR DE CLI Y MENÚ INTERACTIVO
# ---------------------------------------------------------------------

case "$1" in
    --start-all)
        up_full_docker; up_finances; up_production ;;
    --core)
        up_core ;;
    --dev)
        up_dev ;;
    --fuzz)
        up_fuzzing ;;
    --finances)
        up_finances ;;
    --prod)
        up_dev; up_production ;;
    --docker)
        up_full_docker ;;
    --status)
        show_status ;;
    --stop)
        turnoff_all ;;
    *)
        if [ ! -t 0 ]; then
            echo "[!] Error: Entrada no interactiva detectada sin argumentos explícitos."
            exit 1
        fi
        clear
        echo "===================================================="
        echo "          CENTRO OPERATIVO STEALTHOPS               "
        echo "===================================================="
        echo "1) Modulo CORE (VSCodium + Anvil + Foundry CLI)"
        echo "2) Modulo DEV  (CORE + Rust + TypeScript Suites)"
        echo "3) Modulo FUZZ (Echidna + Medusa Fuzzers)"
        echo "4) Modo PRODUCCIÓN (Navegador Prod + Backend DEV)"
        echo "5) Bóveda Financiera Únicamente (Finance-Vault)"
        echo "6) Lanzar TODO (Docker Full + Ambos Navegadores)"
        echo "----------------------------------------------------"
        echo "7) Auditar Estado de Contenedores (--status)"
        echo "8) CIERRE SEGURO Y PURGA TOTAL DE RUNTIMES"
        echo "===================================================="
        read -r -p "Seleccione objetivo operativo: " opcion
        
        case $opcion in
            1) up_core ;;
            2) up_dev ;;
            3) up_fuzzing ;;
            4) up_fuzzing; up_dev ;;
            5) up_finances ;;
            6) up_full_docker; up_finances; up_production ;;
            7) show_status ;;
            8) turnoff_all ;;
            *) echo "[!] Selección inválida." ;;
        esac
        ;;
esac
