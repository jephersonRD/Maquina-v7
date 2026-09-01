#!/usr/bin/env bash
# start_desktop.sh - Inicia Xvfb + LXQt + x11vnc + Guacamole
# Uso: bash start_desktop.sh <RESOLUCION> <USUARIO> <CONTRASEÑA> <PUERTO>
set -uo pipefail

RESOLUTION="${1:-1920x1080}"
USERNAME="${2:-user}"
PASSWORD="${3:-password}"
GUAC_PORT="${4:-8080}"
VNC_PORT="5900"

WIDTH="${RESOLUTION%x*}"
HEIGHT="${RESOLUTION#*x}"

export DISPLAY="${DISPLAY:-:10}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}"
export PULSE_RUNTIME_PATH="${XDG_RUNTIME_DIR}/pulse"
export PULSE_SERVER="unix:${PULSE_RUNTIME_PATH}/native"
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=LXQt
export DESKTOP_SESSION=lxqt

mkdir -p "$XDG_RUNTIME_DIR" "$PULSE_RUNTIME_PATH"
chmod 700 "$XDG_RUNTIME_DIR"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🚀 MAQUINA-V7 — Iniciando escritorio"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  🖥️  Desktop      : LXQt"
echo "  🌐 Gateway      : Apache Guacamole"
echo "  🔗 Backend      : VNC (x11vnc)"
echo "  📺 Resolucion   : ${WIDTH}x${HEIGHT}"
echo ""

# Detectar GPU
echo "  🎮 Detectando GPU..."
HAS_NVIDIA=false
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  HAS_NVIDIA=true
  GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader,nounits 2>/dev/null | head -n1)
  echo "  🎮 GPU          : NVIDIA ${GPU_NAME}"
else
  echo "  🎮 GPU          : No detectada (CPU)"
fi
echo ""

# Matar procesos previos
echo "   ↳ Deteniendo procesos previos..."
pkill -x Xvfb 2>/dev/null || true
pkill -x pulseaudio 2>/dev/null || true
pkill -x x11vnc 2>/dev/null || true
pkill -x openbox 2>/dev/null || true
pkill -x guacd 2>/dev/null || true
pkill -f "tomcat" 2>/dev/null || true
sleep 1

# [1/6] Xvfb
echo "   ↳ [1/6] Iniciando Xvfb (display ${DISPLAY})..."
Xvfb "${DISPLAY}" -screen 0 ${WIDTH}x${HEIGHT}x24 \
  -s 0 -dpms \
  +extension "COMPOSITE" +extension "DAMAGE" +extension "GLX" \
  +extension "RANDR" +extension "RENDER" +extension "MIT-SHM" \
  +extension "XFIXES" +extension "XTEST" +iglx +render \
  -nolisten "tcp" -ac -noreset -shmem \
  >/tmp/xvfb.log 2>&1 &

