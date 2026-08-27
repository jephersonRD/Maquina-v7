<div align="center">

![Logo](assets/logo.svg)

# Maquina-v7

### ☁️ Cloud PC GNU/Linux con xrdp en Google Colab — controla tu escritorio remoto desde Android con RDP vía Tailscale

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/jephersonRD/Maquina-v7/blob/main/Maquina-v7.ipynb)
[![GitHub Stars](https://img.shields.io/github/stars/jephersonRD/Maquina-v7?style=social)](https://github.com/jephersonRD/Maquina-v7/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/jephersonRD/Maquina-v7?style=social)](https://github.com/jephersonRD/Maquina-v7/network/members)
[![License](https://img.shields.io/github/license/jephersonRD/Maquina-v7)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/jephersonRD/Maquina-v7)](https://github.com/jephersonRD/Maquina-v7/commits/main)

![Plataform](https://img.shields.io/badge/platform-Google%20Colab-blue)
![RDP](https://img.shields.io/badge/access-RDP%20%2F%20xrdp-green)
![Android](https://img.shields.io/badge/client-Android%20Ready-purple)
![Tailscale](https://img.shields.io/badge/network-Tailscale-0brand)

</div>

---

## 📖 Descripción

**Maquina-v7** convierte una sesión de **Google Colab** en un **escritorio remoto GNU/Linux**
(Xfce + `xrdp`) al que te conectas con el cliente **Microsoft Remote Desktop** desde
**Android**, Windows o macOS. La conexión se hace por **Tailscale**, una VPN privada de malla,
sin abrir el puerto 3389 a Internet.

## ▶️ Código para Colab (copiar y pegar)

Pega **este único bloque** en una celda de Google Colab y ejecútalo. **No descarga nada
externo** salvo paquetes apt y Tailscale. Antes de ejecutar, pega tu **authkey** de Tailscale
en la variable `TS_AUTHKEY` (línea marcada). Al final muestra un bloque con la **IP, usuario y
contraseña** listos para el RDP.

```python
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
# Chromium se omite a proposito para no bloquear la instalacion de xrdp.

echo "👤 [3/9] Creando usuario __USER__..."
id "__USER__" >/dev/null 2>&1 || useradd -m -s /bin/bash "__USER__" || die "no se pudo crear el usuario"
echo "__USER__:__PASS__" | chpasswd || die "no se pudo fijar la contrasena"
usermod -aG sudo,ssl-cert,xrdp "__USER__" 2>/dev/null
echo "xfce4-session" > /home/__USER__/.xsession
chown __USER__:__USER__ /home/__USER__/.xsession 2>/dev/null || true
printf '#!/bin/sh\nxfce4-session\n' > /etc/xrdp/startwm.sh
chmod +x /etc/xrdp/startwm.sh

# Desactivar el compositor de Xfce (evita repintados completos de pantalla)
mkdir -p /home/__USER__/.config/xfce4/xfconf/xfce-perchannel-xml
cat > /home/__USER__/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="use_compositing" type="bool" value="false"/>
  </property>
</channel>
EOF
chown -R __USER__:__USER__ /home/__USER__/.config 2>/dev/null || true

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

# Rendimiento: menos datos por pixel + compresion (evita el "pintado" lento)
sed -i -E '/^(max_bpp|bitmap_cache|bitmap_compression|bulk_compression|tcp_nodelay|xserverbpp)=/d' /etc/xrdp/xrdp.ini
sed -i '/^\[Globals\]/a max_bpp=16\nbitmap_cache=yes\nbitmap_compression=yes\nbulk_compression=yes\ntcp_nodelay=yes' /etc/xrdp/xrdp.ini
sed -i '/^\[Xorg\]/a xserverbpp=16' /etc/xrdp/xrdp.ini 2>/dev/null || sed -i '/^\[Xvnc\]/a xserverbpp=16' /etc/xrdp/xrdp.ini 2>/dev/null || true

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
```

> 💡 El script **no termina con `returncode=0` si algo falló**: cada paso crítico usa
> `die()` que muestra `/tmp/xrdp.log`, `/tmp/sesman.log` y `/tmp/ts.log` y sale con error.
> Al final imprime el bloque `✅ MAQUINA RDP LISTA` con la IP, usuario y contraseña.

### 📱 Conectarte desde Android (Microsoft Remote Desktop)

1. Instala **Tailscale** en el MÓVIL y entra con la **misma cuenta** que generó la authkey
   (el móvil debe estar en el mismo tailnet para poder路由 a `100.x.x.x`).
2. En la app *Microsoft Remote Desktop* → **Agregar escritorio**:
   - **PC**: la IP `100.x.x.x` (la que muestra el script, sin puerto ni `:3389`).
   - **Nombre de usuario**: `jeph` (sin dominio).
   - **Contraseña**: `medina`.
   - **Puerta de enlace**: *ninguna* (dejar vacío).
3. Si en la consola de Tailscale el dispositivo `maquina-v7` aparece **pendiente**,
   púlsalo y **Aprueba**.

### ⚠️ No cierres la pestaña
Colab mata la sesión si cierras la pestaña. Mantenla abierta (puedes minimizarla).

## ✨ Características

- 🖥️ **Escritorio Xfce4** completo con `xrdp` (protocolo RDP estándar).
- 📱 **Cliente Android**: app oficial *Microsoft Remote Desktop*.
- 🔐 **Tailscale**: red privada segura, el puerto 3389 NO se expone a Internet.
- 🔒 **Keep-alive**: evita el cierre por inactividad de Colab.
- 📦 **100% open-source**: scripts propios, sin binarios cerrados.

## 🏗️ Arquitectura

```
 Tu Android / PC (con Tailscale en la misma cuenta)
       │  RDP (3389) sobre la VPN Tailscale
       ▼
  ┌──────────────────────────────────┐
  │  Google Colab (contenedor Linux) │
  │   ├─ Xfce4 desktop               │
  │   ├─ xrdp  (servidor RDP:3389)   │
  │   └─ Tailscale (VPN mesh)        │
  └──────────────────────────────────┘
```

## ⚠️ Recomendaciones

- Revisa el tiempo restante de uso de Colab (se reinicia cada ~24 h).
- Mantén la pestaña visible/activa.
- El gaming solo funciona si Colab asigna GPU.

## 🐛 Solución de problemas

| Síntoma | Solución |
|---------|----------|
| `0x300005e` en Android | El cliente intenta usar una *Puerta de enlace*. Quítala; además el móvil debe tener Tailscale con la misma cuenta. |
| `login failed` | El script ya corrige PAM/sesman; asegura usuario `jeph` / contraseña `medina` exactos. |
| Tailscale no conecta | Confirma la authkey y **aprueba** `maquina-v7` en login.tailscale.com → Devices. |
| 3389 no escucha | Revisa `tail -n 40 /tmp/xrdp.log` y `tail -n 40 /tmp/sesman.log`. |

## 📜 Licencia

MIT. Ver [`LICENSE`](LICENSE).

---

<div align="center">
Hecho con ❤️ para la comunidad de cloud gaming y escritorios remotos · Maquina-v7
</div>
