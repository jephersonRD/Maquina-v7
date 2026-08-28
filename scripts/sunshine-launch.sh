#!/usr/bin/env bash
# sunshine-launch.sh - Arranca Xvfb + PulseAudio + KDE Plasma + Sunshine.
# Captura X11 (x11) desde el Xvfb y codifica con NVENC en la T4.
# Se llama desde setup_sunshine.sh o desde sunshine.service, como el usuario creado.
# Uso: bash sunshine-launch.sh <USUARIO> <CONTRASEÑA> <RESOLUCION> [PUERTO_WEB]
set -uo pipefail

USERNAME="${1:-jeph}"
PASSWORD="${2:-medina}"
RESOLUTION="${3:-1920x1080}"
WEB_PORT="${4:-47989}"

export DISPLAY=":0"
export XDG_RUNTIME_DIR="/tmp/runtime-$USERNAME"
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"
export HOME="/home/$USERNAME"
# Hacer visibles las libs de encoding NVIDIA para el ffmpeg embebido de Sunshine
export LD_LIBRARY_PATH="/usr/lib/nvidia:/usr/lib/nvidia-*:${LD_LIBRARY_PATH:-}"

echo "🖵 Iniciando Xvfb ($RESOLUTION)..."
if [ ! -S "/tmp/.X11-unix/X0" ]; then
  Xvfb :0 -screen 0 "${RESOLUTION}x24" \
    +extension COMPOSITE +extension DAMAGE +extension GLX +extension RANDR \
    +extension RENDER +extension MIT-SHM +extension XFIXES +extension XTEST \
    -nolisten tcp -ac -noreset -shmem >"$HOME/Xvfb.log" 2>&1 &
fi
until [ -S "/tmp/.X11-unix/X0" ]; do sleep 0.5; done
xhost + >/dev/null 2>&1 || true
echo "   ✅ X disponible en $DISPLAY"

echo "🔊 Iniciando PulseAudio..."
pulseaudio --start --exit-idle-time=-1 >"$HOME/pulse.log" 2>&1 || pulseaudio -k >/dev/null 2>&1 || true

echo "🖥️ Iniciando KDE Plasma..."
if ! pgrep -x startplasma-x11 >/dev/null 2>&1; then
  export XDG_SESSION_TYPE=x11
  export XDG_CURRENT_DESKTOP=KDE
  export DESKTOP_SESSION=plasma
  dbus-launch startplasma-x11 >"$HOME/kde.log" 2>&1 &
  sleep 6
fi

echo "🌐 Lanzando Sunshine (Web UI en 0.0.0.0:$WEB_PORT, stream NVENC)..."
cd "$HOME"
exec sunshine
