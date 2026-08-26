#!/usr/bin/env bash
#
# Maquina-v7 :: install_steam.sh
# Solo se ejecuta si Colab nos otorga GPU. Instala Steam (Linux) y
# utilidades para cloud gaming dentro del escritorio Xfce + xrdp.
# Si no hay GPU, el escritorio RDP sigue funcionando en modo CPU.
#
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "==================================================="
echo "  Maquina-v7 :: Detectando GPU y preparando gaming"
echo "==================================================="

HAS_GPU=0
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
    HAS_GPU=1
    echo "[OK] GPU NVIDIA detectada:"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
else
    echo "[!] Sin GPU: se usa modo solo-escritorio (CPU)."
fi

echo "[*] Instalando Steam y utilidades..."
apt-get update -qq
apt-get install -y -qq steam latte-dock gamemode >/dev/null 2>&1 || \
    apt-get install -y steam >/dev/null 2>&1 || echo "[!] No se pudo instalar steam (revisa conexion)."

if [ "$HAS_GPU" = "1" ]; then
    # Asegurar que el driver de usuario este presente
    apt-get install -y -qq libnvidia-gl-* nvidia-utils-* >/dev/null 2>&1 || true
    echo "[OK] Listo para jugar. Abre Steam desde el menu de Xfce."
    echo "      Conectate por RDP y disfruta. Para mejor latencia,"
    echo "      usa 'Microsoft Remote Desktop' en Android."
else
    echo "[!] GPU no disponible: instalaste solo el entorno de escritorio."
    echo "      Para gaming necesitas una sesion de Colab con GPU (T4)."
fi
