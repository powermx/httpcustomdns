#!/usr/bin/env bash
set -euo pipefail

PATH="/usr/sbin:/usr/bin:/sbin:/bin"
export PATH

# =========================================================
# HCR SERVER - INSTALADOR AUTOMATICO
# =========================================================

REPO="https://raw.githubusercontent.com/powermx/httpcustomdns/main"

INSTALL_DIR="/etc/VpsPackdir/hcr"

INSTALLER_URL="${REPO}/install.sh"
BINARY_URL="${REPO}/hcr-server"

INSTALLER="${INSTALL_DIR}/install.sh"
BINARY="${INSTALL_DIR}/hcr-server"

PORT="${HCR_PORT:-8080}"
TRANSPORT="${HCR_TRANSPORT:-auto}"

SERVICE="hcr-server"

# =========================================================
# COLORES
# =========================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info() {
    echo -e "${CYAN}[HCR]${NC} $*"
}

ok() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
    exit 1
}

# =========================================================
# ROOT
# =========================================================

if [ "$(id -u)" -ne 0 ]; then
    error "Este instalador debe ejecutarse como root."
fi

# =========================================================
# DEPENDENCIAS
# =========================================================

command -v curl >/dev/null 2>&1 || error "curl no está instalado."
command -v chmod >/dev/null 2>&1 || error "chmod no está disponible."
command -v mkdir >/dev/null 2>&1 || error "mkdir no está disponible."

# =========================================================
# CREAR DIRECTORIO
# =========================================================

info "Creando directorio ${INSTALL_DIR}..."

mkdir -p "${INSTALL_DIR}"

chmod 700 "${INSTALL_DIR}"

# =========================================================
# DESCARGAR INSTALL.SH
# =========================================================

info "Descargando install.sh..."

if ! curl -fL --retry 3 --connect-timeout 10 \
    "${INSTALLER_URL}" \
    -o "${INSTALLER}"; then

    rm -f "${INSTALLER}"
    error "No se pudo descargar install.sh."
fi

chmod 700 "${INSTALLER}"

ok "install.sh descargado."

# =========================================================
# DESCARGAR HCR-SERVER
# =========================================================

info "Descargando hcr-server..."

if ! curl -fL --retry 3 --connect-timeout 10 \
    "${BINARY_URL}" \
    -o "${BINARY}"; then

    rm -f "${BINARY}"
    error "No se pudo descargar hcr-server."
fi

chmod 700 "${BINARY}"

ok "hcr-server descargado."

# =========================================================
# VALIDAR BINARIO
# =========================================================

info "Validando binario..."

if ! "${BINARY}" -version >/dev/null 2>&1; then
    rm -f "${BINARY}" "${INSTALLER}"
    error "El binario hcr-server no es compatible con esta arquitectura."
fi

VERSION="$("${BINARY}" -version 2>/dev/null || true)"

ok "Binario detectado: ${VERSION}"

# =========================================================
# INSTALAR
# =========================================================

info "Instalando HCR Server..."
echo

if ! bash "${INSTALLER}" \
    --port "${PORT}" \
    --transport "${TRANSPORT}"; then

    warn "La instalación falló."

    rm -f "${INSTALLER}"

    exit 1
fi

# =========================================================
# ELIMINAR INSTALADOR
# =========================================================

info "Eliminando archivos temporales..."

rm -f "${INSTALLER}"

# =========================================================
# ACTUALIZAR PERMISOS
# =========================================================

chmod 700 "${INSTALL_DIR}"
chmod 700 "${BINARY}"

# =========================================================
# VERIFICAR SERVICIO
# =========================================================

sleep 2

if systemctl is-active --quiet "${SERVICE}.service"; then

    ok "HCR Server está funcionando."

else

    warn "El servicio no está activo."

    systemctl status "${SERVICE}.service" \
        --no-pager \
        --full || true

    exit 1
fi

# =========================================================
# INFORMACION
# =========================================================

echo
echo "===================================================="
echo "          HCR SERVER INSTALADO CORRECTAMENTE"
echo "===================================================="
echo
echo "Directorio : ${INSTALL_DIR}"
echo "Binario    : ${BINARY}"
echo "Servicio   : ${SERVICE}"
echo "Puerto     : ${PORT}"
echo "Transport  : ${TRANSPORT}"
echo
echo "Estado:"
systemctl is-active "${SERVICE}.service"
echo
echo "Comandos útiles:"
echo
echo "  systemctl status ${SERVICE}"
echo "  systemctl restart ${SERVICE}"
echo "  systemctl stop ${SERVICE}"
echo "  journalctl -u ${SERVICE} -f"
echo
echo "===================================================="
