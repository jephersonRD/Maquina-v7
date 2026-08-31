#!/usr/bin/env bash
# setup_openbox.sh - Instala Openbox + utilidades mínimas en Google Colab
# Uso: bash setup_openbox.sh <RESOLUCION>
set -uo pipefail

RESOLUTION="${1:-1920x1080}"
WIDTH="${RESOLUTION%x*}"
HEIGHT="${RESOLUTION#*x}"

export DEBIAN_FRONTEND=noninteractive

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🖥️  Instalando Openbox + escritorio mínimo"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Actualizar repositorios
echo "   ↳ Actualizando repositorios..."
apt-get update -y || { echo "❌ apt-get update falló"; exit 1; }

# Instalar X11, Openbox y utilidades mínimas
echo "   ↳ Instalando X11, Openbox y dependencias..."
apt-get install -y \
  xorg xvfb x11-xserver-utils xauth dbus-x11 \
  openbox obconf lxappearance \
  pcmanfm xterm \
  x11-utils x11-xserver-utils xdotool xclip xsel \
  feh nitrogen \
  libx11-6 libxrandr2 libxinerama1 libxcursor1 libxi6 libxtst6 \
  fonts-noto fonts-dejavu \
  || { echo "❌ fallo al instalar paquetes"; exit 1; }

# Configurar directorios del usuario
echo "   ↳ Configurando directorios..."
mkdir -p ~/.config/openbox
mkdir -p ~/.local/share/applications
mkdir -p ~/.config/pcmanfm/default

# Crear configuración de Openbox
cat > ~/.config/openbox/rc.xml << 'OBEOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <resistance>
    <strength>10</strength>
    <screen_edge_strength>20</screen_edge_strength>
  </resistance>
  <focus>
    <focusNew>yes</focusNew>
    <followMouse>no</followMouse>
    <focusLast>yes</focusLast>
    <underMouse>no</underMouse>
    <focusDelay>200</focusDelay>
    <raiseOnFocus>no</raiseOnFocus>
  </focus>
  <placement>
    <policy>Smart</policy>
    <center>yes</center>
    <monitor>Primary</monitor>
    <primaryMonitor>1</primaryMonitor>
  </placement>
  <theme>
    <name>Clearlooks</name>
    <titleLayout>NLIMC</titleLayout>
    <keepBorder>yes</keepBorder>
    <animateIconify>yes</animateIconify>
    <fontPlace>
      <name>sans</name>
      <size>10</size>
      <weight>bold</weight>
      <slant>normal</slant>
    </fontPlace>
  </theme>
  <desktops>
    <number>1</number>
    <firstdesk>1</firstdesk>
    <names>
      <name>Desktop</name>
    </names>
  </desktops>
  <keyboard>
    <keybind key="A-F4">
      <action name="Close"/>
    </keybind>
    <keybind key="A-Tab">
      <action name="NextWindow">
        <finalactions>
          <action name="Focus"/>
          <action name="Raise"/>
          <action name="Unshade"/>
        </finalactions>
      </action>
    </keybind>
    <keybind key="A-F9">
      <action name="Iconify"/>
    </keybind>
    <keybind key="A-F10">
      <action name="ToggleMaximize"/>
    </keybind>
    <keybind key="C-A-t">
      <action name="Execute">
        <command>xterm</command>
      </action>
    </keybind>
  </keyboard>
  <mouse>
    <context name="Frame">
      <mousebind button="A-F3" action="Press">
        <action name="Focus"/>
        <action name="Raise"/>
      </mousebind>
      <mousebind button="A-Button1" action="Drag">
        <action name="Move"/>
      </mousebind>
      <mousebind button="A-Button3" action="Drag">
        <action name="Resize"/>
      </mousebind>
    </context>
    <context name="Titlebar">
      <mousebind button="Left" action="Press">
        <action name="Focus"/>
        <action name="Raise"/>
      </mousebind>
      <mousebind button="Left" action="Drag">
        <action name="Move"/>
      </mousebind>
      <mousebind button="Left" action="DoubleClick">
        <action name="ToggleMaximize"/>
      </mousebind>
    </context>
  </mouse>
  <applications>
    <application class="*">
      <decor>yes</decor>
      <shade>no</shade>
      <position force="no">
        <x>center</x>
        <y>center</y>
      </position>
    </application>
  </applications>
</openbox_config>
OBEOF

# Crear autostart para Openbox
cat > ~/.config/openbox/autostart << 'OBEOF'
# Iniciar panel inferior simple con tint2 si está disponible
# tint2 &

# Fondo de pantalla
feh --bg-color '#2c3e50' &

# Portapapeles
# Clipmenud &

# Compositor (opcional, desactivado por defecto)
# picom &
OBEOF
chmod +x ~/.config/openbox/autostart

# Configurar variables de entorno para sesión X11
cat > /etc/profile.d/openbox-session.sh << 'OBEOF'
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=Openbox
export DESKTOP_SESSION=openbox
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"
OBEOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Openbox instalado correctamente"
echo "     Resolución: ${WIDTH}x${HEIGHT}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
