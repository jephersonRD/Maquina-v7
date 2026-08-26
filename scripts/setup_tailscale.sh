#!/usr/bin/env bash
#
# Maquina-v7 :: setup_tailscale.sh
# Instala Tailscale en Colab y une la maquina a tu Tailnet para que
# puedas conectarte por RDP de forma segura desde Android / PC
# sin exponer puertos publicos.
#
# Uso:
#   bash setup_tailscale.sh <TAILSCALE_AUTHKEY>   (recomendado)
#   bash setup_tailscale.sh                        (modo QR: escanea con tu cuenta)
#
# Conseguir AUTHKEY gratis: https://login.tailscale.com/admin/settings/keys
#
set -euo pipefail

AUTHKEY="${1:-}"

echo "==================================================="
echo "  Maquina-v7 :: Configurando Tailscale"
echo "==================================================="

# 1) Instalar Tailscale
export DEBIAN_FRONTEND=noninteractive
if ! command -v tailscale >/dev/null 2>&1; then
    echo "[*] Instalando Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
fi

# 2) Arrancar tailscaled en modo userspace (compatible con contenedores Colab)
echo "[*] Iniciando tailscaled..."
pkill tailscaled 2>/dev/null || true
sleep 1
tailscaled --tun=userspace-networking --state=/var/lib/tailscale/tailscaled.state >/tmp/tailscaled.log 2>&1 &
sleep 3

# 3) Unirse a la tailnet
if [ -n "$AUTHKEY" ]; then
    echo "[*] Conectando con authkey..."
    tailscale up --authkey="$AUTHKEY" --hostname=maquina-v7 --accept-routes || \
    tailscale up --authkey="$AUTHKEY" --hostname=maquina-v7
else
    echo "[*] No se proporciono authkey -> mostrando QR para escanear"
    tailscale up --hostname=maquina-v7 --qr || tailscale up --hostname=maquina-v7
fi

sleep 3

# 4) Mostrar IP de Tailscale (esta es la que pondras en el cliente de Android)
TS_IP=$(tailscale ip -4 2>/dev/null | head -n1 || echo "")
echo "==================================================="
echo "  Tailscale listo."
echo "  IP de esta maquina en tu red: $TS_IP"
echo "  Conectate desde Android con 'Microsoft Remote Desktop'"
echo "  usando la IP $TS_IP  y puerto 3389."
echo "==================================================="
