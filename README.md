<p align="center">
  <img src="logo.svg" alt="Maquina Virtual v7" width="220">
</p>

<h1 align="center">Máquina Virtual v7</h1>

<p align="center">
  Escritorio remoto Linux listo en un comando: <b>Ubuntu + XFCE + xrdp + Tailscale</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Ubuntu-22.04%20%7C%2024.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white" alt="Ubuntu">
  <img src="https://img.shields.io/badge/XFCE-4.18-2284F2?style=for-the-badge&logo=xfce&logoColor=white" alt="XFCE">
  <img src="https://img.shields.io/badge/xrdp-3389-2F6DB5?style=for-the-badge&logo=windows&logoColor=white" alt="xrdp">
  <img src="https://img.shields.io/badge/Tailscale-mesh%20VPN-242424?style=for-the-badge&logo=tailscale&logoColor=white" alt="Tailscale">
  <img src="https://img.shields.io/badge/license-MIT-22c55e?style=for-the-badge" alt="MIT">
</p>

<p align="center">
  <b>⭐ Si te sirve, deja una estrella</b>
</p>

---

## 🖥️ ¿Qué es esto?

Un instalador que convierte un servidor **Ubuntu** recién creado en un **escritorio Linux
completo** al que te conectas por **RDP** (el mismo cliente de Windows, sin instalar nada raro)
y al que llegas desde cualquier red gracias a **Tailscale**.

No hay que abrir puertos en el router ni exponer la IP pública: la máquina se une a tu
*tailnet* y tú entras como si estuviera en tu misma LAN.

| Antes | Después |
|---|---|
| Servidor sin entorno gráfico | Escritorio XFCE con teclado, ratón, portapapeles y sonido |
| Acceso solo por SSH | Acceso por RDP desde Windows, Arch, macOS o Android |
| IP pública expuesta | Acceso privado por Tailscale (WireGuard) |

---

## ⚡ Inicio rápido

```bash
git clone https://github.com/jephersonRD/Maquina-V7.git
cd Maquina-V7
sudo bash instalar.sh --user gamer --password 'MiClave123' --authkey tskey-auth-xxxxxxxxxxxx
```

Al terminar verás algo así:

```
========================================================
  Máquina Virtual v7 lista
========================================================
  Servidor : 100.101.102.103:3389
  Usuario  : gamer

  Windows  : mstsc -> 100.101.102.103:3389
  Arch     : xfreerdp /v:100.101.102.103:3389 /u:gamer /dynamic-resolution
========================================================
```

### Opciones disponibles

| Opción | Para qué sirve |
|---|---|
| `--user NOMBRE` | Usuario del escritorio (se crea si no existe) |
| `--password CLAVE` | Contraseña de ese usuario |
| `--authkey CLAVE` | Auth key de Tailscale, sin navegador y sin interacción |
| `--hostname NOMBRE` | Nombre de la máquina dentro de tu tailnet |
| `--port NÚMERO` | Cambia el puerto de xrdp (por defecto `3389`) |
| `--sudo` | Añade el usuario al grupo `sudo` |
| `--no-tailscale` | Instala solo el escritorio, sin VPN |

El script es **idempotente**: puedes relanzarlo las veces que quieras y no rompe nada.

---

## 🔗 Conectarte

### Windows

1. Abre **Conexión a Escritorio remoto** (`Win + R` → `mstsc`).
2. Equipo: `100.x.x.x:3389` (la IP de Tailscale).
3. Usuario y contraseña que pasaste a `instalar.sh`.

### Arch Linux

```bash
sudo pacman -S freerdp                 # cliente por línea de comandos
xfreerdp /v:100.x.x.x:3389 /u:gamer /dynamic-resolution /clipboard /sound
```

O con interfaz gráfica, si lo prefieres:

```bash
sudo pacman -S remmina
remmina -c rdp://gamer@100.x.x.x:3389
```

### macOS / Android / iOS

App **Windows App** (antes Microsoft Remote Desktop) o **Remmina**, mismo host y puerto.

> **Consejo:** añade `/dynamic-resolution` en FreeRDP para que la pantalla se adapte al
> tamaño de tu ventana en lugar de quedarse fija.

---

