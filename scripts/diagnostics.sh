#!/usr/bin/env bash
# diagnostics.sh - Diagnostico completo del sistema Maquina-v7
# Uso: bash diagnostics.sh
set -uo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔍 MAQUINA-V7 — Diagnostico del sistema"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Sistema
echo "【1. Sistema】"
echo "   OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
echo "   Kernel: $(uname -r)"
echo "   Arquitectura: $(uname -m)"
echo ""

# 2. GPU
echo "【2. GPU】"
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  echo "   ✅ NVIDIA GPU detectada"
  nvidia-smi --query-gpu=name,driver_version,memory.total,memory.free --format=csv,noheader 2>/dev/null | while read line; do
    echo "      $line"
  done
else
  echo "   ⚠️  No se detecto GPU NVIDIA"
fi
echo ""

# 3. Display (X11)
echo "【3. Display (X11)】"
if [ -S "/tmp/.X11-unix/X${DISPLAY#:}" ] || [ -S "/tmp/.X11-unix/X10" ]; then
  echo "   ✅ X11 display disponible: ${DISPLAY}"
  if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
    RES=$(xdpyinfo -display "${DISPLAY}" 2>/dev/null | grep 'dimensions' | awk '{print $2}')
    echo "      Resolucion: ${RES:-desconocida}"
  fi
else
  echo "   ❌ No hay X11 display activo"
fi
echo ""

# 4. Audio (PulseAudio)
echo "【4. Audio (PulseAudio)】"
if command -v pactl >/dev/null 2>&1; then
  if pactl info >/dev/null 2>&1; then
    echo "   ✅ PulseAudio ejecutandose"
    SINK_COUNT=$(pactl list short sinks 2>/dev/null | wc -l)
    echo "   📌 Sinks: ${SINK_COUNT}"
    AUDIO_MONITOR=$(pactl list short sources 2>/dev/null | grep "monitor" | awk '{print $2}' | head -n1)
    if [ -n "$AUDIO_MONITOR" ]; then
      echo "   ✅ Monitor de audio: ${AUDIO_MONITOR}"
    else
      echo "   ⚠️  No se encontro monitor de audio"
    fi
  else
    echo "   ❌ PulseAudio no esta ejecutandose"
  fi
else
  echo "   ❌ PulseAudio no esta instalado"
fi
echo ""

# 5. LXQt
echo "【5. LXQt Desktop】"
if pgrep -f "lxqt-session" >/dev/null 2>&1; then
  echo "   ✅ LXQt ejecutandose"
else
  echo "   ⚠️  LXQt no esta ejecutandose"
fi
echo ""

# 6. VNC (x11vnc)
echo "【6. VNC (x11vnc)】"
if command -v x11vnc >/dev/null 2>&1; then
  echo "   ✅ x11vnc instalado"
  if pgrep -x x11vnc >/dev/null 2>&1; then
    echo "   ✅ x11vnc ejecutandose"
    if ss -ltn 2>/dev/null | grep -q ":5900"; then
      echo "   ✅ Puerto 5900 escuchando"
    fi
  else
    echo "   ⚠️  x11vnc no esta ejecutandose"
  fi
else
  echo "   ❌ x11vnc no esta instalado"
fi
echo ""

# 7. Guacamole
echo "【7. Apache Guacamole】"
if pgrep -x guacd >/dev/null 2>&1; then
  echo "   ✅ guacd ejecutandose"
  if ss -ltn 2>/dev/null | grep -q ":4822"; then
    echo "   ✅ Puerto 4822 escuchando"
  fi
else
  echo "   ⚠️  guacd no esta ejecutandose"
fi

if curl -s "http://localhost:8080" >/dev/null 2>&1; then
  echo "   ✅ Guacamole web app respondiendo"
else
  echo "   ⚠️  Guacamole web app no responde"
fi
echo ""

# 8. Variables de entorno
echo "【8. Variables de entorno】"
echo "   DISPLAY=${DISPLAY:-no definido}"
echo "   XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-no definido}"
echo "   XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-no definido}"
echo "   XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-no definido}"
echo "   PULSE_SERVER=${PULSE_SERVER:-no definido}"
echo "   DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-no definido}"
echo ""

# 9. Resumen
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📊 Resumen"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ERRORS=0

if [ -S "/tmp/.X11-unix/X${DISPLAY#:}" ] || [ -S "/tmp/.X11-unix/X10" ]; then
  echo "  ✅ X11 OK"
else
  echo "  ❌ X11 no disponible"
  ((ERRORS++))
fi

if pactl info >/dev/null 2>&1; then
  echo "  ✅ PulseAudio OK"
else
  echo "  ❌ PulseAudio no funciona"
  ((ERRORS++))
fi

if pgrep -f "lxqt-session" >/dev/null 2>&1; then
  echo "  ✅ LXQt OK"
else
  echo "  ⚠️  LXQt no esta ejecutandose"
fi

if pgrep -x x11vnc >/dev/null 2>&1; then
  echo "  ✅ VNC OK"
else
  echo "  ❌ VNC no funciona"
  ((ERRORS++))
fi

if pgrep -x guacd >/dev/null 2>&1; then
  echo "  ✅ guacd OK"
else
  echo "  ❌ guacd no funciona"
  ((ERRORS++))
fi

if curl -s "http://localhost:8080" >/dev/null 2>&1; then
  echo "  ✅ Guacamole OK"
else
  echo "  ❌ Guacamole no responde"
  ((ERRORS++))
fi

echo ""
if [ $ERRORS -eq 0 ]; then
  echo "  ✅ Todos los servicios funcionan correctamente"
else
  echo "  ⚠️  ${ERRORS} problema(s) detectado(s)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
