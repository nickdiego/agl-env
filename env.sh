# ex: ts=2 sw=4 et filetype=sh

if [ -n "$BASH_VERSION" ]; then
    thisscript="${BASH_SOURCE[0]}"
elif [ -n "$ZSH_VERSION" ]; then
    thisscript="${(%):-%N}"
else
    echo "Unsupported shell!"
    exit 1
fi

agldir="$(cd $(dirname $thisscript) && pwd -P)"

_has() {
    type $1 >/dev/null 2>&1
}

agl_bootstrap() {
    echo "## Trying to bootstrap AGL env ${1:+(reason: $1)}" >&2

    _has git || { echo "!! Error: git not installed" >&2; return 1; }
    _has python2 || { echo "!! Error: python2 not installed" >&2; return 1; }

    GIT_DIR="${agldir}/.git" git submodule update --init --recursive
    if [ ! -L "${agldir}/tools/bin/python" ]; then
        mkdir -pv ${agldir}/tools/bin
        ln -sv $(which python2) ${agldir}/tools/bin/python
        ln -sv $(which python2-config) ${agldir}/tools/bin/python-config
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

py2path="${agldir}/tools/bin"
if [ -d "$py2path" ]; then
    export PATH="${py2path}:${PATH}"
else
    agl_bootstrap "python2 wrapper not found"
fi

# Remote AGL workspace
export buildmachine=${buildmachine:-192.168.1.110}
export agl_ws=${agl_ws:-${agldir}/ws}

agl_mount_workspace() {
    if findmnt -n --raw $agl_ws &>/dev/null; then
        echo "AGL workspace already mounted at $agl_ws"
        return 0
    fi
    test -d $agl_ws || mkir -p $agl_ws
    # TODO: Move sudo outside the function / move to separate script
    sudo mount -t nfs "${buildmachine}:${agl_ws}" "$agl_ws"
}


agl_umount_workspace() {
    if ! findmnt -n --raw $agl_ws &>/dev/null; then
        echo "AGL workspace not mounted"
        return 0
    fi
    # TODO: Move sudo outside the function / move to separate script
    sudo umount "$agl_ws"
}
