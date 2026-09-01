# ===== Maquina-v7 (LXQt + Apache Guacamole) =====
import os

# ====== CONFIGURACION ======
USERNAME   = "user"
PASSWORD   = "password"
RESOLUTION = "1920x1080"
GUAC_PORT  = 8080
# ===================================================

# Descargar repositorio si no existe
if not os.path.isdir('/content/Maquina-v7'):
    import subprocess
    print("Descargando repositorio...")
    subprocess.run("curl -fsSL 'https://codeload.github.com/jephersonRD/Maquina-v7/tar.gz/refs/heads/main' -o /tmp/maquina-v7.tar.gz", shell=True, check=True)
    subprocess.run("tar xzf /tmp/maquina-v7.tar.gz -C /content", shell=True, check=True)
    subprocess.run("mv /content/Maquina-v7-main /content/Maquina-v7", shell=True, check=True)
    subprocess.run("rm -f /tmp/maquina-v7.tar.gz", shell=True, check=True)

os.chdir('/content/Maquina-v7/scripts')

print("=" * 50)
print("Instalando LXQt + Guacamole + Audio")
print("=" * 50)

import subprocess

def run_script(script, desc):
    print(f"\n{desc}...")
    r = subprocess.run(f"bash {script}", shell=True)
    if r.returncode != 0:
        print(f"Error en {script}")
        raise SystemExit(r.returncode)

run_script("setup_lxqt.sh", "Instalando LXQt")
run_script("setup_audio.sh", "Configurando audio")
run_script("setup_vnc.sh", "Instalando VNC")
run_script("setup_guacamole.sh", "Instalando Apache Guacamole")

# Iniciar escritorio
print("\n" + "=" * 50)
print("Iniciando escritorio")
print("=" * 50)

r = subprocess.run(f"bash start_desktop.sh {RESOLUTION} {USERNAME} {PASSWORD} {GUAC_PORT}", shell=True)
if r.returncode != 0:
    print("Error al iniciar escritorio")
    raise SystemExit(r.returncode)

# Detectar URL publica
import re
public_url = ""
try:
    with open("/tmp/cloudflared.log") as f:
        for line in f:
            m = re.search(r'https://[a-zA-Z0-9._-]+\.trycloudflare\.com', line)
            if m:
                public_url = m.group(0)
                break
except FileNotFoundError:
    pass

print("\n" + "=" * 50)
print("MAQUINA LISTA (LXQt + Apache Guacamole)")
print("=" * 50)
print(f"   Usuario    : {USERNAME}")
print(f"   Resolucion : {RESOLUTION}")
print(f"   Puerto     : {GUAC_PORT}")
if public_url:
    print(f"\nURL PUBLICA (desde cualquier dispositivo):")
    print(f"   {public_url}")
print(f"\nURL local (solo Colab): http://localhost:{GUAC_PORT}")
print("=" * 50)
