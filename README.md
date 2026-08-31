<div align="center">

![Logo](assets/logo.svg)

# Maquina-v7

### ☁️ Cloud PC GNU/Linux con KDE Plasma + XRDP + Tailscale en Google Colab

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/jephersonRD/Maquina-v7/blob/main/Maquina-v7.ipynb)
[![GitHub Stars](https://img.shields.io/github/stars/jephersonRD/Maquina-v7?style=social)](https://github.com/jephersonRD/Maquina-v7/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/jephersonRD/Maquina-v7?style=social)](https://github.com/jephersonRD/Maquina-v7/network/members)
[![License](https://img.shields.io/github/license/jephersonRD/Maquina-v7)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/jephersonRD/Maquina-v7)](https://github.com/jephersonRD/Maquina-v7/commits/main)

![Platform](https://img.shields.io/badge/platform-Google%20Colab-blue)
![Desktop](https://img.shields.io/badge/desktop-KDE%20Plasma-blue)
![Protocol](https://img.shields.io/badge/protocol-XRDP%20(RDP)-green)
![Network](https://img.shields.io/badge/transport-Tailscale%20(TCP)-0brand)

</div>

---

## 📖 Descripción

**Maquina-v7** convierte una sesión de **Google Colab** en un **escritorio remoto GNU/Linux**
con **KDE Plasma** y **XRDP** (protocolo RDP nativo). Conéctate de forma segura desde
cualquier dispositivo usando **Tailscale**.

### ¿Por qué XRDP en vez de Sunshine/Moonlight?
- **Sin GPU necesaria**: XRDP funciona perfectamente en CPU, sin necesidad de NVENC.
- **Cualquier cliente RDP**: Microsoft Remote Desktop, aRDP, Remmina, xfreerdp.
- **Más simple**: sin PIN de emparejamiento, solo usuario/contraseña.
- **Transporte TCP**: más estable para escritorio/productividad que UDP.
- **Sin cloudflared**: no necesitas exponer una Web UI.

## ▶️ Código para Colab (copiar y pegar)

Pega **este único bloque** en una celda de Google Colab y ejecútalo. Descarga el proyecto
como tarball desde GitHub (sin `git` ni credenciales). Al final muestra la **IP para conectar por RDP**.

```python
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
```

### 📱 Conectarte desde tu dispositivo

| Plataforma | App recomendada | Pasos |
|---|---|---|
| **Android** | **Microsoft Remote Desktop** (oficial, gratis) o **aRDP** | Agrega PC → IP de Tailscale → Puerto 3389 → Usuario/Contraseña |
| **Windows** | **Conexión a Escritorio Remoto** (mstsc.exe) | Ejecuta `mstsc` → IP de Tailscale → Conectar |
| **Linux** | **Remmina** o **xfreerdp** | `xfreerdp /v:IP_TAILSCALE:3389 /u:jeph /p:medina` |

### ⚠️ No cierres la pestaña
Colab mata la sesión si cierras la pestaña. Mantenla abierta (puedes minimizarla).

## ✨ Características

- 🖥️ **Escritorio KDE Plasma** completo con **XRDP** (protocolo RDP nativo).
- 📱 **Cualquier cliente RDP**: Microsoft Remote Desktop, aRDP, Remmina, xfreerdp.
- 🔐 **Tailscale**: conexión TCP segura para RDP (sin abrir puertos).
- 🔒 **Keep-alive**: evita el cierre por inactividad de Colab.
- 📦 **100% open-source**: scripts propios, sin binarios cerrados.
- 💻 **Sin GPU necesaria**: funciona perfectamente en CPU.

## 🏗️ Arquitectura

```
 Tu dispositivo (cualquier cliente RDP)  ←─ TCP (Tailscale) ──┐
        │  RDP protocol (puerto 3389)                         │
        │                                                     ▼
   ┌─────────────────────────────────────────────────────────────┐
   │  Google Colab (contenedor Linux)                             │
   │   ├─ KDE Plasma desktop (XRDP)                               │
   │   ├─ XRDP server (puerto 3389, protocolo RDP nativo)        │
   │   └─ Tailscale (conexión segura TCP)                         │
   └─────────────────────────────────────────────────────────────┘
```

## ⚙️ Diferencias con versiones anteriores

| Aspecto | Sunshine + Moonlight | XRDP + RDP |
|---|---|---|
| **Latencia** | ~10-15 ms (gaming) | ~30-100 ms (escritorio/productividad) |
| **GPU / NVENC** | Requerido para streaming | No necesario |
| **Cliente** | Moonlight app nativa | Cualquier cliente RDP |
| **Audio** | UDP streaming | Redirigido por túnel RDP |
| **Gamepad** | Nativo en Moonlight | No nativo (usa apps de mapeo) |
| **PIN de emparejamiento** | Sí (Web UI) | No (solo usuario/contraseña) |
| **cloudflared** | Necesario para Web UI | No necesario |

## 🐛 Solución de problemas

| Síntoma | Solución |
|---------|----------|
| No conecta por RDP | Verifica que el puerto 3389 escucha: `ss -ltn \| grep 3389` |
| Tailscale no conecta | Confirma la authkey y **aprueba** `maquina-v7` en login.tailscale.com → Devices |
| Escritorio no carga | Verifica la sesión: `cat /home/$USER/.xsession` debe decir `startplasma-x11` |
| XRDP no arranca | Reinicia servicios: `service xrdp-sesman start; service xrdp start` |
| Sin GPU funciona | XRDP no necesita GPU, funciona 100% en CPU |

## 📜 Licencia

MIT. Ver [`LICENSE`](LICENSE).

---

<div align="center">
Hecho con ❤️ para la comunidad de escritorios remotos · Maquina-v7
</div>
