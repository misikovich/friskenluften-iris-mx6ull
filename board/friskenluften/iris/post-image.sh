#!/bin/sh
set -eu

(
	cd "${BINARIES_DIR}"
	sha256sum u-boot-dtb.imx rootfs.ubi > install.sha256
)

support/scripts/genimage.sh -c board/friskenluften/iris/genimage.cfg
