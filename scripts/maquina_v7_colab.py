# ===== Maquina-v7 (autocontenido: NO descarga nada de internet salvo paquetes) =====
# Instala Xfce + xrdp + Tailscale en la sesion de Google Colab y muestra la IP
# para conectarte por RDP (Microsoft Remote Desktop) desde Android / PC.
# Pega este bloque completo en una celda de Colab y ejecutalo.
import os
import time
import base64
import struct
import subprocess
import threading


def _wav_b64():
    sr, dur = 8000, 1
    data = bytes(sr * dur * 2)
    h = (b'RIFF' + struct.pack('<I', 36 + len(data)) + b'WAVE'
         + b'fmt ' + struct.pack('<IHHIIHH', 16, 1, 1, sr, sr * 2, 2, 16)
         + b'data' + struct.pack('<I', len(data)))
    return base64.b64encode(h + data).decode()


# ---- keep-alive (mantiene la sesion viva) ----
try:
    from IPython.display import display, HTML, Javascript
    display(HTML(
        '<b>🔊 Mantén esta pestaña ABIERTA y el audio en reproducción.</b><br/>'
        f'<audio autoplay src="data:audio/wav;base64,{_wav_b64()}" loop controls></audio>'))
    display(Javascript(
        "setInterval(function(){try{"
        "window.dispatchEvent(new Event('mousemove'));"
        "window.dispatchEvent(new Event('mousedown'));"
        "}catch(e){}}, 20000);"))
except Exception:
    pass


def _hb():
    while True:
        time.sleep(60)
        subprocess.run("curl -s -o /dev/null -m5 https://www.google.com",
                       shell=True, check=False)
        print("♥ keep-alive", time.strftime('%H:%M:%S'))


threading.Thread(target=_hb, daemon=True).start()

# ---- datos del usuario ----
USERNAME = input("👤 Usuario del escritorio RDP [v7user]: ") or "v7user"
PASSWORD = input("🔑 Contraseña [v7pass]: ") or "v7pass"
TS_KEY = input("🌐 Tailscale authkey (Enter = omitir Tailscale): ")

# ---- script bash embebido (se ejecuta en la misma maquina) ----
bash_script = r'''
echo "📦 Actualizando listas de apt..."
apt-get update -y

echo "🖥️ Instalando escritorio Xfce4 + xrdp (2-5 min)..."
apt-get install -y xfce4 xfce4-goodies xrdp xorgxrdp \
    tigervnc-standalone-server dbus-x11 x11-utils chromium-browser chromium
if ! command -v chromium-browser >/dev/null 2>&1 && ! command -v chromium >/dev/null 2>&1; then
  echo "   ↳ Chromium no disponible por defecto, usando PPA..."
  add-apt-repository -y ppa:savoury1/chromium
  apt-get update -y
  apt-get install -y chromium
fi

echo "👤 Creando usuario __USER__..."
id "__USER__" >/dev/null 2>&1 || useradd -m -s /bin/bash "__USER__"
echo "__USER__:__PASS__" | chpasswd
usermod -aG sudo "__USER__" 2>/dev/null
echo "xfce4-session" > /home/__USER__/.xsession
chown __USER__:__USER__ /home/__USER__/.xsession 2>/dev/null || true
printf '#!/bin/sh\nxfce4-session\n' > /etc/xrdp/startwm.sh
chmod +x /etc/xrdp/startwm.sh

echo "🚀 Iniciando servidor RDP (puerto 3389)..."
pkill -x xrdp 2>/dev/null; sleep 1
service xrdp restart 2>/dev/null \
  || (nohup xrdp-sesman -n >/tmp/sesman.log 2>&1 & nohup xrdp -n >/tmp/xrdp.log 2>&1 &)
sleep 3
if (ss -ltn 2>/dev/null | grep -q ':3389') || (netstat -ltn 2>/dev/null | grep -q ':3389'); then
  echo "✅ RDP escuchando en puerto 3389"
else
  echo "⚠️ 3389 NO escucha. Revisa: tail /tmp/xrdp.log"
fi

if [ -n "__TS__" ]; then
  echo "🌐 Instalando Tailscale..."
  curl -fsSL https://tailscale.com/install.sh | sh
  mkdir -p /var/run/tailscale
  pkill -x tailscaled 2>/dev/null; sleep 1
  tailscaled --tun=userspace-networking --state=/var/lib/tailscale/state \
    --socket=/var/run/tailscale/tailscaled.sock >/tmp/ts.log 2>&1 &
  sleep 5
  tailscale --socket=/var/run/tailscale/tailscaled.sock up \
    --authkey="__TS__" --hostname=maquina-v7 --accept-routes --netfilter-mode=off
  sleep 3
  IP=$(tailscale --socket=/var/run/tailscale/tailscaled.sock ip -4 2>/dev/null | head -n1)
  echo "📱 IP Tailscale: $IP   |   puerto 3389   |   usuario: __USER__"
  echo "(Ve https://login.tailscale.com -> Devices y APROBA 'maquina-v7' si aparece pendiente)"
else
  echo "ℹ️ Sin Tailscale. IP local de la sesion: $(hostname -I)"
fi

echo "✅ Maquina-v7 lista. Conectate por RDP con la IP de arriba."
'''
bash_script = (bash_script
               .replace("__USER__", USERNAME)
               .replace("__PASS__", PASSWORD)
               .replace("__TS__", TS_KEY))

print("\nEjecutando instalador... (tarda unos minutos)\n")
subprocess.run(bash_script, shell=True, executable="/bin/bash")
