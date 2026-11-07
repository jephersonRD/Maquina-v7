#!/usr/bin/env bash
#
# Maquina Virtual v7 - arranque y estado
# Levanta xrdp y Tailscale si estan parados y muestra como conectarte.
# Funciona con systemd y tambien en contenedores donde no lo hay.
#
set -Eeuo pipefail

XRDP_PORT="3389"
HAS_SYSTEMD=0

C_RESET=$'\033[0m'
C_BLUE=$'\033[1;34m'
C_GREEN=$'\033[1;32m'
C_YELLOW=$'\033[1;33m'
C_RED=$'\033[1;31m'

log()  { printf '%s==>%s %s\n' "$C_BLUE"   "$C_RESET" "$*"; }
ok()   { printf '%s  ok%s %s\n' "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf '%s  !!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
die()  { printf '%sERROR%s %s\n' "$C_RED"   "$C_RESET" "$*" >&2; exit 1; }

# Misma logica que instalar.sh: systemd -> init.d -> demonio a mano
svc_restart() {
  local unit="$1"
  if [ "$HAS_SYSTEMD" -eq 1 ]; then
    systemctl restart "$unit" >/dev/null 2>&1 && return 0
    systemctl start "$unit"   >/dev/null 2>&1 && return 0
    return 1
  fi
  if [ -x "/etc/init.d/${unit}" ]; then
    service "$unit" restart >/dev/null 2>&1 && return 0
    service "$unit" start   >/dev/null 2>&1 && return 0
  fi
  return 1
}

xrdp_direct_start() {
  command -v xrdp >/dev/null 2>&1 || return 1
  pgrep -x xrdp >/dev/null 2>&1 && return 0
  if [ -x /usr/sbin/xrdp-sesman ] && ! pgrep -x xrdp-sesman >/dev/null 2>&1; then
    nohup /usr/sbin/xrdp-sesman >/dev/null 2>&1 &
    sleep 1
  fi
  [ -x /usr/sbin/xrdp ] && nohup /usr/sbin/xrdp >/dev/null 2>&1 &
  sleep 1
  pgrep -x xrdp >/dev/null 2>&1
}

tailscaled_direct_start() {
  command -v tailscaled >/dev/null 2>&1 || return 1
  pgrep -x tailscaled >/dev/null 2>&1 && return 0
  install -d -m 0755 /var/lib/tailscale /run/tailscale
  nohup tailscaled --state=/var/lib/tailscale/tailscaled.state \
    --socket=/run/tailscale/tailscaled.sock >/var/log/tailscaled.log 2>&1 &
  sleep 2
  pgrep -x tailscaled >/dev/null 2>&1
}

if [ "${EUID}" -ne 0 ]; then
  exec sudo -E bash "$0" "$@"
fi

if [ -d /run/systemd/system ]; then
  HAS_SYSTEMD=1
else
  warn "systemd no esta corriendo como PID 1 (contenedor): se arranca a mano"
fi

command -v xrdp >/dev/null 2>&1 || die "xrdp no esta instalado, ejecuta primero: sudo bash instalar.sh"

# El puerto real sale de la config de xrdp, no de una constante
if [ -f /etc/xrdp/xrdp.ini ]; then
  CONFIG_PORT="$(grep -m1 '^port=' /etc/xrdp/xrdp.ini | cut -d= -f2 | tr -d ' ')"
  [ -n "$CONFIG_PORT" ] && XRDP_PORT="$CONFIG_PORT"
fi

log "levantando xrdp"
if svc_restart xrdp; then
  ok "xrdp activo por el gestor de servicios"
elif xrdp_direct_start; then
  warn "xrdp lanzado a mano (sin gestor de servicios): no sobrevive a un reinicio"
else
  warn "xrdp no arranco; revisa /var/log/xrdp.log"
fi

if pgrep -x xrdp >/dev/null 2>&1; then
  ok "xrdp escuchando en el puerto ${XRDP_PORT}"
else
  warn "el proceso de xrdp no aparece; revisa /var/log/xrdp.log y /var/log/xrdp-sesman.log"
fi

TAILSCALE_IP=""
if command -v tailscale >/dev/null 2>&1; then
  log "levantando Tailscale"
  if ! svc_restart tailscaled; then
    tailscaled_direct_start >/dev/null 2>&1 || warn "tailscaled no arranco"
  fi

  if tailscale status >/dev/null 2>&1; then
    TAILSCALE_IP="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
    ok "Tailscale conectado"
  else
    warn "Tailscale sin autenticar: sudo tailscale up --authkey tskey-auth-... --ssh"
  fi
fi

if [ -z "$TAILSCALE_IP" ]; then
  TAILSCALE_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
fi
[ -n "$TAILSCALE_IP" ] || TAILSCALE_IP="<ip-de-la-maquina>"

printf '\n'
printf '%s--------------------------------------------------------%s\n' "$C_BLUE" "$C_RESET"
printf '  Servidor : %s:%s\n' "$TAILSCALE_IP" "$XRDP_PORT"
printf '  Usuarios : %s\n' "$(awk -F: '$3>=1000 && $3<60000 {printf "%s ", $1}' /etc/passwd)"
printf '  Windows  : mstsc -> %s:%s\n' "$TAILSCALE_IP" "$XRDP_PORT"
printf '  Arch     : xfreerdp /v:%s:%s /u:TU_USUARIO /dynamic-resolution\n' \
  "$TAILSCALE_IP" "$XRDP_PORT"
printf '%s--------------------------------------------------------%s\n\n' "$C_BLUE" "$C_RESET"
