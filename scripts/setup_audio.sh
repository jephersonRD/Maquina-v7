#!/usr/bin/env bash
# setup_audio.sh - Configura PulseAudio para Selkies en Google Colab
# Uso: bash setup_audio.sh
set -uo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔊 Configurando audio (PulseAudio)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Instalar PulseAudio
echo "   ↳ Instalando PulseAudio..."
apt-get install -y pulseaudio pulseaudio-utils \
  || { echo "❌ fallo al instalar PulseAudio"; exit 1; }

# Configurar directorio de runtime
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

export PULSE_RUNTIME_PATH="${XDG_RUNTIME_DIR}/pulse"
mkdir -p "$PULSE_RUNTIME_PATH"

# Matar instancias previas
echo "   ↳ Deteniendo instancias previas de PulseAudio..."
pulseaudio --kill 2>/dev/null || true
sleep 1

# Configurar PulseAudio para Colab
mkdir -p ~/.config/pulse

# Crear configuración mínima
cat > ~/.config/pulse/daemon.conf << 'PAEOF'
daemonize = no
exit-idle-time = -1
flat-volumes = no
resample-method = speex-float-3
default-sample-format = s16le
default-sample-rate = 48000
default-sample-channels = 2
PAEOF

# Crear script de inicio de PulseAudio
cat > /tmp/start-pulse.sh << 'PAEOF'
#!/bin/bash
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}"
export PULSE_RUNTIME_PATH="${XDG_RUNTIME_DIR}/pulse"
export PULSE_SERVER="unix:${PULSE_RUNTIME_PATH}/native"

# Matar instancias previas
pulseaudio --kill 2>/dev/null || true
sleep 1

# Iniciar PulseAudio
pulseaudio --daemonize=no \
  --log-target=file:/tmp/pulseaudio.log \
  --exit-idle-time=-1 \
  --disallow-exit \
  --disallow-module-loading=0 &
PA_PID=$!

# Esperar a que PulseAudio esté listo
for i in {1..10}; do
  if pactl info >/dev/null 2>&1; then
    echo "PulseAudio iniciado (PID: $PA_PID)"
    break
  fi
  sleep 1
done

# Verificar que PulseAudio esté funcionando
if pactl info >/dev/null 2>&1; then
  echo "PulseAudio OK"
  pactl info | head -10
else
  echo "ERROR: PulseAudio no pudo iniciar"
  cat /tmp/pulseaudio.log 2>/dev/null | tail -20
  exit 1
fi
PAEOF
chmod +x /tmp/start-pulse.sh

# Iniciar PulseAudio
echo "   ↳ Iniciando PulseAudio..."
bash /tmp/start-pulse.sh

sleep 2

# Verificar estado
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📊 Estado de PulseAudio:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if pactl info >/dev/null 2>&1; then
  echo "   ✅ PulseAudio: ejecutándose"
  echo "   📌 Server: $(pactl info 2>/dev/null | grep 'Server Name' | cut -d: -f2)"
  echo ""
  echo "   Sinks (salidas):"
  pactl list short sinks 2>/dev/null | while read line; do
    echo "      $line"
  done
  echo ""
  echo "   Sources (fuentes):"
  pactl list short sources 2>/dev/null | while read line; do
    echo "      $line"
  done
else
  echo "   ❌ PulseAudio no está ejecutándose"
  echo "   Revisa el log: cat /tmp/pulseaudio.log"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Audio configurado"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
