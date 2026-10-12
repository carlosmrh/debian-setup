#!/usr/bin/env bash

# Debian 13 - Instalación y configuración automatizada
# --------------------------------------------------
# Script para automatizar la configuración de Debian 13 Trixie:
# repositorios, aplicaciones, Flatpak, virtualización, Snapper,
# seguridad, Gaming opcional y Kernel/Mesa desde Backports.
#
# Autor: Carlos
# Versión: 1.0
# Debian: 13 Trixie
# Licencia: MIT
# --------------------------------------------------

# 0 PREPARACIÓN SCRIPT
# --------------------------------------------------

# Detener el script ante errores, variables no definidas
# y fallos dentro de tuberías de comandos.
set -Eeuo pipefail

# VARIABLES Y CONSTANTES
# --------------------------------------------------

# Sistema para el que está diseñado este instalador.
readonly DEBIAN_ID="debian"
readonly DEBIAN_VERSION="13"
readonly DEBIAN_CODENAME="trixie"
readonly ARQUITECTURA="amd64"

# Nombre del propio script.
readonly SCRIPT_NAME="${BASH_SOURCE[0]##*/}"

# Directorio y archivo donde se guardará el registro de ejecución.
readonly LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/debian-setup"
readonly LOG_FILE="$LOG_DIR/${SCRIPT_NAME%.sh}-$(date '+%Y-%m-%d_%H-%M-%S').log"

# Estado interno del script.
SUDO_KEEPALIVE_PID=""

# Repositorios oficiales de Debian.
readonly DEBIAN_SOURCES_FILE="/etc/apt/sources.list.d/debian.sources"
readonly DEBIAN_BACKPORTS_FILE="/etc/apt/sources.list.d/backports.sources"
readonly DEBIAN_LEGACY_SOURCES="/etc/apt/sources.list"
readonly DEBIAN_KEYRING="/usr/share/keyrings/debian-archive-keyring.pgp"

# Marca para continuar con las comprobaciones después del reinicio.
readonly POST_REBOOT_FLAG="$LOG_DIR/post-reboot-pending"
readonly INSTALL_COMPLETE_FLAG="$LOG_DIR/install-complete"
readonly GAMING_BACKPORTS_FLAG="$LOG_DIR/gaming-backports-enabled"

# Directorio para guardar el diagnóstico final.
readonly DIAGNOSTICO_DIR="$HOME/Debian-diagnostico"

# Paquetes a eliminar
readonly PAQUETES_ELIMINAR=(
    "libreoffice*"
    'konqueror*'
    'konq-plugins*'
    'kmail*'
    accountwizard
    'firefox-esr*'
    'goldendict*'
    'gimp*'
    'akregator*'
    'kontact*'
    'pim-sieve-editor*'
    dragonplayer
    juk
    'korganizer*'
    'kaddressbook*'
    'xiterm+thai'
    kasumi
    'anthy*'
    'ibus-anthy*'
    'fcitx-anthy*'
    'fcitx5-anthy*'
    'mozc*'
    'ibus-mozc*'
    'fcitx-mozc*'
    'fcitx5-mozc*'
)

# Paquetes de terminal y utilidades.
readonly PAQUETES_TERMINAL=(
    fish
    fastfetch
    btop
    tree
    bat
    ripgrep
    gh
    wget
    cmake
    pkg-config
)

# Aplicaciones KDE y escritorio.
readonly PAQUETES_ESCRITORIO=(
    filelight
    kio-admin
    kdeconnect
    keepassxc
    converseen
    thunderbird
)

# Syncthing.
readonly PAQUETES_SYNCTHING=(
    syncthing
    syncthingtray-kde-plasma
)

# Multimedia.
readonly PAQUETES_MULTIMEDIA=(
    ffmpeg
    vainfo
    unrar
)

# Sistema y diagnóstico.
readonly PAQUETES_SISTEMA=(
    inxi
    nvme-cli
    ufw
    gufw
    snapper
    btrfs-assistant
    btrfs-progs
    zram-tools
    kitty
    fonts-jetbrains-mono
    lm-sensors
    numlockx
    mesa-utils
    vulkan-tools
    fwupd
    iproute2
    amd64-microcode
)

# Impresora.
readonly PAQUETES_IMPRESORA=(
    printer-driver-brlaser
)

# Flatpak.
readonly PAQUETES_FLATPAK=(
    flatpak
    plasma-discover-backend-flatpak
)

# Virtualización.
readonly PAQUETES_VIRTUALIZACION=(
    virt-manager
    qemu-system-x86
    qemu-utils
    libvirt-daemon-system
    libvirt-clients
    bridge-utils
    ovmf
    virt-viewer
    virtiofsd
)

# Gaming.
readonly PAQUETES_GAMING=(
    steam-installer
    gamemode
    mangohud
)

# Kernel desde Backports.
readonly PAQUETES_KERNEL_BACKPORTS=(
    linux-image-amd64
    linux-headers-amd64
)

# Mesa y firmware AMD desde Backports.
readonly PAQUETES_AMD_BACKPORTS=(
    firmware-amd-graphics
    mesa-vulkan-drivers:amd64
    mesa-vulkan-drivers:i386
    mesa-libgallium:amd64
    mesa-libgallium:i386
    libgl1-mesa-dri:amd64
    libgl1-mesa-dri:i386
    libglx-mesa0:amd64
    libglx-mesa0:i386
    libegl-mesa0:amd64
    libegl-mesa0:i386
    libgbm1:amd64
    libgbm1:i386
)

# Brave Origin.
readonly BRAVE_KEYRING="/usr/share/keyrings/brave-browser-archive-keyring.gpg"
readonly BRAVE_SOURCES_FILE="/etc/apt/sources.list.d/brave-browser-release.sources"
readonly BRAVE_KEY_URL="https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg"
readonly BRAVE_SOURCES_URL="https://brave-browser-apt-release.s3.brave.com/brave-browser.sources"

# ONLYOFFICE.
readonly ONLYOFFICE_KEYRING="/usr/share/keyrings/onlyoffice.gpg"
readonly ONLYOFFICE_SOURCES_FILE="/etc/apt/sources.list.d/onlyoffice.sources"
readonly ONLYOFFICE_KEY_URL="https://download.onlyoffice.com/GPG-KEY-ONLYOFFICE"
readonly ONLYOFFICE_REPO_URL="https://download.onlyoffice.com/repo/debian"

# Visual Studio Code.
readonly VSCODE_KEYRING="/usr/share/keyrings/microsoft.gpg"
readonly VSCODE_SOURCES_FILE="/etc/apt/sources.list.d/vscode.sources"
readonly VSCODE_KEY_URL="https://packages.microsoft.com/keys/microsoft.asc"
readonly VSCODE_REPO_URL="https://packages.microsoft.com/repos/code"

# Aplicaciones externas mediante paquetes .deb.
readonly DISCORD_DEB_URL="https://discord.com/api/download?platform=linux&format=deb"
readonly OBSIDIAN_RELEASES_URL="https://raw.githubusercontent.com/obsidianmd/obsidian-releases/master/desktop-releases.json"
readonly FAUGUS_RELEASE_API="https://api.github.com/repos/Faugus/faugus-launcher/releases/latest"
readonly RUSTDESK_DEB_URL="https://github.com/rustdesk/rustdesk/releases/download/nightly/rustdesk-unattended-wayland-1.4.9-x86_64.deb"

