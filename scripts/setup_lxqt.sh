#!/usr/bin/env bash
# setup_lxqt.sh - Instala LXQt + X11 minimo en Google Colab
# Uso: bash setup_lxqt.sh <RESOLUCION>
set -uo pipefail

RESOLUTION="${1:-1920x1080}"
export DEBIAN_FRONTEND=noninteractive

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🖥️  Instalando LXQt Desktop"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "   ↳ Actualizando repositorios..."
apt-get update -y || { echo "❌ apt-get update fallo"; exit 1; }

echo "   ↳ Instalando LXQt + X11..."
apt-get install -y --no-install-recommends \
  lxqt-core lxqt-session lxqt-panel lxqt-qtplugin \
  openbox \
  pcmanfm-qt qterminal \
  xorg xvfb x11-xserver-utils xauth dbus-x11 \
  x11-utils xdotool xclip xsel \
  fonts-noto fonts-dejavu fonts-liberation \
  libx11-6 libxrandr2 libxinerama1 libxcursor1 libxi6 libxtst6 \
  || { echo "❌ fallo al instalar paquetes"; exit 1; }

mkdir -p ~/.config/lxqt ~/.local/share/applications

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ LXQt instalado correctamente"
echo "  📺 Resolucion: ${RESOLUTION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
