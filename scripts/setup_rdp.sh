#!/usr/bin/env bash
#
# Maquina-v7 :: setup_rdp.sh
# Instala un escritorio Xfce4 + xrdp en Google Colab y lo deja listo
# para conectarse por RDP (Microsoft Remote Desktop) desde Android / PC.
#
# Uso:
#   bash setup_rdp.sh <usuario> <password> [resolucion]
#
# Diseñado para correr como root dentro de un notebook de Colab.
# No depende de binarios externos ni de servicios de terceros frágiles.
#
set -euo pipefail

USERNAME="${1:-v7user}"
PASSWORD="${2:-v7pass}"
RESOLUTION="${3:-1920x1080}"

echo "==================================================="
echo "  Maquina-v7 :: Configurando escritorio RDP"
echo "  Usuario     : $USERNAME"
echo "  Resolucion  : $RESOLUTION"
echo "==================================================="

# 1) Actualizar e instalar Xfce4 + xrdp (sin modo interactivo)
export DEBIAN_FRONTEND=noninteractive
echo "[*] Instalando paquetes (puede tardar 2-4 min)..."
apt-get update -qq
apt-get install -y -qq \
    xfce4 xfce4-goodies xrdp xorgxrdp \
    tigervnc-standalone-server \
    dbus-x11 x11-utils \
    software-properties-common \
    curl wget net-tools >/dev/null 2>&1 || {
        echo "[!] apt fallo parcial, reintentando sin -qq"
        apt-get update
        apt-get install -y xfce4 xfce4-goodies xrdp xorgxrdp tigervnc-standalone-server \
                          dbus-x11 x11-utils curl wget net-tools
    }

# 2) Crear usuario (si no existe) y asignar contrasena
if ! id "$USERNAME" &>/dev/null; then
    echo "[*] Creando usuario $USERNAME"
    useradd -m -s /bin/bash "$USERNAME"
    adduser "$USERNAME" sudo >/dev/null 2>&1 || true
fi
echo "$USERNAME:$PASSWORD" | chpasswd
# Shell por defecto bash
sed -i 's#/bin/sh$#/bin/bash#' /etc/passwd 2>/dev/null || true

# 3) Configurar la sesion Xfce para el usuario
echo "xfce4-session" > "/home/$USERNAME/.xsession"
chown "$USERNAME:$USERNAME" "/home/$USERNAME/.xsession" 2>/dev/null || true
# Tambien para root por si se usa
echo "xfce4-session" > /root/.xsession 2>/dev/null || true

# 4) Ajustar xrdp para usar Xfce y la resolucion deseada
XRDP_INI="/etc/xrdp/xrdp.ini"
if [ -f "$XRDP_INI" ]; then
    # Fijar resolucion por defecto en las secciones de conexion
    sed -i "s/^geometry=.*/geometry=$RESOLUTION/" "$XRDP_INI" 2>/dev/null || true
    # Asegurar que la seccion por defecto use sesman-Xvnc (ya trae Xvnc)
    sed -i "s/^lib=.*/lib=libvnc.so/" "$XRDP_INI" 2>/dev/null || true
fi

# startwm.sh -> Xfce
cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
if [ -r /etc/default/locale ]; then
    . /etc/default/locale
    export LANG LANGUAGE
fi
export DESKTOP_SESSION=xfce
export XDG_CURRENT_DESKTOP=XFCE
exec /usr/bin/xfce4-session
EOF
chmod +x /etc/xrdp/startwm.sh

# 5) Habilitar e iniciar xrdp (Colab no usa systemd: usamos el init.d / service)
echo "[*] Iniciando xrdp..."
service xrdp stop 2>/dev/null || true
sleep 1
if command -v service >/dev/null 2>&1; then
    service xrdp start
else
    /etc/init.d/xrdp start
fi
sleep 2

# 6) Verificacion
if pgrep -x xrdp >/dev/null && pgrep -x xrdp-sesman >/dev/null; then
    echo "[OK] xrdp corriendo en puerto 3389"
else
    echo "[!] xrdp no arranco; intentando en primer plano..."
    (xrdp -n && xrdp-sesman -n) &
    sleep 2
fi

# 7) Resumen de conexion
IP_PUBLICA=$(curl -s -m 5 https://api.ipify.org || echo "desconocida")
echo "==================================================="
echo "  RDP listo."
echo "  Usuario : $USERNAME"
echo "  Puerto  : 3389"
echo "  IP pub  : $IP_PUBLICA (solo util si expones el puerto)"
echo "  Recomendado: conectate via Tailscale (ver setup_tailscale.sh)"
echo "==================================================="
