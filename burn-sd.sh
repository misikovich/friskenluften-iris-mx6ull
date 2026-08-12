#!/bin/sh
set -eu

die()
{
	echo "burnfw: $*" >&2
	exit 1
}

[ "$#" -eq 1 ] || die "usage: $0 /dev/sdX"

script="$(readlink -f -- "$0")"
project="$(dirname -- "$script")"
image="$project/output/images/sdcard.img"
device="$(readlink -f -- "$1")" || die "device does not exist: $1"

[ -r "$image" ] || die "build the image first: $image"
[ -b "$device" ] || die "not a block device: $device"
[ "$(lsblk -dn -o TYPE -- "$device")" = disk ] ||
	die "use the whole disk, not a partition: $device"

image_size="$(stat -c %s -- "$image")"
device_size="$(lsblk -bdn -o SIZE -- "$device")"
[ "$image_size" -gt 0 ] || die "image is empty: $image"
[ "$image_size" -le "$device_size" ] || die "image is larger than $device"

nodes="$(lsblk -nrpo NAME -- "$device")"
for node in $nodes; do
	while IFS= read -r target; do
		[ -n "$target" ] || continue
		case "$target" in
			/mnt|/mnt/*|/media/*|/run/media/*) ;;
			*) die "$node is mounted at $target; refusing to overwrite it" ;;
		esac
	done <<-EOF
	$(findmnt -rn -S "$node" -o TARGET 2>/dev/null || true)
	EOF
done

swap_nodes="$(swapon --noheadings --show=NAME 2>/dev/null || true)"
for node in $nodes; do
	for swap in $swap_nodes; do
		[ "$(readlink -f -- "$swap")" != "$(readlink -f -- "$node")" ] ||
			die "$node is active swap; refusing to overwrite it"
	done
done

[ "$(id -u)" -eq 0 ] || exec sudo -- "$script" "$device"

echo "Image:  $image ($(numfmt --to=iec "$image_size"))"
echo "Target:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,TRAN,RM -- "$device"
[ "$(lsblk -dn -o RM -- "$device" | tr -d ' ')" = 1 ] ||
	echo "WARNING: $device is not marked removable."
printf "Type 'BURN %s' to overwrite it: " "$device"
IFS= read -r answer || die "confirmation input closed"
[ "$answer" = "BURN $device" ] || die "cancelled"

for node in $(printf '%s\n' "$nodes" | tac); do
	while target="$(findmnt -rn -S "$node" -o TARGET 2>/dev/null)" &&
		[ -n "$target" ]; do
		umount -- "$(printf '%s\n' "$target" | head -n 1)"
	done
done

dd if="$image" of="$device" bs=4M status=progress conv=fsync
sync
blockdev --flushbufs "$device"
echo "Verifying written bytes..."
cmp -n "$image_size" "$image" "$device"
blockdev --rereadpt "$device" 2>/dev/null || true
udevadm settle 2>/dev/null || true
echo "Verified. The provisioning microSD is ready."
