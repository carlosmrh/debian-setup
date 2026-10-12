# Debian 13 Setup

Script de post-instalación para automatizar la configuración de **Debian 13 Trixie con KDE Plasma/Wayland**.

Está pensado para una instalación nueva de Debian y automatiza repositorios, actualización del sistema, eliminación de software preinstalado, instalación de aplicaciones, Flatpak, virtualización, Snapper, seguridad, ZRAM, TRIM y, opcionalmente, Gaming junto con Kernel/Mesa desde Backports.

> **Importante:** el script está diseñado para ejecutarse con un usuario normal que tenga acceso a `sudo`.
> **No debe ejecutarse con `sudo ./debian-setup.sh` ni como root.**

---

## Índice

- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Flujo de ejecución](#flujo-de-ejecución)
- [Programas eliminados](#programas-eliminados)
- [Programas instalados](#programas-instalados)
- [Gaming y Backports](#gaming-y-backports)
- [Configuración del sistema](#configuración-del-sistema)
- [Snapper y Btrfs](#snapper-y-btrfs)
- [Firewall y SSH](#firewall-y-ssh)
- [Virtualización](#virtualización)
- [Comprobaciones y diagnóstico](#comprobaciones-y-diagnóstico)
- [Segundo arranque](#segundo-arranque)
- [Archivos generados](#archivos-generados)
- [Advertencias](#advertencias)
- [Licencia](#licencia)

---

## Requisitos

El script está preparado para:

- Debian **13 Trixie**
- Arquitectura **amd64 / x86_64**
- KDE Plasma / Wayland
- Usuario normal con permisos `sudo`
- Conexión a Internet

Btrfs no es obligatorio para ejecutar el instalador, pero es necesario para utilizar la configuración automática de **Snapper**.

El sistema objetivo del proyecto utiliza una GPU AMD, por lo que la instalación opcional de Backports incluye Mesa y firmware AMD.

---

## Instalación

### 1. Clonar el repositorio

```bash
git clone URL_DEL_REPOSITORIO
cd nombre-del-repositorio
```

### 2. Dar permisos de ejecución

```bash
chmod +x debian-setup.sh
```

### 3. Ejecutar el instalador

```bash
./debian-setup.sh
```

No ejecutar:

```bash
sudo ./debian-setup.sh
```

El propio script solicitará la contraseña de `sudo` cuando sea necesario.

### 4. Seguir las preguntas del instalador

Durante la instalación se preguntará, entre otras cosas:

- Si se desea instalar **Gaming + Kernel/Mesa desde Backports**
- Si se desea instalar y configurar un **servidor SSH**

### 5. Reinicio

Al finalizar la primera fase, el script solicitará reiniciar el sistema.

Después del reinicio hay que ejecutar de nuevo:

```bash
./debian-setup.sh
```

El script detectará que el reinicio ya se ha realizado y ejecutará únicamente las comprobaciones finales.

---

## Flujo de ejecución

En la primera ejecución se realiza, de forma resumida:

```text
Comprobaciones iniciales
        ↓
Repositorios Debian + Backports
        ↓
Eliminar programas preinstalados
        ↓
Actualizar Debian
        ↓
Instalar aplicaciones
        ↓
Flatpak + Flathub
        ↓
Virtualización
        ↓
¿Gaming + Backports?
        ↓
Snapper
        ↓
Aplicaciones externas
        ↓
Configuración del sistema
        ↓
Comprobaciones
        ↓
Reinicio
```

Después del reinicio:

```text
Comprobaciones post-reinicio
        ↓
Diagnóstico final
        ↓
Snapshot final
        ↓
Instalación completada
```

Una vez marcada la instalación como completada, volver a ejecutar el script no realizará cambios sobre esa misma instalación de Debian.

---

## Programas eliminados

Antes de actualizar el sistema se eliminan aplicaciones preinstaladas que no se utilizan.

Entre ellas:

- LibreOffice
- Konqueror
- KMail
- Firefox ESR
- GoldenDict-ng
- GIMP
- Akregator
- Kontact
- Sieve Editor
- Dragon Player
- JuK
- KOrganizer
- KAddressBook
- Thai X Terminal
- Anthy / Kasumi
- Mozc

La eliminación se realiza con `apt-get purge` y posteriormente:

```bash
apt-get autoremove --purge
```

Esto permite eliminar también dependencias que hayan quedado sin uso.

La eliminación se hace **antes del `full-upgrade`**, evitando descargar actualizaciones de aplicaciones que van a ser eliminadas.

---

## Programas instalados

### Terminal y utilidades

- Fish
- Fastfetch
- btop
- tree
- bat
- ripgrep
- GitHub CLI (`gh`)
- wget
- cmake
- pkg-config

Fish se establece como shell predeterminada del usuario.

### Escritorio KDE

- Filelight
- KIO Admin
- KDE Connect
- KeePassXC
- Converseen
- Thunderbird

### Sincronización

- Syncthing
- Syncthing Tray para KDE Plasma

### Multimedia

- FFmpeg
- `vainfo`
- unrar

### Sistema y diagnóstico

- inxi
- nvme-cli
- UFW
- GUFW
- Snapper
- Btrfs Assistant
- btrfs-progs
- zram-tools
- Kitty
- JetBrains Mono
- lm-sensors
- amd64-microcode
- mesa-utils
- vulkan-tools
- fwupd
- iproute2

### Impresora

- `printer-driver-brlaser`

### Flatpak

- Flatpak
- Backend Flatpak para Discover
- Repositorio Flathub a nivel de usuario

### Aplicaciones externas

Se instalan también:

- Brave Origin
- ONLYOFFICE Desktop Editors
- Visual Studio Code
- Discord
- Obsidian
- RustDesk Wayland Unattended

Faugus Launcher se instala únicamente cuando se selecciona la opción de Gaming.

---

## Gaming y Backports

El instalador pregunta:

```text
¿Quieres instalar Gaming y Kernel/Mesa desde Backports?
```

### Si se responde SÍ

Se activa la arquitectura `i386`:

```bash
sudo dpkg --add-architecture i386
```

Después se actualizan nuevamente los índices de APT y se instalan:

- Steam
- GameMode
- MangoHud
- Faugus Launcher
- Kernel desde `trixie-backports`
- Headers del kernel
- Firmware AMD
- Mesa AMD `amd64`
- Mesa AMD `i386`

También se crea la configuración de MangoHud.

### Si se responde NO

Se omite:

- Steam
- GameMode
- MangoHud
- Faugus Launcher
- Kernel Backports
- Mesa/Firmware AMD Backports

El script no activa `i386` en este caso.

> Si `i386` ya estaba activada previamente en el sistema, el script no la elimina.

---

## Configuración del sistema

### Fish

- Establece Fish como shell predeterminada
- Elimina el mensaje de bienvenida
- Configura `bat`/`batcat` cuando corresponde

### Kitty

Crea una configuración personalizada con:

- JetBrains Mono
- Transparencia
- Historial ampliado
- Copiar/pegar
- Pestañas
- Splits
- Atajos de teclado
- Navegación entre ventanas

### Num Lock en SDDM

Se crea:

```text
/etc/sddm.conf.d/10-numlock.conf
```

con:

```ini
[General]
Numlock=on
```

### GRUB

El tiempo de espera de GRUB se reduce a **1 segundo**, manteniendo disponible el menú de arranque.

### ZRAM

Se activa:

```text
zramswap.service
```

### TRIM

Se habilita:

```text
fstrim.timer
```

### Microcódigo AMD

Se instala:

```text
amd64-microcode
```

---

## Snapper y Btrfs

Si `/` utiliza Btrfs, el script configura Snapper automáticamente.

Política configurada:

```text
Snapshots horarios:     3
Snapshots diarios:      7
Snapshots semanales:    2
Snapshots mensuales:    0
Snapshots anuales:      0

Snapshots numerados:    10
Snapshots importantes:  10
```

También se habilitan:

```text
snapper-timeline.timer
snapper-cleanup.timer
```

Si se utilizan Kernel/Mesa desde Backports, se crea un snapshot antes de la actualización.

Al finalizar correctamente la instalación se crea otro snapshot con la descripción:

```text
Sistema completo y funcionando
```

---

## Firewall y SSH

### UFW

El firewall se configura con:

```text
Entradas: bloqueadas por defecto
Salidas: permitidas por defecto
```

Para KDE Connect se permiten:

```text
1714:1764/tcp
1714:1764/udp
```

### SSH

La instalación del servidor SSH es opcional.

Si se activa:

- Se instala `openssh-server`
- Se detecta automáticamente la red LAN
- El puerto 22 solo se permite desde la red local
- Root no puede iniciar sesión
- Se utiliza autenticación por contraseña
- Se desactiva autenticación por clave pública
- Se desactiva `KbdInteractiveAuthentication`
- Se limita a 3 intentos de autenticación

Configuración:

```text
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication no
KbdInteractiveAuthentication no
MaxAuthTries 3
```

---

## Virtualización

Se instala soporte para KVM/QEMU y libvirt.

Paquetes principales:

- virt-manager
- qemu-system-x86
- qemu-utils
- libvirt-daemon-system
- libvirt-clients
- bridge-utils
- OVMF
- virt-viewer
- virtiofsd

El usuario se añade automáticamente a:

```text
libvirt
kvm
```

Los nuevos grupos se aplican después de reiniciar o volver a iniciar sesión.

---

## Comprobaciones y diagnóstico

Antes del reinicio se comprueba:

- Btrfs
- Snapper
- ZRAM
- UFW
- SSH, si está instalado
- TRIM
- Backports, si se seleccionó Gaming

Después del reinicio se comprueba:

- Kernel Backports, si corresponde
- GameMode y MangoHud, si corresponde
- GPU
- OpenGL
- Vulkan
- VA-API
- Virtualización
- Fish
- ZRAM
- Snapper
- UFW / SSH
- TRIM

En máquinas virtuales es posible que OpenGL/Vulkan utilicen `llvmpipe` y que `vainfo` no funcione. Esto puede ser normal cuando la VM no expone aceleración gráfica o VA-API al sistema invitado.

---

## Segundo arranque

El instalador guarda el identificador del arranque antes de reiniciar.

Cuando se vuelve a ejecutar:

```bash
./debian-setup.sh
```

se comprueba que el `boot_id` haya cambiado.

Si el equipo todavía no se ha reiniciado, el script no continúa con las comprobaciones post-reinicio.

Cuando todo termina correctamente se guarda el `machine-id` del sistema para evitar ejecutar accidentalmente de nuevo toda la instalación.

---

## Archivos generados

### Logs

Los registros se almacenan en:

```text
~/.local/state/debian-setup/
```

### Diagnóstico

Al terminar se crea:

```text
~/Debian-diagnostico/
```

con información como:

```text
inxi.txt
kernel.txt
opengl.txt
vulkan.txt
```

---

## Advertencias

Este script realiza cambios importantes en el sistema:

- Modifica los repositorios de APT
- Elimina software preinstalado
- Ejecuta `apt-get full-upgrade`
- Puede instalar un kernel desde Backports
- Configura el firewall
- Puede instalar y configurar SSH
- Modifica GRUB
- Configura SDDM
- Cambia la shell predeterminada
- Configura Snapper y snapshots
- Reinicia el equipo al finalizar

Se recomienda revisar el script antes de ejecutarlo y utilizarlo únicamente en sistemas para los que haya sido diseñado.

---

## Licencia

MIT

---

## Autor

Carlos
