#!/usr/bin/env bash
#
# Maquina-v7 :: setup_rdp.sh  (progreso visible + KDE Plasma + verificacion)
#
USERNAME="${1:-v7user}"
PASSWORD="${2:-v7pass}"
RESOLUTION="${3:-1920x1080}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FASE 1/5  📦 Actualizando listas de apt..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
apt-get update -y

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  FASE 2/5  Instalando entorno RDP (KDE Plasma + xrdp) - obligatorio"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
CORE_PKGS="kde-plasma-desktop xrdp xorgxrdp tigervnc-standalone-server dbus-x11 x11-utils curl wget net-tools"
for i in 1 2 3; do
  echo "   intento $i..."
  if DEBIAN_FRONTEND=noninteractive apt-get install -y $CORE_PKGS; then
    echo "   entorno RDP instalado"; break
  fi
  echo "   fallo, reintentando en 5s..."; sleep 5
done

# Si xorgxrdp fallo, reintentar sin el (back-end Xvnc)
if ! command -v xrdp >/dev/null 2>&1; then
  echo "   reintentando sin xorgxrdp (se usara Xvnc)..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y kde-plasma-desktop xrdp \
    tigervnc-standalone-server dbus-x11 x11-utils curl wget net-tools
fi

if ! command -v xrdp >/dev/null 2>&1; then
  echo "   xrdp no se pudo instalar. Revisa apt-get install xrdp manualmente."
  exit 1
fi

echo "   xrdp instalado correctamente (Chromium omitido a proposito)."

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
echo "startplasma-x11" > "/home/$USERNAME/.xsession"
chown "$USERNAME:$USERNAME" "/home/$USERNAME/.xsession" 2>/dev/null || true

cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
export DESKTOP_SESSION=plasma
export XDG_CURRENT_DESKTOP=KDE
exec /usr/bin/startplasma-x11
EOF
chmod +x /etc/xrdp/startwm.sh
sed -i "s/^geometry=.*/geometry=$RESOLUTION/" /etc/xrdp/xrdp.ini 2>/dev/null || true
echo "   ✅ escritorio KDE Plasma configurado para xrdp"

echo ""
echo "   ⚙️  Optimizando rendimiento de xrdp (fluidez RDP)..."
XRDP_INI=/etc/xrdp/xrdp.ini

# 1) Quitar ajustes de rendimiento previos para reinsertarlos limpios
sed -i -E '/^(max_bpp|bitmap_cache|bitmap_compression|bulk_compression|tcp_nodelay|security_layer|crypt_level|xserverbpp)=/d' "$XRDP_INI"

# 2) Claves globales: menos datos por pixel + compresion + sin TLS extra
sed -i '/^\[Globals\]/r /dev/stdin' "$XRDP_INI" <<'XRDPCFG'
max_bpp=16
bitmap_cache=yes
bitmap_compression=yes
bulk_compression=yes
tcp_nodelay=yes
security_layer=rdp
crypt_level=low
XRDPCFG

# 3) Forzar profundidad de color baja en la sesion grafica
if grep -q '^\[Xorg\]' "$XRDP_INI"; then
  sed -i '/^\[Xorg\]/r /dev/stdin' "$XRDP_INI" <<'XRDPCFG'
xserverbpp=16
XRDPCFG
elif grep -q '^\[Xvnc\]' "$XRDP_INI"; then
  sed -i '/^\[Xvnc\]/r /dev/stdin' "$XRDP_INI" <<'XRDPCFG'
xserverbpp=16
XRDPCFG
fi

# 4) Desactivar la composicion de KWin (evita repintados completos de pantalla)
mkdir -p "/home/$USERNAME/.config"
cat > "/home/$USERNAME/.config/kwinrc" <<'EOF'
[Compositing]
Enabled=false
EOF
chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.config" 2>/dev/null || true
echo "   ✅ xrdp ajustado: 16bpp + compresion + composicion KWin OFF"

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
echo "   Chromium: omitido (no necesario para el RDP)"
echo ""
echo "📋 RESUMEN: Usuario=$USERNAME | Password=$PASSWORD | Puerto=3389"
