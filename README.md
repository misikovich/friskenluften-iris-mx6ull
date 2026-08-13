# i.MX6ULL NAND Provisioning Project

This repository builds a self-contained microSD provisioning image for a custom i.MX6ULL board. It supports first boot on a board with blank NAND, automatic installation of U-Boot and a Buildroot system into raw SLC NAND, subsequent NAND boot, visible programming status, and SDIO Wi-Fi bring-up.

The image is intentionally board-specific. The installer writes raw flash and must not be used on hardware with a different NAND geometry or pinout.

## Hardware profile

- i.MX6ULL-class ARM Cortex-A7 processor
- 512 MiB DDR3
- 512 MiB (4 Gbit) SLC NAND
- 2.4 GHz Wi-Fi/Bluetooth combo module on USDHC2
  - Wi-Fi chipset compatible with `brcmfmac` BCM43430/CYW4343W support
  - Bluetooth is currently disabled
- Grid PLC using QCA7005 on ECSPI1
- PN7150 NFC controller on I2C4
- Buzzer on PWM3
- Debug console on UART1 at 115200 8N1

## Repository layout

```text
├── README.md
├── AGENTS.md
├── burn-sd.sh                    Safely write the generated image to microSD
├── plceth-testcmd.txt            Grid PLC test command notes
├── hardware/                     Hardware and firmware reference archive
├── configs/friskenluften_iris_defconfig
├── board/friskenluften/iris/     Board support: DTS, U-Boot patches, installer
└── …                             upstream Buildroot 2026.05 tree
```

This repository is a self-contained Buildroot 2026.05 fork; board support lives in-tree under `configs/` and `board/`.

The names `friskenluften_iris_defconfig` and `board/friskenluften/iris` are retained as existing build identifiers. They should be treated as literal paths; the implementation itself is documented generically.

Important board files:

- `configs/friskenluften_iris_defconfig`: complete Buildroot configuration
- `board/friskenluften/iris/linux-dts/`: Linux device tree
- `board/friskenluften/iris/patches/uboot/`: U-Boot board, NAND, UBI, and boot-flow changes
- `board/friskenluften/iris/linux.fragment`: additional kernel options
- `board/friskenluften/iris/S99nand-install`: automatic NAND installer and LED status logic
- `board/friskenluften/iris/buzz`: buzzer tone player installed as `/usr/sbin/buzz`
- `board/friskenluften/iris/S00buzz-boot`: power-on buzzer cue, first init script
- `board/friskenluften/iris/post-build.sh`: installs kernel, DTB, and init script into the target root filesystem
- `board/friskenluften/iris/post-image.sh`: creates payload checksums and invokes `genimage`
- `board/friskenluften/iris/genimage.cfg`: microSD layout

The sanitized `hardware/` archive contains the recovered DTB/DTS, component
datasheets, known-good firmware, and driver notes. Complete factory recovery
images, provisioning material, credentials, keys, and unique device data are
intentionally not retained. See `hardware/README.md`.

## Boot architecture

### Provisioning microSD

The generated `output/images/sdcard.img` contains:

1. U-Boot at byte offset 1024, outside the partition table.
2. A 64 MiB FAT boot/payload partition starting at 8 MiB.
3. A 128 MiB ext4 Buildroot partition used while provisioning.

The FAT partition contains:

- `u-boot-dtb.imx`
- `rootfs.ubi`
- `zImage`
- the board DTB
- `install.sha256`

### NAND

Linux exposes two fixed MTD partitions:

```text
mtd0  0x00000000-0x00400000  boot  4 MiB
mtd1  0x00400000-0x20000000  ubi   508 MiB
```

`kobs-ng` writes the i.MX NAND boot structures and redundant U-Boot bootstreams into `mtd0`. `mtd1` contains UBI with a dynamic `rootfs` volume. The UBIFS root filesystem also contains `/boot/zImage` and the DTB.

Normal NAND boot is:

