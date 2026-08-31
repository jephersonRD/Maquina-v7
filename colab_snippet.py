# ===== Maquina-v7 (Openbox + Selkies) =====
import os

# ====== CONFIGURACION ======
USERNAME   = "user"
PASSWORD   = "password"
RESOLUTION = "1920x1080"
PORT       = 8080
USE_TAILSCALE = False  # Cambiar a True para acceso remoto
TAILSCALE_AUTHKEY = "tskey-auth-kHmbnmbDji11CNTRL-ogppCQkj3CVv1NhZniZ2CVJ7SzBuhnQx"
# ===================================================

# Descargar repositorio si no existe
if not os.path.isdir('/content/Maquina-v7'):
    import subprocess
    print("📥 Descargando repositorio...")
    subprocess.run("curl -fsSL 'https://codeload.github.com/jephersonRD/Maquina-v7/tar.gz/refs/heads/main' -o /tmp/maquina-v7.tar.gz", shell=True, check=True)
    subprocess.run("tar xzf /tmp/maquina-v7.tar.gz -C /content", shell=True, check=True)
    subprocess.run("mv /content/Maquina-v7-main /content/Maquina-v7", shell=True, check=True)
    subprocess.run("rm -f /tmp/maquina-v7.tar.gz", shell=True, check=True)

os.chdir('/content/Maquina-v7/scripts')

print("="*50)
print("📦 Instalando Openbox + Selkies + Audio")
print("="*50)

# Instalar componentes
import subprocess

def run_script(script, desc):
    print(f"\n{desc}...")
    r = subprocess.run(f"bash {script}", shell=True)
    if r.returncode != 0:
        print(f"❌ Error en {script}")
        raise SystemExit(r.returncode)

run_script("setup_openbox.sh", "📦 Instalando Openbox")
run_script("setup_audio.sh", "🔊 Configurando audio")
run_script("setup_selkies.sh", "🌐 Instalando Selkies")

if USE_TAILSCALE:
    run_script(f"setup_tailscale.sh {TAILSCALE_AUTHKEY}", "🌐 Instalando Tailscale")
else:
    print("\n⏭️  Tailscale omitido (USE_TAILSCALE = False)")

# Iniciar escritorio
print("\n" + "="*50)
print("🚀 Iniciando escritorio")
print("="*50)

r = subprocess.run(f"bash start_desktop.sh {RESOLUTION} {USERNAME} {PASSWORD} {PORT}", shell=True)
if r.returncode != 0:
    print("❌ Error al iniciar escritorio")
    raise SystemExit(r.returncode)

print("\n" + "="*50)
print("✅ MAQUINA LISTA (Openbox + Selkies)")
print("="*50)
print(f"   Usuario    : {USERNAME}")
print(f"   Resolución : {RESOLUTION}")
print(f"   Puerto     : {PORT}")

if USE_TAILSCALE:
    import subprocess
    ts_ip = subprocess.getoutput("tailscale --socket=/var/run/tailscale/tailscaled.sock ip -4 2>/dev/null | head -n1").strip()
    if ts_ip:
        print(f"\n🌐 Abre en tu navegador (desde tu Android/misma tailnet):")
        print(f"   http://{ts_ip}:{PORT}")
    else:
        print(f"\n⚠️  Tailscale no conectó. URL local: http://localhost:{PORT}")
else:
    print(f"\n🌐 URL local (solo Colab): http://localhost:{PORT}")
print("="*50)
