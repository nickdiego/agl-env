# ex: ts=2 sw=4 et filetype=sh

if [ -n "$BASH_VERSION" ]; then
    thisscript="${BASH_SOURCE[0]}"
elif [ -n "$ZSH_VERSION" ]; then
    thisscript="${(%):-%N}"
else
    echo "Unsupported shell!"
    exit 1
fi

AGL_DIR="$(cd $(dirname $thisscript) && pwd -P)"

_has() {
    type $1 >/dev/null 2>&1
}

agl_bootstrap() {
    echo "## Trying to bootstrap AGL env ${1:+(reason: $1)}" >&2

    _has git || { echo "!! Error: git not installed" >&2; return 1; }
    _has python2 || { echo "!! Error: python2 not installed" >&2; return 1; }

    GIT_DIR="${AGL_DIR}/.git" git submodule update --init --recursive
    if [ ! -L "${AGL_DIR}/tools/bin/python" ]; then
        mkdir -pv ${AGL_DIR}/tools/bin
        ln -sv $(which python2) ${AGL_DIR}/tools/bin/python
        ln -sv $(which python2-config) ${AGL_DIR}/tools/bin/python-config
    fi

    if [ $? -ne 0 ]; then
        echo "WARN: Bootstrap failed!" >&2
        return 1
    else
        source $thisscript
        echo "Bootstrap done."
        return 0
    fi
}

py2path="${AGL_DIR}/tools/bin"
if [ -d "$py2path" ]; then
    export PATH="${py2path}:${PATH}"
else
    agl_bootstrap "python2 wrapper not found"
fi

# Remote AGL workspace
export BUILDMACHINE=${BUILDMACHINE:-192.168.1.110}
export AGL_WS=${AGL_WS:-${AGL_DIR}/ws}
export AGL_DIR

agl_mount_workspace() {
    if findmnt -n --raw $AGL_WS &>/dev/null; then
        echo "AGL workspace already mounted at $AGL_WS"
        return 0
    fi
    test -d $AGL_WS || mkir -p $AGL_WS
    # TODO: Move sudo outside the function / move to separate script
    sudo mount -t nfs "${BUILDMACHINE}:${AGL_WS}" "$AGL_WS"
}


agl_umount_workspace() {
    if ! findmnt -n --raw $AGL_WS &>/dev/null; then
        echo "AGL workspace not mounted"
        return 0
    fi
    # TODO: Move sudo outside the function / move to separate script
    sudo umount "$AGL_WS"
}

agl_logs() {
    local device=rpi # TODO: get from parent context?
    local exclude_regex='raspberrypi3 \(sshd\|systemd.\+\|kernel\|audit\)'
    while :; do
        echo -e "\n\n### AGL LOGS @ ${device} --  $(date)"
        ssh rpi -- journalctl --follow | grep -v -e "$exclude_regex"
        sleep 2
    done
}

# Add scripts dir to system path
export PATH="${AGL_DIR}/tools/scripts:${PATH}"
