#!/usr/bin/env bash
# setup_sunshine.sh - Instala Sunshine (servidor de streaming, NVENC en la T4) sobre
# Xvfb + KDE Plasma en Google Colab. Reemplaza Selkies / XRDP.
#
# Sunshine es el servidor open-source que codifica con NVENC (GPU T4) y lo reproduce
# Moonlight (cliente nativo de Android). La Web UI se expone via cloudflared (HTTPS) para
# leer el PIN de emparejamiento; el stream UDP real de Moonlight va por Tailscale
# (cloudflared solo tuneliza HTTP/TCP, no UDP).
#
# Uso: bash setup_sunshine.sh <USUARIO> <CONTRASEÑA> <RESOLUCION> [PUERTO_WEB]
set -uo pipefail

USERNAME="${1:-jeph}"
PASSWORD="${2:-medina}"
RESOLUTION="${3:-1920x1080}"
WEB_PORT="${4:-47989}"

SUN_HOME="/home/$USERNAME"
CONFIG_DIR="$SUN_HOME/.config/sunshine"
SUN_DIR="/opt/sunshine"
LOGDIR="/tmp"
export DEBIAN_FRONTEND=noninteractive

echo "📦 [1/8] Actualizando apt..."
apt-get update -y || { echo "❌ apt-get update fallo"; exit 1; }

echo "🖥️ [2/8] Instalando KDE Plasma, Xvfb y PulseAudio..."
apt-get install -y \
  kde-plasma-desktop xvfb x11-utils xauth dbus-x11 \
  pulseaudio pavucontrol \
  openssl ca-certificates curl git wget \
  libx11-6 libxrandr2 libxinerama1 libxcursor1 libxi6 libxtst6 \
  libssl3 ffmpeg \
  || { echo "❌ fallo al instalar el escritorio"; exit 1; }

echo "🧹 [3/8] Eliminando XRDP/Selkies (ya no se usan)..."
apt-get remove -y --purge xrdp xorgxrdp 2>/dev/null || true
pkill -x xrdp xrdp-sesman 2>/dev/null || true
rm -rf /opt/selkies /opt/gst-web /etc/xrdp 2>/dev/null || true
echo "   ✅ limpieza lista"

echo "👤 [4/8] Creando usuario '$USERNAME'..."
id "$USERNAME" >/dev/null 2>&1 || useradd -m -s /bin/bash "$USERNAME" || { echo "❌ no se pudo crear el usuario"; exit 1; }
echo "$USERNAME:$PASSWORD" | chpasswd || { echo "❌ no se pudo fijar la contrasena"; exit 1; }
usermod -aG sudo,audio,video,render,input "$USERNAME" 2>/dev/null || true

echo "🎬 [5/8] Detectando codificador de video (NVENC en la T4)..."
if [ -e /dev/nvidia0 ] && command -v nvidia-smi >/dev/null 2>&1; then
  ENC="nvenc"; CAP="x11"
  echo "   → GPU NVIDIA detectada: encoder=$ENC, capture=$CAP (NVENC por hardware, casi 0% CPU)"
  # Hacer visibles las libs de encoding NVIDIA para el ffmpeg embebido de Sunshine
  for p in /usr/lib/nvidia /usr/lib/nvidia-* /usr/lib/x86_64-linux-gnu; do
    [ -d "$p" ] && export LD_LIBRARY_PATH="$p:$LD_LIBRARY_PATH"
  done
  # libnvidia-encode (necesaria para h264_nvenc)
  if ! ldconfig -p 2>/dev/null | grep -q "libnvidia-encode.so.1"; then
    DRV=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1 | cut -d. -f1)
    apt-get install -y "libnvidia-encode-$DRV" 2>/dev/null \
      || apt-get install -y libnvidia-encode1 2>/dev/null \
      || echo "   ⚠️ no se pudo instalar libnvidia-encode (NVENC podria fallar)"
  fi
else
  ENC="libx264"; CAP="x11"
  echo "   → Sin GPU: encoder=$ENC (CPU, fallback). El streaming sigue funcionando."
fi

echo "📥 [6/8] Instalando Sunshine..."
. /etc/os-release
case "${VERSION_ID:-22.04}" in
  24.04) DEB="sunshine-ubuntu-24.04-amd64.deb" ;;
  22.04) DEB="sunshine-ubuntu-22.04-amd64.deb" ;;
  *)     DEB="sunshine-ubuntu-22.04-amd64.deb" ;;
esac
TAG="$(curl -fsSL --max-time 30 https://api.github.com/repos/LizardByte/Sunshine/releases/latest \
      | python3 -c 'import sys,json;print(json.load(sys.stdin)["tag_name"])')"
[ -n "$TAG" ] || { echo "❌ no se pudo resolver la version de Sunshine"; exit 1; }
echo "   Versión Sunshine: $TAG"
curl -fsSL --max-time 240 -o "/tmp/$DEB" \
  "https://github.com/LizardByte/Sunshine/releases/download/$TAG/$DEB" \
  || { echo "❌ fallo al descargar Sunshine"; exit 1; }
dpkg -i "/tmp/$DEB" >/dev/null 2>&1 || apt-get -f install -y >/dev/null 2>&1 \
  || { echo "❌ fallo al instalar Sunshine"; exit 1; }
command -v sunshine >/dev/null 2>&1 || { echo "❌ sunshine no instalado"; exit 1; }
echo "   ✅ sunshine: $(command -v sunshine)"

