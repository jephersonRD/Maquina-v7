#!/usr/bin/env bash
#
# Maquina-v7 :: setup_rdp.sh  (progreso visible + Chromium + verificacion)
#
USERNAME="${1:-v7user}"
PASSWORD="${2:-v7pass}"
RESOLUTION="${3:-1920x1080}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FASE 1/5  📦 Actualizando listas de apt..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
apt-get update -y

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FASE 2/5  🖥️  Instalando Xfce4 + xrdp + Chromium (2-5 min)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for i in 1 2 3; do
  echo "   ↳ intento $i..."
  if apt-get install -y xfce4 xfce4-goodies xrdp xorgxrdp \
        tigervnc-standalone-server dbus-x11 x11-utils curl wget net-tools \
        chromium-browser chromium; then
    echo "   ✅ paquetes base instalados"; break
  fi
  echo "   ⚠️ fallo, reintentando en 3s..."; sleep 3
done

# Chromium puede no estar en los repos estandar (snap). Usar PPA no-snap.
if ! command -v chromium-browser >/dev/null 2>&1 && ! command -v chromium >/dev/null 2>&1; then
  echo "   ↳ Chromium no disponible por defecto, probando PPA savoury1..."
  add-apt-repository -y ppa:savoury1/chromium >/dev/null 2>&1
  apt-get update -y >/dev/null 2>&1
  apt-get install -y chromium >/dev/null 2>&1 || apt-get install -y chromium-browser
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FASE 3/5  👤 Creando usuario RDP: $USERNAME"
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
echo "  FASE 4/5  🚀 Iniciando servidor RDP (puerto 3389)"
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

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FASE 5/5  🔎 Verificacion"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
[ "$(command -v xrdp >/dev/null 2>&1 && echo 1)" = "1" ] && echo "   ✅ xrdp instalado" || echo "   ❌ xrdp NO instalado"
if (ss -ltn 2>/dev/null | grep -q ':3389') || (netstat -ltn 2>/dev/null | grep -q ':3389'); then
  echo "   ✅ RDP escuchando en puerto 3389"
else
  echo "   ⚠️ 3389 NO escucha. Revisa: tail /tmp/xrdp.log"
fi
CB=$(command -v chromium-browser || command -v chromium || echo "NO")
echo "   Chromium: $CB"
echo ""
echo "📋 RESUMEN: Usuario=$USERNAME | Password=$PASSWORD | Puerto=3389"
