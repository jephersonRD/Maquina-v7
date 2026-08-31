#!/usr/bin/env bash
#
# Maquina-v7 :: setup_anydesk.sh
# Instala AnyDesk (escritorio remoto alternativo). Se ejecuta en celda aparte.
#
set -uo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🖥️  Instalando AnyDesk..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v anydesk >/dev/null 2>&1; then
  echo "   ℹ️ AnyDesk ya esta instalado"
  anydesk --version 2>/dev/null | head -n1
  exit 0
fi

cd /tmp
DEB="anydesk_amd64.deb"

# Intento 1: enlace directo a la ultima version estable
URL="https://download.anydesk.com/linux/anydesk_amd64.deb"
if ! wget -q -O "$DEB" "$URL"; then
  echo "   ↳ enlace directo fallo, buscando version en la pagina oficial..."
  VER=$(curl -fsSL https://anydesk.com/en/downloads/linux 2>/dev/null \
        | grep -oE 'anydesk_[0-9.]+\-[0-9]+_amd64\.deb' | head -n1)
  if [ -n "$VER" ]; then
    echo "   ↳ version detectada: $VER"
    wget -q -O "$DEB" "https://download.anydesk.com/linux/$VER" \
      || echo "   ⚠️ no se pudo descargar AnyDesk"
  else
    echo "   ⚠️ no se encontro la version de AnyDesk en la pagina"
  fi
fi

if [ -s "$DEB" ]; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y "./$DEB" 2>/dev/null \
    || (dpkg -i "./$DEB" 2>/dev/null; apt-get -f install -y)
  if command -v anydesk >/dev/null 2>&1; then
    echo "   ✅ AnyDesk instalado"
    anydesk --version 2>/dev/null | head -n1
  else
    echo "   ⚠️ AnyDesk no se pudo instalar (revisa la descarga / red)"
  fi
else
  echo "   ⚠️ No se descargo el paquete AnyDesk"
fi
