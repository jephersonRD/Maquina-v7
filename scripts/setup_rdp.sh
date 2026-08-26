#!/usr/bin/env bash
#
# Maquina-v7 :: setup_rdp.sh  (version robusta para Colab)
# Instala Xfce4 + xrdp y deja el escritorio listo en el puerto 3389.
# No usa 'set -e' para no morir ante un fallo parcial de apt.
#
USERNAME="${1:-v7user}"
PASSWORD="${2:-v7pass}"
RESOLUTION="${3:-1920x1080}"

echo "[*] Actualizando apt..."
apt-get update -y >/dev/null 2>&1 || apt-get update -y --fix-missing >/dev/null 2>&1

echo "[*] Instalando Xfce4 + xrdp (hasta 3 intentos)..."
for i in 1 2 3; do
  if apt-get install -y xfce4 xfce4-goodies xrdp xorgxrdp tigervnc-standalone-server \
        dbus-x11 x11-utils curl wget net-tools >/dev/null 2>&1; then
    echo "[OK] paquetes instalados"
    break
  fi
  echo "[!] intento $i fallo, reintentando..."
  sleep 3
done

# Crear usuario
if ! id "$USERNAME" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$USERNAME"
fi
echo "$USERNAME:$PASSWORD" | chpasswd
usermod -aG sudo "$USERNAME" 2>/dev/null
echo "xfce4-session" > "/home/$USERNAME/.xsession"
chown "$USERNAME:$USERNAME" "/home/$USERNAME/.xsession" 2>/dev/null || true

# startwm -> Xfce
cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
export DESKTOP_SESSION=xfce
export XDG_CURRENT_DESKTOP=XFCE
exec /usr/bin/xfce4-session
EOF
chmod +x /etc/xrdp/startwm.sh

# Resolucion por defecto
sed -i "s/^geometry=.*/geometry=$RESOLUTION/" /etc/xrdp/xrdp.ini 2>/dev/null || true

# Iniciar xrdp (Colab no usa systemd)
echo "[*] Iniciando xrdp..."
pkill -x xrdp 2>/dev/null; pkill -x xrdp-sesman 2>/dev/null; sleep 1
if command -v service >/dev/null 2>&1; then
  service xrdp stop 2>/dev/null
  service xrdp start 2>/dev/null || service xrdp restart 2>/dev/null
fi
sleep 2
if ! pgrep -x xrdp >/dev/null 2>&1; then
  echo "[*] arrancando xrdp manualmente (background)..."
  nohup xrdp-sesman -n >/tmp/sesman.log 2>&1 &
  nohup xrdp -n >/tmp/xrdp.log 2>&1 &
  sleep 2
fi

# Verificar
if (ss -ltn 2>/dev/null | grep -q ':3389') || (netstat -ltn 2>/dev/null | grep -q ':3389'); then
  echo "[OK] RDP escuchando en puerto 3389"
else
  echo "[!] 3389 NO escucha. Revisa /tmp/xrdp.log y /tmp/sesman.log"
fi
echo "[INFO] Usuario=$USERNAME  Password=$PASSWORD  Puerto=3389"
