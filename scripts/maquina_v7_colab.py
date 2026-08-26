# ===== Maquina-v7 (autocontenido: NO descarga nada externo salvo paquetes) =====
# Cloud PC Linux (XFCE + xrdp) accesible por RDP via Tailscale en Google Colab.
# Pega ESTE bloque completo en una celda de Colab y ejecutalo.
import subprocess

# ====== CONFIGURACION (edita solo TS_AUTHKEY) ======
TS_AUTHKEY = "PEG_AQUI_TU_TAILSCALE_AUTHKEY"   # <-- pega tu authkey de https://login.tailscale.com/admin/settings/keys
USERNAME   = "jeph"
PASSWORD   = "medina"
# ===================================================

if TS_AUTHKEY in ("", "PEG_AQUI_TU_TAILSCALE_AUTHKEY"):
    print("❌ Debes pegar tu Tailscale authkey en la variable TS_AUTHKEY (arriba).")
    raise SystemExit(1)

bash_script = r'''
set -uo pipefail

die() {
  echo ""
  echo "❌❌ ERROR: $1"
  echo "──────── /tmp/xrdp.log ────────"
  tail -n 30 /tmp/xrdp.log 2>/dev/null || echo "(sin log)"
  echo "──────── /tmp/sesman.log ────────"
  tail -n 30 /tmp/sesman.log 2>/dev/null || echo "(sin log)"
  echo "──────── /tmp/ts.log ────────"
  tail -n 30 /tmp/ts.log 2>/dev/null || echo "(sin log)"
  exit 1
}

echo "📦 [1/9] Actualizando apt..."
apt-get update -y || die "apt-get update fallo"

echo "🖥️ [2/9] Instalando XFCE4 + xrdp..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  xfce4 xfce4-goodies xrdp xorgxrdp tigervnc-standalone-server \
  dbus-x11 x11-utils || die "fallo al instalar xfce4/xrdp"
# Chromium es opcional (no bloquea el RDP)
DEBIAN_FRONTEND=noninteractive apt-get install -y chromium-browser chromium 2>/dev/null \
  || { add-apt-repository -y ppa:savoury1/chromium 2>/dev/null && apt-get update -y && apt-get install -y chromium 2>/dev/null; } \
  || echo "   ⚠️ Chromium no se pudo instalar (no afecta al RDP)"

echo "👤 [3/9] Creando usuario __USER__..."
id "__USER__" >/dev/null 2>&1 || useradd -m -s /bin/bash "__USER__" || die "no se pudo crear el usuario"
echo "__USER__:__PASS__" | chpasswd || die "no se pudo fijar la contrasena"
usermod -aG sudo,ssl-cert,xrdp "__USER__" 2>/dev/null
echo "xfce4-session" > /home/__USER__/.xsession
chown __USER__:__USER__ /home/__USER__/.xsession 2>/dev/null || true
printf '#!/bin/sh\nxfce4-session\n' > /etc/xrdp/startwm.sh
chmod +x /etc/xrdp/startwm.sh

echo "🔧 [4/9] Configurando xrdp (PAM / sesman)..."
cat > /etc/pam.d/xrdp-sesman <<'EOF'
auth     include     common-auth
account  include     common-account
password include     common-password
session  include     common-session-noninteractive
EOF
sed -i 's/^TerminalServerUsers=.*/TerminalServerUsers=/' /etc/xrdp/sesman.ini
sed -i 's/^TerminalServerAdmins=.*/TerminalServerAdmins=/' /etc/xrdp/sesman.ini
grep -q '^AllowedUsers' /etc/xrdp/sesman.ini || echo 'AllowedUsers=*' >> /etc/xrdp/sesman.ini
sed -i 's/^security_layer=.*/security_layer=rdp/' /etc/xrdp/xrdp.ini
sed -i 's/^crypt_level=.*/crypt_level=low/' /etc/xrdp/xrdp.ini

echo "🚀 [5/9] Iniciando xrdp-sesman y xrdp..."
pkill -x xrdp-sesman 2>/dev/null; pkill -x xrdp 2>/dev/null; sleep 2
nohup xrdp-sesman -n >/tmp/sesman.log 2>&1 &
sleep 1
nohup xrdp -n >/tmp/xrdp.log 2>&1 &
sleep 3

echo "🔎 [6/9] Comprobando que 0.0.0.0:3389 escucha..."
if ss -ltnp 2>/dev/null | grep -q ':3389'; then
  echo "   ✅ 3389 escuchando en:"; ss -ltnp 2>/dev/null | grep ':3389'
else
  die "xrdp NO esta escuchando en 3389"
fi

echo "🌐 [7/9] Instalando Tailscale..."
curl -fsSL https://tailscale.com/install.sh | sh || die "no se pudo instalar Tailscale"
mkdir -p /var/run/tailscale
pkill -x tailscaled 2>/dev/null; sleep 1
tailscaled --tun=userspace-networking --state=/var/lib/tailscale/state \
  --socket=/var/run/tailscale/tailscaled.sock >/tmp/ts.log 2>&1 &
sleep 8

echo "🔑 Conectando Tailscale con la authkey..."
tailscale --socket=/var/run/tailscale/tailscaled.sock up \
  --authkey="__TS__" --hostname=maquina-v7 --accept-routes --netfilter-mode=off \
  || die "tailscale up fallo (authkey invalida o rechazada)"

echo "🌍 Obteniendo IP IPv4 de Tailscale (tailscale ip -4)..."
TS_IP=$(tailscale --socket=/var/run/tailscale/tailscaled.sock ip -4 2>/dev/null | head -n1)
if [ -z "$TS_IP" ]; then
  echo "⚠️ Tailscale no devolvio IP. Estado actual:"
  tailscale --socket=/var/run/tailscale/tailscaled.sock status 2>&1 | head -n 20
  die "No se obtuvo IP de Tailscale (¿authkey invalida o dispositivo pendiente de aprobacion en la consola?)"
fi
echo "   IP Tailscale: $TS_IP"

echo "🔎 Verificando que 'maquina-v7' esta conectado a Tailscale..."
if tailscale --socket=/var/run/tailscale/tailscaled.sock status 2>/dev/null | grep -qi "maquina-v7"; then
  echo "   ✅ dispositivo maquina-v7 presente en el tailnet"
else
  echo "⚠️ El dispositivo 'maquina-v7' NO aparece conectado. Estado:"
  tailscale --socket=/var/run/tailscale/tailscaled.sock status 2>&1 | head -n 20
  die "El dispositivo no aparece conectado a Tailscale"
fi

echo "🔎 [8/9] Probando conectividad local al puerto 3389..."
if (exec 3<>/dev/tcp/127.0.0.1/3389) 2>/dev/null; then
  echo "   ✅ puerto 3389 accesible localmente"
  exec 3>&- 2>/dev/null
else
  die "no se puede conectar localmente a 3389 (el servidor RDP no responde)"
fi

echo "🔎 [9/9] Comprobando aprobacion en Tailscale (si aplica)..."
if tailscale --socket=/var/run/tailscale/tailscaled.sock status 2>/dev/null | grep -qi "maquina-v7.*pending\|maquina-v7.*needs"; then
  echo "⚠️ El dispositivo 'maquina-v7' esta PENDIENTE de aprobacion."
  echo "   Ve a https://login.tailscale.com -> Devices y APROBA 'maquina-v7'."
else
  echo "   ✅ dispositivo no pendiente de aprobacion"
fi

echo ""
echo "========================================"
echo "✅ MAQUINA RDP LISTA"
echo ""
echo "🌐 IP TAILSCALE: $TS_IP"
echo "🔌 PUERTO RDP: 3389"
echo "👤 USUARIO: __USER__"
echo "🔑 CONTRASEÑA: __PASS__"
echo "🖥️ SERVIDOR: $TS_IP:3389"
echo "========================================"
echo "Conectate desde Microsoft Remote Desktop (Android/Windows) usando SERVIDOR = $TS_IP:3389"
echo "NO configures ninguna 'Puerta de enlace' (Gateway) en el cliente."
'''

bash_script = (bash_script
               .replace("__USER__", USERNAME)
               .replace("__PASS__", PASSWORD)
               .replace("__TS__", TS_AUTHKEY))

print("Ejecutando instalador de Maquina-v7... (tarda unos minutos)\n")
r = subprocess.run(bash_script, shell=True, executable="/bin/bash")
if r.returncode != 0:
    print("\n❌❌ EL SCRIPT TERMINO CON ERROR (returncode=%d). Revisa los mensajes y los logs de arriba." % r.returncode)
    raise SystemExit(r.returncode)
print("\n✅ Script completado sin errores.")