# Configuración de Kitty.
readonly KITTY_CONFIG_DIR="$HOME/.config/kitty"
readonly KITTY_CONFIG_FILE="$KITTY_CONFIG_DIR/kitty.conf"

# Configuración de MangoHud.
readonly MANGOHUD_CONFIG_DIR="$HOME/.config/MangoHud"
readonly MANGOHUD_CONFIG_FILE="$MANGOHUD_CONFIG_DIR/MangoHud.conf"

# INTERFAZ Y COLORES
# --------------------------------------------------

# Usar colores solo cuando la salida estándar sea un terminal.
if [[ -t 1 && "${TERM:-dumb}" != "dumb" ]]; then
    readonly VERDE=$'\e[32m'
    readonly ROJO=$'\e[31m'
    readonly AMARILLO=$'\e[33m'
    readonly AZUL=$'\e[34m'
    readonly NEGRITA=$'\e[1m'
    readonly RESET=$'\e[0m'
else
    readonly VERDE=''
    readonly ROJO=''
    readonly AMARILLO=''
    readonly AZUL=''
    readonly NEGRITA=''
    readonly RESET=''
fi

mostrar_banner() {
    clear

    printf '\n'
    printf 'Debian 13 Setup\n'
    printf '%s\n' '--------------------------------------------------'
    printf 'Instalación y configuración automatizada de Debian 13 Trixie\n'
    printf 'Autor: Carlos\n'
    printf 'Versión: 1.0\n'
    printf '%s\n\n' '--------------------------------------------------'
}

# FUNCIONES GENERALES
# --------------------------------------------------

titulo() {
    printf '\n%s%s%s\n' "$NEGRITA" "$1" "$RESET"
    printf '%s\n' '--------------------------------------------------'
}

info() {
    printf '%s[INFO]%s %s\n' "$AZUL" "$RESET" "$1"
}

ok() {
    printf '%s[OK]%s %s\n' "$VERDE" "$RESET" "$1"
}

aviso() {
    printf '%s[AVISO]%s %s\n' "$AMARILLO" "$RESET" "$1"
}

error() {
    printf '%s[ERROR]%s %s\n' "$ROJO" "$RESET" "$1" >&2
}

fatal() {
    error "$1"
    exit 1
}

pausa() {
    local respuesta

    if [[ ! -t 0 ]]; then
        fatal "Esta operación requiere una terminal interactiva."
    fi

    printf '\nPulsa Enter para continuar...'

    if ! read -r respuesta; then
        fatal "No se ha podido leer la entrada del usuario."
    fi
}

confirmar() {
    local respuesta

    if [[ ! -t 0 ]]; then
        fatal "Esta operación requiere una terminal interactiva."
    fi

    while true; do
        if ! read -rp "$1 [s/N]: " respuesta; then
            fatal "No se ha podido leer la respuesta del usuario."
        fi

        case "${respuesta,,}" in
            s|si|sí)
                return 0
                ;;
            n|no|'')
                return 1
                ;;
            *)
                aviso "Responde s o n."
                ;;
        esac
    done
}

comprobar_comando() {
    local comando="$1"

    command -v "$comando" >/dev/null 2>&1
}

instalar_paquetes() {
    local descripcion="$1"
    shift

    info "Instalando $descripcion..."

    sudo apt-get install -y "$@"

    ok "$descripcion instalados correctamente."
}

instalar_deb() {
    local nombre="$1"
    local url="$2"
    local archivo

    archivo=$(mktemp --suffix=.deb)

    info "Descargando $nombre..."

    if ! curl -fL --retry 3 --retry-delay 2 \
        -o "$archivo" "$url"; then
        rm -f "$archivo"
        fatal "No se ha podido descargar $nombre."
    fi
    chmod 644 "$archivo"

    # Comprobar que lo descargado es realmente un paquete Debian.
    if ! dpkg-deb --info "$archivo" >/dev/null 2>&1; then
        rm -f "$archivo"
        fatal "El archivo descargado de $nombre no es un paquete .deb válido."
    fi

    info "Instalando $nombre..."

    if ! sudo apt-get install -y "$archivo"; then
        rm -f "$archivo"
        fatal "No se ha podido instalar $nombre."
    fi

    rm -f "$archivo"

    ok "$nombre instalado correctamente."
}

# GESTIÓN DE ERRORES Y LOG
# --------------------------------------------------

iniciar_log() {
    if ! mkdir -p "$LOG_DIR"; then
        fatal "No se ha podido crear el directorio de registros: $LOG_DIR"
    fi

    if ! chmod 700 "$LOG_DIR"; then
        fatal "No se han podido establecer los permisos de $LOG_DIR"
    fi

    if ! touch "$LOG_FILE"; then
        fatal "No se ha podido crear el archivo de registro: $LOG_FILE"
    fi

    if ! chmod 600 "$LOG_FILE"; then
        fatal "No se han podido establecer los permisos de $LOG_FILE"
    fi

    exec > >(tee >(sed -u $'s/\033\\[[0-9;]*m//g' >> "$LOG_FILE")) 2>&1

    info "Registro de instalación: $LOG_FILE"
}

gestionar_error() {
    local codigo="$1"
    local linea="$2"
    local comando="$3"

    # Evitar que un error dentro del propio gestor provoque otro trap.
    trap - ERR

    printf '\n'
    error "La instalación se ha detenido."
    error "Línea: $linea"
    error "Código de salida: $codigo"
    error "Comando: $comando"
    error "Registro: $LOG_FILE"

    exit "$codigo"
}

limpiar() {
    # Detener el proceso que mantiene activa la autorización de sudo.
    if [[ -n "$SUDO_KEEPALIVE_PID" ]]; then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
        wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    fi
}

activar_traps() {
    trap 'gestionar_error "$?" "$LINENO" "$BASH_COMMAND"' ERR
    trap limpiar EXIT
}

# 1 COMPROBACIONES INICIALES
# --------------------------------------------------

comprobar_usuario() {
    if [[ $EUID -eq 0 ]]; then
        fatal "No ejecutes este script como root ni con sudo. Ejecuta: ./$SCRIPT_NAME"
    fi

    ok "Usuario detectado: $USER"
}

comprobar_sistema() {
    if [[ ! -f /etc/os-release ]]; then
        fatal "No se encuentra /etc/os-release."
    fi

    source /etc/os-release

    if [[ "${ID:-}" != "$DEBIAN_ID" ||
          "${VERSION_ID:-}" != "$DEBIAN_VERSION" ||
          "${VERSION_CODENAME:-}" != "$DEBIAN_CODENAME" ]]; then
        fatal "Este instalador requiere Debian $DEBIAN_VERSION $DEBIAN_CODENAME."
    fi

    ok "Debian $DEBIAN_VERSION $DEBIAN_CODENAME detectado."
}

comprobar_arquitectura() {
    local arquitectura

    arquitectura=$(dpkg --print-architecture)

    if [[ "$arquitectura" != "$ARQUITECTURA" ]]; then
        fatal "Arquitectura no compatible: $arquitectura. Se requiere $ARQUITECTURA."
    fi

    ok "Arquitectura $arquitectura detectada."
}

