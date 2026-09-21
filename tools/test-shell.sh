#!/bin/bash
# 在无头 GNOME Shell 里测试扩展，不用注销当前会话。
# Run the extension in a throwaway headless GNOME Shell, so you don't have
# to log out of your own session to test a change.
#
#   tools/test-shell.sh start [seconds]   install, launch, wait, show the log
#   tools/test-shell.sh log [pattern]     grep the running shell's log
#   tools/test-shell.sh stop              kill the shell and its bus
#
# The shell runs on its own D-Bus session, so `gnome-extensions` commands
# meant for it need DBUS_SESSION_BUS_ADDRESS=$(cat "$RUNDIR/busaddr").
set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNDIR="${TMPDIR:-/tmp}/gs-clock-test-shell"
mkdir -p "$RUNDIR"
LOG="$RUNDIR/shell.log"
MONITOR="${MONITOR:-1280x1024}"

# 不要用 pkill -f 'gnome-shell --headless'：它会匹配到自己的命令行，
# 连自己一起杀掉。用 pid 文件。
# Never pkill -f on the shell's command line: the pattern matches this
# script's own argv and it kills itself. Use the pid file.
stop() {
    for f in shell.pid dbus.pid; do
        [ -f "$RUNDIR/$f" ] && kill "$(cat "$RUNDIR/$f")" 2>/dev/null
        rm -f "$RUNDIR/$f"
    done
    rm -f "$RUNDIR/busaddr"
    sleep 1
}

case "${1:-start}" in
stop)
    stop
    echo "test shell stopped"
    ;;
log)
    grep -inE "${2:-JS ERROR|CRITICAL|WARNING}" "$LOG" | head -40
    ;;
start)
    stop
    ( cd "$REPO" && bash pack.bash ) || exit 1

    dbus-daemon --session --fork --print-address > "$RUNDIR/busaddr" 2>/dev/null
    # dbus-daemon --fork 自己脱离，记不到 pid，靠地址里的 socket 路径收尾。
    export DBUS_SESSION_BUS_ADDRESS="$(cat "$RUNDIR/busaddr")"

    rm -f "$LOG"
    XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
        setsid nohup gnome-shell --headless --virtual-monitor "$MONITOR" \
        --wayland-display=gs-clock-test > "$LOG" 2>&1 < /dev/null &
    echo $! > "$RUNDIR/shell.pid"

    sleep "${2:-30}"
    echo "--- log: $LOG"
    grep -inE 'JS ERROR|CRITICAL|Extension .*(cairo|error)' "$LOG" | head -20
    echo "--- state"
    gnome-extensions info cairo@eexpss.gmail.com 2>&1 | grep -E 'State|Enabled'
    echo "--- bus: export DBUS_SESSION_BUS_ADDRESS=\$(cat $RUNDIR/busaddr)"
    ;;
*)
    sed -n '2,12p' "$0"
    exit 1
    ;;
esac
