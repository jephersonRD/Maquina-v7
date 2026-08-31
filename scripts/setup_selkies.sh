#!/usr/bin/env bash
# setup_selkies.sh - Instala Selkies (escritorio remoto vía navegador)
# Uso: bash setup_selkies.sh
set -uo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🌐 Instalando Selkies (remote desktop via browser)"
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
  python3 python3-pip python3-venv \
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
  echo "   ⚠️ No se pudo obtener la versión, usando AppImage"
  SELKIES_USE_APPIMAGE=true
else
  echo "   📦 Versión: $SELKIES_VERSION"
  SELKIES_USE_APPIMAGE=false
fi

# Intentar instalar paquete .deb primero
if [ "$SELKIES_USE_APPIMAGE" = false ]; then
  echo "   ↳ Intentando instalar paquete .deb..."
  . /etc/os-release 2>/dev/null || true
  DISTRO="ubuntu22.04"
  if [ -n "${VERSION_CODENAME:-}" ]; then
    if [ "${ID:-}" = "ubuntu" ]; then
      DISTRO="ubuntu${VERSION_ID:-22.04}"
    else
      DISTRO="${VERSION_CODENAME}"
    fi
  fi
  
  PKG="selkies_${SELKIES_VERSION}-1~${DISTRO}_$(dpkg --print-architecture 2>/dev/null || echo amd64).deb"
  DOWNLOAD_URL="https://github.com/selkies-project/selkies/releases/download/v${SELKIES_VERSION}/${PKG}"
  
  echo "   📥 Descargando: $PKG"
  if curl -O -fsSL "$DOWNLOAD_URL" 2>/dev/null; then
    if apt-get install -y "./${PKG}" 2>/dev/null; then
      echo "   ✅ Selkies instalado via paquete .deb"
      rm -f "./${PKG}"
    else
      echo "   ⚠️ Paquete .deb no compatible, usando AppImage"
      rm -f "./${PKG}"
      SELKIES_USE_APPIMAGE=true
    fi
  else
    echo "   ⚠️ Paquete .deb no disponible, usando AppImage"
    SELKIES_USE_APPIMAGE=true
  fi
fi

# Si no se pudo instalar el .deb, usar AppImage
if [ "$SELKIES_USE_APPIMAGE" = true ]; then
  echo "   ↳ Descargando AppImage..."
  APP="selkies-$(curl -fsSL 'https://api.github.com/repos/selkies-project/selkies/releases/latest' 2>/dev/null | jq -r '.tag_name' | sed 's/^v//' 2>/dev/null)-$(uname -m).AppImage"
  
  if [ -z "$APP" ] || [ "$APP" = "selkies-null-$(uname -m).AppImage" ]; then
    echo "   ❌ No se pudo obtener la versión de Selkies"
    echo "   Intentando descargar última release conocida..."
    APP="selkies-1.0.0-$(uname -m).AppImage"
  fi
  
  DOWNLOAD_URL="https://github.com/selkies-project/selkies/releases/download/v$(echo $APP | sed 's/selkies-//' | sed 's/-.*//' )/${APP}"
  
  echo "   📥 Descargando: $APP"
  if curl -O -fsSL "$DOWNLOAD_URL" 2>/dev/null; then
    chmod +x "./${APP}"
    mv "./${APP}" /usr/local/bin/selkies-appimage
    echo "   ✅ Selkies AppImage instalado en /usr/local/bin/selkies-appimage"
  else
    echo "   ❌ No se pudo descargar Selkies"
    echo "   Verifica: https://github.com/selkies-project/selkies/releases"
    exit 1
  fi
fi

# Verificar instalación
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📊 Verificando instalación de Selkies:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v selkies >/dev/null 2>&1; then
  echo "   ✅ selkies: $(which selkies)"
elif [ -f /usr/local/bin/selkies-appimage ]; then
  echo "   ✅ selkies-appimage: /usr/local/bin/selkies-appimage"
else
  echo "   ❌ Selkies no encontrado"
  exit 1
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
