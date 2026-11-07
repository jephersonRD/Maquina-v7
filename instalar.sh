#!/usr/bin/env bash
#
# Maquina Virtual v7 - Ubuntu + XFCE + xrdp + Tailscale
# Instalador idempotente para Ubuntu 22.04 / 24.04 y Debian 12.
#
# Uso basico:
#   sudo bash instalar.sh --user gamer --password 'MiClave123' --authkey tskey-auth-xxxx
#
# Se puede volver a ejecutar sin miedo: no duplica configuracion.
#
set -Eeuo pipefail

APP_NAME="Maquina Virtual v7"
XRDP_PORT="3389"
NEW_USER=""
NEW_PASS=""
AUTHKEY=""
TS_HOSTNAME=""
WITH_TAILSCALE=1
GRANT_SUDO=0

C_RESET=$'\033[0m'
C_BLUE=$'\033[1;34m'
C_GREEN=$'\033[1;32m'
C_YELLOW=$'\033[1;33m'
C_RED=$'\033[1;31m'

log()  { printf '%s==>%s %s\n' "$C_BLUE"   "$C_RESET" "$*"; }
ok()   { printf '%s  ok%s %s\n' "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf '%s  !!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
die()  { printf '%sERROR%s %s\n' "$C_RED"   "$C_RESET" "$*" >&2; exit 1; }

usage() {
  cat <<EOF
${APP_NAME} - instalador de escritorio remoto

OPCIONES
  --user NOMBRE        Usuario para el escritorio (se crea si no existe)
  --password CLAVE     Contrasena de ese usuario (se aplica con chpasswd)
  --authkey CLAVE      Auth key de Tailscale (tskey-auth-...); sin esto hay
                       que autorizar a mano desde el navegador
  --hostname NOMBRE    Nombre de la maquina en tu tailnet
  --port NUMERO        Puerto de xrdp (por defecto ${XRDP_PORT})
  --sudo               Anade el usuario al grupo sudo
  --no-tailscale       No instala ni configura Tailscale
  -h, --help           Muestra esta ayuda

EJEMPLOS
  sudo bash instalar.sh --user gamer --password 'MiClave123'
  sudo bash instalar.sh --user gamer --password 'MiClave123' \\
      --authkey tskey-auth-xxxxxxxxxxxx --hostname maquina-v7 --sudo
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --user)         NEW_USER="${2:-}"; shift 2 ;;
    --password)     NEW_PASS="${2:-}"; shift 2 ;;
    --authkey)      AUTHKEY="${2:-}"; shift 2 ;;
    --hostname)     TS_HOSTNAME="${2:-}"; shift 2 ;;
    --port)         XRDP_PORT="${2:-}"; shift 2 ;;
    --sudo)         GRANT_SUDO=1; shift ;;
    --no-tailscale) WITH_TAILSCALE=0; shift ;;
    -h|--help)      usage; exit 0 ;;
    *)              die "opcion desconocida: $1 (usa --help)" ;;
  esac
done

[ -n "$XRDP_PORT" ] || die "--port no puede estar vacio"

if [ "${EUID}" -ne 0 ]; then
  log "se necesitan privilegios de root, reintentando con sudo"
  exec sudo -E bash "$0" "$@"
fi

trap 'die "fallo en la linea $LINENO (comando: $BASH_COMMAND)"' ERR

# ---------------------------------------------------------------- sistema base
log "comprobando el sistema operativo"
if [ ! -r /etc/os-release ]; then
  die "no encuentro /etc/os-release; distribucion no soportada"
fi
# shellcheck disable=SC1091
. /etc/os-release

case "${ID:-}" in
  ubuntu|debian) ok "detectado ${PRETTY_NAME:-$ID}" ;;
  *) die "solo Ubuntu 22.04/24.04 o Debian 12; detectado ${PRETTY_NAME:-desconocido}" ;;
esac

export DEBIAN_FRONTEND=noninteractive

log "actualizando indices de paquetes"
apt-get update -qq

log "instalando XFCE, xrdp y utilidades"
PKGS=(
  xfce4
  xfce4-goodies
  xfce4-terminal
  xorgxrdp
  xrdp
  dbus-x11
  dbus-user-session
  x11-xserver-utils
  curl
  ca-certificates
)
apt-get install -y -qq "${PKGS[@]}"
ok "paquetes instalados"

# ---------------------------------------------------------------------- xrdp
log "configurando el arranque de la sesion XFCE"
if [ -f /etc/xrdp/startwm.sh ] && [ ! -f /etc/xrdp/startwm.sh.orig-mv7 ]; then
  cp /etc/xrdp/startwm.sh /etc/xrdp/startwm.sh.orig-mv7
fi

cat > /etc/xrdp/startwm.sh <<'STARTWM'
#!/bin/sh
# startwm.sh - inicia XFCE dentro de la sesion de xrdp
# Generado por Maquina Virtual v7

if [ -r /etc/profile ]; then . /etc/profile; fi
if [ -r "$HOME/.profile" ]; then . "$HOME/.profile"; fi
if [ -r "$HOME/.bashrc" ]; then . "$HOME/.bashrc"; fi

# Evita choques con el bus de sesion del sistema
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR

export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=xfce
export XDG_SESSION_CLASS=user

# Sin salvapantallas ni apagado de monitor: evita desconexiones raras
xset s off 2>/dev/null || true
xset s noblank 2>/dev/null || true
xset -dpms 2>/dev/null || true

