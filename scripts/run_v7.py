#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Maquina-v7 :: run_v7.py
# Orquestador "pegado y ejecutado" en Google Colab.
# Monta el entorno RDP (xrdp + Xfce), conecta Tailscale y (opcional)
# instala Steam. Pide usuario/contraseña/authkey de forma interactiva.
#
# Se ejecuta en Colab con:
#   %run run_v7.py
# (los input() funcionan porque %run usa el kernel interactivo)
#
import os
import sys
import time
import base64
import struct
import subprocess
import threading


def _silent_wav_b64():
    sr, dur = 8000, 1
    data = bytes(sr * dur * 2)  # 16-bit silence
    hdr = (b'RIFF' + struct.pack('<I', 36 + len(data)) + b'WAVE'
           + b'fmt ' + struct.pack('<IHHIIHH', 16, 1, 1, sr, sr * 2, 2, 16)
           + b'data' + struct.pack('<I', len(data)))
    return base64.b64encode(hdr + data).decode()


def _keepalive():
    try:
        from IPython.display import display, HTML
        uri = "data:audio/wav;base64," + _silent_wav_b64()
        display(HTML(
            '<b>🔊 Mantén este audio en reproducción para evitar que Colab '
            'cierre la sesión.</b><br/>'
            f'<audio autoplay src="{uri}" loop controls></audio>'))
    except Exception:
        pass
    def _hb():
        while True:
            time.sleep(60)
            print("♥ keep-alive", time.strftime('%H:%M:%S'))
    threading.Thread(target=_hb, daemon=True).start()


def _run(cmd):
    print("\n>> " + cmd)
    subprocess.run(cmd, shell=True, check=False)


def main():
    print("===================================================")
    print("  Maquina-v7 :: arrancando escritorio RDP en Colab")
    print("===================================================")
    _keepalive()

    USERNAME = input("👤 Usuario para el escritorio RDP [v7user]: ").strip() or "v7user"
    PASSWORD = input("🔑 Contraseña [v7pass]: ").strip() or "v7pass"
    TS = input("🌐 Tailscale authkey (deja vacío para modo QR): ").strip()
    steam = input("🎮 ¿Instalar Steam para juegos? (s/n) [n]: ").strip().lower().startswith('s')

    # Clonar el repo para tener los scripts
    if not os.path.isdir('/content/Maquina-v7'):
        _run("git clone https://github.com/jephersonRD/Maquina-v7.git /content/Maquina-v7")
    os.chdir('/content/Maquina-v7/scripts')

    # 1) Escritorio RDP
    _run(f"bash setup_rdp.sh {USERNAME} {PASSWORD} 1920x1080")

    # 2) Tailscale
    if TS:
        _run(f'bash setup_tailscale.sh "{TS}"')
    else:
        _run("bash setup_tailscale.sh")

    # 3) Steam (si hay GPU)
    if steam:
        _run("bash install_steam.sh")

    # 4) Datos de conexion
    print("\n===================================================")
    print("  ✅ Listo. Datos de conexion RDP")
    print("  Puerto : 3389")
    try:
        ip = subprocess.run("tailscale ip -4 2>/dev/null | head -n1",
                            shell=True, capture_output=True, text=True).stdout.strip()
    except Exception:
        ip = ""
    if ip:
        print("  IP     : " + ip + "  (usa esta en tu cliente de Android)")
    else:
        print("  Tailscale: no conectado (usa la IP que muestre arriba o expón el 3389).")
    print("---------------------------------------------------")
    print("  En Android: abre 'Microsoft Remote Desktop' ->")
    print("    Dirección = " + (ip or "<IP Tailscale>") + "  |  Usuario = " + USERNAME)
    print("    Puerto 3389. ¡Disfruta tu Maquina-v7!")
    print("===================================================")


if __name__ == "__main__":
    main()
