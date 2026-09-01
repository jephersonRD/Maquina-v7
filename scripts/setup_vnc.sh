#!/usr/bin/env bash
# setup_vnc.sh - Instala x11vnc para acceso VNC remoto
# Uso: bash setup_vnc.sh
set -uo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔗 Instalando x11vnc"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

apt-get install -y --no-install-recommends x11vnc \
  || { echo "❌ fallo al instalar x11vnc"; exit 1; }

echo "   ✅ x11vnc instalado: $(which x11vnc)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ VNC configurado"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
