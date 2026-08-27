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
**Android**, Windows o macOS. La conexión se hace por **Tailscale**, una VPN privada de malla,
sin abrir el puerto 8080 a Internet.

## ▶️ Código para Colab (copiar y pegar)

Pega **este único bloque** en una celda de Google Colab y ejecútalo. Descarga el proyecto
como tarball desde GitHub (sin `git` ni credenciales) y los paquetes apt/Tailscale. Antes de
ejecutar, pega tu **authkey** de Tailscale en la variable `TS_AUTHKEY` (línea marcada). Al final
muestra la **URL, usuario y contraseña** listos para abrir en el navegador.

```python
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
```

> 💡 El script **no termina con `returncode=0` si algo falló**: revisa
> `tail -n 40 /tmp/selkies.log` y los mensajes de arriba. Al final imprime la
> URL `https://<IP>:8080` con la IP, usuario y contraseña.

### 🌐 Conectarte desde el navegador (Chrome / Edge / Firefox)

1. Instala **Tailscale** en el MÓVIL/PC y entra con la **misma cuenta** que generó la authkey
   (el cliente debe estar en el mismo tailnet para enrutar a `100.x.x.x`).
2. Abre **https://`100.x.x.x`:8080** (la URL que muestra el script) en el navegador.
3. Si el navegador avisa del certificado autofirmado, es normal: continúa (opción "avanzado/continuar").
4. Inicia sesión con **usuario** `jeph` y **contraseña** `medina`.
5. Si en la consola de Tailscale el dispositivo `maquina-v7` aparece **pendiente**,
   púlsalo y **Aprueba**.

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
       │  WebRTC/HTTPS (8080) sobre la VPN Tailscale
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
