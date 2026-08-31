#!/usr/bin/env bash
# xrdp-launch.sh - Reinicia XRDP y Xvfb si caen (bucle de keep-alive)
# Funciona en Colab (sin systemd) usando los binarios directamente
while true; do
  # Verificar y reiniciar Xvfb si es necesario
  if ! pgrep -x Xvfb >/dev/null 2>&1; then
    echo "$(date): Reiniciando Xvfb..."
    Xvfb :10 -screen 0 1920x1080x24 -ac +extension GLX +render -noreset &
    sleep 2
  fi
  
  # Verificar y reiniciar XRDP si es necesario
  if ! pgrep -x xrdp >/dev/null 2>&1; then
    echo "$(date): Reiniciando XRDP..."
    /usr/sbin/xrdp-sesman 2>/dev/null || true
    sleep 1
    /usr/sbin/xrdp 2>/dev/null || true
  fi
  sleep 10
done