```text
i.MX ROM → NAND boot structures → U-Boot → UBI/UBIFS → Linux → UBIFS root
```

The NAND boot partition is read-only during normal NAND operation. U-Boot removes that protection only from the in-memory device tree used by the SD installer.

## Build

Clone the repository (self-contained Buildroot tree, no submodules):

```bash
git clone git@github.com:misikovich/friskenluften-iris-mx6ull.git
cd friskenluften-iris-mx6ull
```

From the repository root:

```bash
make friskenluften_iris_defconfig
make
```

If the kernel configuration or custom device tree changed, force Linux to recopy and rebuild it before the full image build:

```bash
make linux-reconfigure
make
```

Primary output files are under `output/images/`:

- `sdcard.img`: complete provisioning card image
- `u-boot-dtb.imx`: U-Boot bootstream input
- `rootfs.ubi`: NAND root filesystem payload
- `rootfs.ext2`: provisioning root filesystem
- `zImage` and `imx6ull-14x14-evk.dtb`
- `install.sha256`: installer payload hashes

Validate the payload and complete image after every build:

```bash
cd output/images
sha256sum -c install.sha256
sha256sum sdcard.img
```

## Write the provisioning card

Identify the card carefully. The following operation overwrites the selected device:

```bash
lsblk -p -o NAME,SIZE,MODEL,TRAN,MOUNTPOINTS
```

Replace `/dev/sdX` with the whole microSD device, not a partition:

```bash
./burn-sd.sh /dev/sdX
```

The script finds the freshly built `output/images/sdcard.img`, rejects
partitions and system-mounted disks, escalates through `sudo`, requires an
exact device-name confirmation, unmounts removable-media filesystems, writes
the card, and verifies every written image byte.

## Automatic provisioning workflow

1. Insert the provisioning microSD before power-on.
2. The i.MX ROM loads U-Boot from the card.
3. U-Boot loads Linux and the ext4 root filesystem from the card.
4. `/etc/init.d/S99nand-install` detects `root=/dev/mmcblk0p2` and starts automatically.
5. The installer mounts the FAT payload partition read-only.
6. It verifies payload hashes, board identity, exact MTD sizes, page/OOB/erase geometry, and write access to the boot MTD.
7. `kobs-ng` writes the NAND boot structures and U-Boot.
8. `ubiformat` writes the UBI image.
9. The installer attaches and mounts the new UBIFS volume, then checks for a non-empty kernel and DTB.
10. It detaches cleanly, reports completion, and remains running.
11. Remove the microSD and reset the board manually.

There is deliberately no automatic reboot or power-off. On a NAND-root boot the destructive installer path is skipped and only the programmed-board LED state is selected.

## Status LED

The kernel exposes the PWM LED as:

```text
/sys/class/leds/debug
```

The installer uses the native Linux LED pattern trigger:


| State                        | Pattern                                                                                     |
| ---------------------------- | ------------------------------------------------------------------------------------------- |
| Programming started          | Fast breathing with a 200 ms full-brightness plateau, approximately 0.8 seconds per cycle   |
| Programming complete         | Ten flashes in one second, then slow breathing with a full-brightness plateau               |
| Programming failed           | Toggle every 250 ms forever                                                                 |
| Normal programmed-board boot | Slow breathing with a 600 ms full-brightness plateau, approximately three seconds per cycle |

The implementation is in `board/friskenluften/iris/S99nand-install`. Kernel support is enabled by `CONFIG_LEDS_TRIGGER_PATTERN`.

## Buzzer

The buzzer is driven by PWM3 (`2088000.pwm`) on `GPIO1_IO04`. No kernel
consumer claims the channel, so it stays available through the standard Linux
PWM sysfs interface. `buzz` plays a tone sequence:

```sh
buzz 20 600:100,0:50,800:100
```

