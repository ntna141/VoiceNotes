#!/bin/sh
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
SKETCH="$HERE/voicenote"
BUILD="$HERE/build"
EASYBLE="$HERE/../EasyBLE/libraries/EasyBLE"
FQBN="esp32:esp32:esp32s3:FlashSize=8M,PartitionScheme=default_8MB,PSRAM=opi,FlashMode=qio,USBMode=hwcdc,CDCOnBoot=cdc"
PORT="${PORT:-$(ls /dev/cu.usbmodem* 2>/dev/null | head -1)}"

case "${1:-build}" in
  build)
    arduino-cli compile --fqbn "$FQBN" --library "$EASYBLE" --build-path "$BUILD" "$SKETCH"
    ;;
  upload)
    arduino-cli compile --fqbn "$FQBN" --library "$EASYBLE" --build-path "$BUILD" "$SKETCH"
    arduino-cli upload --fqbn "$FQBN" --input-dir "$BUILD" -p "$PORT" "$SKETCH"
    ;;
  monitor)
    arduino-cli monitor -p "$PORT" -c baudrate=115200
    ;;
  *)
    echo "usage: $0 [build|upload|monitor]"
    exit 1
    ;;
esac
