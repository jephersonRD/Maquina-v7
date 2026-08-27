# ===== Maquina-v7 (Selkies / WebRTC en vez de XRDP) =====
# Cloud PC Linux (KDE Plasma + Selkies) accesible desde el navegador via Tailscale en Google Colab.
# Pega ESTE bloque completo en una celda de Colab y ejecutalo.
import subprocess, os

# ====== CONFIGURACION (edita solo TS_AUTHKEY) ======
TS_AUTHKEY = "PEG_AQUI_TU_TAILSCALE_AUTHKEY"   # <-- pega tu authkey de https://login.tailscale.com/admin/settings/keys
USERNAME   = "jeph"
PASSWORD   = "medina"
RESOLUTION = "1920x1080"
PORT       = "8080"
# ===================================================

if TS_AUTHKEY in ("", "PEG_AQUI_TU_TAILSCALE_AUTHKEY"):
    print("Debes pegar tu Tailscale authkey en la variable TS_AUTHKEY (arriba).")
    raise SystemExit(1)

repo_dir = "/content/Maquina-v7"
if not os.path.isdir(repo_dir):
    subprocess.run(f"git clone https://github.com/jephersonRD/Maquina-v7.git {repo_dir}", shell=True, check=True)
os.chdir(repo_dir + "/scripts")

print("Ejecutando instalador Selkies (puede tardar varios minutos)...\n")
r = subprocess.run(f"bash setup_selkies.sh {USERNAME} {PASSWORD} {RESOLUTION} {PORT}", shell=True)
if r.returncode != 0:
    print("\n❌❌ setup_selkies.sh termino con error."); raise SystemExit(r.returncode)

print("Conectando a Tailscale...")
r = subprocess.run(f'bash setup_tailscale.sh "{TS_AUTHKEY}"', shell=True)
if r.returncode != 0:
    print("\n❌❌ setup_tailscale.sh termino con error."); raise SystemExit(r.returncode)

ip = subprocess.run("tailscale ip -4 2>/dev/null | head -n1", shell=True, capture_output=True, text=True).stdout.strip()
print("\n========================================")
print("✅ MAQUINA LISTA (Selkies / WebRTC)")
print("🌐 URL navegador : https://%s:%s" % (ip, PORT))
print("👤 USUARIO       :", USERNAME)
print("🔑 CONTRASEÑA     :", PASSWORD)
print("========================================")
print("Abre esa URL en Chrome/Edge/Firefox. Si el certificado es autofirmado, continua.")