The first argument is the loudness in percent, `0`-`100`. The sequence is a
comma-separated list of `HZ:MS` notes, played in order: frequency in hertz,
then duration in milliseconds. Frequency `0` is a rest. Accepted ranges are
20-20000 Hz and 1-60000 ms; any malformed sequence is rejected before the
hardware is touched.

Pitch is the PWM period and loudness is the PWM duty ratio, so volume `100`
means a 50 percent duty cycle, the loudest square wave the pin can produce.
The command blocks for the length of the sequence and silences the buzzer on
exit, including on interruption. The implementation is
`board/friskenluften/iris/buzz`.

Two cues are automatic:

| Event                | Sequence                                | Played by                     |
| -------------------- | --------------------------------------- | ----------------------------- |
| Power-on             | `20 600:100,0:50,600:100`               | `/etc/init.d/S00buzz-boot`    |
| NAND install complete| `20 600:100,0:50,900:100,0:50,1300:100` | `/etc/init.d/S99nand-install` |

`S00buzz-boot` is the first script `rcS` runs, so the power-on cue sounds as
early as userspace can reach the buzzer. It runs on every boot, from the
provisioning card and from NAND. The completion cue sounds once the installer
has verified the programmed NAND, immediately before the completion LED
pattern; a failed install stays silent and only the failure LED state applies.

Inspect or drive the channel manually:

```sh
readlink -f /sys/class/pwm/pwmchip*
cat /sys/class/pwm/pwmchip*/pwm0/period /sys/class/pwm/pwmchip*/pwm0/duty_cycle
```

## Wi-Fi

The Linux device tree enables USDHC2, the standard MMC power sequence, the host-wake interrupt, and the PWM-generated 32.768 kHz low-power clock. Buildroot includes `brcmfmac`, the matching firmware and module NVRAM, the regulatory database, `iw`, and `wpa_supplicant` tools.

After boot, confirm enumeration:

```sh
dmesg | grep -Ei '2194000|mmc1|brcmfmac|firmware'
iw dev
ip link show wlan0
```

Scan for networks:

```sh
ip link set wlan0 up
iw reg set NO
iw dev wlan0 scan | grep SSID
```

Replace `NO` with the correct ISO country code when operating elsewhere.

Create a persistent connection configuration on the NAND root filesystem:

```sh
wpa_passphrase "YOUR_SSID" "YOUR_PASSWORD" \
  | sed '/#psk=/d' > /etc/wpa_supplicant.conf
wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant.conf
udhcpc -i wlan0
wpa_cli -i wlan0 status
```

Running `wpa_passphrase` with the password as an argument can leave it in shell history. The generated configuration contains the derived PSK after the commented clear-text line is removed.

No Wi-Fi credentials are embedded in the build, and no automatic Wi-Fi
connection service is enabled yet.

## NFC

The PN7150 NFC controller uses I2C4 at address `0x29`. Its interrupt is
connected to `GPIO2_IO08`, and its active-high reset/enable input is connected
to `GPIO2_IO14`. Linux uses the upstream `nxp_nci_i2c` driver and exposes the
controller through the kernel NFC subsystem. `neard` provides tag and NDEF
record discovery to userspace.

Scan for one NFC tag, with a default 30-second timeout:

```sh
nfc-scan
```

Pass a different timeout in seconds when needed:

```sh
nfc-scan 60
```

The command verifies the I2C device, kernel driver, NFC adapter, and `neard`
service before polling. It prints the detected tag path, UID, type, protocol,
read-only state, and decoded NDEF record fields. On a terminal, logs scroll
above a fixed status panel. Preview it without NFC hardware using
`nfc-scan --tui-test`.

## Grid PLC

Linux uses the upstream `qcaspi` Ethernet driver for the QCA7005 host
interface. The device identifies through the established `qca,qca7000`
binding, as it did in the recovered working board description. The early
`S09plc-grid-reset` script pulses the dedicated reset before udev loads the
driver. The interface is the only enabled wired Ethernet device and is brought
up as `eth0` using DHCP.

