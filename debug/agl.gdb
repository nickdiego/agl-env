# vim:ft=gdb et sw=2

# Workflow (TODO: Automate when possible)
#
# - (Re-)build AGL (with IMAGE_GEN_DEBUGFS = "1" and IMAGE_FSTYPES_DEBUGFS = "tar.gz")
#
# - Generate/update debug sysroot (at host side):
#   $ cd ~/agl-sysroot
#   $ rsync -aHAX <BUILD_DIR>/tmp/work/raspberrypi3-agl-linux-gnueabi/agl-demo-platform/1.0-r0/rootfs/* .
#   $ tar xf <BUILD_DIR>/tmp/deploy/images/raspberrypi3/agl-demo-platform-raspberrypi3-dbg.tar.gz
#
# - (Scenario 1) Attach to a process already running on AGL device:
#   $ ssh rpi -- "pkill gdbserver; gdbserver :2345 --attach 367"
#
# - (Scenario 2) Run WebAppMgr manually (run at AGL device):
#   $ systemctl --user stop WebAppMgr
#   $ source /etc/default/WebAppMgr.env
#   $ gdbserver :2345 /usr/bin/WebAppMgr --no-sandbox --in-process-gpu \
#       --remote-debugging-port=9998 --user-data-dir="/home/0/wamdata" --webos-wa
#
# - Connecting from the host machine (inside chroot if building AGL using it):
#   $ gdb-multiarch ~/agl-sysroot/usr/bin/WebAppMgr -x agl.gdb
#
# - Monitoring process subtree (e.g: WebAppMgr) to choose which process to attach to:
#   $ watch -n2 -- "ssh rpi -- ps --forest -fC WebAppMgr | cut -c1-$COLUMNS"


printf "Setting sysroot..\n"
set sysroot ~/agl-sysroot

add-auto-load-safe-path ~/agl-sysroot/usr/lib/libstdc++.so.6.0.24-gdb.py

printf "Connecting (may take a few minutes)...\n"
target remote 192.168.1.100:2345
printf "Done. What now?\n"

#printf "Setting solib paths..\n" # not needed
#set solib-absolute-prefix /dev/null
#set solib-search-path ~/agl-sysroot:~/agl-sysroot/lib:~/agl-sysroot/usr/lib

#set follow-fork-mode child

