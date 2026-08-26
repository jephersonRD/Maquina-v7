#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Maquina-v7 :: run_v7.py
# Orquestador para Google Colab con barras de progreso y keep-alive reforzado.
# Uso:  %run run_v7.py
#
import os
import re
import sys
import time
import base64
import struct
import subprocess
import threading


def _bar(pct, texto, width=24):
    f = max(0, min(100, pct)) * width // 100
    bar = "█" * f + "░" * (width - f)
    print(f"\n║ [{bar}] {pct:3d}%  {texto}")
    print("╚" + "═" * (width + 12))


def _silent_wav_b64():
    sr, dur = 8000, 1
    data = bytes(sr * dur * 2)
    hdr = (b'RIFF' + struct.pack('<I', 36 + len(data)) + b'WAVE'
           + b'fmt ' + struct.pack('<IHHIIHH', 16, 1, 1, sr, sr * 2, 2, 16)
           + b'data' + struct.pack('<I', len(data)))
    return base64.b64encode(hdr + data).decode()


def _keepalive():
    # 1) Audio en silencio en loop (mantiene la pagina "activa")
    try:
        from IPython.display import display, HTML
        uri = "data:audio/wav;base64," + _silent_wav_b64()
        display(HTML(
            '<b>🔊 Mantén esta pestaña ABIERTA y el audio en reproducción.</b><br/>'
            f'<audio autoplay src="{uri}" loop controls></audio>'))
    except Exception:
        pass
    # 2) JavaScript: simula actividad de raton para enganar el detector de
    #    inactividad de Colab (evita desconexion mientras la celda trabaja)
    try:
        from IPython.display import Javascript
        display(Javascript(
            "setInterval(function(){try{"
            "window.dispatchEvent(new Event('mousemove'));"
            "window.dispatchEvent(new Event('mousedown'));"
            "}catch(e){}}, 20000);"))
    except Exception:
        pass
    # 3) Heartbeat de red cada 60s
    def _hb():
        while True:
            time.sleep(60)
            try:
                subprocess.run("curl -s -o /dev/null -m 5 https://www.google.com",
                               shell=True, check=False)
            except Exception:
                pass
            print("♥ keep-alive " + time.strftime('%H:%M:%S'))
    threading.Thread(target=_hb, daemon=True).start()


def _run(cmd, timeout=1800, live=True):
    print("\n>> " + cmd)
    if live:
        # Muestra la salida en vivo (hereda la terminal de la celda)
        subprocess.run(cmd, shell=True, check=False, timeout=timeout)
    else:
        r = subprocess.run(cmd, shell=True, check=False, capture_output=True, text=True,
                           timeout=timeout)
        return r.stdout.strip()


def _ensure_scripts():
    base = "/content/Maquina-v7"
    sd = os.path.join(base, "scripts")
    needed = ["setup_rdp.sh", "setup_tailscale.sh", "install_steam.sh"]
    if all(os.path.isfile(os.path.join(sd, s)) for s in needed):
        return sd
    if not os.path.isdir(base):
        print("   ↳ clonando repo...")
        if subprocess.run(f"git clone https://github.com/jephersonRD/Maquina-v7.git {base}",
                          shell=True, check=False, capture_output=True).returncode == 0:
            if all(os.path.isfile(os.path.join(sd, s)) for s in needed):
                return sd
    os.makedirs(sd, exist_ok=True)
    for s in needed:
        url = f"https://raw.githubusercontent.com/jephersonRD/Maquina-v7/main/scripts/{s}"
        print(f"   ↳ descargando {s}...")
        _run(f"curl -fsSL {url} -o {os.path.join(sd, s)}", live=False)
    return sd


def _start_cloudflared():
    print("   ↳ descargando cloudflared...")
    _run("curl -fsSL# https://github.com/cloudflare/cloudflared/releases/latest/download/"
         "cloudflared-linux-amd64 -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared",
         live=False)
    print("   ↳ abriendo tunel publico TCP -> 3389 (espera ~10s)...")
    proc = subprocess.Popen("cloudflared tunnel --url tcp://localhost:3389",
                             shell=True, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, text=True)
    found = {}
    def _reader():
        for line in proc.stdout:
            print("   cloudflared:", line.rstrip())
            m = re.search(r'tcp://([A-Za-z0-9.\-]+):(\d+)', line)
            if m and "host" not in found:
                found["host"] = m.group(1)
                found["port"] = m.group(2)
    threading.Thread(target=_reader, daemon=True).start()
    for _ in range(45):
        if "host" in found:
            break
        time.sleep(1)
    return found.get("host"), found.get("port")


def main():
    print("╔" + "═" * 56)
    print("║   MAQUINA-v7  ·  Cloud PC Linux + xrdp en Google Colab")
    print("╚" + "═" * 56)
    _keepalive()

    USERNAME = input("\n👤 Usuario del escritorio RDP [v7user]: ").strip() or "v7user"
    PASSWORD = input("🔑 Contraseña [v7pass]: ").strip() or "v7pass"
    print("\n🌐 Método de red para conectar desde Android:")
    print("   1) Tailscale  (authkey gratis, red privada)")
    print("   2) Cloudflare (túnel público automático, SIN cuenta)  ← fácil")
    print("   3) Solo local (no conectable desde fuera)")
    metodo = input("Elige [2]: ").strip() or "2"
    steam = input("🎮 ¿Instalar Steam para juegos? (s/n) [n]: ").strip().lower().startswith('s')

    total = 5
    # FASE 1
    _bar(20, "DESCARGANDO SCRIPTS")
    sd = _ensure_scripts()
    os.chdir(sd)

    # FASE 2
    _bar(40, "INSTALANDO ESCRITORIO Xfce + xrdp (2-5 min)")
    _run(f"bash setup_rdp.sh {USERNAME} {PASSWORD} 1920x1080")

    # FASE 3
    _bar(60, "CONFIGURANDO RED / TÚNEL")
    host = port = None
    if metodo == "1":
        TS = input("🌐 Tailscale authkey: ").strip()
        _run(f'bash setup_tailscale.sh "{TS}"' if TS else "bash setup_tailscale.sh")
        out = _run("tailscale ip -4 2>/dev/null | head -n1", live=False)
        if out:
            host, port = out, "3389"
    elif metodo == "2":
        host, port = _start_cloudflared()
    else:
        print("   ℹ️ solo local.")

    # FASE 4
    if steam:
        _bar(80, "INSTALANDO STEAM (1-3 min)")
        _run("bash install_steam.sh")
    else:
        _bar(80, "OMITIENDO STEAM")

    # FASE 5
    _bar(100, "LISTO")
    print("\n" + "=" * 56)
    print("  ✅ MAQUINA-v7 LISTA")
    print("  Usuario : " + USERNAME)
    print("  Puerto local: 3389")
    if host and port:
        print("-" * 56)
        print("  📱 PON ESTO EN 'Microsoft Remote Desktop' (Android):")
        print("     Dirección : " + host)
        print("     Puerto    : " + port)
        print("     Usuario   : " + USERNAME)
        print("     (o directo: " + host + ":" + port + ")")
        with open("/content/Maquina-v7/CONEXION.txt", "w") as f:
            f.write(f"{host}:{port} | usuario: {USERNAME}\n")
    else:
        local = _run("hostname -I 2>/dev/null", live=False)
        print("  [!] Sin red/túnel: no accesible desde Android. IP local: " + str(local))
    print("=" * 56)
    print("  ⚠️ No CIERRES la pestaña de Colab (mínimala, no la cierres).")


if __name__ == "__main__":
    main()
