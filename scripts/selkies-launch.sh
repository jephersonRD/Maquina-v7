#!/usr/bin/env bash
# selkies-launch.sh - Arranca Xvfb + PulseAudio + KDE Plasma + Selkies (WebRTC/HTTPS).
# Se llama desde setup_selkies.sh o desde selkies.service.
# Uso: bash selkies-launch.sh <USUARIO> <CONTRASEÑA> <RESOLUCION> [PUERTO]
set -uo pipefail

USERNAME="${1:-jeph}"
PASSWORD="${2:-medina}"
RESOLUTION="${3:-1920x1080}"
PORT="${4:-8080}"

SELKIES_DIR="/opt/selkies"
APP_DIR="$SELKIES_DIR/selkies-gstreamer"
WEB_ROOT="/opt/gst-web"
CERT="$SELKIES_DIR/selkies.crt"
KEY="$SELKIES_DIR/selkies.key"
LOGDIR="/tmp"
export DISPLAY=":0"

# Entorno del bundle portable (conda autocontenido)
export CONDA_PREFIX="$APP_DIR"
export PATH="$APP_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$APP_DIR/lib:$LD_LIBRARY_PATH"
export GST_PLUGIN_PATH="$APP_DIR/lib/gstreamer-1.0"
export GI_TYPELIB_PATH="$APP_DIR/lib/girepository-1.0"
export XDG_RUNTIME_DIR="/tmp/runtime-$USERNAME"
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"

echo "🖵 Iniciando Xvfb ($RESOLUTION)..."
if [ ! -S "/tmp/.X11-unix/X0" ]; then
  Xvfb :0 -screen 0 "${RESOLUTION}x24" \
    +extension COMPOSITE +extension DAMAGE +extension GLX +extension RANDR \
    +extension RENDER +extension MIT-SHM +extension XFIXES +extension XTEST \
    -nolisten tcp -ac -noreset -shmem >"$LOGDIR/Xvfb_selkies.log" 2>&1 &
fi
until [ -S "/tmp/.X11-unix/X0" ]; do sleep 0.5; done
echo "   ✅ X disponible en $DISPLAY"

echo "🔊 Iniciando PulseAudio..."
pulseaudio --start --exit-idle-time=-1 >"$LOGDIR/pulse_selkies.log" 2>&1 || true

echo "🖥️ Iniciando KDE Plasma..."
if ! pgrep -x startplasma-x11 >/dev/null 2>&1; then
  export XDG_SESSION_TYPE=x11
  export XDG_CURRENT_DESKTOP=KDE
  export DESKTOP_SESSION=plasma
  dbus-launch startplasma-x11 >"$LOGDIR/kde_selkies.log" 2>&1 &
  sleep 5
fi

echo "🎬 Detectando codificador de video..."
if [ -e /dev/nvidia0 ]; then
  ENC="nvh264enc"
  echo "   → GPU NVIDIA detectada: $ENC (NVENC por hardware)"
else
  ENC="x264enc"
  echo "   → Sin GPU: $ENC (CPU, fallback)"
fi

echo "🌐 Lanzando servidor Selkies en 0.0.0.0:$PORT (WebRTC + HTTPS)..."
exec "$APP_DIR/bin/python" -m selkies_gstreamer \
  --addr=0.0.0.0 \
  --port="$PORT" \
  --enable_https=true \
  --https_cert="$CERT" \
  --https_key="$KEY" \
  --enable_basic_auth=true \
  --basic_auth_user="$USERNAME" \
  --basic_auth_password="$PASSWORD" \
  --encoder="$ENC" \
  --enable_resize=true \
  --video_bitrate=20000 \
  --framerate=60 \
  --web_root="$WEB_ROOT"