comprobar_herramientas_base() {
    local comando

    for comando in dpkg apt-get; do
        if ! comprobar_comando "$comando"; then
            fatal "No se encuentra una herramienta esencial: $comando"
        fi
    done

    ok "Herramientas básicas del sistema disponibles."
}

preparar_sudo() {
    if ! comprobar_comando sudo; then
        fatal "sudo no está instalado."
    fi

    info "Solicitando permisos administrativos..."

    if ! sudo -v; then
        fatal "No se han podido obtener permisos con sudo."
    fi

    # Si ya existe un keepalive activo en esta ejecución,
    # no crear otro proceso en segundo plano.
    if [[ -n "$SUDO_KEEPALIVE_PID" ]] &&
       kill -0 "$SUDO_KEEPALIVE_PID" 2>/dev/null; then
        ok "Permisos administrativos disponibles."
        return 0
    fi

    # Mantener válida la autorización de sudo mientras se ejecuta
    # el instalador, sin solicitar contraseñas en segundo plano.
    (
        while true; do
            sudo -n -v 2>/dev/null || exit
            sleep 60
        done
    ) &

    SUDO_KEEPALIVE_PID=$!

    ok "Permisos administrativos disponibles."
}

comprobaciones_iniciales() {
    comprobar_sistema
    comprobar_arquitectura
    comprobar_herramientas_base
    preparar_sudo
}

# 2 REPOSITORIOS
# --------------------------------------------------

configurar_repositorios_debian() {
    titulo "Repositorios Debian"

    # Comprobar que existe el keyring oficial antes de crear los repositorios.
    if [[ ! -f "$DEBIAN_KEYRING" ]]; then
        fatal "No se encuentra el keyring de Debian: $DEBIAN_KEYRING"
    fi

    info "Configurando repositorios oficiales de Debian..."

    # Crear o sobrescribir debian.sources usando el formato moderno Deb822.
    cat <<EOF | sudo tee "$DEBIAN_SOURCES_FILE" >/dev/null
Types: deb
URIs: https://deb.debian.org/debian
Suites: $DEBIAN_CODENAME ${DEBIAN_CODENAME}-updates
Components: main contrib non-free non-free-firmware
Signed-By: $DEBIAN_KEYRING

Types: deb
URIs: https://security.debian.org/debian-security
Suites: ${DEBIAN_CODENAME}-security
Components: main contrib non-free non-free-firmware
Signed-By: $DEBIAN_KEYRING
EOF

    # Verificar que el archivo existe y no está vacío.
    if [[ ! -s "$DEBIAN_SOURCES_FILE" ]]; then
        fatal "No se ha podido crear correctamente $DEBIAN_SOURCES_FILE"
    fi

    # Eliminar el antiguo sources.list para usar únicamente Deb822.
    if [[ -f "$DEBIAN_LEGACY_SOURCES" ]]; then
        sudo rm -f "$DEBIAN_LEGACY_SOURCES"
        info "Eliminado el antiguo /etc/apt/sources.list."
    fi

    ok "Repositorios oficiales de Debian configurados."
}

configurar_backports() {
    titulo "Debian Backports"

    info "Configurando repositorio Backports..."

    cat <<EOF | sudo tee "$DEBIAN_BACKPORTS_FILE" >/dev/null
Types: deb
URIs: https://deb.debian.org/debian
Suites: ${DEBIAN_CODENAME}-backports
Components: main contrib non-free non-free-firmware
Signed-By: $DEBIAN_KEYRING
EOF

    if [[ ! -s "$DEBIAN_BACKPORTS_FILE" ]]; then
        fatal "No se ha podido crear correctamente $DEBIAN_BACKPORTS_FILE"
    fi

    ok "Repositorio ${DEBIAN_CODENAME}-backports configurado."
}

activar_i386() {
    titulo "Arquitectura i386"

    # Comprobar si i386 ya está activada como arquitectura secundaria.
    if dpkg --print-foreign-architectures | grep -qx "i386"; then
        ok "La arquitectura i386 ya está activada."
        return 0
    fi

    info "Activando arquitectura i386..."

    sudo dpkg --add-architecture i386

    # Verificar que se ha activado correctamente.
    if ! dpkg --print-foreign-architectures | grep -qx "i386"; then
        fatal "No se ha podido activar la arquitectura i386."
    fi

    ok "Arquitectura i386 activada."
}

actualizar_indices_apt() {
    titulo "Actualizar índices de APT"

    info "Actualizando información de los repositorios..."

    sudo apt-get --error-on=any update

    ok "Índices de APT actualizados correctamente."
}

preparar_repositorios() {
    configurar_repositorios_debian
    configurar_backports
    actualizar_indices_apt
}

# 3 ELIMINAR PROGRAMAS ACTUALIZACIÓN Y DEPENDENCIAS
# --------------------------------------------------

eliminar_programas_preinstalados() {
    titulo "Eliminar programas preinstalados"

    info "Eliminando programas que no se van a utilizar..."

    sudo apt-get purge -y "${PAQUETES_ELIMINAR[@]}"
    sudo apt-get autoremove --purge -y

    ok "Programas innecesarios eliminados."
}

actualizar_sistema() {
    titulo "Actualizar Debian"

    info "Actualizando todos los paquetes instalados..."

    sudo apt-get full-upgrade -y

    ok "Sistema actualizado correctamente."
}

instalar_dependencias() {
    titulo "Dependencias del instalador"

    info "Instalando herramientas necesarias para continuar..."

    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg

    ok "Dependencias del instalador instaladas."
}

preparar_sistema() {
    eliminar_programas_preinstalados
    actualizar_sistema
    instalar_dependencias
}

# 4 APLICACIONES DEBIAN
# --------------------------------------------------

instalar_aplicaciones_debian() {
    titulo "Aplicaciones Debian"

    instalar_paquetes "terminal y utilidades" "${PAQUETES_TERMINAL[@]}"
    instalar_paquetes "aplicaciones de escritorio" "${PAQUETES_ESCRITORIO[@]}"
    instalar_paquetes "Syncthing" "${PAQUETES_SYNCTHING[@]}"
    instalar_paquetes "herramientas multimedia" "${PAQUETES_MULTIMEDIA[@]}"
    instalar_paquetes "herramientas de sistema y diagnóstico" "${PAQUETES_SISTEMA[@]}"
    instalar_paquetes "controlador de impresora" "${PAQUETES_IMPRESORA[@]}"
}

# 5 FLATPAK
# --------------------------------------------------

configurar_flatpak() {
    titulo "Flatpak"

    instalar_paquetes "Flatpak" "${PAQUETES_FLATPAK[@]}"

    info "Configurando repositorio Flathub..."

    flatpak remote-add --user --if-not-exists \
        flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo

    ok "Flatpak y Flathub configurados correctamente."
}

# 6 VIRTUALIZACIÓN
# --------------------------------------------------

configurar_virtualizacion() {
    titulo "Virtualización"

    instalar_paquetes "virtualización" "${PAQUETES_VIRTUALIZACION[@]}"

    info "Añadiendo $USER a los grupos libvirt y kvm..."

    sudo usermod -aG libvirt,kvm "$USER"

    ok "Virtualización instalada y usuario añadido a libvirt y kvm."
    aviso "Los nuevos grupos se aplicarán después de cerrar sesión o reiniciar."
}