for i in {1..15}; do
  if [ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; then
    echo "      ✅ Xvfb listo"
    break
  fi
  sleep 0.5
done

if [ ! -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; then
  echo "      ❌ Xvfb no pudo iniciar"
  cat /tmp/xvfb.log | tail -10
  exit 1
fi

# [2/6] PulseAudio
echo "   ↳ [2/6] Iniciando PulseAudio..."
pulseaudio --kill 2>/dev/null || true
sleep 1

pulseaudio --daemonize=no \
  --log-target=file:/tmp/pulseaudio.log \
  --exit-idle-time=-1 \
  --disallow-exit \
  --disallow-module-loading=0 &

for i in {1..10}; do
  if pactl info >/dev/null 2>&1; then
    echo "      ✅ PulseAudio listo"
    break
  fi
  sleep 1
done

AUDIO_MONITOR=""
if pactl info >/dev/null 2>&1; then
  AUDIO_MONITOR=$(pactl list short sources 2>/dev/null | grep "monitor" | awk '{print $2}' | head -n1)
  if [ -n "$AUDIO_MONITOR" ]; then
    echo "      🔊 Audio Monitor: ${AUDIO_MONITOR}"
  fi
fi

# [3/6] LXQt
echo "   ↳ [3/6] Iniciando LXQt..."
export DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"
mkdir -p "$XDG_RUNTIME_DIR"
eval $(dbus-launch --sh-syntax)
export DBUS_SESSION_BUS_ADDRESS

lxqt-session &
LXQT_PID=$!
sleep 3
echo "      ✅ LXQt listo (PID: ${LXQT_PID})"

# [4/6] x11vnc
echo "   ↳ [4/6] Iniciando x11vnc..."
echo "${PASSWORD}" | x11vnc -storepasswd - /tmp/vnc_password 2>/dev/null

x11vnc -display "${DISPLAY}" -forever -shared \
  -rfbport ${VNC_PORT} \
  -rfbauth /tmp/vnc_password \
  -noxdamage \
  >/tmp/x11vnc.log 2>&1 &
VNC_PID=$!

for i in {1..10}; do
  if ss -ltn 2>/dev/null | grep -q ":${VNC_PORT}"; then
    echo "      ✅ x11vnc listo (PID: ${VNC_PID})"
    break
  fi
  sleep 1
done

# [5/6] guacd
echo "   ↳ [5/6] Iniciando guacd..."
guacd -f -b 127.0.0.1 -l 4822 >/tmp/guacd.log 2>&1 &
GUACD_PID=$!

for i in {1..10}; do
  if ss -ltn 2>/dev/null | grep -q ":4822"; then
    echo "      ✅ guacd listo (PID: ${GUACD_PID})"
    break
  fi
  sleep 1
done

# [6/6] Apache Guacamole (Tomcat)
echo "   ↳ [6/6] Iniciando Apache Guacamole..."

# Generar configuracion de usuarios
SALT=$(openssl rand -hex 16)
HASH=$(echo -n "${SALT}${PASSWORD}" | sha256sum | awk '{print $1}')

cat > /etc/guacamole/users.json << GUCEOF
{
  "users": {
    "${USERNAME}": {
      "password": "\$sha256\$${SALT}\$${HASH}",
      "connections": {
        "Desktop": {
          "protocol": "vnc",
          "parameters": {
            "hostname": "127.0.0.1",
            "port": "${VNC_PORT}",
            "password": "${PASSWORD}",
            "ignore-cert-errors": "true",
            "resize-method": "display-update"
          }
        }
      }
    }
  }
}
GUCEOF

# Configurar guacamole.properties
cat > /etc/guacamole/guacamole.properties << PROPEOF
auth-provider: net.sourceforge.guacamole.net.auth.json.JSONAuthenticationProvider
json-secret-key: maquina-v7-guac-key
json-users: /etc/guacamole/users.json
guacd-hostname: 127.0.0.1
guacd-port: 4822
log-level: info
PROPEOF

# Enlazar configuracion para Tomcat
ln -sf /etc/guacamole /var/lib/tomcat9/.guacamole 2>/dev/null || true
ln -sf /etc/guacamole /root/.guacamole 2>/dev/null || true

# Crear setenv.sh para Tomcat
CATALINA_HOME=/usr/share/tomcat9
CATALINA_BASE=/var/lib/tomcat9
mkdir -p "${CATALINA_HOME}/bin"
cat > "${CATALINA_HOME}/bin/setenv.sh" << 'SETEOF'
export GUACAMOLE_HOME=/etc/guacamole
SETEOF
chmod +x "${CATALINA_HOME}/bin/setenv.sh"

# Iniciar Tomcat
export GUACAMOLE_HOME=/etc/guacamole
${CATALINA_HOME}/bin/catalina.sh start 2>/dev/null || \
  ${CATALINA_HOME}/bin/catalina.sh run &>/dev/null &

echo "      Esperando Guacamole..."
for i in {1..30}; do
  if curl -s "http://localhost:${GUAC_PORT}" >/dev/null 2>&1; then
    echo "      ✅ Guacamole listo"
    break
  fi
  sleep 1
done

# [7/7] Cloudflared tunnel (URL publica)
echo "   ↳ [7/7] Creando tunnel publico..."
PUBLIC_URL=""
if ! command -v cloudflared >/dev/null 2>&1; then
  curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared 2>/dev/null
  chmod +x /usr/local/bin/cloudflared
fi

if command -v cloudflared >/dev/null 2>&1; then
  cloudflared tunnel --url "http://localhost:${GUAC_PORT}" >/tmp/cloudflared.log 2>&1 &
  CFPID=$!
  for i in {1..30}; do
    PUBLIC_URL=$(grep -oE 'https://[a-zA-Z0-9._-]+\.trycloudflare\.com' /tmp/cloudflared.log 2>/dev/null | head -n1)
    if [ -n "$PUBLIC_URL" ]; then
      echo "      ✅ Tunnel listo"
      break
    fi
    sleep 1
  done
else
  echo "      ⚠️  cloudflared no se pudo instalar"
fi

# Verificar estado final
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Escritorio iniciado correctamente"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [ -n "$PUBLIC_URL" ]; then
  echo "  🌐 URL PUBLICA (abre desde cualquier dispositivo):"
  echo "     ${PUBLIC_URL}"
  echo ""
fi
echo "  🌐 GUACAMOLE (local):"
echo "     http://localhost:${GUAC_PORT}"
echo ""
echo "  📊 Estado:"
if [ -S "/tmp/.X11-unix/X${DISPLAY#*:}" ]; then
  echo "     ✅ Xvfb: ejecutandose"
else
  echo "     ❌ Xvfb: no responde"
fi
if pactl info >/dev/null 2>&1; then
  echo "     ✅ PulseAudio: ejecutandose"
else
  echo "     ⚠️  PulseAudio: no responde"
fi
if pgrep -f "lxqt-session" >/dev/null 2>&1; then
  echo "     ✅ LXQt: ejecutandose"
else
  echo "     ❌ LXQt: no responde"
fi
if pgrep -x x11vnc >/dev/null 2>&1; then
  echo "     ✅ x11vnc: ejecutandose"
else
  echo "     ❌ x11vnc: no responde"
fi
if pgrep -x guacd >/dev/null 2>&1; then
  echo "     ✅ guacd: ejecutandose"
else
  echo "     ❌ guacd: no responde"
fi
if curl -s "http://localhost:${GUAC_PORT}" >/dev/null 2>&1; then
  echo "     ✅ Guacamole: ejecutandose"
else
  echo "     ⚠️  Guacamole: no responde"
fi
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
