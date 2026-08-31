# ===== Maquina-v7 (KDE Plasma + XRDP + Tailscale) =====
import subprocess, os

# ====== CONFIGURACION ======
USERNAME   = "jeph"
PASSWORD   = "medina"
RESOLUTION = "1920x1080"
# Tailscale: pega tu authkey de https://login.tailscale.com/admin/settings/keys
# (o déjalo en "" si prefieres escanear el QR manualmente)
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

print("Ejecutando instalador XRDP + KDE Plasma...\n")
r = subprocess.run(f"bash setup_xrdp.sh {USERNAME} {PASSWORD} {RESOLUTION}", shell=True)
if r.returncode != 0:
    print("\n❌❌ setup_xrdp.sh terminó con error."); raise SystemExit(r.returncode)

# Tailscale (para conectarte desde tu móvil/PC de forma segura)
ip = ""
if TS_AUTHKEY:
    print("\nConectando a Tailscale...")
    subprocess.run(f'bash setup_tailscale.sh "{TS_AUTHKEY}"', shell=True)
    ip = subprocess.run("tailscale ip -4 2>/dev/null | head -n1", shell=True, capture_output=True, text=True).stdout.strip()

print("\n========================================")
print("✅ MÁQUINA LISTA (KDE Plasma + XRDP)")
print("   Usuario      :", USERNAME)
print("   Contraseña   :", PASSWORD)
if ip:
    print("   🌐 IP Tailscale :", ip, "(conéctate por RDP a este IP:3389)")
else:
    print("   🌐 Tailscale    : esperando conexión...")
print("========================================")
print("\n📱 En tu móvil/PC:")
print("   1. Abre Microsoft Remote Desktop (o aRDP en Android)")
print("   2. Agrega PC: IP-de-Tailscale:3389")
print("   3. Usuario:", USERNAME, "| Contraseña:", PASSWORD)
print("========================================")