# 7 PREGUNTAR GAMING
# --------------------------------------------------
preguntar_gaming_backports() {
    titulo "Gaming y Backports"

    if confirmar "¿Quieres instalar Gaming y Kernel/Mesa desde Backports?"; then
        touch "$GAMING_BACKPORTS_FLAG"
        ok "Gaming y Backports seleccionados."
        return 0
    fi

    rm -f "$GAMING_BACKPORTS_FLAG"

    info "Se omitirá:"
    info "- Steam, GameMode y MangoHud"
    info "- Kernel desde Backports"
    info "- Mesa y firmware AMD desde Backports"

    return 1
}

# 7.5 GAMING
# --------------------------------------------------

instalar_gaming() {
    titulo "Gaming"

    instalar_paquetes "herramientas de gaming" "${PAQUETES_GAMING[@]}"

    ok "Steam, GameMode y MangoHud instalados."
}

# 8 CONFIGURAR SNAPPER
# --------------------------------------------------

configurar_snapper() {
    local sistema_archivos

    titulo "Snapper"

    sistema_archivos=$(findmnt -n -o FSTYPE /)

    if [[ "$sistema_archivos" != "btrfs" ]]; then
        aviso "La partición raíz no usa Btrfs. Se omitirá la configuración de Snapper."
        return 0
    fi

if [[ ! -f /etc/snapper/configs/root ]]; then

    # Snapper necesita crear /.snapshots por sí mismo.
    # Si existe previamente, no eliminamos nada que pueda contener snapshots.
    if [[ -e /.snapshots ]]; then

        if sudo btrfs subvolume show /.snapshots >/dev/null 2>&1; then
            fatal "Existe el subvolumen /.snapshots pero Snapper no tiene configuración root. No se modificará automáticamente."
        fi

        if [[ -d /.snapshots ]]; then
            if [[ -n "$(sudo find /.snapshots -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
                fatal "El directorio /.snapshots ya existe y contiene datos. No se modificará automáticamente."
            fi

            info "Eliminando el directorio vacío /.snapshots para que Snapper pueda crearlo..."
            sudo rmdir /.snapshots
        else
            fatal "/.snapshots existe pero no es un directorio válido."
        fi
    fi

    info "Creando configuración de Snapper para /..."
    sudo snapper -c root create-config /

else
    ok "Snapper ya está configurado para la partición raíz."
fi

    info "Configurando política de snapshots..."

    sudo snapper -c root set-config \
        'TIMELINE_CREATE=yes' \
        'TIMELINE_CLEANUP=yes' \
        'TIMELINE_LIMIT_HOURLY=3' \
        'TIMELINE_LIMIT_DAILY=7' \
        'TIMELINE_LIMIT_WEEKLY=2' \
        'TIMELINE_LIMIT_MONTHLY=0' \
        'TIMELINE_LIMIT_YEARLY=0' \
        'NUMBER_CLEANUP=yes' \
        'NUMBER_LIMIT=10' \
        'NUMBER_LIMIT_IMPORTANT=10'

    info "Activando limpieza y snapshots automáticos..."

    sudo systemctl enable --now snapper-timeline.timer
    sudo systemctl enable --now snapper-cleanup.timer

    ok "Snapper configurado correctamente."
}

# 9 KERNEL Y MESA BACKPORTS
# --------------------------------------------------
crear_snapshot_pre_backports() {
    titulo "Snapshot antes de Backports"

    if [[ ! -f /etc/snapper/configs/root ]]; then
        aviso "Snapper no está configurado. Se omitirá el snapshot previo."
        return 0
    fi

    info "Creando snapshot antes de actualizar kernel y Mesa..."

    sudo snapper -c root create \
        --description "Antes de kernel y Mesa Backports" \
        --cleanup-algorithm number \
        --userdata important=yes

    ok "Snapshot previo creado."
}

instalar_kernel_backports() {
    titulo "Kernel Backports"

    info "Instalando kernel y headers desde ${DEBIAN_CODENAME}-backports..."

    sudo apt-get install -y \
        -t "${DEBIAN_CODENAME}-backports" \
        "${PAQUETES_KERNEL_BACKPORTS[@]}"

    ok "Kernel de Backports instalado."
}

instalar_amd_backports() {
    titulo "Mesa y firmware AMD"

    info "Instalando Mesa y firmware AMD desde ${DEBIAN_CODENAME}-backports..."

    sudo apt-get install -y \
        -t "${DEBIAN_CODENAME}-backports" \
        "${PAQUETES_AMD_BACKPORTS[@]}"

    ok "Mesa y firmware AMD desde Backports instalados."
}

configurar_backports_sistema() {
    crear_snapshot_pre_backports
    instalar_kernel_backports
    instalar_amd_backports
}

# 10 APLICACIONES EXTERNAS
# --------------------------------------------------

configurar_repositorio_brave() {
    titulo "Brave Origin"

    info "Añadiendo repositorio oficial de Brave Origin..."

    sudo curl -fsSLo "$BRAVE_KEYRING" "$BRAVE_KEY_URL"
    sudo curl -fsSLo "$BRAVE_SOURCES_FILE" "$BRAVE_SOURCES_URL"

    if [[ ! -s "$BRAVE_KEYRING" ]]; then
        fatal "No se ha podido descargar la clave de Brave."
    fi

    if [[ ! -s "$BRAVE_SOURCES_FILE" ]]; then
        fatal "No se ha podido descargar el repositorio de Brave."
    fi

    ok "Repositorio de Brave Origin configurado."
}

configurar_repositorio_onlyoffice() {
    titulo "ONLYOFFICE"

    info "Añadiendo clave y repositorio oficial de ONLYOFFICE..."

    curl -fsSL "$ONLYOFFICE_KEY_URL" \
        | gpg --dearmor \
        | sudo tee "$ONLYOFFICE_KEYRING" >/dev/null

    if [[ ! -s "$ONLYOFFICE_KEYRING" ]]; then
        fatal "No se ha podido instalar la clave de ONLYOFFICE."
    fi

    cat <<EOF | sudo tee "$ONLYOFFICE_SOURCES_FILE" >/dev/null
Types: deb
URIs: $ONLYOFFICE_REPO_URL
Suites: squeeze
Components: main
Architectures: amd64
Signed-By: $ONLYOFFICE_KEYRING
EOF

    if [[ ! -s "$ONLYOFFICE_SOURCES_FILE" ]]; then
        fatal "No se ha podido crear el repositorio de ONLYOFFICE."
    fi

    ok "Repositorio de ONLYOFFICE configurado."
}

configurar_repositorio_vscode() {
    titulo "Visual Studio Code"

    info "Añadiendo clave y repositorio oficial de Visual Studio Code..."

    curl -fsSL "$VSCODE_KEY_URL" \
        | gpg --dearmor \
        | sudo tee "$VSCODE_KEYRING" >/dev/null

    if [[ ! -s "$VSCODE_KEYRING" ]]; then
        fatal "No se ha podido instalar la clave de Visual Studio Code."
    fi

    cat <<EOF | sudo tee "$VSCODE_SOURCES_FILE" >/dev/null
Types: deb
URIs: $VSCODE_REPO_URL
Suites: stable
Components: main
Architectures: amd64
Signed-By: $VSCODE_KEYRING
EOF

    if [[ ! -s "$VSCODE_SOURCES_FILE" ]]; then
        fatal "No se ha podido crear el repositorio de Visual Studio Code."
    fi

    ok "Repositorio de Visual Studio Code configurado."
}

instalar_discord() {
    titulo "Discord"

    instalar_deb "Discord" "$DISCORD_DEB_URL"
}

instalar_obsidian() {
    local releases_json
    local version
    local url

    titulo "Obsidian"

    info "Consultando última versión estable de escritorio..."

    releases_json=$(curl -fsSL "$OBSIDIAN_RELEASES_URL")

    version=$(
        sed -n 's/.*"latestVersion": "\([^"]*\)".*/\1/p' \
            <<< "$releases_json" |
        sed -n '1p'
    )

    if [[ -z "$version" ]]; then
        fatal "No se ha podido obtener la última versión de Obsidian."
    fi

    url="https://github.com/obsidianmd/obsidian-releases/releases/download/v${version}/obsidian_${version}_amd64.deb"

    info "Última versión estable de escritorio: $version"

    instalar_deb "Obsidian $version" "$url"
}

instalar_faugus() {
    local release_json
    local url

    titulo "Faugus Launcher"

    info "Consultando última versión de Faugus Launcher..."

    release_json=$(curl -fsSL "$FAUGUS_RELEASE_API")

    url=$(
        grep -oE 'https://[^"]+faugus-launcher_[^"]+_all\.deb' \
            <<< "$release_json" |
        sed -n '1p'
    )

    if [[ -z "$url" ]]; then
        fatal "No se ha podido localizar el paquete .deb de Faugus Launcher."
    fi

    instalar_deb "Faugus Launcher" "$url"
}

instalar_rustdesk() {
    titulo "RustDesk"

    instalar_deb \
        "RustDesk Wayland Unattended 1.4.9" \
        "$RUSTDESK_DEB_URL"
}

instalar_aplicaciones_externas() {
    configurar_repositorio_brave
    configurar_repositorio_onlyoffice
    configurar_repositorio_vscode

    titulo "Aplicaciones externas"

    info "Actualizando índices de APT..."
    sudo apt-get --error-on=any update

    info "Instalando aplicaciones desde repositorios..."

    sudo apt-get install -y \
        brave-origin \
        onlyoffice-desktopeditors \
        code

    ok "Aplicaciones mediante repositorios instaladas correctamente."

    instalar_discord
    instalar_obsidian
    if [[ -f "$GAMING_BACKPORTS_FLAG" ]]; then
        instalar_faugus
    fi
    instalar_rustdesk
}

# 11 CONFIGURACIÓN APLICACIONES
# --------------------------------------------------

configurar_fish() {
    local fish_path
    local shell_actual

    titulo "Configurar Fish"

if ! fish_path=$(command -v fish); then
    fatal "Fish no está instalado."
fi

    shell_actual=$(getent passwd "$USER" | cut -d: -f7)

    if [[ "$shell_actual" != "$fish_path" ]]; then
        info "Estableciendo Fish como shell predeterminada..."
        sudo chsh -s "$fish_path" "$USER"
        ok "Fish establecido como shell predeterminada."
    else
        ok "Fish ya es la shell predeterminada."
    fi

    info "Configurando Fish..."

    fish -c 'set -U fish_greeting'

    if command -v batcat >/dev/null 2>&1; then
        fish -c 'abbr --add bat batcat'
    fi

    ok "Fish configurado correctamente."
}

configurar_kitty() {
    titulo "Configurar Kitty"

    info "Creando configuración de Kitty..."

    mkdir -p "$KITTY_CONFIG_DIR"

    cat <<'EOF' > "$KITTY_CONFIG_FILE"
# Fuente
font_family JetBrains Mono
font_size 11
adjust_line_height 1

# Ventana
window_padding_width 10
background_opacity 0.90
dynamic_background_opacity no
remember_window_size yes

# Cursor
cursor_shape beam
cursor_beam_thickness 1.5
cursor_blink_interval 0.5
cursor_shape_unfocused hollow

# Historial
scrollback_lines 20000
wheel_scroll_multiplier 3.0

# Ratón
mouse_hide_wait 2.0
mouse_map left press ungrabbed mouse_selection normal
mouse_map left doublepress ungrabbed mouse_selection word
mouse_map left triplepress ungrabbed mouse_selection line
mouse_map middle release ungrabbed paste_from_selection

# Portapapeles
copy_on_select no
map ctrl+shift+c copy_to_clipboard
map ctrl+shift+v paste_from_clipboard

# Enlaces
underline_hyperlinks hover
url_style curly
allow_hyperlinks yes

# Pestañas
tab_bar_edge top
tab_bar_style powerline
tab_powerline_style round
tab_bar_min_tabs 2
tab_title_template "{index}: {title}"

# Crear pestañas conservando la carpeta actual
map ctrl+shift+t new_tab_with_cwd

# Ventanas
map ctrl+shift+enter new_window_with_cwd
map ctrl+shift+n new_os_window_with_cwd

# Cerrar ventana o split actual
map ctrl+shift+w close_window

# Cerrar pestaña completa
map ctrl+shift+q close_tab

# Splits
map ctrl+shift+alt+right launch --location=hsplit
map ctrl+shift+alt+down launch --location=vsplit

# Moverse entre splits
map alt+h neighboring_window left
map alt+j neighboring_window bottom
map alt+k neighboring_window top
map alt+l neighboring_window right

# Cambiar pestaña
map ctrl+shift+right next_tab
map ctrl+shift+left previous_tab

# Tamaño de fuente
map ctrl+plus change_font_size all +1.0
map ctrl+minus change_font_size all -1.0
map ctrl+0 change_font_size all 0

# Sonido
enable_audio_bell no

# Cierre
confirm_os_window_close -1
EOF

    if [[ ! -s "$KITTY_CONFIG_FILE" ]]; then
        fatal "No se ha podido crear la configuración de Kitty."
    fi

    ok "Kitty configurado correctamente."
}

configurar_numlock_sddm() {
    titulo "Configurar Num Lock"

    info "Activando Num Lock en la pantalla de inicio de SDDM..."

    sudo mkdir -p /etc/sddm.conf.d

    cat <<'EOF' | sudo tee /etc/sddm.conf.d/10-numlock.conf >/dev/null
[General]
Numlock=on
EOF

    if [[ ! -s /etc/sddm.conf.d/10-numlock.conf ]]; then
        fatal "No se ha podido crear la configuración de Num Lock para SDDM."
    fi

    ok "Num Lock activado para SDDM."
}

configurar_mangohud() {
    titulo "Configurar MangoHud"

    info "Creando configuración de MangoHud..."

    mkdir -p "$MANGOHUD_CONFIG_DIR"

    cat <<'EOF' > "$MANGOHUD_CONFIG_FILE"
# Diseño
legacy_layout=0
horizontal
hud_compact
hud_no_margin
position=top-left
offset_x=5
offset_y=5

# Tamaño y apariencia
font_size=12
background_alpha=0
alpha=1.0
text_outline

# Información mostrada
fps
gpu_stats
gpu_temp
cpu_stats
cpu_temp

# Atajo para mostrar/ocultar MangoHud
toggle_hud=Shift_R+F12
EOF

    if [[ ! -s "$MANGOHUD_CONFIG_FILE" ]]; then
        fatal "No se ha podido crear la configuración de MangoHud."
    fi

    ok "MangoHud configurado correctamente."
}

configurar_ufw() {
    titulo "Configurar UFW"

    info "Configurando políticas del firewall..."

    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # KDE Connect.
    info "Permitiendo KDE Connect..."
    sudo ufw allow 1714:1764/tcp
    sudo ufw allow 1714:1764/udp

    info "Activando UFW..."
    sudo ufw --force enable

    ok "UFW configurado y activado."
}

configurar_ssh_opcional() {
    local interfaz
    local subred

    titulo "Servidor SSH"

    if ! confirmar "¿Quieres instalar el servidor SSH en este equipo?"; then
        info "Servidor SSH omitido."
        return 0
    fi

    info "Instalando servidor OpenSSH..."
    sudo apt-get install -y openssh-server

    # Detectar la interfaz utilizada para la conexión de red principal.
    interfaz=$(
    ip route show default |
    awk '/^default/ && !encontrada {
        print $5
        encontrada=1
    }'
)

    if [[ -z "$interfaz" ]]; then
        fatal "No se ha podido detectar la interfaz de red principal."
    fi

    # Detectar la subred local directamente conectada a esa interfaz.
    subred=$(
    ip -o -4 route show dev "$interfaz" scope link |
    awk '$1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/[0-9]+$/ && !encontrada {
        print $1
        encontrada=1
    }'
)

    if [[ -z "$subred" ]]; then
        fatal "No se ha podido detectar automáticamente la red LAN para SSH."
    fi

    info "Configurando OpenSSH..."

    sudo mkdir -p /etc/ssh/sshd_config.d

    cat <<'EOF' | sudo tee /etc/ssh/sshd_config.d/00-debian-setup.conf >/dev/null
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication no
KbdInteractiveAuthentication no
MaxAuthTries 3
EOF

    # Comprobar que la configuración de OpenSSH es válida.
    sudo /usr/sbin/sshd -t

    info "Activando servidor SSH..."
    sudo systemctl enable --now ssh.service

    info "Permitiendo SSH únicamente desde la red $subred..."
    sudo ufw allow from "$subred" to any port 22 proto tcp

    ok "Servidor SSH instalado y disponible desde la LAN: $subred"
}

