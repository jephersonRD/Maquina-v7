#!/usr/bin/env bash
#
# Maquina Virtual v7 - arranque y estado
# Levanta xrdp y Tailscale si estan parados y muestra como conectarte.
#
set -Eeuo pipefail

XRDP_PORT="3389"

C_RESET=$'\033[0m'
C_BLUE=$'\033[1;34m'
C_GREEN=$'\033[1;32m'
C_YELLOW=$'\033[1;33m'
C_RED=$'\033[1;31m'

log()  { printf '%s==>%s %s\n' "$C_BLUE"   "$C_RESET" "$*"; }
ok()   { printf '%s  ok%s %s\n' "$C_GREEN"  "$C_RESET" "$*"; }
warn() { printf '%s  !!%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
die()  { printf '%sERROR%s %s\n' "$C_RED"   "$C_RESET" "$*" >&2; exit 1; }

if [ "${EUID}" -ne 0 ]; then
  exec sudo -E bash "$0" "$@"
fi

command -v xrdp >/dev/null 2>&1 || die "xrdp no esta instalado, ejecuta primero: sudo bash instalar.sh"

# El puerto real sale de la config de xrdp, no de una constante
if [ -f /etc/xrdp/xrdp.ini ]; then
  CONFIG_PORT="$(grep -m1 '^port=' /etc/xrdp/xrdp.ini | cut -d= -f2 | tr -d ' ')"
  [ -n "$CONFIG_PORT" ] && XRDP_PORT="$CONFIG_PORT"
fi

log "levantando xrdp"
systemctl enable xrdp >/dev/null 2>&1 || true
systemctl restart xrdp
if systemctl is-active --quiet xrdp; then
  ok "xrdp escuchando en el puerto ${XRDP_PORT}"
else
  warn "xrdp no arranco; revisa: journalctl -u xrdp -n 50 --no-pager"
fi

TAILSCALE_IP=""
if command -v tailscale >/dev/null 2>&1; then
  log "levantando Tailscale"
  systemctl enable --now tailscaled >/dev/null 2>&1 || true

  if tailscale status >/dev/null 2>&1; then
    TAILSCALE_IP="$(tailscale ip -4 2>/dev/null | head -n1 || true)"
    ok "Tailscale conectado"
  else
    warn "Tailscale sin autenticar: sudo tailscale up --ssh"
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
