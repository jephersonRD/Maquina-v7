#!/usr/bin/env bash
# xrdp-launch.sh - Reinicia XRDP si cae (bucle de keep-alive)
# Funciona en Colab (sin systemd) usando los binarios directamente
while true; do
  if ! pgrep -x xrdp >/dev/null 2>&1; then
    /usr/sbin/xrdp-sesman 2>/dev/null || true
    sleep 1
    /usr/sbin/xrdp 2>/dev/null || true
  fi
  sleep 10
done
