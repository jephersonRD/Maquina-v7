#!/usr/bin/env bash
# setup_xrdp.sh - Instala KDE Plasma + XRDP en Google Colab.
# Uso: bash setup_xrdp.sh <USUARIO> <CONTRASEÑA> <RESOLUCION>
set -uo pipefail

USERNAME="${1:-jeph}"
PASSWORD="${2:-medina}"
RESOLUTION="${3:-1920x1080}"

export DEBIAN_FRONTEND=noninteractive

echo "📦 [1/6] Actualizando apt..."
apt-get update -y || { echo "❌ apt-get update falló"; exit 1; }

echo "🖥️ [2/6] Instalando KDE Plasma, Xorg y dependencias..."
apt-get install -y \
  kde-plasma-desktop xorg x11-xserver-utils xauth dbus-x11 \
  openssl ca-certificates curl wget \
  libx11-6 libxrandr2 libxinerama1 libxcursor1 libxi6 libxtst6 \
  || { echo "❌ fallo al instalar el escritorio"; exit 1; }

echo "🔌 [3/6] Instalando XRDP..."
apt-get install -y xrdp xorgxrdp || { echo "❌ fallo al instalar XRDP"; exit 1; }

echo "👤 [4/6] Creando usuario '$USERNAME'..."
id "$USERNAME" >/dev/null 2>&1 || useradd -m -s /bin/bash "$USERNAME" || { echo "❌ no se pudo crear el usuario"; exit 1; }
echo "$USERNAME:$PASSWORD" | chpasswd || { echo "❌ no se pudo fijar la contraseña"; exit 1; }
usermod -aG sudo,audio,video,render,input "$USERNAME" 2>/dev/null || true

echo "⚙️ [5/6] Configurando XRDP para KDE Plasma..."
# Asegurar que XRDP use la sesión KDE Plasma
echo "startplasma-x11" > "/home/$USERNAME/.xsession"
chown "$USERNAME:$USERNAME" "/home/$USERNAME/.xsession"

# Configurar sesman.ini
mkdir -p /etc/xrdp
cat > /etc/xrdp/sesman.ini <<EOF
[Globals]
ListenAddress=127.0.0.1
ListenPort=3350
EnableUserWindowManager=true
UserWindowManager=startwm.sh
DefaultWindowManager=startwm.sh

[Security]
AllowRootLogin=true
MaxLoginRetry=4
TerminalServerUsers=tsusers
TerminalServerAdmins=tsadmins
EOF

# Configurar xrdp.ini
cat > /etc/xrdp/xrdp.ini <<EOF
[Globals]
ini_version=1
bitmap_cache=yes
bitmap_compression=yes
port=3389
crypt_level=high
channel_code=1
max_bpp=32
fork=yes
tcp_nodelay=yes
tcp_keepalive=yes
security_layer=tls
ssl_protocols=TLSv1.2, TLSv1.3
certificate=
key_file=
EOF

# Script de inicio de sesión que lanza KDE
cat > /etc/xrdp/startwm.sh <<EOF
#!/bin/bash
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=KDE
export DESKTOP_SESSION=plasma
export DISPLAY=:10
exec dbus-launch startplasma-x11
EOF
chmod +x /etc/xrdp/startwm.sh

# Limpiar cualquier sesión previa
rm -rf /tmp/.X11-unix/X10 /tmp/.X10-lock 2>/dev/null || true

echo "🚀 [6/6] Iniciando servicios XRDP..."
# Matar procesos previos
pkill -x xrdp 2>/dev/null || true
pkill -x xrdp-sesman 2>/dev/null || true
sleep 1

# En Google Colab NO hay systemd, así que iniciamos los binarios directamente
echo "   ↳ Iniciando xrdp-sesman..."
/usr/sbin/xrdp-sesman || { echo "❌ xrdp-sesman no arrancó"; exit 1; }
sleep 1

echo "   ↳ Iniciando xrdp..."
/usr/sbin/xrdp || { echo "❌ xrdp no arrancó"; exit 1; }

sleep 3

# Verificar que estén escuchando
if ss -ltn 2>/dev/null | grep -q ':3389'; then
  echo "   ✅ XRDP escuchando en puerto 3389"
else
  echo "   ⚠️ XRDP podría no estar escuchando aún. Verifica con: ss -ltn | grep 3389"
fi

echo ""
echo "========================================"
echo "✅ XRDP + KDE Plasma listos"
echo "   Puerto RDP   : 3389"
echo "   Usuario      : $USERNAME"
echo "   Contraseña   : $PASSWORD"
echo "========================================"
echo ""
echo "📱 Conéctate con cualquier cliente RDP:"
echo "   - Microsoft Remote Desktop (Android/Windows)"
echo "   - aRDP (Android)"
echo "   - Remmina (Linux)"
echo ""
echo "   Servidor: <IP-de-Tailscale>:3389"
echo "   o      : <IP-local>:3389"
echo "========================================"
