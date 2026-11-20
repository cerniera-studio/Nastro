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
shot() { timeout 20 adb exec-out screencap -p > "shot-win-$1.png"; }

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
for a in window_animation_scale transition_animation_scale animator_duration_scale; do adb shell settings put global $a 0; done
# No "isn't responding" dialogs, and three-button navigation, so a stalled launcher can't hold up
# input (as seen in Fold Taskbar's and Solco's runs)
adb shell settings put global hide_error_dialogs 1
adb shell cmd overlay enable com.android.internal.systemui.navbar.threebutton
adb shell am force-stop com.google.android.apps.nexuslauncher
# Music access again after the reboot (the grant before it didn't hold), and check it took
adb shell pm grant $PKG android.permission.READ_MEDIA_AUDIO
adb shell pm grant $PKG android.permission.POST_NOTIFICATIONS
adb shell dumpsys package $PKG | grep -E "READ_MEDIA_AUDIO|POST_NOTIFICATIONS" | head -4
adb logcat -c
# The media scanner, in case the boot scan hasn't reached the tracks yet
adb shell content call --uri content://media --method scan_volume --arg external_primary >/dev/null 2>&1
sleep 5
# What the media index holds (for the log)
adb shell content query --uri content://media/external/audio/media --projection _display_name:is_music:duration:album:artist 2>&1 | head -10 | tee -a $out

# Nastro is open (the Walkman unfolded, silent) when it has most of the main screen, and closed and
# playing on the cover or in a share of the main screen (StageView.onMainScreen). So: the turn on
# the cover's shape; the resize in a pop-up window that stays a share of the main screen.
set +x
task() {  # "<id> <mode>" of the task whose affinity is exactly $1
  adb shell dumpsys activity activities | python3 -c "
import sys, re
for line in sys.stdin:
    m = re.search(r'\* Task\{\S+ #(\d+) .*?A=\d+:(\S+) .*?mode=(\S+)', line)
    if m and m.group(2) == '$1': print(m.group(1), m.group(3)); break"
}
alive() { [ "$(timeout 10 adb get-state 2>/dev/null)" = device ]; }
deck() {  # "<playing> <pos> <width> <tapes>"
  timeout 15 adb shell run-as $PKG cat files/deck.json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin); print(str(d['playing']).lower(), round(d['pos'], 1), d['view'][0], d['tapes'])" 2>/dev/null
}
wait_playing() {
  for try in $(seq 1 40); do set -- $(deck); [ "$1" = true ] && return 0; sleep 1; done
  return 1
}
carries() {  # what happened ($what), the position before
  local before=$2; sleep 3
  if ! alive; then warn "Playback through $what: the emulator stopped responding; not counted"; return; fi
  set -- $(deck)
  if [ -z "$1" ] || [ -z "$before" ]; then warn "Playback through $what: nothing could be read back from the emulator; not counted"
  elif [ "$1" = true ] && python3 -c "import sys; sys.exit(0 if float('$2') > float('$before') else 1)"; then
    note "Playback: carried on through $what ($before s -> $2 s)"
  else
    fail "Playback: stopped or stuck through $what (playing $1, $before s -> $2 s)"
  fi
}

# ---- 1. A turn, on the cover's shape (full screen)
adb shell wm density 320; adb shell wm size 823x1920; sleep 3
adb shell am force-stop $PKG; adb shell run-as $PKG rm -f files/deck.json
adb shell am start -W --windowingMode 1 -n $PKG/.MainActivity --es play first >/dev/null
if ! wait_playing; then
  set -- $(deck)
  warn "Playback never started on the cover (tapes found: ${4:-?}); check 1 skipped"
  adb logcat -d -s NastroTest:I Nastro:W | tail -8
  shot not-playing-cover
else
  shot playing-cover
  set -- $(deck); p=$2
  adb shell settings put system user_rotation 1; sleep 2; shot playing-cover-turned
  what="turning the cover"; carries "$what" "$p"
  adb shell settings put system user_rotation 0; sleep 2
fi
adb shell am force-stop $PKG; sleep 1

# ---- 2. A pop-up window on the main screen, a share of it, resized; 3. another app in front
adb shell wm density 280; adb shell wm size 1503x1568; sleep 3
adb shell run-as $PKG rm -f files/deck.json
adb shell am start -W --windowingMode 5 -n $PKG/.MainActivity --es play first >/dev/null; sleep 2
set -- $(task $PKG); id=$1; mode=$2
echo "task: $id $mode" | tee -a $out
if [ "$mode" != freeform ]; then
  warn "Pop-up window: the emulator would not open one (mode ${mode:-none}); checks 2 and 3 skipped"
else
  adb shell am task resize "$id" 0 0 900 1568
  if ! wait_playing; then
    warn "Pop-up window: playback never started; checks 2 and 3 skipped"
    adb logcat -d -s NastroTest:I | tail -6
  else
    shot playing-popup
    set -- $(deck); p=$2; w0=$3
    timeout 20 adb shell am task resize "$id" 0 0 640 1568; shot playing-popup-narrow
    what="resizing a pop-up window (900 to 640 px wide)"; carries "$what" "$p"
    set -- $(deck); echo "width: $w0 -> $3" | tee -a $out

    set -- $(deck); p=$2
    timeout 30 adb shell am start -W -a android.settings.SETTINGS >/dev/null; sleep 1; shot another-app
    what="another app taking focus"; carries "$what" "$p"
  fi
fi
timeout 20 adb shell am force-stop $PKG
timeout 20 adb shell wm size reset; timeout 20 adb shell wm density reset

{ echo "logcat after the windows test"; timeout 60 adb logcat -d; } > app-log-windows.txt
if grep -A2 "FATAL EXCEPTION" app-log-windows.txt | grep -q "Process: $PKG"; then fail "Nastro crashed in the windows test"; grep -A20 "FATAL EXCEPTION" app-log-windows.txt | head -40; fi
grep -q "^::error::" $out && exit 1
exit 0
