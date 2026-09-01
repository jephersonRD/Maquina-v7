#!/usr/bin/env bash
# setup_guacamole.sh - Instala Apache Guacamole (guacd + web app)
# Uso: bash setup_guacamole.sh
set -uo pipefail

GUAC_VERSION="1.5.5"
GUAC_DIR="/opt/guacamole"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🌐 Instalando Apache Guacamole ${GUAC_VERSION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# [1/5] Java
echo "   ↳ [1/5] Instalando Java..."
apt-get install -y --no-install-recommends openjdk-17-jre-headless 2>/dev/null || \
apt-get install -y --no-install-recommends openjdk-11-jre-headless 2>/dev/null || \
{ echo "❌ No se pudo instalar Java"; exit 1; }
echo "      ✅ Java: $(java -version 2>&1 | head -1)"

# [2/5] Dependencias de compilacion
echo "   ↳ [2/5] Instalando dependencias de compilacion..."
apt-get install -y --no-install-recommends \
  build-essential \
  libcairo2-dev libjpeg-turbo8-dev libpng-dev libtool-bin \
  libossp-uuid-dev libpango1.0-dev libssh2-1-dev \
  libvncserver-dev libwebsockets-dev libpulse-dev libssl-dev \
  libvorbis-dev libwebp-dev \
  libavcodec-dev libavformat-dev libavutil-dev libswscale-dev \
  freerdp2-dev \
  || { echo "❌ fallo al instalar dependencias"; exit 1; }
echo "      ✅ Dependencias instaladas"

# [3/5] Compilar guacd
echo "   ↳ [3/5] Compilando guacd (puede tardar 3-5 min)..."
cd /tmp
rm -rf guacamole-server-* guacamole-server.tar.gz 2>/dev/null

curl -L -o guacamole-server.tar.gz \
  "https://archive.apache.org/dist/guacamole/${GUAC_VERSION}/source/guacamole-server-${GUAC_VERSION}.tar.gz" 2>/dev/null

if [ ! -f guacamole-server.tar.gz ]; then
  echo "   ❌ Error al descargar guacamole-server"
  exit 1
fi

tar -xzf guacamole-server.tar.gz
cd guacamole-server-${GUAC_VERSION}

./configure --with-init-dir=/etc/init.d --disable-guacenc 2>&1 | tail -5
make -j$(nproc) 2>&1 | tail -5
make install 2>&1 | tail -5
ldconfig

cd /tmp
rm -rf guacamole-server-* guacamole-server.tar.gz

if ! command -v guacd >/dev/null 2>&1; then
  echo "   ❌ guacd no se pudo compilar"
  exit 1
fi
echo "      ✅ guacd: $(command -v guacd)"

# [4/5] Instalar Tomcat
echo "   ↳ [4/5] Instalando Tomcat..."
apt-get install -y --no-install-recommends tomcat9 2>/dev/null || \
{ echo "❌ No se pudo instalar Tomcat"; exit 1; }
echo "      ✅ Tomcat instalado"

# [5/5] Desplegar Guacamole
echo "   ↳ [5/5] Desplegando Guacamole web app..."
mkdir -p ${GUAC_DIR}

curl -L -o /tmp/guacamole.war \
  "https://archive.apache.org/dist/guacamole/${GUAC_VERSION}/binary/guacamole-${GUAC_VERSION}.war" 2>/dev/null

if [ ! -f /tmp/guacamole.war ]; then
  echo "   ❌ Error al descargar Guacamole WAR"
  exit 1
fi

rm -rf /var/lib/tomcat9/webapps/ROOT 2>/dev/null
cp /tmp/guacamole.war /var/lib/tomcat9/webapps/ROOT.war
rm -f /tmp/guacamole.war

mkdir -p /etc/guacamole

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Apache Guacamole instalado"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
