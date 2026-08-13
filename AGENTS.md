# Repository Instructions

## Scope

This repository builds and documents a provisioning image for a custom i.MX6ULL board with removable microSD and raw SLC NAND. Make the smallest board-specific change that solves the requested problem.

This repository is a self-contained Buildroot fork for the custom i.MX6ULL board. `board/friskenluften/` and `configs/friskenluften_iris_defconfig` are project files; do not delete, reset, or overwrite them. The `upstream` remote tracks Buildroot (gitlab.com/buildroot.org) for future release rebases.

## Terminology and paths

Use generic terms such as “custom i.MX6ULL board,” “provisioning image,” and “status LED” in new documentation. Product names may remain where they are literal paths, configuration symbols, device-tree identity strings, or required compatibility data.

The following legacy identifiers are active build interfaces and must not be renamed without an explicit migration request:

- `configs/friskenluften_iris_defconfig`
- `board/friskenluften/iris/`
- `imx6ull-14x14-evk.dtb`

Treat `hardware/` as reference evidence. Do not package its legacy binaries or
firmware into the target automatically; use normal Buildroot packages where
available. Never add complete factory images, provisioning material,
credentials, keys, MAC addresses, or unique device data to it.

## Hardware invariants

- RAM: 512 MiB DDR3 at `0x80000000`
- NAND: 512 MiB SLC, 4096-byte page, 256-byte OOB, 256 KiB erase block
- BCH: strength 18, 512-byte step
- MTD layout: 4 MiB `boot`, remaining 508 MiB `ubi`
- microSD: USDHC1, Linux `mmc0`
- Wi-Fi: USDHC2, four-bit SDIO, maximum 25 MHz
- WLAN host wake: `GPIO1_IO06`, level-low IRQ in the recovered working DT
- WLAN reset/enable: `GPIO1_IO07`, active low through `mmc-pwrseq-simple`
- WLAN low-power clock: PWM6 on `JTAG_TDI`, 32768 Hz
- Debug LED: PWM1 on `ENET1_RX_DATA0`
- Buzzer: PWM3 on `GPIO1_IO04`, ALT1, pad setting `0x10`, no kernel consumer;
  tones come from userspace through the PWM sysfs interface
- Grid PLC: QCA7005 using the upstream `qcaspi`/`qca,qca7000` interface on
  ECSPI1, mode 3 at 8 MHz
- Grid PLC chip select: `GPIO4_IO26`, active low
- Grid PLC interrupt: `GPIO3_IO00`, rising edge
- Grid PLC reset: `GPIO3_IO01`, active low; pulse before udev loads `qcaspi`
- NFC: PN7150 on I2C4 at address `0x29`, 400 kHz
- NFC interrupt: `GPIO2_IO08`, rising edge
- NFC reset/enable: `GPIO2_IO14`, active high
- EV PLC: ECSPI2, disabled until explicitly requested
- Console: UART1, 115200 8N1
- Bluetooth: disabled until explicitly requested

Do not change these values from convention or a similar evaluation board. Require board evidence, a datasheet, schematic, or a verified reference DT.

## Provisioning safety

Changes to `S99nand-install` must retain:

- execution of destructive programming only when the kernel root is `/dev/mmcblk0p2`
- read-only mounting of the FAT payload partition
- SHA-256 payload verification
- board identity check
- exact MTD size and NAND geometry checks
- writable-boot-MTD check
- `kobs-ng` for NAND boot structures
- UBI formatting followed by attach, mount, kernel/DTB verification, unmount, and detach
- cleanup on failure
- no automatic reboot or power-off

Never replace `kobs-ng` with a raw NAND write. Do not alter `--search_exponent=1` or `-x` without verified ROM boot-layout evidence.

The required LED states are:

- programming: fast breathing
- complete: ten flashes in one second, then slow breathing
- failure: toggle every 250 ms forever
- programmed NAND boot: slow breathing

The required buzzer cues, played through `buzz`, are:

- power-on, every boot, first init script: `20 600:100,0:50,600:100`
- install complete, before the completion LED pattern: `20 600:100,0:50,900:100,0:50,1300:100`
- install failure: silent

## Build and validation

Run commands from the repository root.

On a fresh checkout or after removing `.config`, configure the board before
building:

```bash
make friskenluften_iris_defconfig
```

After configuration changes:

```bash
make friskenluften_iris_defconfig
```

After Linux configuration or DTS changes:

```bash
make linux-reconfigure
```

Build the complete image:

```bash
make
```

Minimum validation for relevant changes:

```bash
sh -n board/friskenluften/iris/S99nand-install
git diff --check
(cd output/images && sha256sum -c install.sha256)
sha256sum output/images/sdcard.img
```

For device-tree work, decompile the generated DTB and verify the affected nodes rather than checking only the source:

```bash
output/host/bin/dtc -I dtb -O dts \
  output/images/imx6ull-14x14-evk.dtb
```

For root-filesystem additions, verify the actual generated image or `output/target`, including file modes and symlink targets.

## Generated files

Do not edit or commit `output/` or `dl/`. The distributable artifact is generated as `output/images/sdcard.img`.

Do not execute host-side `dd`, `ubiformat`, NAND erase/write commands, or fuse operations unless the user explicitly requests the action and the exact target has been verified. Providing commands for the user to run is acceptable when the destructive target is clearly marked.

## Change style

- Reuse Buildroot, kernel, U-Boot, MTD, UBI, LED, MMC power-sequence, and `brcmfmac` facilities before adding custom services or daemons.
- Keep board logic in the existing board support directory.
- Preserve unrelated user changes in the dirty worktree.
- Use `apply_patch` for source edits.
- Prefer one direct implementation and one proportional runtime/build check.
- Do not add Wi-Fi credentials, secrets, unique MAC addresses, or fuse values to source control.
