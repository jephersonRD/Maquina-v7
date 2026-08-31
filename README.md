<div align="center">

![Logo](assets/logo.svg)

# Maquina-v7

### ☁️ Cloud PC Linux + Openbox + Selkies en Google Colab

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/jephersonRD/Maquina-v7/blob/main/Maquina-v7.ipynb)
[![GitHub Stars](https://img.shields.io/github/stars/jephersonRD/Maquina-v7?style=social)](https://github.com/jephersonRD/Maquina-v7/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/jephersonRD/Maquina-v7?style=social)](https://github.com/jephersonRD/Maquina-v7/network/members)
[![License](https://img.shields.io/github/license/jephersonRD/Maquina-v7)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/jephersonRD/Maquina-v7)](https://github.com/jephersonRD/Maquina-v7/commits/main)

![Platform](https://img.shields.io/badge/platform-Google%20Colab-blue)
![Desktop](https://img.shields.io/badge/desktop-Openbox-light)
![Remote](https://img.shields.io/badge/remote-Selkies-green)
![Protocol](https://img.shields.io/badge/protocol-WebRTC/WebSocket-blueviolet)

</div>

---

## 📖 Descripción

**Maquina-v7** convierte una sesión de **Google Colab** en un **escritorio remoto GNU/Linux** accesible desde **cualquier navegador web** mediante **Selkies**.

### Arquitectura

```
Google Colab
     ↓
   Linux
     ↓
   Xvfb (display virtual)
     ↓
  Openbox (window manager)
     ↓
   Selkies (remote desktop)
     ↓
  Browser (acceso web)
```

### ¿Por qué Selkies en vez de XRDP/Sunshine?

- **Sin cliente especializado**: accede desde cualquier navegador web.
- **Baja latencia**: streaming WebRTC/WebSocket optimizado.
- **GPU acceleration**: NVENC (NVIDIA) o fallback a software (CPU).
- **Audio nativo**: captura de audio del sistema via PulseAudio.
- **Simple**: sin configuración compleja de red o VPN.

## ▶️ Cómo usar

### Opción 1: Notebook (recomendado)

1. Abre el notebook en Colab usando el botón de arriba
2. Selecciona **Runtime → Change runtime type → GPU**
3. Ejecuta las celdas en orden:
   - ⚙️ Configuración
   - 📦 Instalar
   - 🚀 Iniciar
4. Abre la URL que aparece en el navegador

### Opción 2: Snippet (copiar y pegar)

Pega este código en una celda de Google Colab:

```python
import os

# Configuración
USERNAME = "user"
PASSWORD = "password"
RESOLUTION = "1920x1080"
PORT = 8080

# Descargar proyecto
if not os.path.isdir('/content/Maquina-v7'):
    !curl -fsSL "https://codeload.github.com/jephersonRD/Maquina-v7/tar.gz/refs/heads/main" -o /tmp/maquina-v7.tar.gz
    !tar xzf /tmp/maquina-v7.tar.gz -C /content
    !mv /content/Maquina-v7-main /content/Maquina-v7
    !rm -f /tmp/maquina-v7.tar.gz

# Instalar
%cd /content/Maquina-v7/scripts
!bash setup_openbox.sh {RESOLUTION}
!bash setup_audio.sh
!bash setup_selkies.sh

# Iniciar
!bash start_desktop.sh {RESOLUTION} {USERNAME} {PASSWORD} {PORT}
```

## 🖥️ Requisitos

| Componente | Requisito |
|------------|-----------|
| **Plataforma** | Google Colab (gratuito o Pro) |
| **GPU** | Opcional (mejora rendimiento con NVENC) |
| **Navegador** | Chrome, Firefox, Edge, Safari (cualquier navegador moderno) |
| **Internet** | Conexión estable |

## 🎮 GPU y Encoding

| GPU | Encoder | Descripción |
|-----|---------|-------------|
| NVIDIA Tesla T4 | NVENC H.264 | Hardware encoding (recomendado) |
| Sin GPU | Software H.264 | CPU encoding (funcional) |

La detección de GPU es automática. Si hay NVIDIA, se usa NVENC. Si no, se usa software.

## 🔊 Audio

El audio del escritorio se captura via PulseAudio y se transmite al navegador mediante Selkies.

```
Aplicación Linux
      ↓
PulseAudio
      ↓
Monitor del sink
      ↓
Selkies (pcmflux)
      ↓
Opus encoding
      ↓
Browser
```

## 📱 Acceso

| Plataforma | Cómo acceder |
|------------|--------------|
| **Cualquier dispositivo** | Abre `http://<URL>:8080` en el navegador |
| **Android** | Chrome o cualquier navegador |
| **iOS** | Safari o Chrome |
| **Windows/Linux/Mac** | Chrome, Firefox, Edge |

## ⚠️ Importante

- **No cierres la pestaña de Colab** si deseas mantener la sesión activa.
- **Selecciona GPU** en Runtime → Change runtime type para mejor rendimiento.
- **La URL es local**: solo funciona en la misma máquina. Para acceso externo, usa Tailscale o similar.

## 🐛 Solución de problemas

| Síntoma | Solución |
|---------|----------|
| No carga el escritorio | Verifica que Xvfb esté corriendo: `ps aux \| grep Xvfb` |
| Sin audio | Ejecuta `pactl info` para verificar PulseAudio |
| Selkies no inicia | Revisa logs: `cat /tmp/selkies.log` |
| GPU no detectada | Verifica con `nvidia-smi` |
| Pantalla negra | Reinicia el escritorio: `bash start_desktop.sh` |

## 📂 Estructura del proyecto

```
Maquina-v7/
├── Maquina-v7.ipynb          # Notebook principal para Colab
├── README.md                  # Esta documentación
├── LICENSE                    # Licencia MIT
├── assets/                    # Logos e imágenes
├── colab_snippet.py          # Snippet para copiar/pegar
└── scripts/
    ├── setup_openbox.sh       # Instala Openbox + dependencias
    ├── setup_audio.sh         # Configura PulseAudio
    ├── setup_selkies.sh       # Instala Selkies
    ├── start_desktop.sh       # Inicia todos los servicios
    ├── diagnostics.sh         # Diagnóstico del sistema
    ├── install_steam.sh       # Instala Steam (opcional)
    └── setup_tailscale.sh     # Instala Tailscale (opcional)
```

## 📜 Licencia

MIT. Ver [`LICENSE`](LICENSE).

---

<div align="center">
Hecho con ❤️ para la comunidad de escritorios remotos · Maquina-v7
</div>
