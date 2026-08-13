#!/bin/sh
set -eu

install -D -m 0644 "${BINARIES_DIR}/zImage" "${TARGET_DIR}/boot/zImage"
install -D -m 0644 "${BINARIES_DIR}/imx6ull-14x14-evk.dtb" \
	"${TARGET_DIR}/boot/imx6ull-14x14-evk.dtb"
install -D -m 0755 board/friskenluften/iris/S99nand-install \
	"${TARGET_DIR}/etc/init.d/S99nand-install"
install -D -m 0755 board/friskenluften/iris/S00buzz-boot \
	"${TARGET_DIR}/etc/init.d/S00buzz-boot"
install -D -m 0755 board/friskenluften/iris/S09plc-grid-reset \
	"${TARGET_DIR}/etc/init.d/S09plc-grid-reset"
install -D -m 0755 board/friskenluften/iris/plc-grid-check \
	"${TARGET_DIR}/usr/sbin/plc-grid-check"
install -D -m 0755 board/friskenluften/iris/nfc-scan \
	"${TARGET_DIR}/usr/sbin/nfc-scan"
install -D -m 0755 board/friskenluften/iris/buzz \
	"${TARGET_DIR}/usr/sbin/buzz"
