#!/usr/bin/env bash
# setup_selkies.sh - Instala Selkies (HTML5 + WebRTC) sobre KDE Plasma en Colab.
# Reemplaza XRDP por Selkies (remote desktop HTML5 + WebRTC) sobre KDE Plasma.
# Uso: bash setup_selkies.sh <USUARIO> <CONTRASEÑA> <RESOLUCION> [PUERTO]
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
export DEBIAN_FRONTEND=noninteractive

echo "📦 [1/7] Actualizando apt..."
apt-get update -y || { echo "❌ apt-get update fallo"; exit 1; }

echo "🖥️ [2/7] Instalando KDE Plasma, Xvfb y PulseAudio..."
apt-get install -y \
  kde-plasma-desktop xvfb dbus-x11 x11-utils pulseaudio \
  openssl ca-certificates curl git \
  || { echo "❌ fallo al instalar el escritorio"; exit 1; }

echo "🧹 [3/7] Eliminando XRDP (ya no se usa)"
apt-get remove -y --purge xrdp xorgxrdp 2>/dev/null || true
pkill -x xrdp xrdp-sesman 2>/dev/null || true
rm -rf /etc/xrdp /etc/xrdp.ini 2>/dev/null || true
echo "   ✅ XRDP eliminado"

echo "👤 [4/7] Creando usuario '$USERNAME'..."
id "$USERNAME" >/dev/null 2>&1 || useradd -m -s /bin/bash "$USERNAME" || { echo "❌ no se pudo crear el usuario"; exit 1; }
echo "$USERNAME:$PASSWORD" | chpasswd || { echo "❌ no se pudo fijar la contrasena"; exit 1; }
usermod -aG sudo,audio,video,render "$USERNAME" 2>/dev/null || true

echo "📥 [5/7] Descargando Selkies (portable + web)..."
mkdir -p "$SELKIES_DIR" "$WEB_ROOT"
VER="$(curl -fsSL --max-time 30 https://api.github.com/repos/selkies-project/selkies/releases/latest \
      | python3 -c 'import sys,json;print(json.load(sys.stdin)["tag_name"].lstrip("v"))')"
[ -n "$VER" ] || { echo "❌ no se pudo resolver la version de Selkies"; exit 1; }
echo "   Versión Selkies: $VER"

echo "   ↳ bundle portable (gstreamer autocontenido)..."
PORTABLE="selkies-gstreamer-portable-v${VER}_amd64.tar.gz"
curl -fsSL --max-time 180 -o "/tmp/$PORTABLE" \
  "https://github.com/selkies-project/selkies/releases/download/v${VER}/$PORTABLE" \
  || { echo "❌ fallo al descargar el bundle portable de Selkies"; exit 1; }
tar xzf "/tmp/$PORTABLE" -C "$SELKIES_DIR" || { echo "❌ fallo al extraer Selkies"; exit 1; }

echo "   ↳ frontend web (gst-web)..."
WEB="selkies-gstreamer-web_v${VER}.tar.gz"
curl -fsSL --max-time 120 -o "/tmp/$WEB" \
  "https://github.com/selkies-project/selkies/releases/download/v${VER}/$WEB" \
  || { echo "❌ fallo al descargar el frontend web de Selkies"; exit 1; }
tar xzf "/tmp/$WEB" -C "$(dirname "$WEB_ROOT")" || { echo "❌ fallo al extraer el frontend web"; exit 1; }

echo "🔐 [6/7] Generando certificado TLS autofirmado..."
if [ ! -f "$CERT" ]; then
  openssl req -x509 -newkey rsa:2048 -nodes -keyout "$KEY" -out "$CERT" \
    -days 3650 -subj "/CN=maquina-v7" >/dev/null 2>&1 || echo "⚠️ no se pudo generar el cert (HTTPS opcional)"
fi

echo "⚙️ [7/7] Desactivando compositor de KWin (menos latencia)..."
mkdir -p "/home/$USERNAME/.config"
cat > "/home/$USERNAME/.config/kwinrc" <<'EOF'
[Compositing]
Enabled=false
EOF
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config" 2>/dev/null || true

echo "🚀 Lanzando Selkies (bucle de reinicio)..."
cp "$(dirname "$0")/selkies-launch.sh" "$SELKIES_DIR/selkies-launch.sh" 2>/dev/null || true
while true; do
  echo "[$(date)] iniciando Selkies..." >> "$LOGDIR/selkies.log"
  bash "$SELKIES_DIR/selkies-launch.sh" "$USERNAME" "$PASSWORD" "$RESOLUTION" "$PORT" \
    >> "$LOGDIR/selkies.log" 2>&1
  echo "[$(date)] Selkies terminó (rc=$?). Reiniciando en 3s..." >> "$LOGDIR/selkies.log"
  sleep 3
done
