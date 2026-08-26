#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Maquina-v7 :: run_v7.py
# Orquestador "pegado y ejecutado" en Google Colab.
# Instala Xfce + xrdp y te da una IP real para conectar desde Android
# (via Tailscale o, sin cuenta, via tunel TCP de Cloudflare).
#
# Usar en Colab con:  %run run_v7.py
#
import os
import re
import sys
import time
import base64
import struct
import subprocess
import threading


def _silent_wav_b64():
    sr, dur = 8000, 1
    data = bytes(sr * dur * 2)
    hdr = (b'RIFF' + struct.pack('<I', 36 + len(data)) + b'WAVE'
           + b'fmt ' + struct.pack('<IHHIIHH', 16, 1, 1, sr, sr * 2, 2, 16)
           + b'data' + struct.pack('<I', len(data)))
    return base64.b64encode(hdr + data).decode()


def _keepalive():
    try:
        from IPython.display import display, HTML
        uri = "data:audio/wav;base64," + _silent_wav_b64()
        display(HTML(
            '<b>🔊 Mantén esta pestaña ABIERTA y el audio en reproducción para '
            'evitar que Colab cierre la sesión.</b><br/>'
            f'<audio autoplay src="{uri}" loop controls></audio>'))
    except Exception:
        pass
    # heartbeat de red para mantener actividad
    def _hb():
        while True:
            time.sleep(60)
            try:
                subprocess.run("curl -s -o /dev/null -m 5 https://www.google.com",
                               shell=True, check=False)
            except Exception:
                pass
            print("♥ keep-alive", time.strftime('%H:%M:%S'))
    threading.Thread(target=_hb, daemon=True).start()


def _run(cmd, timeout=900):
    print("\n>> " + cmd)
    try:
        subprocess.run(cmd, shell=True, check=False, timeout=timeout)
    except Exception as e:
        print("[!] error ejecutando comando:", e)


def _ensure_scripts():
    """Clona el repo; si falla, descarga los scripts uno a uno."""
    base = "/content/Maquina-v7"
    scripts_dir = os.path.join(base, "scripts")
    needed = ["setup_rdp.sh", "setup_tailscale.sh", "install_steam.sh"]
    if all(os.path.isfile(os.path.join(scripts_dir, s)) for s in needed):
        return scripts_dir
    if not os.path.isdir(base):
        print("[*] Clonando repo...")
        if subprocess.run(f"git clone https://github.com/jephersonRD/Maquina-v7.git {base}",
                          shell=True, check=False).returncode == 0:
            if all(os.path.isfile(os.path.join(scripts_dir, s)) for s in needed):
                return scripts_dir
    # Respaldo: descarga directa
    os.makedirs(scripts_dir, exist_ok=True)
    for s in needed:
        url = f"https://raw.githubusercontent.com/jephersonRD/Maquina-v7/main/scripts/{s}"
        _run(f"curl -fsSL {url} -o {os.path.join(scripts_dir, s)}")
    return scripts_dir


def _start_cloudflared():
    """Crea un tunel TCP publico al puerto 3389 y devuelve (host, port)."""
    _run("curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/"
         "cloudflared-linux-amd64 -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared")
    print("[*] Creando tunel publico TCP -> 3389 (espera ~10s)...")
    proc = subprocess.Popen("cloudflared tunnel --url tcp://localhost:3389",
                             shell=True, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, text=True)
    found = {}
    def _reader():
        for line in proc.stdout:
            print(line.rstrip())
            m = re.search(r'tcp://([A-Za-z0-9.\-]+):(\d+)', line)
            if m and "found" not in found:
                found["host"] = m.group(1)
                found["port"] = m.group(2)
    threading.Thread(target=_reader, daemon=True).start()
    for _ in range(40):
        if "host" in found:
            break
        time.sleep(1)
    return found.get("host"), found.get("port")


def main():
    print("=" * 52)
    print("  Maquina-v7 :: escritorio RDP en Google Colab")
    print("=" * 52)
    _keepalive()

    USERNAME = input("👤 Usuario del escritorio RDP [v7user]: ").strip() or "v7user"
    PASSWORD = input("🔑 Contraseña [v7pass]: ").strip() or "v7pass"
    print("\n🌐 ¿Cómo quieres conectarte desde Android?")
    print("  1) Tailscale  (authkey gratis, red privada)")
    print("  2) Cloudflare (túnel público automático, SIN cuenta)  ← fácil")
    print("  3) Solo local (no conectable desde Android)")
    metodo = input("Elige [2]: ").strip() or "2"

    scripts = _ensure_scripts()
    os.chdir(scripts)

    # 1) Escritorio RDP
    _run(f"bash setup_rdp.sh {USERNAME} {PASSWORD} 1920x1080")

    host = port = None
    if metodo == "1":
        TS = input("🌐 Tailscale authkey: ").strip()
        _run(f'bash setup_tailscale.sh "{TS}"' if TS else "bash setup_tailscale.sh")
        out = subprocess.run("tailscale ip -4 2>/dev/null | head -n1",
                             shell=True, capture_output=True, text=True).stdout.strip()
        if out:
            host, port = out, "3389"
    elif metodo == "2":
        host, port = _start_cloudflared()
    else:
        print("[i] Modo solo local.")

    # 2) Steam opcional
    steam = input("\n🎮 ¿Instalar Steam para juegos? (s/n) [n]: ").strip().lower().startswith('s')
    if steam:
        _run("bash install_steam.sh")

    # 3) Resumen claro para el usuario
    print("\n" + "=" * 52)
    print("  ✅ MAQUINA-V7 LISTA")
    print("  Usuario : " + USERNAME)
    print("  Puerto local: 3389")
    if host and port:
        print("-" * 52)
        print("  📱 PON ESTO EN 'Microsoft Remote Desktop' (Android):")
        print("     Dirección : " + host)
        print("     Puerto    : " + port)
        print("     Usuario   : " + USERNAME)
        print("  (o pega directo: " + host + ":" + port + ")")
        with open("/content/Maquina-v7/CONEXION.txt", "w") as f:
            f.write(f"{host}:{port} | usuario: {USERNAME}\n")
    else:
        local = subprocess.run("hostname -I 2>/dev/null", shell=True,
                                capture_output=True, text=True).stdout.strip()
        print("  [!] Sin red/túnel: no es accesible desde Android.")
        print("      IP local: " + local + " (solo dentro de la misma red)")
    print("=" * 52)
    print("  ⚠️ No CIERRES la pestaña de Colab (mínimala, pero no la cierres).")


if __name__ == "__main__":
    main()
