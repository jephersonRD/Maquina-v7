#!/usr/bin/env bash
# start_desktop.sh - Inicia Xvfb + Openbox + PulseAudio + Selkies
# Uso: bash start_desktop.sh <RESOLUCION> <USUARIO> <CONTRASEÑA>
set -uo pipefail

RESOLUTION="${1:-1920x1080}"
USERNAME="${2:-user}"
PASSWORD="${3:-password}"
PORT="${4:-8080}"

WIDTH="${RESOLUTION%x*}"
HEIGHT="${RESOLUTION#*x}"

export DISPLAY="${DISPLAY:-:10}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}"
export PULSE_RUNTIME_PATH="${XDG_RUNTIME_DIR}/pulse"
export PULSE_SERVER="unix:${PULSE_RUNTIME_PATH}/native"
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=Openbox
export DESKTOP_SESSION=openbox

# Crear directorios
mkdir -p "$XDG_RUNTIME_DIR" "$PULSE_RUNTIME_PATH"
chmod 700 "$XDG_RUNTIME_DIR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀 MAQUINA-V7 — Iniciando escritorio"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  🖥️  Desktop      : Openbox"
echo "  🌐 Remote       : Selkies"
echo "  📺 Resolución   : ${WIDTH}x${HEIGHT}"
echo ""

# Detectar GPU
echo "  🎮 Detectando GPU..."
HAS_NVIDIA=false
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  HAS_NVIDIA=true
  GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | head -n1)
  echo "  🎮 GPU          : NVIDIA ${GPU_NAME}"
  echo "  ⚡ Encoder      : NVENC H.264"
else
  echo "  🎮 GPU          : CPU fallback"
  echo "  ⚡ Encoder      : Software H.264"
fi
echo ""

# Matar procesos previos
echo "   ↳ Deteniendo procesos previos..."
pkill -x Xvfb 2>/dev/null || true
pkill -x pulseaudio 2>/dev/null || true
pkill -f "selkies" 2>/dev/null || true
pkill -x openbox 2>/dev/null || true
sleep 1

# 1. Iniciar Xvfb (servidor X virtual)
echo "   ↳ [1/4] Iniciando Xvfb (display ${DISPLAY})..."
Xvfb "${DISPLAY}" -screen 0 ${WIDTH}x${HEIGHT}x24 \
  -s 0 -dpms \
  +extension "COMPOSITE" +extension "DAMAGE" +extension "GLX" \
  +extension "RANDR" +extension "RENDER" +extension "MIT-SHM" \
  +extension "XFIXES" +extension "XTEST" +iglx +render \
  -nolisten "tcp" -ac -noreset -shmem \
  >/tmp/xvfb.log 2>&1 &

# Esperar a que Xvfb esté listo
echo "      Esperando Xvfb..."
for i in {1..15}; do
  if [ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; then
    echo "      ✅ Xvfb listo"
    break
  fi
  sleep 0.5
done

if [ ! -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; then
  echo "      ❌ Xvfb no pudo iniciar"
  cat /tmp/xvfb.log | tail -10
  exit 1
fi

# 2. Iniciar PulseAudio
echo "   ↳ [2/4] Iniciando PulseAudio..."
pulseaudio --kill 2>/dev/null || true
sleep 1

pulseaudio --daemonize=no \
  --log-target=file:/tmp/pulseaudio.log \
  --exit-idle-time=-1 \
  --disallow-exit \
  --disallow-module-loading=0 &

# Esperar a que PulseAudio esté listo
for i in {1..10}; do
  if pactl info >/dev/null 2>&1; then
    echo "      ✅ PulseAudio listo"
    break
  fi
  sleep 1
done

# Verificar monitor de PulseAudio para Selkies
AUDIO_MONITOR=""
if pactl info >/dev/null 2>&1; then
  # Buscar monitor del sink
  AUDIO_MONITOR=$(pactl list short sources 2>/dev/null | grep "monitor" | awk '{print $2}' | head -n1)
  if [ -n "$AUDIO_MONITOR" ]; then
    echo "      🔊 Audio Monitor: ${AUDIO_MONITOR}"
  else
    echo "      ⚠️ No se encontró monitor de audio"
  fi
fi

# 3. Iniciar Openbox
echo "   ↳ [3/4] Iniciando Openbox..."
openbox &
sleep 2
echo "      ✅ Openbox listo"

# 4. Iniciar Selkies
echo "   ↳ [4/4] Iniciando Selkies..."

# Configurar variables para Selkies
export DISPLAY="${DISPLAY}"
export PULSE_SERVER="${PULSE_SERVER}"

# Detectar comando de Selkies
SELKIES_CMD=""
if command -v selkies >/dev/null 2>&1; then
  SELKIES_CMD="selkies"
elif [ -f /usr/local/bin/selkies-appimage ]; then
  SELKIES_CMD="/usr/local/bin/selkies-appimage"
else
  echo "      ❌ Selkies no encontrado"
  exit 1
fi

# Construir comando de Selkies
SELKIES_ARGS="--addr=0.0.0.0 --port=${PORT}"
SELKIES_ARGS="${SELKIES_ARGS} --enable-https=false"
SELKIES_ARGS="${SELKIES_ARGS} --basic-auth-user=${USERNAME}"
SELKIES_ARGS="${SELKIES_ARGS} --basic-auth-password=${PASSWORD}"
SELKIES_ARGS="${SELKIES_ARGS} --encoder=h264enc"
SELKIES_ARGS="${SELKIES_ARGS} --enable-resize=true"

# Si hay monitor de audio, configurarlo
if [ -n "$AUDIO_MONITOR" ]; then
  export SELKIES_AUDIO_DEVICE="${AUDIO_MONITOR}"
fi

# Forzar CPU si no hay NVIDIA
if [ "$HAS_NVIDIA" = false ]; then
  SELKIES_ARGS="${SELKIES_ARGS} --use-cpu=true"
fi

# Iniciar Selkies
env -u LD_PRELOAD ${SELKIES_CMD} ${SELKIES_ARGS} > /tmp/selkies.log 2>&1 &
SELKIES_PID=$!

# Esperar a que Selkies esté listo
echo "      Esperando Selkies..."
for i in {1..15}; do
  if curl -s "http://localhost:${PORT}" >/dev/null 2>&1; then
    echo "      ✅ Selkies listo (PID: ${SELKIES_PID})"
    break
  fi
  sleep 1
done

# Verificar estado final
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Escritorio iniciado correctamente"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Mostrar URL de acceso
SELKIES_URL="http://localhost:${PORT}"
echo "  🌐 DESKTOP:"
echo "     ${SELKIES_URL}"
echo ""

# Verificar servicios
echo "  📊 Estado:"
if [ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; then
  echo "     ✅ Xvfb: ejecutándose"
else
  echo "     ❌ Xvfb: no responde"
fi

if pactl info >/dev/null 2>&1; then
  echo "     ✅ PulseAudio: ejecutándose"
  if [ -n "$AUDIO_MONITOR" ]; then
    echo "     ✅ Audio Monitor: ${AUDIO_MONITOR}"
  fi
else
  echo "     ⚠️ PulseAudio: no responde"
fi

if pgrep -x openbox >/dev/null 2>&1; then
  echo "     ✅ Openbox: ejecutándose"
else
  echo "     ❌ Openbox: no responde"
fi

if pgrep -f "selkies" >/dev/null 2>&1; then
  echo "     ✅ Selkies: ejecutándose"
else
  echo "     ❌ Selkies: no responde"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