## 🔑 Crear la auth key de Tailscale

1. Entra en <https://login.tailscale.com/admin/settings/keys>.
2. **Generate auth key** → marca *Reusable* si vas a crear varias máquinas.
3. Opcional pero recomendado: marca **Ephemeral** para que la máquina se borre sola del
   tailnet cuando se apague, y así no acumules nodos muertos.
4. Copia la clave (`tskey-auth-...`) y pásala con `--authkey`.

Si prefieres no usar auth key, ejecuta el instalador sin `--authkey` y luego:

```bash
sudo tailscale up --ssh
```

Te dará una URL, la abres en tu navegador, autorizas, y listo.

---

## 📁 Estructura del repositorio

| Archivo | Qué hace |
|---|---|
| `instalar.sh` | Instala y configura XFCE, xrdp y Tailscale. Idempotente. |
| `arrancar.sh` | Levanta los servicios si están caídos y muestra cómo conectarte. |
| `logo.svg` | Logo del proyecto. |
| `LICENSE` | Licencia MIT. |

Uso típico del segundo script cuando reinicias la máquina:

```bash
sudo bash arrancar.sh
```

---

## 🧩 Qué configura exactamente

- **XFCE 4.18** como sesión gráfica, sin arrastrar GNOME.
- **xrdp** con un `startwm.sh` propio que lanza `startxfce4` con `dbus-launch`, que es lo
  que evita el clásico *"black screen"* al conectarse.
- **Pantalla y ahorro de energía** desactivados dentro de la sesión: nada de que se apague
  el monitor a los 10 minutos y te tire la conexión.
- **Polkit** configurado para que no salte el popup de *"Authentication required"* cada vez
  que XFCE toca el gestor de color.
- **Tailscale** con `--ssh` y `--accept-routes`, habilitado en el arranque.
- **ufw**: si está activo, abre solo el puerto de RDP.

---

## 🛠️ Solución de problemas

| Síntoma | Causa y solución |
|---|---|
| Pantalla negra al conectar | Sesión mal lanzada. Revisa `/etc/xrdp/startwm.sh` y `sudo systemctl restart xrdp`. |
| Se corta a los ~10 min | Salvapantallas. El instalador ya lo desactiva; si tocaste la config, vuelve a lanzarlo. |
| `Authentication required` | Popup de colord. El instalador crea la regla de polkit; cierra sesión y reconecta. |
| No aparece la máquina en Tailscale | `sudo tailscale status` y `sudo tailscale up --ssh`. |
| Puerto ocupado o cambiado | `sudo grep ^port /etc/xrdp/xrdp.ini`, o relanza con `--port 3390`. |
| El escritorio se ve borroso | Usa `/dynamic-resolution` en FreeRDP o cambia la resolución en la config del cliente. |
| Quiero ver los logs | `journalctl -u xrdp -n 100 --no-pager` y `journalctl -u tailscaled -n 50 --no-pager`. |

---

## ⚠️ Sobre Google Colab

Este repositorio **no incluye** un notebook de Colab a propósito.

Las condiciones de uso de Colab prohíben expresamente el escritorio remoto y el control
remoto de sus máquinas, y un script pensado para esquivar sus bloqueos va contra esas
condiciones (y contra el resto de usuarios, que comparten la GPU). Por eso aquí no hay
nada de ocultar procesos ni de evadir la detección.

La buena noticia: todo esto funciona igual en cualquier proveedor que **sí** permite
escritorio remoto en su GPU, y con el mismo comando:

- Vast.ai o RunPod (RTX / T4 por horas, escritorio permitido)
- Oracle Cloud Free Tier (Ampere ARM, gratis, permite RDP)
- Un VPS normal (Hetzner, Contabo, DigitalOcean...)
- Tu propia máquina con Ubuntu

En todos ellos, `instalar.sh` deja el escritorio listo igual que aquí.

---

## 🤝 Contribuir

Los *issues* y *pull requests* son bienvenidos. Si añades soporte para otra distro o para
otro cliente de escritorio remoto, mejor con pruebas de que funciona.

---

## 📄 Licencia

MIT © [jephersonRD](https://github.com/jephersonRD)

Hecho con ❤️ para la comunidad.
