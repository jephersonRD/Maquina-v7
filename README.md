<div align="center">

![Logo](assets/logo.svg)

# Maquina-v7

### ☁️ Cloud PC Linux + LXQt + Apache Guacamole en Google Colab

[![Open In Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/jephersonRD/Maquina-v7/blob/main/Maquina-v7.ipynb)
[![GitHub Stars](https://img.shields.io/github/stars/jephersonRD/Maquina-v7?style=social)](https://github.com/jephersonRD/Maquina-v7/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/jephersonRD/Maquina-v7?style=social)](https://github.com/jephersonRD/Maquina-v7/network/members)
[![License](https://img.shields.io/github/license/jephersonRD/Maquina-v7)](LICENSE)
[![Last Commit](https://img.shields.io/github/last-commit/jephersonRD/Maquina-v7)](https://github.com/jephersonRD/Maquina-v7/commits/main)

![Platform](https://img.shields.io/badge/platform-Google%20Colab-blue)
![Desktop](https://img.shields.io/badge/desktop-LXQt-light)
![Gateway](https://img.shields.io/badge/gateway-Apache%20Guacamole-green)
![Backend](https://img.shields.io/badge/backend-VNC-blueviolet)

</div>

---

## 📖 Descripcion

**Maquina-v7** convierte una sesion de **Google Colab** en un **escritorio remoto GNU/Linux** accesible desde **cualquier navegador web** mediante **Apache Guacamole**.

### Arquitectura

```
Google Colab
     ↓
   Linux
     ↓
 Xvfb (display virtual)
     ↓
   LXQt (escritorio)
     ↓
 x11vnc (servidor VNC)
     ↓
  guacd (proxy Guacamole)
     ↓
 Apache Guacamole (gateway web)
     ↓
   Browser (acceso web)
```

### Por que VNC + Guacamole?

- **Estabilidad**: VNC es maduro y predecible en contenedores Colab
- **Sin cliente especializado**: accede desde cualquier navegador web
- **X11 nativo**: x11vnc comparte el display Xvfb directamente
- **Audio**: PulseAudio integrado con monitor de audio
- **GPU**: compatible con NVIDIA T4 cuando Colab la proporciona
- **Sencillo**: instalacion automatizada en 3 pasos

## ▶️ Como usar

### Opcion 1: Notebook (recomendado)

1. Abre el notebook en Colab usando el boton de arriba
2. Selecciona **Runtime → Change runtime type → GPU**
3. Ejecuta las celdas en orden:
   - ⚙️ Configuracion
   - 📦 Instalar
   - 🚀 Iniciar
4. Abre `http://localhost:8080` en tu navegador
5. Ingresa con el usuario y password configurados

### Opcion 2: Snippet (copiar y pegar)

Pega este codigo en una celda de Google Colab:

```python
import os

USERNAME   = "user"
PASSWORD   = "password"
RESOLUTION = "1920x1080"
GUAC_PORT  = 8080

if not os.path.isdir('/content/Maquina-v7'):
    !curl -fsSL "https://codeload.github.com/jephersonRD/Maquina-v7/tar.gz/refs/heads/main" -o /tmp/maquina-v7.tar.gz
    !tar xzf /tmp/maquina-v7.tar.gz -C /content
    !mv /content/Maquina-v7-main /content/Maquina-v7
    !rm -f /tmp/maquina-v7.tar.gz

os.chdir('/content/Maquina-v7/scripts')

!bash setup_lxqt.sh {RESOLUTION}
!bash setup_audio.sh
!bash setup_vnc.sh
!bash setup_guacamole.sh
!bash start_desktop.sh {RESOLUTION} {USERNAME} {PASSWORD} {GUAC_PORT}
```

## 🖥️ Requisitos

| Componente | Requisito |
|------------|-----------|
| **Plataforma** | Google Colab (gratuito o Pro) |
| **GPU** | Opcional (mejora rendimiento) |
| **Navegador** | Chrome, Firefox, Edge, Safari |
| **Internet** | Conexion estable |

## 🎮 GPU y Encoding

| GPU | Encoder | Descripcion |
|-----|---------|-------------|
| NVIDIA Tesla T4 | VNC encoder | Hardware acceleration (si disponible) |
| Sin GPU | Software VNC | CPU encoding (funcional) |

La deteccion de GPU es automatica. El sistema funciona con o sin GPU.

## 🔊 Audio

El audio del escritorio se captura via PulseAudio y se transmite al navegador mediante Guacamole.

```
Aplicacion Linux
      ↓
PulseAudio
      ↓
Monitor del sink
      ↓
x11vnc (audio capture)
      ↓
Guacamole
      ↓
Browser
```

### Diagnostico de audio

```bash
pactl info                    # Verificar PulseAudio
pactl list short sinks        # Ver sinks disponibles
pactl list short sources      # Ver sources (monitores)
paplay /usr/share/sounds/...  # Probar audio
```

## 📱 Acceso

| Plataforma | Como acceder |
|------------|--------------|
| **Cualquier dispositivo** | Abre `http://localhost:8080` en el navegador |
| **Android** | Chrome o cualquier navegador |
| **iOS** | Safari o Chrome |
| **Windows/Linux/Mac** | Chrome, Firefox, Edge |

**Credenciales por defecto:** usuario `user`, password `password` (configurables en la celda de Configuracion).

## ⚠️ Importante

- **No cierres la pestana de Colab** si deseas mantener la sesion activa.
- **Selecciona GPU** en Runtime → Change runtime type para mejor rendimiento.
- **Compilacion de guacd**: la instalacion de Guacamole puede tardar 5-10 minutos la primera vez.

## 🐛 Solucion de problemas

| Sintoma | Solucion |
|---------|----------|
| No carga el escritorio | Verifica que Xvfb este corriendo: `ps aux \| grep Xvfb` |
| Sin audio | Ejecuta `pactl info` para verificar PulseAudio |
| Guacamole no inicia | Revisa logs: `cat /tmp/guacd.log`, `cat /tmp/tomcat*.log` |
| GPU no detectada | Verifica con `nvidia-smi` |
| Pantalla negra | Reinicia el escritorio: `bash start_desktop.sh` |
| Tomcat no inicia | Verifica: `cat /var/lib/tomcat9/logs/catalina.out` |

## 📂 Estructura del proyecto

```
Maquina-v7/
├── Maquina-v7.ipynb          # Notebook principal para Colab
├── README.md                  # Esta documentacion
├── LICENSE                    # Licencia MIT
├── assets/                    # Logos e imagenes
├── colab_snippet.py          # Snippet para copiar/pegar
└── scripts/
    ├── setup_lxqt.sh         # Instala LXQt + dependencias
    ├── setup_audio.sh        # Configura PulseAudio
    ├── setup_vnc.sh          # Instala x11vnc
    ├── setup_guacamole.sh    # Instala Apache Guacamole
    ├── start_desktop.sh      # Inicia todos los servicios
    ├── diagnostics.sh        # Diagnostico del sistema
    └── install_steam.sh      # Instala Steam (opcional)
```

## 📜 Licencia

MIT. Ver [`LICENSE`](LICENSE).

---

<div align="center">
Hecho con ❤️ para la comunidad de escritorios remotos · Maquina-v7
</div>