configurar_zram() {
    titulo "Configurar ZRAM"

    info "Activando ZRAM..."

    sudo systemctl enable --now zramswap.service

    if ! systemctl is-active --quiet zramswap.service; then
        aviso "ZRAM no está activo."
        return 0
    fi

    ok "ZRAM activo correctamente."
}

configurar_trim() {
    titulo "Configurar TRIM"

    # Comprobar que systemd conoce el temporizador.
    if ! systemctl cat fstrim.timer >/dev/null 2>&1; then
        aviso "fstrim.timer no está disponible en este sistema."
        return 0
    fi

    info "Activando TRIM periódico para SSD/NVMe..."

    sudo systemctl enable --now fstrim.timer

    if systemctl is-enabled --quiet fstrim.timer; then
        ok "TRIM periódico habilitado correctamente."
    else
        aviso "No se ha podido habilitar fstrim.timer."
    fi
}

configurar_grub() {
    titulo "Configurar GRUB"

    info "Reduciendo el tiempo de espera de GRUB a 1 segundo..."

    if grep -q '^GRUB_TIMEOUT=' /etc/default/grub; then
        sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
    else
        echo 'GRUB_TIMEOUT=1' | sudo tee -a /etc/default/grub >/dev/null
    fi

    if grep -q '^GRUB_TIMEOUT_STYLE=' /etc/default/grub; then
        sudo sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/' /etc/default/grub
    else
        echo 'GRUB_TIMEOUT_STYLE=menu' | sudo tee -a /etc/default/grub >/dev/null
    fi

    info "Actualizando GRUB..."
    sudo update-grub

    ok "GRUB configurado con 1 segundo de espera."
}