echo "⚙️ [7/8] Configurando Sunshine (capture=$CAP, encoder=$ENC)..."
mkdir -p "$CONFIG_DIR"
cat > "$CONFIG_DIR/sunshine.conf" <<EOF
log_path = /tmp/sunshine.log
min_log_level = info
capture = $CAP
encoder = $ENC
fps = 60
port = $WEB_PORT
address_family = ipv4
origin_web_ui_allowed = pc|lan|wan
EOF
chown -R "$USERNAME:$USERNAME" "$CONFIG_DIR"
mkdir -p "$SUN_DIR"
cp "$(dirname "$0")/sunshine-launch.sh" "$SUN_DIR/sunshine-launch.sh" 2>/dev/null || true
chmod +x "$SUN_DIR/sunshine-launch.sh" 2>/dev/null || true

echo "🚀 [8/8] Iniciando Sunshine + escritorio en segundo plano (bucle de reinicio)..."
cat > "$SUN_DIR/sunshine-loop.sh" <<'EOF'
#!/usr/bin/env bash
# Bucle de reinicio de Sunshine (ejecutado en segundo plano por setup_sunshine.sh)
U="$1"; P="$2"; R="$3"; PT="$4"
export LD_LIBRARY_PATH="/usr/lib/nvidia:/usr/lib/nvidia-*:${LD_LIBRARY_PATH:-}"
while true; do
  echo "[$(date)] iniciando Sunshine..." >> "/tmp/sunshine.log"
  bash "/opt/sunshine/sunshine-launch.sh" "$U" "$P" "$R" "$PT" >> "/tmp/sunshine.log" 2>&1
  echo "[$(date)] Sunshine terminó (rc=$?). Reiniciando en 3s..." >> "/tmp/sunshine.log"
  sleep 3
done
EOF
chmod +x "$SUN_DIR/sunshine-loop.sh"
su - "$USERNAME" -c "nohup /opt/sunshine/sunshine-loop.sh '$USERNAME' '$PASSWORD' '$RESOLUTION' '$WEB_PORT' >/dev/null 2>&1 &"
echo ""
echo "========================================"
echo "✅ Sunshine corriendo en segundo plano (Web UI puerto $WEB_PORT)."
echo "   Acceso local : http://localhost:$WEB_PORT"
echo "   Usuario      : $USERNAME"
echo "   Contraseña   : $PASSWORD"
echo "   Exponiendo Web UI por túnel público (cloudflared)... espera ~15s."
echo "========================================"

# ---- Verificacion de salud local (usar 127.0.0.1, NO localhost: este resuelve
#      a IPv6 ::1 y Sunshine solo escucha IPv4 con address_family=ipv4) ----
sleep 6
CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${WEB_PORT}/serverinfo" 2>/dev/null)
echo "   Sunshine local responde (serverinfo): ${CODE:-sin respuesta}"
if [ "$CODE" != "200" ]; then
  echo "   ⚠️ Sunshine aún no responde en 127.0.0.1:$WEB_PORT. Cola de log:"
  tail -n 15 /tmp/sunshine.log 2>/dev/null || true
fi

# ---- IP de Tailscale para la Web UI (la forma mas fiable de emparejar) ----
TS_IP=""
if command -v tailscale >/dev/null 2>&1; then
  TS_IP=$(tailscale ip -4 2>/dev/null | head -n1)
fi

# ---- Exponer la Web UI de Sunshine por cloudflared (HTTPS, para leer el PIN) ----
if [ ! -x /usr/local/bin/cloudflared ]; then
  echo "   ↳ descargando cloudflared..."
  curl -fsSL --max-time 120 -o /usr/local/bin/cloudflared \
    "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64" \
    && chmod +x /usr/local/bin/cloudflared || echo "⚠️ no se pudo descargar cloudflared"
fi
URL=""
if [ -x /usr/local/bin/cloudflared ]; then
  nohup /usr/local/bin/cloudflared tunnel --url "http://127.0.0.1:${WEB_PORT}" \
    --no-autoupdate >/tmp/cloudflared.log 2>&1 &
  for i in $(seq 1 40); do
    URL=$(grep -oE 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' /tmp/cloudflared.log | head -n1)
    [ -n "$URL" ] && break
    sleep 1
  done
fi
echo ""
echo "========================================"
echo "✅ Sunshine listo. Web UI (para el PIN de emparejamiento):"
if [ -n "$TS_IP" ]; then
  echo "   🥇 Recomendado (Tailscale, en el navegador del movil):"
  echo "      http://$TS_IP:$WEB_PORT   (usuario: $USERNAME / password: $PASSWORD)"
fi
if [ -n "$URL" ]; then
  echo "   🌐 También por cloudflared (HTTPS):"
  echo "      $URL   (usuario: $USERNAME / password: $PASSWORD)"
else
  echo "   ⚠️ URL cloudflared no disponible; usa la de Tailscale arriba."
fi
echo ""
echo "   📌 Emparejar Moonlight: abre la Web UI, ve a 'PIN', y escribe el"
echo "      numero que te muestra Moonlight en el movil. Luego 'Pair'."
echo "   Logs Sunshine : tail -f /tmp/sunshine.log"
echo "========================================"
echo ""
echo "📱 Para jugar: instala Moonlight en Android, conecta por Tailscale a esta maquina"
echo "   (misma cuenta) y empareja usando el PIN que aparece en la Web UI."
