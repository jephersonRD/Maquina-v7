#!/usr/bin/env bash
# setup_selkies.sh - Instala Selkies (HTML5 + WebRTC) sobre XFCE en Colab.
# Reemplaza XRDP por Selkies (remote desktop HTML5 + WebRTC) sobre XFCE.
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

echo "🖥️ [2/7] Instalando XFCE, Xvfb y PulseAudio..."
apt-get install -y \
  xfce4 xfce4-goodies xvfb dbus-x11 x11-utils pulseaudio \
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

# Ajustar WEB_ROOT por si el tarball extrajo en un subdirectorio
if [ ! -f "$WEB_ROOT/index.html" ]; then
  FOUND=$(find "$(dirname "$WEB_ROOT")" -name index.html 2>/dev/null | head -n1)
  [ -n "$FOUND" ] && WEB_ROOT="$(dirname "$FOUND")"
fi
echo "   Web root detectado: $WEB_ROOT"
[ -f "$WEB_ROOT/index.html" ] || { echo "❌ No se encontro index.html en $WEB_ROOT"; exit 1; }
export WEB_ROOT

echo "🔐 [6/7] Generando certificado TLS autofirmado..."
if [ ! -f "$CERT" ]; then
  openssl req -x509 -newkey rsa:2048 -nodes -keyout "$KEY" -out "$CERT" \
    -days 3650 -subj "/CN=maquina-v7" >/dev/null 2>&1 || echo "⚠️ no se pudo generar el cert (HTTPS opcional)"
fi

echo "⚙️ [7/7] Desactivando compositor de XFCE (menos latencia)..."
mkdir -p "/home/$USERNAME/.config/xfce4/xfconf/xfce-perchannel-xml"
cat > "/home/$USERNAME/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="use_compositing" type="bool" value="false"/>
  </property>
</channel>
EOF
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config" 2>/dev/null || true

echo "🚀 Iniciando Selkies en segundo plano (bucle de reinicio)..."
cp "$(dirname "$0")/selkies-launch.sh" "$SELKIES_DIR/selkies-launch.sh" 2>/dev/null || true
cat > "$SELKIES_DIR/selkies-loop.sh" <<'EOF'
#!/usr/bin/env bash
# Bucle de reinicio de Selkies (ejecutado en segundo plano por setup_selkies.sh)
U="$1"; P="$2"; R="$3"; PT="$4"
while true; do
  echo "[$(date)] iniciando Selkies..." >> "/tmp/selkies.log"
  bash "/opt/selkies/selkies-launch.sh" "$U" "$P" "$R" "$PT" >> "/tmp/selkies.log" 2>&1
  echo "[$(date)] Selkies terminó (rc=$?). Reiniciando en 3s..." >> "/tmp/selkies.log"
  sleep 3
done
EOF
chmod +x "$SELKIES_DIR/selkies-loop.sh"
nohup "$SELKIES_DIR/selkies-loop.sh" "$USERNAME" "$PASSWORD" "$RESOLUTION" "$PORT" >/dev/null 2>&1 &
echo ""
echo "========================================"
echo "✅ Selkies corriendo en segundo plano (puerto $PORT)."
echo "   Acceso local : http://localhost:$PORT"
echo "   Usuario      : $USERNAME"
echo "   Contraseña   : $PASSWORD"
echo "   Exponiendo por túnel público (cloudflared)... espera ~15s."
echo "========================================"

# ---- Verificacion de salud local ----
sleep 5
CODE=""
for i in $(seq 1 20); do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}/" 2>/dev/null)
  [ "$CODE" = "200" ] && break
  [ "$CODE" = "404" ] && break
  sleep 2
done
echo "   Selkies local responde HTTP: ${CODE:-sin respuesta}"
if [ "$CODE" = "000" ] || [ -z "$CODE" ]; then
  echo "❌ Selkies NO escucha en $PORT. Ultimas lineas de /tmp/selkies.log:"
  tail -n 25 /tmp/selkies.log
fi

# ---- Exponer Selkies por cloudflared (URL pública HTTPS, sin Tailscale) ----
if [ ! -x /usr/local/bin/cloudflared ]; then
  echo "   ↳ descargando cloudflared..."
  curl -fsSL --max-time 120 -o /usr/local/bin/cloudflared \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" \
    && chmod +x /usr/local/bin/cloudflared || echo "⚠️ no se pudo descargar cloudflared"
fi
if [ -x /usr/local/bin/cloudflared ]; then
  nohup /usr/local/bin/cloudflared tunnel --url "http://localhost:${PORT}" \
    --no-autoupdate >/tmp/cloudflared.log 2>&1 &
  URL=""
  for i in $(seq 1 40); do
    URL=$(grep -oE 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' /tmp/cloudflared.log | head -n1)
    [ -n "$URL" ] && break
    sleep 1
  done
  echo ""
  if [ -n "$URL" ]; then
    echo "========================================"
    echo "🌐 URL PÚBLICA (abrela en el navegador):"
    echo "   $URL"
    echo "   Usuario: $USERNAME | Contraseña: $PASSWORD"
    echo "========================================"
  else
    echo "⚠️ No se obtuvo la URL de cloudflared. Revisa /tmp/cloudflared.log"
    echo "   Mientras tanto puedes usar el acceso local http://localhost:$PORT"
  fi
fi
echo "   Logs Selkies : tail -f /tmp/selkies.log"
