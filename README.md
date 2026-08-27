<div align="center">

![Logo](assets/logo.svg)

# Maquina-v7

### ☁️ Cloud PC GNU/Linux con Selkies (WebRTC) en Google Colab — controla tu escritorio remoto desde el navegador vía Tailscale

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/jephersonRD/Maquina-v7/blob/main/Maquina-v7.ipynb)
[![GitHub Stars](https://img.shields.io/github/stars/jephersonRD/Maquina-v7?style=social)](https://github.com/jephersonRD/Maquina-v7/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/jephersonRD/Maquina-v7?style=social)](https://github.com/jephersonRD/Maquina-v7/network/members)
[![License](https://img.shields.io/github/license/jephersonRD/Maquina-v7)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/jephersonRD/Maquina-v7)](https://github.com/jephersonRD/Maquina-v7/commits/main)

![Plataform](https://img.shields.io/badge/platform-Google%20Colab-blue)
![WebRTC](https://img.shields.io/badge/access-WebRTC%20%2F%20Selkies-blue)
![Android](https://img.shields.io/badge/client-Android%20Ready-purple)
![Tailscale](https://img.shields.io/badge/network-Tailscale-0brand)

</div>

---

## 📖 Descripción

**Maquina-v7** convierte una sesión de **Google Colab** en un **escritorio remoto GNU/Linux**
(KDE Plasma + `Selkies`) al que te conectas desde el **navegador** (Chrome, Edge, Firefox) en
**Android**, Windows o macOS. La conexión se expone vía un **túnel público de cloudflared**
(URL HTTPS lista para usar); **Tailscale es opcional** y ya no se requiere. El puerto 8080 no
queda abierto directamente a Internet.

## ▶️ Código para Colab (copiar y pegar)

Pega **este único bloque** en una celda de Google Colab y ejecútalo. Descarga el proyecto
como tarball desde GitHub (sin `git` ni credenciales) y los paquetes apt/Tailscale. Antes de
ejecutar, pega tu **authkey** de Tailscale en la variable `TS_AUTHKEY` (línea marcada). Al final
muestra la **URL, usuario y contraseña** listos para abrir en el navegador.

```python
# ===== Maquina-v7 (Selkies / WebRTC en vez de XRDP) =====
# Cloud PC Linux (KDE Plasma + Selkies) accesible desde el navegador via túnel cloudflared en Google Colab.
# Pega ESTE bloque completo en una celda de Colab y ejecutalo.
import subprocess, os

# ====== CONFIGURACION ======
USERNAME   = "jeph"
PASSWORD   = "medina"
RESOLUTION = "1920x1080"
PORT       = "8080"
# Acceso por túnel público cloudflared (Tailscale es opcional, ya no requerido).
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

print("Ejecutando instalador Selkies (puede tardar varios minutos)...\n")
r = subprocess.run(f"bash setup_selkies.sh {USERNAME} {PASSWORD} {RESOLUTION} {PORT}", shell=True)
if r.returncode != 0:
    print("\n❌❌ setup_selkies.sh termino con error."); raise SystemExit(r.returncode)

import re, time
url = ""
for _ in range(45):
    log = subprocess.run("tail -n 200 /tmp/cloudflared.log 2>/dev/null", shell=True, capture_output=True, text=True).stdout
    m = re.search(r'https://[a-zA-Z0-9._-]+\.trycloudflare\.com', log)
    if m:
        url = m.group(0); break
    time.sleep(1)

print("\n========================================")
print("✅ MAQUINA LISTA (Selkies / WebRTC)")
if url:
    print("🌐 URL pública   :", url)
else:
    print("🌐 URL cloudflared: no disponible aún (revisa /tmp/cloudflared.log)")
print("👤 USUARIO       :", USERNAME)
print("🔑 CONTRASEÑA     :", PASSWORD)
print("========================================")
print("Abre esa URL en Chrome/Edge/Firefox. El certificado es autofirmado: continua.")
```

> 💡 El script **no termina con `returncode=0` si algo falló**: revisa
> `tail -n 40 /tmp/selkies.log` y los mensajes de arriba. Al final imprime la
> **URL pública de cloudflared** (https://...trycloudflare.com) con usuario y contraseña.

### 🌐 Conectarte desde el navegador (Chrome / Edge / Firefox)

1. Ejecuta la celda de instalación: al terminar muestra una **URL pública**
   `https://<random>.trycloudflare.com`. También la muestra la celda **URL de acceso**.
2. Abre esa URL en el navegador (móvil o PC).
3. Si el navegador avisa del certificado autofirmado, es normal: continúa (opción "avanzado/continuar").
4. Inicia sesión con **usuario** `jeph` y **contraseña** `medina`.
5. (Opcional) Si prefieres **Tailscale** en vez de cloudflared, descomenta las líneas de la
   celda "URL de acceso" y usa `https://<IP_Tailscale>:8080`.

### ⚠️ No cierres la pestaña
Colab mata la sesión si cierras la pestaña. Mantenla abierta (puedes minimizarla).

## ✨ Características

- 🖥️ **Escritorio KDE Plasma** completo con `Selkies` (HTML5 + WebRTC).
- 📱 **Cliente**: cualquier navegador moderno (Chrome, Edge, Firefox) en Android, PC o macOS.
- 🔐 **Tailscale**: red privada segura, el puerto 8080 (HTTPS) NO se expone a Internet.
- 🔒 **Keep-alive**: evita el cierre por inactividad de Colab.
- 📦 **100% open-source**: scripts propios, sin binarios cerrados.

## 🏗️ Arquitectura

```
 Tu Android / PC (con Tailscale en la misma cuenta)
        │  WebRTC/HTTPS (8080) sobre túnel cloudflared
       ▼
  ┌──────────────────────────────────┐
  │  Google Colab (contenedor Linux) │
  │   ├─ KDE Plasma desktop               │
  │   ├─ Selkies (servidor WebRTC/HTTPS:8080) │
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
| `0x300005e` (ya no aplica, era de RDP) | Selkies usa navegador; asegura Tailscale con la misma cuenta en el cliente. |
| No abre la página | Verifica la IP de Tailscale y que el puerto 8080 está en escucha (`ss -ltn | grep 8080`). |
| Tailscale no conecta | Confirma la authkey y **aprueba** `maquina-v7` en login.tailscale.com → Devices. |
| 8080 no escucha | Revisa `tail -n 40 /tmp/selkies.log`. |

## 📜 Licencia

MIT. Ver [`LICENSE`](LICENSE).

---

<div align="center">
Hecho con ❤️ para la comunidad de cloud gaming y escritorios remotos · Maquina-v7
</div>