if command -v dbus-launch >/dev/null 2>&1; then
  exec dbus-launch --exit-with-session startxfce4
fi
exec startxfce4
STARTWM
chmod 0755 /etc/xrdp/startwm.sh
ok "startwm.sh escrito"

log "ajustando el puerto de xrdp a ${XRDP_PORT}"
if [ -f /etc/xrdp/xrdp.ini ]; then
  sed -i "s/^port=.*/port=${XRDP_PORT}/" /etc/xrdp/xrdp.ini
  grep -q "^port=${XRDP_PORT}$" /etc/xrdp/xrdp.ini \
    || printf 'port=%s\n' "$XRDP_PORT" >> /etc/xrdp/xrdp.ini
fi
if [ -f /etc/xrdp/sesman.ini ]; then
  sed -i 's/^MaxSessions=.*/MaxSessions=20/' /etc/xrdp/sesman.ini
fi

# xrdp necesita leer el certificado TLS autogenerado
if getent group ssl-cert >/dev/null 2>&1; then
  adduser xrdp ssl-cert >/dev/null 2>&1 || true
fi

# Quita el popup "Authentication required" de colord
install -d -m 0755 /etc/polkit-1/localauthority/50-local.d
cat > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla <<'PKLA'
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
PKLA

systemctl enable xrdp >/dev/null 2>&1 || true
systemctl restart xrdp
ok "servicio xrdp activo en el puerto ${XRDP_PORT}"

# -------------------------------------------------------------------- usuario
if [ -n "$NEW_USER" ]; then
  log "preparando el usuario ${NEW_USER}"
  if id -u "$NEW_USER" >/dev/null 2>&1; then
    ok "el usuario ya existia"
  else
    useradd -m -s /bin/bash "$NEW_USER"
    ok "usuario creado"
  fi

  if [ -n "$NEW_PASS" ]; then
    printf '%s:%s\n' "$NEW_USER" "$NEW_PASS" | chpasswd
    ok "contrasena establecida"
  else
    warn "sin --password: define la contrasena con: sudo passwd ${NEW_USER}"
  fi

  if [ "$GRANT_SUDO" -eq 1 ]; then
    usermod -aG sudo "$NEW_USER" 2>/dev/null || usermod -aG wheel "$NEW_USER" 2>/dev/null || true
    ok "usuario anadido al grupo de administradores"
  fi

  HOME_DIR="$(getent passwd "$NEW_USER" | cut -d: -f6)"
  printf 'startxfce4\n' > "${HOME_DIR}/.xsession"
  chown "${NEW_USER}:${NEW_USER}" "${HOME_DIR}/.xsession"
  chmod 0644 "${HOME_DIR}/.xsession"
  ok "sesion XFCE asociada al usuario"
else
  warn "no se indico --user: usa cualquier usuario existente con contrasena"
fi

# ------------------------------------------------------------------ tailscale
TAILSCALE_IP=""
if [ "$WITH_TAILSCALE" -eq 1 ]; then
  log "instalando Tailscale"
  if ! command -v tailscale >/dev/null 2>&1; then
    curl -fsSL https://tailscale.com/install.sh | sh
  fi
  systemctl enable --now tailscaled >/dev/null 2>&1 || true

  TS_ARGS=(--accept-routes --ssh)
  [ -n "$TS_HOSTNAME" ] && TS_ARGS+=(--hostname "$TS_HOSTNAME")

  if [ -n "$AUTHKEY" ]; then
    log "conectando la maquina a tu tailnet"
    tailscale up --authkey "$AUTHKEY" "${TS_ARGS[@]}"
    ok "Tailscale autenticado"
  else
    warn "sin --authkey: ejecuta 'sudo tailscale up --ssh' y autoriza en el navegador"
  fi

  TAILSCALE_IP="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
else
  warn "Tailscale omitido (--no-tailscale)"
fi

# ------------------------------------------------------------------- firewall
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
  ufw allow "${XRDP_PORT}/tcp" >/dev/null 2>&1 || true
  ok "ufw: puerto ${XRDP_PORT}/tcp permitido"
fi

# -------------------------------------------------------------------- resumen
if [ -z "$TAILSCALE_IP" ]; then
  TAILSCALE_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi
[ -n "$TAILSCALE_IP" ] || TAILSCALE_IP="<ip-de-la-maquina>"

printf '\n'
printf '%s========================================================%s\n' "$C_BLUE" "$C_RESET"
printf '%s  %s lista%s\n' "$C_GREEN" "$APP_NAME" "$C_RESET"
printf '%s========================================================%s\n' "$C_BLUE" "$C_RESET"
printf '  Servidor : %s:%s\n' "$TAILSCALE_IP" "$XRDP_PORT"
printf '  Usuario  : %s\n' "${NEW_USER:-<tu-usuario>}"
printf '\n  Windows  : mstsc -> %s:%s\n' "$TAILSCALE_IP" "$XRDP_PORT"
printf '  Arch     : xfreerdp /v:%s:%s /u:%s /dynamic-resolution\n' \
  "$TAILSCALE_IP" "$XRDP_PORT" "${NEW_USER:-TU_USUARIO}"
printf '\n  Estado   : sudo bash arrancar.sh\n'
printf '%s========================================================%s\n\n' "$C_BLUE" "$C_RESET"
