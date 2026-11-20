"""Three 45-second test tracks for the emulator (19 Nov 2026), tagged as one album ("Nastro Test"
by "Cerniera") like a real library, so Nastro makes a tape of them. Quiet sine tones, written as
MP3 with ffmpeg where it is installed (it is on GitHub's Ubuntu runners), WAV otherwise.
Usage: make_tracks.py <out dir>"""
import math, os, shutil, struct, subprocess, sys, wave

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
rate = 22050
for n, freq in enumerate((220.0, 277.18, 329.63), 1):
    wav = os.path.join(out, f"{n:02d}.wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", int(3000 * math.sin(2 * math.pi * freq * i / rate))) for i in range(rate * 45)))
    if shutil.which("ffmpeg"):
        mp3 = os.path.join(out, f"{n:02d} Tone {n}.mp3")
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-codec:a", "libmp3lame", "-b:a", "64k",
                        "-metadata", f"title=Tone {n}", "-metadata", "artist=Cerniera", "-metadata", "album_artist=Cerniera",
                        "-metadata", "album=Nastro Test", "-metadata", f"track={n}", "-metadata", "genre=Test", mp3], check=True)
        os.remove(wav)
print("\n".join(sorted(os.listdir(out))))
