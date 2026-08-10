# Hardware Reference

This directory contains the small, reusable part of the original board dump:
component documentation, recovered board-description evidence, known-good
firmware, and one legacy driver binary. It contains no complete factory image,
provisioning scripts, credentials, keys, device identities, or network
configuration.

None of these files is automatically copied into the Buildroot image. The
active board support remains under `board/friskenluften/iris/`.

## Board profile

| Function | Hardware and connection |
|---|---|
| Processor | i.MX6ULL, ARM Cortex-A7 |
| RAM | MT41K256M16, 512 MiB DDR3, mapped at `0x80000000` |
| NAND | MT29F4G08ABAFAWP, 512 MiB SLC, 4096-byte page, 256-byte OOB, 256 KiB erase block |
| NAND ECC | BCH strength 18 per 512-byte step |
| NAND layout | 4 MiB `boot`, remaining 508 MiB `ubi` |
| Removable media | USDHC1, Linux `mmc0` |
| Wi-Fi | LBEE5KL1DX/CYW4343W on four-bit USDHC2 SDIO, maximum 25 MHz |
| WLAN host wake | `GPIO1_IO06`, level-low interrupt |
| WLAN reset/enable | `GPIO1_IO07`, active low through `mmc-pwrseq-simple` |
| WLAN low-power clock | PWM6 on `JTAG_TDI`, 32768 Hz |
| Grid PLC | QCA7005 on ECSPI1, mode 3 at 8 MHz |
| Grid PLC chip select | `GPIO4_IO26`, active low |
| Grid PLC interrupt | `GPIO3_IO00`, rising edge |
| Grid PLC reset | `GPIO3_IO01`, active low |
| Status LED | PWM1 on `ENET1_RX_DATA0` |
| Console | UART1, 115200 8N1 |

The recovered reference DT describes two QCA7005-compatible SPI Ethernet
devices. The minimal Buildroot image enables only the ECSPI1 Grid module; the
ECSPI2 EV module remains disabled. The reference also describes a PCF85063TP
RTC, an I2C EEPROM, and a PN547 NFC controller, which are not yet enabled or
tested in the minimal image.

## Contents

### `board/`

- `reference-board.dtb` is the original known-good device-tree blob.
- `reference-board.dts` is a mechanical decompilation of that blob for pin and
  peripheral research. It is not maintained source and retains literal legacy
  identity strings where they are part of the evidence. `dtc` reports several
  warnings inherited from the original blob.

Use the maintained DTS for builds:

```text
board/friskenluften/iris/linux-dts/nxp/imx/imx6ull-14x14-evk.dts
```

### `datasheets/`

- `mt41k256m16-ddr3.pdf`: DDR3 component datasheet.
- `mt29f4g08abafawp-nand.pdf`: SLC NAND component datasheet.

### `firmware/`

- `wifi/cyfmac43430-sdio.bin`: known-good CYW43430 Wi-Fi firmware.
- `wifi/cyfmac43430-sdio.clm_blob`: matching regulatory/calibration data.
- `wifi/cyfmac43430-sdio.1DX.txt`: module-specific NVRAM parameters.
- `bluetooth/BCM43430A1_001.002.009.0159.0528.1DX.hcd`: Bluetooth patchram
  firmware retained for future work; Bluetooth is currently disabled.
- `imx/sdma-imx6q.bin`: i.MX6 SDMA firmware.

Buildroot currently obtains newer firmware through `linux-firmware`. The files
here are fallback/reference copies from a known-working image. Their original
licenses and redistribution terms still apply.

### `drivers/`

Most relevant drivers are upstream Linux drivers and must be rebuilt with the
active kernel:

| Hardware | Linux driver |
|---|---|
| GPMI NAND/BCH | `gpmi-nand`, `mxs-dma` |
| USDHC/SDIO | `sdhci-esdhc-imx` |
| CYW43430 Wi-Fi | `brcmfmac`, `brcmutil`, `cfg80211` |
| QCA7000 SPI Ethernet | `qcaspi`, `qca_7k_common` |
| PCF85063TP RTC | `rtc-pcf85063` |
| i.MX PWM LED | `pwm-imx`, LED PWM/pattern trigger support |

`drivers/legacy/pn5xx_i2c-linux-5.15.ko` is retained only because the dump had
no corresponding PN54x source. It has kernel-5.15 symbol/version dependencies
and must not be loaded into the current kernel. Find or port source before
enabling NFC.

## Reference checksums

```text
cc7eae6f2e519a0d3f37807f5d55e9c9db1aa33bfc157dc835876d44818349fb  board/reference-board.dtb
82ed67a211877efa47aff4aab83d6d2d1ccf3d5d0f5c396df97f292ade01de9e  firmware/wifi/cyfmac43430-sdio.bin
2c4037b6289ea08b79ba3139860ee66f565e8e614ea3e39eda82b7aae1ae155c  firmware/wifi/cyfmac43430-sdio.clm_blob
18f0a96a8e5fad35d045f6f841db18a901d55cd3f9f2eff71dde0f8213799dba  firmware/wifi/cyfmac43430-sdio.1DX.txt
fd838e39566270f633f0a53326a7db2539b9b20bd423eac7f40e9a7643ed8e19  firmware/bluetooth/BCM43430A1_001.002.009.0159.0528.1DX.hcd
8295b3a4e1aa7b41cabca166da2357848fd172203893e94ecb84fe42143f495e  firmware/imx/sdma-imx6q.bin
89ffcc2ee5dc7fb4a916dfebb506b12f224434e9347667b51f29d872ad0e09ef  drivers/legacy/pn5xx_i2c-linux-5.15.ko
```
