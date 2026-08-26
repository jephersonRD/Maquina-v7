<div align="center">

![Logo](assets/logo.svg)

# Maquina-v7

### ☁️ Cloud PC GNU/Linux con xrdp en Google Colab — controla tu escritorio remoto desde Android con RDP

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/jephersonRD/Maquina-v7/blob/main/Maquina-v7.ipynb)
[![GitHub Stars](https://img.shields.io/github/stars/jephersonRD/Maquina-v7?style=social)](https://github.com/jephersonRD/Maquina-v7/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/jephersonRD/Maquina-v7?style=social)](https://github.com/jephersonRD/Maquina-v7/network/members)
[![GitHub Issues](https://img.shields.io/github/issues/jephersonRD/Maquina-v7)](https://github.com/jephersonRD/Maquina-v7/issues)
[![License](https://img.shields.io/github/license/jephersonRD/Maquina-v7)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/jephersonRD/Maquina-v7)](https://github.com/jephersonRD/Maquina-v7/commits/main)

![Plataform](https://img.shields.io/badge/platform-Google%20Colab-blue)
![RDP](https://img.shields.io/badge/access-RDP%20%2F%20xrdp-green)
![Android](https://img.shields.io/badge/client-Android%20Ready-purple)
![Tailscale](https://img.shields.io/badge/network-Tailscale-0brand)
![GPU](https://img.shields.io/badge/GPU-T4%20passthrough%20%2F%20CPU%20fallback-orange)

</div>

---

## 📖 Descripción

**Maquina-v7** convierte una sesión gratuita de **Google Colab** en un **escritorio remoto GNU/Linux**
(Xfce + `xrdp`) al que te conectas con el cliente **Microsoft Remote Desktop** directo desde
**Android**, Windows o macOS. A diferencia de otros proyectos que usan Moonlight/Sunshine (streaming
de video), Maquina-v7 usa el protocolo **RDP nativo** vía `xrdp`, lo que lo hace compatible con
cualquier dispositivo móvil sin instalar software extra.

Diseñado para las **nuevas reglas de Colab**: si Google otorga la GPU (T4), el entorno la aprovecha
para *cloud gaming* (Steam/Linux); si la sesión viene sin GPU, **degrada automáticamente a un
escritorio remoto en CPU** en lugar de apagarse. La conexión se hace por **Tailscale**, una VPN
privada de malla, para no exponer puertos públicos.

## ▶️ Código para Colab (copiar y pegar)

Pega **este único bloque** en una celda de Google Colab y ejecútalo.
Él solo monta Drive, descarga el orquestador y te preguntará el usuario,
la contraseña y el authkey de Tailscale paso a paso:

```python
from google.colab import drive
drive.mount('/content/drive')

!wget -q https://raw.githubusercontent.com/jephersonRD/Maquina-v7/main/scripts/run_v7.py
%run run_v7.py
```

> 💡 Equivalente al viejo `ColabSteam`: tras ejecutarlo, contesta las
> preguntas en los cuadros de Colab y se instala todo automáticamente.

## ✨ Características

- 🖥️ **Escritorio Xfce4** completo con `xrdp` (protocolo RDP estándar).
- 📱 **Cliente Android**: usa la app oficial *Microsoft Remote Desktop* (ya viene con RDP).
- 🔐 **Tailscale**: red privada segura, sin abrir puertos ni usar ngrok frágil.
- 🎮 **Modo gaming**: detecta la GPU T4 de Colab y prepara Steam automáticamente.
- 🛡️ **Fallback a CPU**: si Colab no da GPU, el escritorio RDP sigue funcionando.
- 🔒 **Keep-alive integrado**: evita el cierre por inactividad de Colab.
- 📦 **100% open-source**: scripts propios, sin binarios cerrados ni `bit.ly` externos.

## 🚀 Inicio rápido

1. Abre el notebook con el botón **Open In Colab** de arriba.
2. En la celda **⚙️ Configuración** define:
   - `USERNAME` / `PASSWORD` → credenciales de tu escritorio RDP.
   - `TAILSCALE_AUTHKEY` → clave gratis en https://login.tailscale.com/admin/settings/keys
   - `INSTALL_STEAM = True` si quieres juegos (requiere sesión con GPU).
3. Ejecuta las celdas en orden: **Keep-Alive → Instalar RDP → Tailscale → (Steam)**.
4. En Android, abre *Microsoft Remote Desktop* y agrega:
   - **Dirección**: la `IP Tailscale` que muestra la celda de estado (puerto `3389`).
   - **Usuario** / **Contraseña**: los que definiste.

```bash
# Resumen de lo que hace cada script (también disponible en /scripts)
bash scripts/setup_rdp.sh <usuario> <password> [resolucion]   # Xfce + xrdp
bash scripts/setup_tailscale.sh <AUTHKEY>                     # VPN privada
bash scripts/install_steam.sh                                 # Steam si hay GPU
```

## 📋 Requisitos

| Software | Descripción |
|----------|-------------|
| 🔗 **Tailscale** | Cuenta gratuita + authkey para la red privada |
| 📲 **Microsoft Remote Desktop** | Cliente RDP en Android / iOS / Windows / macOS |
| ☁️ **Google Colab** | Sesión gratuita (GPU opcional, mejora el rendimiento) |

## 🏗️ Arquitectura

```
 Tu Android / PC
      │  RDP (3389) sobre Tailscale
      ▼
 ┌──────────────────────────────────┐
 │  Google Colab (contenedor Linux) │
 │   ├─ Xfce4 desktop               │
 │   ├─ xrdp  (servidor RDP)        │
 │   ├─ Tailscale (VPN mesh)        │
 │   └─ [Opcional] GPU T4 + Steam   │
 └──────────────────────────────────┘
```

> **¿Por qué Xfce + xrdp y no una VM anidada?** En Colab ya corres Linux con la GPU
> disponible de forma nativa. Montar el escritorio directamente aprovecha mejor los
> recursos y es mucho más estable que una VM KVM anidada; si Colab quita la GPU,
> conservas el escritorio RDP en CPU.

## 💻 Especificaciones de la máquina (típicas en Colab)

| 🧩 Componente | 📊 Especificación |
|--------------|-------------------|
| 🎮 GPU | NVIDIA Tesla T4 *(si la sesión la otorga)* |
| ⚡ CPU | Intel Xeon — 2 núcleos @ 2.0 GHz |
| 💾 RAM | ~12.7 GB |
| 🖥️ SO | Ubuntu (contendedor Colab) + Xfce4 |
| 🔌 Acceso | RDP 3389 vía Tailscale |

## ⚠️ Recomendaciones importantes

- ⏰ Revisa el tiempo restante de uso de Colab (se reinicia cada ~24 h).
- 🔉 **No ocultes ni cambies de pestaña** mientras uses la sesión (el keep-alive ayuda, pero la página debe permanecer visible/activa).
- 🔌 Desconéctate cuando no uses la máquina para aprovechar mejor el tiempo.
- 🎮 El gaming solo funciona si Colab asigna GPU; de lo contrario usa el modo escritorio.

## 🐛 Solución de problemas

| Síntoma | Solución |
|---------|----------|
| No conecta por RDP | Verifica la `IP Tailscale` y que el cliente use puerto `3389`. |
| `tailscale` no arranca | Usa `tailscale up --qr` y escanea con tu cuenta en el celular. |
| Sin GPU / Steam no juega | Normal: Colab dio sesión sin GPU. Usa el escritorio en CPU. |
| Colab se apaga | Mantén la pestaña visible y el audio del keep-alive en reproducción. |
| Error al clonar repo | Confirma `GITHUB_USER` en la celda de configuración. |

## 📜 Licencia

Este proyecto se distribuye bajo la licencia **MIT**. Ver [`LICENSE`](LICENSE).

---

<div align="center">

Hecho con ❤️ para la comunidad de cloud gaming y远程桌面 · Maquina-v7

</div>
