#!/usr/bin/env bash
# diagnostics.sh - Diagnóstico completo del sistema Maquina-v7
# Uso: bash diagnostics.sh
set -uo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔍 MAQUINA-V7 — Diagnóstico del sistema"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 1. Sistema
echo "【1. Sistema】"
echo "   OS: $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
echo "   Kernel: $(uname -r)"
echo "   Arquitectura: $(uname -m)"
echo "   Hostname: $(hostname)"
echo ""

# 2. GPU
echo "【2. GPU】"
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  echo "   ✅ NVIDIA GPU detectada"
  nvidia-smi --query-gpu=name,driver_version,memory.total,memory.free --format=csv,noheader 2>/dev/null | while read line; do
    echo "      $line"
  done
  
  # Verificar NVENC
  if nvidia-smi --query-gpu=encoder.stats.sessionCount --format=csv,noheader 2>/dev/null >/dev/null; then
    echo "   ✅ NVENC disponible"
  else
    echo "   ⚠️ NVENC no verificado"
  fi
else
  echo "   ⚠️ No se detectó GPU NVIDIA"
  echo "   Usando CPU para encoding"
fi
echo ""

# 3. Display (X11)
echo "【3. Display (X11)】"
if [ -S "/tmp/.X11-unix/X${DISPLAY#:}" ] || [ -S "/tmp/.X11-unix/X10" ]; then
  echo "   ✅ X11 display disponible: ${DISPLAY}"
  if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
    RES=$(xdpyinfo -display "${DISPLAY}" 2>/dev/null | grep 'dimensions' | awk '{print $2}')
    echo "      Resolución: ${RES:-desconocida}"
  fi
else
  echo "   ❌ No hay X11 display activo"
  echo "      DISPLAY=${DISPLAY:-no definido}"
fi
echo ""

# 4. Audio (PulseAudio)
echo "【4. Audio (PulseAudio)】"
if command -v pactl >/dev/null 2>&1; then
  if pactl info >/dev/null 2>&1; then
    echo "   ✅ PulseAudio ejecutándose"
    
    # Verificar sinks
    SINK_COUNT=$(pactl list short sinks 2>/dev/null | wc -l)
    echo "   📌 Sinks: ${SINK_COUNT}"
    pactl list short sinks 2>/dev/null | while read line; do
      echo "      $line"
    done
    
    # Verificar sources (monitores)
    echo ""
    echo "   📌 Sources (monitores de audio):"
    pactl list short sources 2>/dev/null | while read line; do
      echo "      $line"
    done
    
    # Verificar monitor específico
    AUDIO_MONITOR=$(pactl list short sources 2>/dev/null | grep "monitor" | awk '{print $2}' | head -n1)
    if [ -n "$AUDIO_MONITOR" ]; then
      echo ""
      echo "   ✅ Monitor de audio disponible: ${AUDIO_MONITOR}"
    else
      echo ""
      echo "   ❌ No se encontró monitor de audio"
    fi
  else
    echo "   ❌ PulseAudio no está ejecutándose"
  fi
else
  echo "   ❌ PulseAudio no está instalado"
fi
echo ""

# 5. Openbox
echo "【5. Openbox】"
if command -v openbox >/dev/null 2>&1; then
  echo "   ✅ Openbox instalado: $(which openbox)"
  if pgrep -x openbox >/dev/null 2>&1; then
    echo "   ✅ Openbox ejecutándose"
  else
    echo "   ⚠️ Openbox no está ejecutándose"
  fi
else
  echo "   ❌ Openbox no está instalado"
fi
echo ""

# 6. Selkies
echo "【6. Selkies】"
SELKIES_FOUND=false
if command -v selkies-gstreamer >/dev/null 2>&1; then
  echo "   ✅ Selkies instalado: $(which selkies-gstreamer)"
  SELKIES_FOUND=true
elif command -v selkies >/dev/null 2>&1; then
  echo "   ✅ Selkies instalado: $(which selkies)"
  SELKIES_FOUND=true
fi

if [ "$SELKIES_FOUND" = true ]; then
  if pgrep -f "selkies" >/dev/null 2>&1; then
    echo "   ✅ Selkies ejecutándose"
    
    # Verificar puerto
    if ss -ltn 2>/dev/null | grep -q ':8080'; then
      echo "   ✅ Puerto 8080 escuchando"
    else
      echo "   ⚠️ Puerto 8080 no escucha"
    fi
  else
    echo "   ⚠️ Selkies no está ejecutándose"
  fi
else
  echo "   ❌ Selkies no está instalado"
fi
echo ""

# 7. Variables de entorno
echo "【7. Variables de entorno】"
echo "   DISPLAY=${DISPLAY:-no definido}"
echo "   XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-no definido}"
echo "   XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-no definido}"
echo "   XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-no definido}"
echo "   PULSE_SERVER=${PULSE_SERVER:-no definido}"
echo "   PULSE_RUNTIME_PATH=${PULSE_RUNTIME_PATH:-no definido}"
echo ""

# 8. Procesos activos
echo "【8. Procesos activos】"
echo "   Xvfb: $(pgrep -x Xvfb >/dev/null 2>&1 && echo 'ejecutándose' || echo 'no activo')"
echo "   PulseAudio: $(pgrep -x pulseaudio >/dev/null 2>&1 && echo 'ejecutándose' || echo 'no activo')"
echo "   Openbox: $(pgrep -x openbox >/dev/null 2>&1 && echo 'ejecutándose' || echo 'no activo')"
echo "   Selkies: $(pgrep -f selkies >/dev/null 2>&1 && echo 'ejecutándose' || echo 'no activo')"
echo ""

# 9. Resumen
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📊 Resumen"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ERRORS=0

if [ ! -S "/tmp/.X11-unix/X${DISPLAY#:}" ] && [ ! -S "/tmp/.X11-unix/X10" ]; then
  echo "  ❌ X11 no disponible"
  ((ERRORS++))
else
  echo "  ✅ X11 OK"
fi

if ! pactl info >/dev/null 2>&1; then
  echo "  ❌ PulseAudio no funciona"
  ((ERRORS++))
else
  echo "  ✅ PulseAudio OK"
fi

if ! pgrep -x openbox >/dev/null 2>&1; then
  echo "  ⚠️ Openbox no está ejecutándose"
else
  echo "  ✅ Openbox OK"
fi

if ! pgrep -f selkies >/dev/null 2>&1; then
  echo "  ❌ Selkies no está ejecutándose"
  ((ERRORS++))
else
  echo "  ✅ Selkies OK"
fi

echo ""
if [ $ERRORS -eq 0 ]; then
  echo "  ✅ Todos los servicios funcionan correctamente"
else
  echo "  ⚠️ ${ERRORS} problema(s) detectado(s)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