configurar_sistema() {
    configurar_fish
    configurar_kitty
    configurar_numlock_sddm
    if [[ -f "$GAMING_BACKPORTS_FLAG" ]]; then
        configurar_mangohud
    fi
    configurar_ufw
    configurar_ssh_opcional
    configurar_zram
    configurar_trim
    configurar_grub
}

# 12 COMPROBACIONES PRE-REINICIO
# --------------------------------------------------

comprobar_btrfs() {
    local sistema_archivos

    titulo "Comprobar Btrfs"

    sistema_archivos=$(findmnt -n -o FSTYPE /)

    if [[ "$sistema_archivos" != "btrfs" ]]; then
        aviso "La partición raíz no utiliza Btrfs."
        return 0
    fi

    ok "La partición raíz utiliza Btrfs."

info "Subvolúmenes Btrfs:"

if ! sudo btrfs subvolume list /; then
    aviso "No se ha podido obtener la lista de subvolúmenes Btrfs."
fi
}

comprobar_snapper_pre() {
    titulo "Comprobar Snapper"

    if [[ ! -f /etc/snapper/configs/root ]]; then
        aviso "Snapper no está configurado para la raíz."
        return 0
    fi

    ok "Configuración root de Snapper detectada."

    if systemctl is-enabled --quiet snapper-timeline.timer; then
        ok "snapper-timeline.timer habilitado."
    else
        aviso "snapper-timeline.timer no está habilitado."
    fi

    if systemctl is-enabled --quiet snapper-cleanup.timer; then
        ok "snapper-cleanup.timer habilitado."
    else
        aviso "snapper-cleanup.timer no está habilitado."
    fi
}

comprobar_zram_pre() {
    titulo "Comprobar ZRAM"

    if systemctl is-active --quiet zramswap.service; then
        ok "ZRAM está activo."
    else
        aviso "zramswap.service no está activo."
    fi
}

comprobar_ufw_pre() {
    local estado_ufw

    titulo "Comprobar UFW"

    if ! estado_ufw=$(sudo env LC_ALL=C ufw status 2>&1); then
        aviso "No se ha podido consultar el estado de UFW."
        return 0
    fi

    if [[ "$estado_ufw" == *"Status: active"* ]]; then
        ok "UFW está activo."
    else
        aviso "UFW no está activo."
        return 0
    fi

    info "Reglas actuales:"

    if ! sudo ufw status numbered; then
        aviso "No se han podido mostrar las reglas de UFW."
    fi
}

comprobar_ssh_pre() {
    titulo "Comprobar SSH"

    # Si OpenSSH Server no está instalado, no hay nada que comprobar.
    if ! dpkg-query -W -f='${Status}' openssh-server 2>/dev/null \
        | grep -q 'install ok installed'; then
        info "Servidor SSH no instalado. Comprobación omitida."
        return 0
    fi

    if sudo /usr/sbin/sshd -t; then
        ok "Configuración de OpenSSH válida."
    else
        aviso "La configuración de OpenSSH contiene errores."
    fi

    if systemctl is-active --quiet ssh.service; then
        ok "Servidor SSH activo."
    else
        aviso "El servicio SSH no está activo."
    fi
}

