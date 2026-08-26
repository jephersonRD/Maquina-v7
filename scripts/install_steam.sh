#!/usr/bin/env bash
#
# Maquina-v7 :: install_steam.sh
# Instala Steam (Linux). Habilita multiverse si hace falta.
#
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🎮 Comprobando GPU..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi >/dev/null 2>&1; then
  echo "   ✅ GPU NVIDIA detectada:"
  nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
  HAS_GPU=1
else
  echo "   ℹ️ Sin GPU: Steam igual se instala (modo CPU)."
  HAS_GPU=0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📦 Instalando Steam (puede tardar 1-3 min)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# Steam esta en multiverse
add-apt-repository -y multiverse >/dev/null 2>&1
apt-get update -y
for i in 1 2 3; do
  if apt-get install -y steam; then
    echo "   ✅ Steam instalado"; break
  fi
  echo "   ⚠️ reintento $i..."; sleep 3
done

if [ "$HAS_GPU" = "1" ]; then
  echo "   ↳ drivers de usuario NVIDIA..."
  apt-get install -y libnvidia-gl-* nvidia-utils-* >/dev/null 2>&1 || true
  echo "   ✅ Listo para jugar. Abre Steam desde el menu de Xfce."
else
  echo "   ✅ Steam instalado. Para gaming necesitas sesion con GPU."
fi
