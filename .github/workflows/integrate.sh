#!/usr/bin/env bash
# integrate.sh — run from kernel source root (CI calls this).
# Adds ONLY v4l2loopback in-tree. Does NOT touch KernelSU-Next / SuSFS — they stay
# exactly as your Anymore tree already ships them.
set -euo pipefail

V4L2_REF="${V4L2_REF:-v0.13.1}"
DEFCONFIG="${DEFCONFIG:-vayu_defconfig}"
DEFCONFIG_PATH="arch/arm64/configs/${DEFCONFIG}"

echo "==> v4l2loopback in-tree (ref: ${V4L2_REF})"
TMP="$(mktemp -d)"
git clone --depth=1 --branch "${V4L2_REF}" https://github.com/v4l2loopback/v4l2loopback.git "$TMP/v4l2lb"
DST="drivers/media/v4l2loopback"
mkdir -p "$DST"
cp "$TMP/v4l2lb/v4l2loopback.c" "$DST/"
# copy ALL headers from the repo root (v4l2loopback.h + v4l2loopback_formats.h)
cp "$TMP/v4l2lb/"*.h "$DST/"
rm -rf "$TMP"

cat > "$DST/Kconfig" <<'EOF'
config V4L2LOOPBACK
	tristate "V4L2 loopback device (virtual camera)"
	depends on VIDEO_V4L2
	help
	  Creates V4L2 loopback nodes (/dev/videoN) that one process can
	  write frames into and another can read as a capture device.
EOF

cat > "$DST/Makefile" <<'EOF'
obj-$(CONFIG_V4L2LOOPBACK) += v4l2loopback.o
EOF

# Wire into drivers/media (idempotent)
grep -q 'v4l2loopback/Kconfig' drivers/media/Kconfig || \
  sed -i '1i source "drivers/media/v4l2loopback/Kconfig"' drivers/media/Kconfig
grep -q 'v4l2loopback/' drivers/media/Makefile || \
  echo 'obj-$(CONFIG_V4L2LOOPBACK) += v4l2loopback/' >> drivers/media/Makefile

echo "==> defconfig fragment (v4l2loopback only) -> ${DEFCONFIG_PATH}"
# Built as a loadable module so you can pass params (exclusive_caps, video_nr, label)
# at insmod time and enable/disable on demand. Nothing else in your config is changed.
cat >> "$DEFCONFIG_PATH" <<'EOF'

# --- v4l2loopback (virtual camera) ---
CONFIG_MODULES=y
CONFIG_MODULE_UNLOAD=y
CONFIG_MEDIA_SUPPORT=y
CONFIG_MEDIA_CAMERA_SUPPORT=y
CONFIG_VIDEO_DEV=y
CONFIG_VIDEO_V4L2=y
CONFIG_V4L2LOOPBACK=m
EOF

echo "==> done. KernelSU-Next / SuSFS were left untouched."