comprobar_trim_pre() {
    titulo "Comprobar TRIM"

    if systemctl is-enabled --quiet fstrim.timer; then
        ok "fstrim.timer está habilitado."
    else
        aviso "fstrim.timer no está habilitado."
    fi

    if systemctl is-active --quiet fstrim.timer; then
        ok "fstrim.timer está activo."
    else
        aviso "fstrim.timer no está activo actualmente."
    fi
}

comprobar_backports_pre() {
    titulo "Comprobar paquetes Backports"

    info "Procedencia y versiones instaladas:"

    if ! apt-cache policy \
        linux-image-amd64 \
        linux-headers-amd64 \
        mesa-vulkan-drivers \
        firmware-amd-graphics; then

        aviso "No se ha podido consultar la información de los paquetes Backports."
    fi
}

comprobaciones_pre_reinicio() {
    comprobar_btrfs
    comprobar_snapper_pre
    comprobar_zram_pre
    comprobar_ufw_pre
    comprobar_ssh_pre
    comprobar_trim_pre
    if [[ -f "$GAMING_BACKPORTS_FLAG" ]]; then
        comprobar_backports_pre
    fi
}

# 13 REINICIO
# --------------------------------------------------

preparar_reinicio() {
    local boot_id

    titulo "Reinicio del sistema"

    ok "Instalación principal completada."
    aviso "Es necesario reiniciar para cargar el nuevo kernel y aplicar todos los cambios."

    pausa

    # Guardar el identificador del arranque actual.
    boot_id=$(cat /proc/sys/kernel/random/boot_id)

    if [[ -z "$boot_id" ]]; then
        fatal "No se ha podido obtener el identificador del arranque actual."
    fi

    printf '%s\n' "$boot_id" > "$POST_REBOOT_FLAG"

    info "Reiniciando el sistema..."

    if ! sudo reboot; then
        rm -f "$POST_REBOOT_FLAG"
        fatal "No se ha podido reiniciar el sistema."
    fi
}

# 14 COMPROBACIONES POST-REINICIO
# --------------------------------------------------

comprobar_kernel() {
    local kernel
    local paquete
    local version

    titulo "Comprobar kernel"

    kernel=$(uname -r)
    paquete="linux-image-$kernel"

    info "Kernel en ejecución: $kernel"

    if ! version=$(dpkg-query -W -f='${Version}' "$paquete" 2>/dev/null); then
        aviso "No se ha podido identificar el paquete correspondiente al kernel actual."
        return 0
    fi

    info "Paquete: $paquete"
    info "Versión Debian: $version"

    if [[ "$version" == *"~bpo${DEBIAN_VERSION}"* ]]; then
        ok "El sistema está usando un kernel de Debian Backports."
    else
        aviso "El kernel en ejecución no parece proceder de Debian Backports."
    fi
}

comprobar_gpu() {
    local opengl

    titulo "Comprobar GPU"

    info "Información gráfica:"

    if ! inxi -G; then
        aviso "No se ha podido obtener la información gráfica con inxi."
    fi

    printf '\n'
    info "OpenGL:"

    if opengl=$(glxinfo -B 2>&1); then
        printf '%s\n' "$opengl"

        if grep -qi "llvmpipe" <<< "$opengl"; then
            aviso "Se ha detectado llvmpipe. La aceleración gráfica por hardware puede no estar funcionando."
        else
            ok "OpenGL está utilizando aceleración gráfica por hardware."
        fi
    else
        aviso "No se ha podido comprobar OpenGL con glxinfo."
        printf '%s\n' "$opengl"
    fi

    printf '\n'
    info "Vulkan:"

    if ! vulkaninfo --summary; then
        aviso "No se ha podido comprobar Vulkan."
    fi

    printf '\n'
    info "Aceleración de vídeo VA-API:"

    if ! vainfo; then
        aviso "No se ha podido comprobar VA-API con vainfo."
    fi
}

comprobar_gaming() {
    titulo "Comprobar Gaming"

    info "Probando GameMode..."

    if gamemoded -t >/dev/null 2>&1; then
        ok "GameMode funciona correctamente."
    else
        aviso "GameMode no ha superado la prueba."
    fi

    if comprobar_comando mangohud; then
        ok "MangoHud está instalado."
    else
        aviso "MangoHud no está disponible."
    fi
}

comprobar_virtualizacion() {
    local grupos

    titulo "Comprobar virtualización"

    if ! grupos=$(id -nG "$USER"); then
        aviso "No se han podido consultar los grupos del usuario."
        return 0
    fi

    if grep -qw "libvirt" <<< "$grupos" && grep -qw "kvm" <<< "$grupos"; then
        ok "El usuario pertenece a los grupos libvirt y kvm."
    else
        aviso "El usuario no pertenece correctamente a los grupos libvirt y kvm."
    fi

    if [[ -e /dev/kvm ]]; then
        ok "KVM está disponible."
    else
        aviso "No se encuentra /dev/kvm."
    fi

    if systemctl is-active --quiet libvirtd.socket ||
       systemctl is-active --quiet libvirtd.service; then
        ok "libvirt está disponible."
    else
        aviso "libvirt no aparece activo."
    fi

    if virsh -c qemu:///system list --all >/dev/null 2>&1; then
        ok "Conexión de Virt-Manager/libvirt correcta."
    else
        aviso "No se ha podido conectar con libvirt mediante qemu:///system."
    fi
}

comprobar_fish() {
    local fish_path
    local shell_actual

    titulo "Comprobar Fish"

    if ! fish_path=$(command -v fish); then
        aviso "Fish no está disponible."
        return 0
    fi

    if ! shell_actual=$(getent passwd "$USER" | cut -d: -f7); then
        aviso "No se ha podido consultar la shell del usuario."
        return 0
    fi

    if [[ "$shell_actual" == "$fish_path" ]]; then
        ok "Fish es la shell predeterminada del usuario."
    else
        aviso "Fish no aparece como shell predeterminada."
        info "Shell configurada: $shell_actual"
    fi
}

comprobar_zram_post() {
    local swap_activa

    titulo "Comprobar ZRAM"

    if systemctl is-active --quiet zramswap.service; then
        ok "zramswap.service ha arrancado automáticamente."
    else
        aviso "zramswap.service no está activo."
        return 0
    fi

    if ! swap_activa=$(swapon --show=NAME --noheadings 2>/dev/null); then
        aviso "No se ha podido consultar la swap activa."
        return 0
    fi

    if [[ "$swap_activa" == *"/dev/zram"* ]]; then
        ok "ZRAM está siendo utilizada como swap."
    else
        aviso "No se ha encontrado ningún dispositivo ZRAM activo como swap."
    fi

    info "Estado de ZRAM:"

    if ! zramctl; then
        aviso "No se ha podido obtener información con zramctl."
    fi

    printf '\n'
    info "Swap activa:"

    if ! swapon --show; then
        aviso "No se ha podido mostrar la swap activa."
    fi
}

