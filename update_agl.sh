#!/usr/bin/env bash
# vim: ts=2 sw=2 et filetype=sh

set -e

#FIXME: temp
#set -x

BUILD=${BUILD:-0} # Build the artifact(s) before fetching/installing?
FETCH=${FETCH:-1} # Fetch the artifact(s) from the build server?
FETCH_DBG=${FETCH_DBG:-0} # Fetch the debug artifact(s) from the build server?

TARGET="${TARGET:-raspberrypi3}"
TARGET_SSH="${DEVICE:-rpi}"
SDCARD='/dev/mmcblk0'
REMOTE="${REMOTE:-igalia}"

# AGL/Yocto workspace path in Build server
WS_PATH='agl/workspaces/flounder-c68-rpi3'

# AGL Image vars
IMG_FILE_NAME='agl-demo-platform-wam-raspberrypi3.wic.xz'
IMG_DBG_FILES=('agl-demo-platform-wam-raspberrypi3.tar.xz' 'agl-demo-platform-wam-raspberrypi3-dbg.tar.gz')
BUILD_PATH="${WS_PATH}/build"
IMG_PATH="${BUILD_PATH}/tmp/deploy/images/${TARGET}"
IMG_REMOTE_PATH="${REMOTE}:${IMG_PATH}"

SCRIPT_TEMPLATE=$(cat <<-END
  cd $BUILD_PATH
  source agl-init-build-env
  set -e
  %s
END
)

# set package vars
# FIXME: Supporting only RPi for now
set_pkg_vars() {
  local pkgname=$1
  export PKG_FILE_NAME="${pkgname}-1.0*.armv7vehf_neon_vfpv4.rpm"
  export PKG_PATH="${BUILD_PATH}/tmp/deploy/rpm/armv7vehf_neon_vfpv4"
  export PKG_REMOTE_PATH="${REMOTE}:${PKG_PATH}/${PKG_FILE_NAME}"
}

download_file() {
  rsync -arvzL --progress "$1" "$2"
  #scp ${IMG_REMOTE_PATH} .
}

download_and_flash_image() {
  if (( BUILD )); then
    echo '### Building whole AGL WAM demo image...'
    build_script=$(printf "$SCRIPT_TEMPLATE" "bitbake agl-demo-platform-wam")
    ssh $REMOTE -t eval "$build_script"
  fi
  if (( FETCH )); then
      echo '### Downloading...'
      download_file "${IMG_REMOTE_PATH}/${IMG_FILE_NAME}" .
  fi
  if (( FETCH_DBG )); then
      echo '### Downloading debug files...'
      for file in "${IMG_DBG_FILES[@]}"; do
        download_file "${IMG_REMOTE_PATH}/$file" .
      done
  fi
  if ! lsblk ${SDCARD} &>/dev/null; then
      echo "### SDCard not found, please insert it!" >&2
      exit 1
  fi
  echo '### Writing to sdcard...'
  xzcat $IMG_FILE_NAME | sudo dd of=${SDCARD} bs=4M status=progress && sync
}

download_and_install_pkg() {
  local artifact="${1:-chromium68}"
  if (( BUILD )); then
    echo '### Building...'
    build_script=$(printf "$SCRIPT_TEMPLATE" "bitbake -C compile $artifact")
    ssh $REMOTE -t eval "$build_script"
  fi
  if (( FETCH )); then
      echo '### Downloading...'
      scp ${PKG_REMOTE_PATH} .
  fi
  echo "### Copying to ${TARGET}..."
  scp $PKG_FILE_NAME ${TARGET_SSH}:/tmp/
  echo '### Installing...'
  ssh ${TARGET_SSH} -- rpm -Uvh --force /tmp/${PKG_FILE_NAME}
}

ARTIFACTS="${@:-chromium68}"

for artifact in "$ARTIFACTS"; do
  case "$artifact" in
    image)
      echo -ne "--> Updating whole AGL image\n\n"
      download_and_flash_image
      ;;
    *)
      echo -ne "--> Updating package: ${artifact}\n\n"
      set_pkg_vars $artifact
      download_and_install_pkg $artifact
      ;;
  esac
done

echo '### Done.'
