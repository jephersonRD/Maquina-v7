#!/usr/bin/env bash
# setup_selkies.sh - Instala Selkies GStreamer (escritorio remoto vía navegador)
# Uso: bash setup_selkies.sh
set -uo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🌐 Instalando Selkies GStreamer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Detectar GPU
echo "   ↳ Detectando GPU..."
HAS_NVIDIA=false
if command -v nvidia-smi >/dev/null 2>&1; then
  if nvidia-smi >/dev/null 2>&1; then
    HAS_NVIDIA=true
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | head -n1)
    echo "   ✅ NVIDIA GPU detectada: ${GPU_NAME}"
  fi
fi

if [ "$HAS_NVIDIA" = false ]; then
  echo "   ⚠️ No se detectó GPU NVIDIA, usando CPU"
fi

# Instalar dependencias del sistema
echo "   ↳ Instalando dependencias del sistema..."
apt-get install -y \
  python3 python3-pip python3-venv python3-setuptools python3-wheel \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
  gstreamer1.0-nice \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  gstreamer1.0-x gstreamer1.0-gl \
  libx11-dev libxtst-dev libxfixes-dev \
  libpipewire-0.3-dev \
  jq curl wget \
  || { echo "❌ fallo al instalar dependencias"; exit 1; }

# Obtener última versión de Selkies
echo "   ↳ Obteniendo última versión de Selkies..."
SELKIES_VERSION=$(curl -fsSL "https://api.github.com/repos/selkies-project/selkies/releases/latest" 2>/dev/null | jq -r '.tag_name' | sed 's/^v//' 2>/dev/null)

if [ -z "$SELKIES_VERSION" ] || [ "$SELKIES_VERSION" = "null" ]; then
  echo "   ❌ No se pudo obtener la versión de Selkies"
  exit 1
fi
echo "   📦 Versión: $SELKIES_VERSION"

# Intentar instalar via pip (Python wheel)
echo "   ↳ Instalando Selkies via pip..."
WHEEL_NAME="selkies_gstreamer-${SELKIES_VERSION}-py3-none-any.whl"
WHEEL_URL="https://github.com/selkies-project/selkies/releases/download/v${SELKIES_VERSION}/${WHEEL_NAME}"

echo "   📥 Descargando: $WHEEL_NAME"
if curl -O -fsSL "$WHEEL_URL" 2>/dev/null; then
  if pip3 install "./${WHEEL_NAME}" 2>/dev/null; then
    echo "   ✅ Selkies instalado via pip"
    rm -f "./${WHEEL_NAME}"
  else
    echo "   ⚠️ pip install falló, intentando con --break-system-packages..."
    if pip3 install --break-system-packages "./${WHEEL_NAME}" 2>/dev/null; then
      echo "   ✅ Selkies instalado via pip (--break-system-packages)"
      rm -f "./${WHEEL_NAME}"
    else
      echo "   ❌ No se pudo instalar Selkies via pip"
      rm -f "./${WHEEL_NAME}"
      exit 1
    fi
  fi
else
  echo "   ❌ No se pudo descargar Selkies wheel"
  echo "   Verifica: $WHEEL_URL"
  exit 1
fi

# Verificar instalación
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📊 Verificando instalación de Selkies:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v selkies-gstreamer >/dev/null 2>&1; then
  echo "   ✅ selkies-gstreamer: $(which selkies-gstreamer)"
else
  # Buscar en ubicaciones comunes
  SELKIES_BIN=$(find /usr -name "selkies*" -type f 2>/dev/null | head -n1)
  if [ -n "$SELKIES_BIN" ]; then
    echo "   ✅ selkies: $SELKIES_BIN"
  else
    echo "   ⚠️ selkies-gstreamer no encontrado en PATH"
    echo "   Verificando instalación de Python..."
    pip3 show selkies-gstreamer 2>/dev/null | head -5
  fi
fi

# Verificar GPU para Selkies
if [ "$HAS_NVIDIA" = true ]; then
  echo "   🎮 GPU: NVIDIA (${GPU_NAME})"
  echo "   ⚡ Encoder: NVENC H.264 (hardware)"
else
  echo "   🎮 GPU: CPU fallback"
  echo "   ⚡ Encoder: Software H.264 (x264)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Selkies instalado correctamente"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
