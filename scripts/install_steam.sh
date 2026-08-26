#!/usr/bin/env bash
#
# Maquina-v7 :: install_steam.sh
# Instala Steam (Linux) dentro del escritorio. Muestra progreso.
# Si Colab da GPU, prepara gaming; si no, igual instala el cliente.
#
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🎮 Comprobando GPU..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  echo "   ✅ GPU NVIDIA detectada:"
  nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
  HAS_GPU=1
else
  echo "   ℹ️ Sin GPU: se instala Steam igual, pero sin aceleracion."
  HAS_GPU=0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📦 Instalando Steam (puede tardar 1-3 min)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
apt-get update -y
apt-get install -y steam

if [ "$HAS_GPU" = "1" ]; then
  echo "   ↳ instalando drivers de usuario NVIDIA..."
  apt-get install -y libnvidia-gl-* nvidia-utils-* >/dev/null 2>&1 || true
  echo "   ✅ Listo para jugar. Abre Steam desde el menu de Xfce."
else
  echo "   ✅ Steam instalado (modo CPU). Para gaming necesitas sesion con GPU."
fi
