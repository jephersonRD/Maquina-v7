#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Maquina-v7 :: run_v7.py
# Orquestador para Google Colab. Config por variables de entorno.
# Muestra spinner en tiempo real mientras instala y verifica Tailscale.
# Uso:  %run run_v7.py
#
import os
import re
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
    try:
        from IPython.display import display, HTML
        uri = "data:audio/wav;base64," + _silent_wav_b64()
        display(HTML(
            '<b>🔊 Mantén esta pestaña ABIERTA y el audio en reproducción.</b><br/>'
            f'<audio autoplay src="{uri}" loop controls></audio>'))
    except Exception:
        pass
    try:
        from IPython.display import Javascript
        display(Javascript(
            "setInterval(function(){try{"
            "window.dispatchEvent(new Event('mousemove'));"
            "window.dispatchEvent(new Event('mousedown'));"
            "}catch(e){}}, 20000);"))
    except Exception:
        pass
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


def _spin(stop, text):
    frames = "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    i = 0
    while not stop.is_set():
        print(f"\r   {frames[i % len(frames)]} {text}", end="", flush=True)
        i += 1
        time.sleep(0.1)
    print("\r   " + " " * 50 + "\r", end="")


def _run_spin(cmd, label="instalando", timeout=1800):
    print("\n>> " + cmd)
    stop = threading.Event()
    t = threading.Thread(target=_spin, args=(stop, label))
    t.start()
    r = subprocess.run(cmd, shell=True, check=False,
                       capture_output=True, text=True, timeout=timeout)
    stop.set()
    t.join()
    if r.returncode == 0:
        print("   ✅ listo")
    else:
        print("   ❌ fallo (rc=%d)" % r.returncode)
        out = (r.stderr or r.stdout or "")
        print("   ── últimas líneas del error ──")
        print("\n".join(out.strip().splitlines()[-25:]))
    return r.returncode


def _run_live(cmd):
    print("\n>> " + cmd)
    subprocess.run(cmd, shell=True, check=False)


def _ensure_scripts():
    base = "/content/Maquina-v7"
    sd = os.path.join(base, "scripts")
    os.makedirs(sd, exist_ok=True)
    for s in ["setup_rdp.sh", "setup_tailscale.sh", "install_steam.sh"]:
        url = f"https://raw.githubusercontent.com/jephersonRD/Maquina-v7/main/scripts/{s}"
        print(f"   ↳ descargando {s} ...")
        subprocess.run(f"curl -fsSL {url} -o {os.path.join(sd, s)}",
                       shell=True, check=False)
    return sd


def _start_cloudflared():
    print("   ↳ descargando cloudflared...")
    subprocess.run(
        "curl -fsSL# https://github.com/cloudflare/cloudflared/releases/latest/download/"
        "cloudflared-linux-amd64 -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared",
        shell=True, check=False)
    print("   ↳ abriendo túnel público TCP -> 3389 (espera ~10s)...")
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
    USERNAME = os.environ.get("MV7_USER", "v7user").strip() or "v7user"
    PASSWORD = os.environ.get("MV7_PASS", "v7pass").strip() or "v7pass"
    NET = (os.environ.get("MV7_NET", "2") or "2").strip()
    TS = os.environ.get("MV7_TS", "").strip()
    STEAM = os.environ.get("MV7_STEAM", "1") == "1"

    print("╔" + "═" * 56)
    print("║   MAQUINA-v7  ·  Cloud PC Linux + xrdp en Google Colab")
    print("╚" + "═" * 56)
    _keepalive()

    _bar(20, "DESCARGANDO SCRIPTS")
    sd = _ensure_scripts()
    os.chdir(sd)

    _bar(40, "INSTALANDO Xfce + xrdp")
    _run_spin(f"bash setup_rdp.sh {USERNAME} {PASSWORD} 1920x1080",
              label="instalando escritorio (2-5 min)")

    _bar(60, "CONFIGURANDO RED / TÚNEL")
    host = port = None
    if NET == "1":
        _run_live(f'bash setup_tailscale.sh "{TS}"' if TS else "bash setup_tailscale.sh")
        out = subprocess.run("tailscale ip -4 2>/dev/null | head -n1",
                             shell=True, capture_output=True, text=True).stdout.strip()
        if out:
            host, port = out, "3389"
            print("   ✅ Tailscale conectado. IP:", host)
        else:
            print("   ⚠️ Tailscale NO conectó. Revisa el authkey arriba y tu")
            print("      lista de dispositivos en https://login.tailscale.com")
    elif NET == "2":
        host, port = _start_cloudflared()
    else:
        print("   ℹ️ solo local.")

    if STEAM:
        _bar(80, "INSTALANDO STEAM")
        _run_spin("bash install_steam.sh", label="instalando Steam (1-3 min)")
    else:
        _bar(80, "OMITIENDO STEAM")

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
        local = subprocess.run("hostname -I 2>/dev/null", shell=True,
                               capture_output=True, text=True).stdout.strip()
        print("  [!] Sin red/túnel: no accesible desde Android. IP local: " + str(local))
    print("=" * 56)
    print("  ⚠️ No CIERRES la pestaña de Colab (mínimala, no la cierres).")


if __name__ == "__main__":
    main()
