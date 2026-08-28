<div align="center">

![Logo](assets/logo.svg)

# Maquina-v7

### ☁️ Cloud PC GNU/Linux con Sunshine (NVENC) + Moonlight en Google Colab — juega en Android con latencia ~10-15 ms

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/jephersonRD/Maquina-v7/blob/main/Maquina-v7.ipynb)
[![GitHub Stars](https://img.shields.io/github/stars/jephersonRD/Maquina-v7?style=social)](https://github.com/jephersonRD/Maquina-v7/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/jephersonRD/Maquina-v7?style=social)](https://github.com/jephersonRD/Maquina-v7/network/members)
[![License](https://img.shields.io/github/license/jephersonRD/Maquina-v7)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/jephersonRD/Maquina-v7)](https://github.com/jephersonRD/Maquina-v7/commits/main)

![Plataform](https://img.shields.io/badge/platform-Google%20Colab-blue)
![Streaming](https://img.shields.io/badge/engine-Sunshine%20%2F%20NVENC-blue)
![Client](https://img.shields.io/badge/client-Moonlight%20Android-purple)
![Network](https://img.shields.io/badge/transport-Tailscale%20(UDP)-0brand)

</div>

---

## 📖 Descripción

**Maquina-v7** convierte una sesión de **Google Colab** en un **escritorio remoto GNU/Linux**
(KDE Plasma + `Sunshine`) que codifica el vídeo con **NVENC en la GPU T4** y se reproduce en
**Moonlight** (app nativa de Android). La **Web UI** de Sunshine se expone vía un **túnel público
de cloudflared** (HTTPS) para leer el PIN de emparejamiento; el **stream real de Moonlight** viaja
por **UDP** (Tailscale, ya que cloudflared solo tuneliza HTTP/TCP).

### ¿Por qué Sunshine + Moonlight y no Selkies/XRDP?
- **NVENC en la T4**: codificación por hardware, casi **0% de CPU**.
- **Latencia de ~10-15 ms** (vs. decenas de ms del WebRTC por navegador).
- **App nativa de Android** (Moonlight) muy pulida, con gamepad y 1080p/60fps.
- Estándar de facto para cloud gaming casero.

## ▶️ Código para Colab (copiar y pegar)

Pega **este único bloque** en una celda de Google Colab y ejecútalo. Descarga el proyecto
como tarball desde GitHub (sin `git` ni credenciales). Al final muestra la **URL de la Web UI**
y la **IP para Moonlight**.

```python
# ===== Maquina-v7 (Sunshine + Moonlight en vez de Selkies/XRDP) =====
import subprocess, os

# ====== CONFIGURACION ======
USERNAME   = "jeph"
PASSWORD   = "medina"
RESOLUTION = "1920x1080"
WEB_PORT   = "47989"
# Tailscale = transporte UDP que necesita Moonlight. Pega tu authkey de
# https://login.tailscale.com/admin/settings/keys (o deja "" si usas otra VPN UDP).
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
    subprocess.run(f'bash setup_tailscale.sh "{TS_AUTHKEY}"', shell=True)
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
    print("🎮 Moonlight IP :", ip, "(agrega en Moonlight y empareja con el PIN)")
else:
    print("🎮 Moonlight     : usa la IP de Tailscale (o tu VPN UDP) de esta maquina.")
print("========================================")
print("Abre la WEB UI en el navegador, ve a 'PIN', y empareja Moonlight con ese codigo.")
```

### 📱 Conectarte desde Moonlight (Android)

1. Ejecuta la celda de instalación: al terminar muestra la **URL de la Web UI** (cloudflared).
2. Abre esa URL en el navegador de tu móvil/PC e inicia sesión con **usuario** y **contraseña**.
3. En la Web UI de Sunshine ve a **PIN** y anota el código que aparece.
4. Instala **Moonlight** en Android y agrega la **IP de Tailscale** de esta máquina.
5. Moonlight pedirá el PIN: introduce el de la Web UI. ¡Listo para jugar!

> 💡 ¿Sin Tailscale? Moonlight necesita **UDP** para transmitir. cloudflared solo expone la
> Web UI (HTTP). Usa Tailscale (opción recomendada) o cualquier VPN/túnel que transporte UDP.

### ⚠️ No cierres la pestaña
Colab mata la sesión si cierras la pestaña. Mantenla abierta (puedes minimizarla).

## ✨ Características

- 🖥️ **Escritorio KDE Plasma** completo con `Sunshine` (codificación **NVENC** en la T4).
- 📱 **Cliente**: **Moonlight** en Android / PC (app nativa, gamepad, 1080p/60fps).
- 🔐 **Tailscale**: transporte UDP seguro para el stream (cloudflared solo para la Web UI).
- 🔒 **Keep-alive**: evita el cierre por inactividad de Colab.
- 📦 **100% open-source**: scripts propios, sin binarios cerrados.

## 🏗️ Arquitectura

```
 Tu Android (Moonlight)  ←─ UDP (Tailscale) ──┐
        │  Stream NVENC (bajo latency)        │
        │                                     ▼
   ┌─────────────────────────────────────────────────────┐
   │  Google Colab (contenedor Linux)                     │
   │   ├─ KDE Plasma desktop (Xvfb :0)                    │
   │   ├─ Sunshine (servidor, capture=x11, encoder=nvenc) │
   │   └─ cloudflared → Web UI HTTPS (PIN)                │
   └─────────────────────────────────────────────────────┘
```

## ⚠️ Recomendaciones

- Revisa el tiempo restante de uso de Colab (se reinicia cada ~24 h).
- Mantén la pestaña visible/activa.
- El gaming solo funciona si Colab asigna GPU (NVENC).
- En Xvfb usamos captura `x11` + codificación `nvenc` (nvfbc no funciona con Xvfb, que es
  software). La carga de CPU de captura es mínima; toda la codificación va en la T4.

## 🐛 Solución de problemas

| Síntoma | Solución |
|---------|----------|
| Moonlight no encuentra la máquina | Usa la **IP de Tailscale** (UDP). cloudflared no lleva el stream. |
| Web UI no abre | Verifica la URL `https://<random>.trycloudflare.com` y que el puerto 47989 escucha (`ss -ltn \| grep 47989`). |
| Sin GPU / NVENC | Sunshine cae a `libx264` (CPU). Revisa `nvidia-smi`. |
| 47989 no escucha | Revisa `tail -n 40 /tmp/sunshine.log`. |
| Tailscale no conecta | Confirma la authkey y **aprueba** `maquina-v7` en login.tailscale.com → Devices. |

## 📜 Licencia

MIT. Ver [`LICENSE`](LICENSE).

---

<div align="center">
Hecho con ❤️ para la comunidad de cloud gaming y escritorios remotos · Maquina-v7
</div>
