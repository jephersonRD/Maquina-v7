#!/usr/bin/env bash
#
# Maquina-v7 :: setup_rdp.sh  (version con progreso visible)
# Instala Xfce4 + xrdp y deja el escritorio listo en el puerto 3389.
# Muestra todo el proceso (sin silenciar) para que veas que si instala.
#
USERNAME="${1:-v7user}"
PASSWORD="${2:-v7pass}"
RESOLUTION="${3:-1920x1080}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FASE 1/4  📦 Actualizando listas de apt..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
apt-get update -y

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FASE 2/4  🖥️  Instalando escritorio Xfce4 + xrdp (puede tardar 2-5 min)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for i in 1 2 3; do
  echo "   ↳ intento $i de instalacion..."
  if apt-get install -y xfce4 xfce4-goodies xrdp xorgxrdp \
        tigervnc-standalone-server dbus-x11 x11-utils curl wget net-tools; then
    echo "   ✅ paquetes instalados"
    break
  fi
  echo "   ⚠️ fallo, reintentando en 3s..."; sleep 3
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FASE 3/4  👤 Creando usuario RDP: $USERNAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ! id "$USERNAME" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "$USERNAME" && echo "   ✅ usuario creado"
else
  echo "   ℹ️ el usuario ya existe"
fi
echo "$USERNAME:$PASSWORD" | chpasswd && echo "   ✅ contrasena configurada"
usermod -aG sudo "$USERNAME" 2>/dev/null
echo "xfce4-session" > "/home/$USERNAME/.xsession"
chown "$USERNAME:$USERNAME" "/home/$USERNAME/.xsession" 2>/dev/null || true

cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
export DESKTOP_SESSION=xfce
export XDG_CURRENT_DESKTOP=XFCE
exec /usr/bin/xfce4-session
EOF
chmod +x /etc/xrdp/startwm.sh
sed -i "s/^geometry=.*/geometry=$RESOLUTION/" /etc/xrdp/xrdp.ini 2>/dev/null || true
echo "   ✅ escritorio Xfce configurado para xrdp"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FASE 4/4  🚀 Iniciando servidor RDP (puerto 3389)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
pkill -x xrdp 2>/dev/null; pkill -x xrdp-sesman 2>/dev/null; sleep 1
if command -v service >/dev/null 2>&1; then
  service xrdp stop 2>/dev/null
  service xrdp start 2>/dev/null || service xrdp restart 2>/dev/null
fi
sleep 2
if ! pgrep -x xrdp >/dev/null 2>&1; then
  echo "   ↳ arranque manual en background..."
  nohup xrdp-sesman -n >/tmp/sesman.log 2>&1 &
  nohup xrdp -n >/tmp/xrdp.log 2>&1 &
  sleep 2
fi

if (ss -ltn 2>/dev/null | grep -q ':3389') || (netstat -ltn 2>/dev/null | grep -q ':3389'); then
  echo "   ✅ RDP escuchando en puerto 3389"
else
  echo "   ⚠️ 3389 NO escucha. Revisa: tail /tmp/xrdp.log"
fi
echo ""
echo "📋 RESUMEN: Usuario=$USERNAME | Password=$PASSWORD | Puerto=3389"
