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

# Instalar dependencias del sistema (mínimas)
echo "   ↳ Instalando dependencias del sistema..."
apt-get install -y --no-install-recommends \
  python3 python3-pip python3-venv \
  gstreamer1.0-plugins-base gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad gstreamer1.0-nice \
  libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  libx11-dev libxtst-dev libxfixes-dev \
  jq curl wget \
  || { echo "❌ fallo al instalar dependencias"; exit 1; }

# Obtener última versión de Selkies
echo "   ↳ Obteniendo última versión de Selkies..."
SELKIES_VERSION=$(curl -fsSL --connect-timeout 10 --max-time 30 \
  "https://api.github.com/repos/selkies-project/selkies/releases/latest" 2>/dev/null | \
  jq -r '.tag_name' | sed 's/^v//' 2>/dev/null)

if [ -z "$SELKIES_VERSION" ] || [ "$SELKIES_VERSION" = "null" ]; then
  echo "   ❌ No se pudo obtener la versión de Selkies"
  echo "   Intentando versión conocida..."
  SELKIES_VERSION="1.6.2"
fi
echo "   📦 Versión: $SELKIES_VERSION"

# Instalar via pip con timeout
echo "   ↳ Instalando Selkies via pip..."
WHEEL_NAME="selkies_gstreamer-${SELKIES_VERSION}-py3-none-any.whl"
WHEEL_URL="https://github.com/selkies-project/selkies/releases/download/v${SELKIES_VERSION}/${WHEEL_NAME}"

echo "   📥 Descargando: $WHEEL_NAME"
curl -fsSL --connect-timeout 10 --max-time 120 -o "/tmp/${WHEEL_NAME}" "$WHEEL_URL" 2>/dev/null

if [ ! -f "/tmp/${WHEEL_NAME}" ]; then
  echo "   ❌ No se pudo descargar Selkies wheel"
  echo "   URL: $WHEEL_URL"
  exit 1
fi

echo "   📦 Instalando paquete Python..."
pip3 install --quiet --no-cache-dir "/tmp/${WHEEL_NAME}" 2>/dev/null || \
pip3 install --quiet --no-cache-dir --break-system-packages "/tmp/${WHEEL_NAME}" 2>/dev/null || \
{ echo "   ❌ No se pudo instalar Selkies via pip"; rm -f "/tmp/${WHEEL_NAME}"; exit 1; }

rm -f "/tmp/${WHEEL_NAME}"
echo "   ✅ Selkies instalado"

# Verificar instalación
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📊 Verificando instalación:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SELKIES_BIN=""
for cmd in selkies-gstreamer selkies; do
  if command -v "$cmd" >/dev/null 2>&1; then
    SELKIES_BIN="$cmd"
    echo "   ✅ $cmd: $(which $cmd)"
    break
  fi
done

if [ -z "$SELKIES_BIN" ]; then
  echo "   ⚠️ Comando selkies no encontrado en PATH"
  echo "   Verificando instalación de Python..."
  pip3 show selkies-gstreamer 2>/dev/null | head -3 || echo "   No instalado"
fi

if [ "$HAS_NVIDIA" = true ]; then
  echo "   🎮 GPU: NVIDIA (${GPU_NAME})"
  echo "   ⚡ Encoder: NVENC H.264"
else
  echo "   🎮 GPU: CPU fallback"
  echo "   ⚡ Encoder: Software H.264"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Selkies instalado correctamente"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
