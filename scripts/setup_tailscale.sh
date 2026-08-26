#!/usr/bin/env bash
#
# Maquina-v7 :: setup_tailscale.sh  (robusto para contenedores Colab)
# Instala Tailscale, une la maquina a tu tailnet y muestra la IP.
# Uso: bash setup_tailscale.sh <AUTHKEY>
#
set -u
AUTHKEY="${1:-}"
SOCK="/var/run/tailscale/tailscaled.sock"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🌐 Instalando Tailscale"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if ! command -v tailscale >/dev/null 2>&1; then
  echo "   ↳ descargando installer oficial..."
  curl -fsSL https://tailscale.com/install.sh -o /tmp/ts_install.sh
  sh /tmp/ts_install.sh >/tmp/ts_install.log 2>&1 \
    || (apt-get update -y && apt-get install -y tailscale)
fi

if ! command -v tailscale >/dev/null 2>&1; then
  echo "   ❌ No se pudo instalar Tailscale. Revisa /tmp/ts_install.log"
  echo "      (¿la sesion tiene salida a internet? ¿apt funciona?)"
  exit 1
fi
echo "   ✅ tailscale instalado: $(command -v tailscale)"

mkdir -p /var/lib/tailscale /var/run/tailscale
pkill -x tailscaled 2>/dev/null; sleep 1

echo "   ↳ arrancando tailscaled (userspace)..."
tailscaled --tun=userspace-networking \
  --state=/var/lib/tailscale/tailscaled.state \
  --socket="$SOCK" >/tmp/tailscaled.log 2>&1 &
sleep 5

echo "   ↳ uniendo a la tailnet..."
if [ -n "$AUTHKEY" ]; then
  tailscale --socket="$SOCK" up --authkey="$AUTHKEY" \
    --hostname=maquina-v7 --accept-routes --netfilter-mode=off \
    && echo "   ✅ conectado con authkey" \
    || echo "   ❌ fallo al conectar. ¿authkey valido? log: tail /tmp/tailscaled.log"
else
  echo "   (sin authkey) mostrando QR para escanear con tu cuenta:"
  tailscale --socket="$SOCK" up --hostname=maquina-v7 --accept-routes --netfilter-mode=off --qr 2>/dev/null \
    || tailscale --socket="$SOCK" up --hostname=maquina-v7 --accept-routes --netfilter-mode=off
fi

sleep 3
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Estado de Tailscale:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
tailscale --socket="$SOCK" status 2>&1 | head -20
TS_IP=$(tailscale --socket="$SOCK" ip -4 2>/dev/null | head -n1)
echo "IP de esta maquina en tu red: ${TS_IP:-<no conectado>}"
echo "${TS_IP}" > /tmp/maquina_v7_ts_ip.txt