Verify the complete PLC path:

```sh
plc-grid-check
```

The command verifies the SPI driver and counters, reads the local QCA7005
identity and membership, requires a remote PLC station with nonzero PHY rates,
and runs ARP discovery when DHCP has supplied an IPv4 address. On a terminal,
logs scroll above a fixed status panel. Preview it without hardware using
`plc-grid-check --tui-test`. To also require a response from a known IP peer:

```sh
plc-grid-check PEER_IP
```

For manual diagnosis, inspect the same driver state directly:

```sh
dmesg | grep -Ei 'qca|spi0\.0|ecspi'
readlink /sys/class/net/eth0/device/driver
ethtool -i eth0
ifconfig eth0
cat /proc/interrupts | grep -Ei 'qca|spi0\.0'
plctool -i eth0 -r -L -m
plcstat -i eth0 -t
plcrate -i eth0 -l 3 -w 1 -x
```

A working host interface reports the `qcaspi` driver and transitions to
`LOWER_UP` after the driver synchronizes with the QCA7005. Inspect its SPI and
packet counters before and after a traffic test:

```sh
ethtool -S eth0
udhcpc -i eth0 -n -q
arp-scan --interface=eth0 --localnet
ping -c 4 GATEWAY_OR_PEER_IP
ethtool -S eth0
```

Successful DHCP/ping with increasing TX/RX counters verifies the complete
CPU-to-SPI-to-PLC-to-grid-network path. Driver binding without `LOWER_UP`
verifies only the CPU-to-SPI portion; then check PLC pairing/configuration and
the power-line side separately. No fixed MAC address is embedded, so the
driver uses a random locally administered address until board-specific MAC
storage is defined.

## Useful runtime checks

Boot source and root filesystem:

```sh
cat /proc/cmdline
mount | grep ' on / '
cat /proc/partitions
```

NAND and UBI:

```sh
cat /proc/mtd
dmesg | grep -Ei 'gpmi|nand|mtd|ubi|ubifs|bch'
ubinfo -a
```

Memory and board identity:

```sh
uname -a
cat /proc/device-tree/model; echo
free -h
```

Expected NAND geometry in U-Boot:

```text
Page size       4096 B
OOB size         256 B
Erase size    262144 B
ECC strength      18 bits
ECC step size     512 B
```

Do not program NAND if these values differ.

## Recovery and troubleshooting

- No UART output: verify 3.3 V UART levels, 115200 8N1, common ground, SD image placement, and ROM boot configuration.
- U-Boot stops at networking: networking is optional for provisioning; the current build reports no Ethernet and continues to the prompt.
- SD not detected: verify USDHC instance numbering, card-detect polarity, pad mux, and that the card was present at reset.
- NAND reports the wrong OOB or ECC geometry: stop before writing; kernel and U-Boot must agree on the GPMI/BCH layout.
- `ubi part ubi` fails in U-Boot: first select the named MTD partition using the U-Boot MTD/UBI commands supported by the current build.
- Wi-Fi does not enumerate: inspect `mmc1`, REG_ON, the 32.768 kHz clock, SDIO pin mux, and firmware request filenames in `dmesg`.
- `wlan0` exists but cannot associate: verify the country code, SSID, PSK, antenna, and regulatory database.

Keep a known-good provisioning microSD. It is the primary recovery route while the SoC boot configuration remains capable of removable-media boot.

## Safety notes

- Never copy NAND commands from another board without confirming page, OOB, erase, ECC, partition, and bootstream parameters.
- Never use `nand write` as a substitute for `kobs-ng` on this boot layout.
- Never point `dd`, `ubiformat`, or `kobs-ng` at an unverified device.
- Do not burn boot fuses during bring-up. Fuses are irreversible and are not needed for this workflow.
- Preserve the installer checks. They are the boundary preventing accidental writes on the wrong boot source or hardware.