comprobar_snapper_post() {
    titulo "Comprobar Snapper"

    if [[ ! -f /etc/snapper/configs/root ]]; then
        aviso "Snapper no está configurado para la raíz."
        return 0
    fi

    ok "Configuración root de Snapper detectada."

    if systemctl is-active --quiet snapper-timeline.timer; then
        ok "snapper-timeline.timer está activo."
    else
        aviso "snapper-timeline.timer no está activo."
    fi

    if systemctl is-active --quiet snapper-cleanup.timer; then
        ok "snapper-cleanup.timer está activo."
    else
        aviso "snapper-cleanup.timer no está activo."
    fi

info "Snapshots disponibles:"

if ! sudo snapper -c root list; then
    aviso "No se ha podido obtener la lista de snapshots."
fi
}

comprobar_ufw_ssh_post() {
    titulo "Comprobar firewall y SSH"

    info "Estado de UFW:"

    if ! sudo ufw status numbered; then
        aviso "No se ha podido consultar el estado de UFW."
    fi

    # SSH solo se comprueba si openssh-server está instalado.
    if ! dpkg-query -W -f='${Status}' openssh-server 2>/dev/null \
        | grep -q 'install ok installed'; then
        info "Servidor SSH no instalado."
        return 0
    fi

    if systemctl is-active --quiet ssh.service; then
        ok "Servidor SSH activo."
    else
        aviso "El servidor SSH no está activo."
    fi

    if sudo /usr/sbin/sshd -t; then
        ok "Configuración de OpenSSH válida."
    else
        aviso "La configuración de OpenSSH contiene errores."
    fi
}

comprobar_trim_post() {
    titulo "Comprobar TRIM"

    if systemctl is-enabled --quiet fstrim.timer; then
        ok "fstrim.timer está habilitado."
    else
        aviso "fstrim.timer no está habilitado."
    fi

    if systemctl is-active --quiet fstrim.timer; then
        ok "fstrim.timer está activo."
    else
        aviso "fstrim.timer no está activo."
    fi
}

comprobaciones_post_reinicio() {

    if [[ -f "$GAMING_BACKPORTS_FLAG" ]]; then
        comprobar_kernel
        comprobar_gaming
    fi

    comprobar_gpu
    comprobar_virtualizacion
    comprobar_fish
    comprobar_zram_post
    comprobar_snapper_post
    comprobar_ufw_ssh_post
    comprobar_trim_post
}

# 15 FINALIZACIÓN
# --------------------------------------------------

crear_diagnostico_final() {
    titulo "Diagnóstico final"

    info "Creando diagnóstico del sistema..."

    mkdir -p "$DIAGNOSTICO_DIR"

    if ! inxi -Fxxxz > "$DIAGNOSTICO_DIR/inxi.txt" 2>&1; then
        aviso "No se ha podido generar inxi.txt."
    fi

    if ! uname -a > "$DIAGNOSTICO_DIR/kernel.txt" 2>&1; then
        aviso "No se ha podido generar kernel.txt."
    fi

    if ! glxinfo -B > "$DIAGNOSTICO_DIR/opengl.txt" 2>&1; then
        aviso "No se ha podido generar opengl.txt."
    fi

    if ! vulkaninfo --summary > "$DIAGNOSTICO_DIR/vulkan.txt" 2>&1; then
        aviso "No se ha podido generar vulkan.txt."
    fi

    ok "Diagnóstico guardado en $DIAGNOSTICO_DIR"
}

crear_snapshot_final() {
    titulo "Snapshot final"

    if [[ ! -f /etc/snapper/configs/root ]]; then
        aviso "Snapper no está configurado. Se omitirá el snapshot final."
        return 0
    fi

    info "Creando snapshot final del sistema..."

    if sudo snapper -c root create \
        --description "Sistema completo y funcionando" \
        --cleanup-algorithm number \
        --userdata important=yes; then

        ok "Snapshot final creado."
    else
        aviso "No se ha podido crear el snapshot final."
        aviso "La instalación continuará considerándose completada."
    fi
}

finalizar_instalacion() {
    local machine_id

    crear_diagnostico_final
    crear_snapshot_final

    machine_id=$(cat /etc/machine-id)

    if [[ -z "$machine_id" ]]; then
        fatal "No se ha podido obtener el machine-id del sistema."
    fi

    # Registrar que esta instalación concreta de Debian ya está terminada.
    printf '%s\n' "$machine_id" > "$INSTALL_COMPLETE_FLAG"

    # Ya no quedan tareas pendientes después del reinicio.
    rm -f "$POST_REBOOT_FLAG"

    printf '\n'
    ok "Instalación de Debian completada correctamente."
    info "Diagnóstico disponible en: $DIAGNOSTICO_DIR"
    info "Registro disponible en: $LOG_FILE"
}

# EJECUCIÓN PRINCIPAL
# --------------------------------------------------

instalacion_principal() {
    mostrar_banner
    titulo "Instalación de Debian"
    comprobaciones_iniciales
    preparar_repositorios
    preparar_sistema
    instalar_aplicaciones_debian
    configurar_flatpak
    configurar_virtualizacion
    if preguntar_gaming_backports; then
    activar_i386
    actualizar_indices_apt
    instalar_gaming
    fi

    configurar_snapper

    if [[ -f "$GAMING_BACKPORTS_FLAG" ]]; then
    configurar_backports_sistema
    fi

    instalar_aplicaciones_externas
    configurar_sistema
    comprobaciones_pre_reinicio
    preparar_reinicio
}

post_instalacion() {
    titulo "Post-instalación"

    info "Se ha detectado una instalación pendiente de comprobación."

    preparar_sudo

    comprobaciones_post_reinicio
    finalizar_instalacion
}

main() {
    local boot_anterior
    local boot_actual

    # Esta comprobación se hace antes de crear logs o modificar nada.
    comprobar_usuario

    activar_traps
    iniciar_log

    if [[ -f "$INSTALL_COMPLETE_FLAG" ]]; then
    local machine_id_guardado
    local machine_id_actual

    read -r machine_id_guardado < "$INSTALL_COMPLETE_FLAG"
    machine_id_actual=$(cat /etc/machine-id)

    if [[ -n "$machine_id_guardado" &&
          "$machine_id_guardado" == "$machine_id_actual" ]]; then
        ok "Este sistema ya ha completado la instalación."
        info "No se realizará ningún cambio."
        return 0
    fi

    # La marca pertenece a otra instalación de Debian.
    aviso "Se ha encontrado una marca de una instalación anterior."
    rm -f "$INSTALL_COMPLETE_FLAG"
fi

    if [[ -f "$POST_REBOOT_FLAG" ]]; then
        read -r boot_anterior < "$POST_REBOOT_FLAG"
        boot_actual=$(cat /proc/sys/kernel/random/boot_id)

        if [[ -z "$boot_anterior" || -z "$boot_actual" ]]; then
            fatal "No se ha podido comprobar correctamente el estado del reinicio."
        fi

        # Si ambos identificadores son iguales, todavía estamos
        # en el mismo arranque y el reinicio sigue pendiente.
        if [[ "$boot_anterior" == "$boot_actual" ]]; then
            aviso "La instalación terminó, pero el sistema todavía no se ha reiniciado."

            preparar_sudo
            preparar_reinicio
            return 0
        fi

        # El Boot ID ha cambiado: el sistema sí se ha reiniciado.
        post_instalacion
        return 0
    fi

    instalacion_principal
}

main "$@"
