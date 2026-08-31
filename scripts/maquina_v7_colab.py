# ===== Maquina-v7 (Sunshine + Moonlight en vez de Selkies/XRDP) =====
# Cloud PC Linux (KDE Plasma + Sunshine) que codifica con NVENC en la GPU T4 y se
# reproduce en Moonlight (app nativa de Android). La Web UI se expone por cloudflared
# (HTTPS) para leer el PIN; el stream UDP de Moonlight va por Tailscale.
# Pega ESTE bloque completo en una celda de Colab y ejecutalo.
import subprocess, os

# ====== CONFIGURACION ======
USERNAME   = "jeph"
PASSWORD   = "medina"
RESOLUTION = "1920x1080"
WEB_PORT   = "47989"
# Tailscale es el transporte UDP que necesita Moonlight (cloudflared solo expone la Web UI).
# Pega tu authkey de https://login.tailscale.com/admin/settings/keys (o deja vacio si usas otra VPN/UDP).
TS_AUTHKEY = ""
# ===================================================

repo_dir = "/content/Maquina-v7"
if not os.path.isdir(repo_dir):
    import tarfile, urllib.request
    tar_url = "https://codeload.github.com/jephersonRD/Maquina-v7/tar.gz/refs/heads/main"
    urllib.request.urlretrieve(tar_url, "/tmp/maquina-v7.tar.gz")
    with tarfile.open("/tmp/maquina-v7.tar.gz") as t:
        t.extractall("/content")
    os.rename("/content/Maquina-v7-main", repo_dir)
    os.remove("/tmp/maquina-v7.tar.gz")
os.chdir(repo_dir + "/scripts")

print("Ejecutando instalador Sunshine (puede tardar varios minutos)...\n")
r = subprocess.run(f"bash setup_sunshine.sh {USERNAME} {PASSWORD} {RESOLUTION} {WEB_PORT}", shell=True)
if r.returncode != 0:
    print("\n❌❌ setup_sunshine.sh termino con error."); raise SystemExit(r.returncode)

ip = ""
if TS_AUTHKEY:
    print("Conectando a Tailscale (transporte UDP para Moonlight)...")
    r = subprocess.run(f'bash setup_tailscale.sh "{TS_AUTHKEY}"', shell=True)
    if r.returncode == 0:
        ip = subprocess.run("tailscale ip -4 2>/dev/null | head -n1", shell=True, capture_output=True, text=True).stdout.strip()

import re, time
url = ""
for _ in range(45):
    log = subprocess.run("tail -n 200 /tmp/cloudflared.log 2>/dev/null", shell=True, capture_output=True, text=True).stdout
    m = re.search(r'https://[a-zA-Z0-9._-]+\.trycloudflare\.com', log)
    if m:
        url = m.group(0); break
    time.sleep(1)

print("\n========================================")
print("✅ MAQUINA LISTA (Sunshine + Moonlight / NVENC)")
if url:
    print("🌐 WEB UI (PIN)  :", url)
    print("   Usuario       :", USERNAME, " | Contraseña:", PASSWORD)
if ip:
    print("🎮 Moonlight IP :", ip, "(agrega esta IP en Moonlight y empareja con el PIN)")
else:
    print("🎮 Moonlight     : usa la IP de Tailscale (o tu VPN UDP) de esta maquina.")
print("========================================")
print("Abre la WEB UI en el navegador, ve a 'PIN', y empareja Moonlight con ese codigo.")
