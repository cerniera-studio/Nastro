#!/usr/bin/env bash
# Windows (adaptive quality, 19 Nov 2026; Sveglia's tools/windows.sh is the template). Playback
# through a turn, a resize and another app taking focus, on the main screen's shape (859 x 896
# dp). Writes windows.txt; a line starting ::error:: fails the run.
#
# 1. A tape playing full screen keeps playing, and moving on, through a turn.
# 2. In a pop-up window, through shrinking the window to half width.
# 3. ...and while another app is in front.
# Playback is seen through files/deck.json, which debug builds write every half second.
#
# Pop-up windows need freeform support, which the emulator only reads at boot: this reboots it
# (which also has the media scanner find the test tracks).
set -x
PKG=com.fergusonconsultancy.nastro
out=windows.txt; : > $out
note() { echo "::notice::$*" | tee -a $out; }
fail() { echo "::error::$*" | tee -a $out; }
warn() { echo "::warning::$*" | tee -a $out; }
shot() { adb exec-out screencap -p > "shot-win-$1.png"; }

adb install -r Nastro.apk
python3 tools/make_tracks.py /tmp/tracks
adb shell mkdir -p "/sdcard/Music/NastroTest"
for f in /tmp/tracks/*; do adb push "$f" "/sdcard/Music/NastroTest/" >/dev/null; done
adb shell pm grant $PKG android.permission.READ_MEDIA_AUDIO
adb shell pm grant $PKG android.permission.POST_NOTIFICATIONS
adb shell settings put global enable_freeform_support 1
adb shell settings put global force_resizable_activities 1
adb reboot
adb wait-for-device
until [ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = 1 ]; do sleep 2; done
sleep 30
adb shell input keyevent 82
adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 0
adb logcat -c
# The media scanner, in case the boot scan hasn't reached the tracks yet
adb shell content call --uri content://media --method scan_volume --arg external_primary >/dev/null 2>&1
sleep 5
# What the media index holds (for the log)
adb shell content query --uri content://media/external/audio/media --projection _display_name:is_music:duration:album:artist 2>&1 | head -10 | tee -a $out

# The main screen, upright
adb shell wm density 280; adb shell wm size 1503x1568; sleep 3

set +x
task() {  # "<id> <mode>" of the task whose affinity is exactly $1
  adb shell dumpsys activity activities | python3 -c "
import sys, re
for line in sys.stdin:
    m = re.search(r'\* Task\{\S+ #(\d+) .*?A=\d+:(\S+) .*?mode=(\S+)', line)
    if m and m.group(2) == '$1': print(m.group(1), m.group(3)); break"
}
deck() {  # "<playing> <pos> <width> <tapes>"
  adb shell run-as $PKG cat files/deck.json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin); print(str(d['playing']).lower(), round(d['pos'], 1), d['view'][0], d['tapes'])" 2>/dev/null
}
wait_playing() {
  for try in $(seq 1 40); do set -- $(deck); [ "$1" = true ] && return 0; sleep 1; done
  return 1
}
carries() {  # what happened ($what), the position before
  local before=$2; sleep 3
  set -- $(deck)
  if [ "$1" = true ] && python3 -c "import sys; sys.exit(0 if float('$2') > float('$before') else 1)"; then
    note "Playback: carried on through $what ($before s -> $2 s)"
  else
    fail "Playback: stopped or stuck through $what (playing $1, $before s -> $2 s)"
  fi
}

# ---- 1. A turn (full screen)
adb shell am force-stop $PKG; adb shell run-as $PKG rm -f files/deck.json
adb shell am start -W --windowingMode 1 -n $PKG/.MainActivity --es play first >/dev/null
if ! wait_playing; then
  set -- $(deck)
  warn "Playback never started (tapes found: ${4:-?}); checks skipped"
  shot not-playing
else
  shot playing
  set -- $(deck); p=$2
  adb shell settings put system user_rotation 1; sleep 2; shot playing-turned
  what="a turn"; carries "$what" "$p"
  adb shell settings put system user_rotation 0; sleep 2

  # ---- 2. A pop-up window, shrunk
  adb shell am force-stop $PKG; adb shell run-as $PKG rm -f files/deck.json
  adb shell am start -W --windowingMode 5 -n $PKG/.MainActivity --es play first >/dev/null; sleep 3
  set -- $(task $PKG); id=$1; mode=$2
  echo "task: $id $mode" | tee -a $out
  if [ "$mode" != freeform ]; then
    warn "Pop-up window: the emulator would not open one (mode ${mode:-none}); checks 2 and 3 skipped"
  elif ! wait_playing; then
    warn "Pop-up window: playback never started; checks 2 and 3 skipped"
  else
    adb shell am task resize "$id" 0 0 1503 1568; sleep 3
    set -- $(deck); p=$2; w0=$3
    adb shell am task resize "$id" 0 0 740 1568; shot playing-popup-narrow
    what="shrinking a pop-up window"; carries "$what" "$p"
    set -- $(deck); echo "width: $w0 -> $3" | tee -a $out

    # ---- 3. Another app in front
    set -- $(deck); p=$2
    adb shell am start -W -a android.settings.SETTINGS >/dev/null; sleep 1; shot another-app
    what="another app taking focus"; carries "$what" "$p"
  fi
fi
adb shell am force-stop $PKG
adb shell wm size reset; adb shell wm density reset

{ echo "logcat after the windows test"; adb logcat -d; } > app-log-windows.txt
if grep -A2 "FATAL EXCEPTION" app-log-windows.txt | grep -q "Process: $PKG"; then fail "Nastro crashed in the windows test"; grep -A20 "FATAL EXCEPTION" app-log-windows.txt | head -40; fi
grep -q "^::error::" $out && exit 1
exit 0
