"""Three 30-second test tracks for the emulator (19 Nov 2026): quiet sine tones as WAV files, long
enough for Nastro's library (it lists music over 20 seconds). Usage: make_tracks.py <out dir>"""
import math, os, struct, sys, wave

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
rate = 22050
for n, freq in enumerate((220.0, 277.18, 329.63), 1):
    with wave.open(os.path.join(out, f"{n:02d} Tone {n}.wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate)
        frames = bytearray()
        for i in range(rate * 30):
            frames += struct.pack("<h", int(3000 * math.sin(2 * math.pi * freq * i / rate)))
        w.writeframes(bytes(frames))
