"""
Asset builder (NOT part of the game).

This script generates simple placeholder "programmer art" sprite sheets
and short sound effects so the game has something to load. It is run
once, offline, ahead of time, and its *output files* (images/*.png,
sounds/*.wav, music/*.wav) are what ship with the project. The game
itself (main.py) only ever imports pgzero, math and random, as
required by the task.
"""
import os
import math
import struct
import wave

import pygame

pygame.init()
os.makedirs("images", exist_ok=True)
os.makedirs("sounds", exist_ok=True)
os.makedirs("music", exist_ok=True)

SIZE = 48


def new_surface():
    surf = pygame.Surface((SIZE, SIZE), pygame.SRCALPHA)
    return surf


def save(surf, name):
    pygame.image.save(surf, f"images/{name}.png")


def draw_hero(surf, leg_offset, arm_offset, bob):
    body_color = (60, 130, 220)
    skin_color = (250, 200, 160)
    cx, cy = SIZE // 2, SIZE // 2 + bob
    # legs
    pygame.draw.line(surf, (40, 40, 90), (cx - 6, cy + 10), (cx - 6 + leg_offset, cy + 20), 4)
    pygame.draw.line(surf, (40, 40, 90), (cx + 6, cy + 10), (cx + 6 - leg_offset, cy + 20), 4)
    # body
    pygame.draw.rect(surf, body_color, (cx - 8, cy - 6, 16, 18), border_radius=4)
    # arms
    pygame.draw.line(surf, skin_color, (cx - 8, cy - 2), (cx - 14, cy + 6 + arm_offset), 4)
    pygame.draw.line(surf, skin_color, (cx + 8, cy - 2), (cx + 14, cy + 6 - arm_offset), 4)
    # head
    pygame.draw.circle(surf, skin_color, (cx, cy - 14), 9)
    pygame.draw.circle(surf, (30, 30, 30), (cx - 3, cy - 15), 1)
    pygame.draw.circle(surf, (30, 30, 30), (cx + 3, cy - 15), 1)


def draw_walker_enemy(surf, leg_offset, bob):
    color = (200, 60, 60)
    cx, cy = SIZE // 2, SIZE // 2 + bob
    pygame.draw.line(surf, (90, 30, 30), (cx - 7, cy + 12), (cx - 7 + leg_offset, cy + 22), 4)
    pygame.draw.line(surf, (90, 30, 30), (cx + 7, cy + 12), (cx + 7 - leg_offset, cy + 22), 4)
    pygame.draw.ellipse(surf, color, (cx - 12, cy - 10, 24, 22))
    pygame.draw.circle(surf, (255, 255, 255), (cx - 4, cy - 4), 3)
    pygame.draw.circle(surf, (255, 255, 255), (cx + 4, cy - 4), 3)
    pygame.draw.circle(surf, (0, 0, 0), (cx - 4, cy - 4), 1)
    pygame.draw.circle(surf, (0, 0, 0), (cx + 4, cy - 4), 1)


def draw_flyer_enemy(surf, wing_offset, bob):
    color = (150, 70, 200)
    cx, cy = SIZE // 2, SIZE // 2 + bob
    pygame.draw.polygon(surf, (110, 40, 160),
                         [(cx - 16, cy - wing_offset), (cx - 4, cy), (cx - 16, cy + wing_offset)])
    pygame.draw.polygon(surf, (110, 40, 160),
                         [(cx + 16, cy - wing_offset), (cx + 4, cy), (cx + 16, cy + wing_offset)])
    pygame.draw.circle(surf, color, (cx, cy), 11)
    pygame.draw.circle(surf, (255, 255, 255), (cx - 3, cy - 2), 2)
    pygame.draw.circle(surf, (255, 255, 255), (cx + 3, cy - 2), 2)


# Hero: idle (breathing bob) 2 frames, walk 4 frames, jump 1 frame
for i, bob in enumerate([0, 1]):
    s = new_surface()
    draw_hero(s, 0, 0, bob)
    save(s, f"hero_idle_{i}")

for i, leg in enumerate([-6, -2, 6, 2]):
    s = new_surface()
    draw_hero(s, leg, leg, 0)
    save(s, f"hero_walk_{i}")

s = new_surface()
draw_hero(s, -4, -4, -3)
save(s, "hero_jump")

# Walker enemy: idle 2 frames, walk 4 frames
for i, bob in enumerate([0, 1]):
    s = new_surface()
    draw_walker_enemy(s, 0, bob)
    save(s, f"walker_idle_{i}")

for i, leg in enumerate([-6, -2, 6, 2]):
    s = new_surface()
    draw_walker_enemy(s, leg, 0)
    save(s, f"walker_walk_{i}")

# Flyer enemy: idle (slow wing) 2 frames, "walk"/fly 4 frames
for i, wing in enumerate([10, 12]):
    s = new_surface()
    draw_flyer_enemy(s, wing, 0)
    save(s, f"flyer_idle_{i}")

for i, wing in enumerate([6, 14, 6, 14]):
    s = new_surface()
    draw_flyer_enemy(s, wing, [0, -2, 0, 2][i])
    save(s, f"flyer_walk_{i}")

# Coin (2 frame spin)
for i, w in enumerate([16, 8]):
    s = new_surface()
    pygame.draw.ellipse(s, (255, 210, 60), (SIZE // 2 - w // 2, SIZE // 2 - 10, w, 20))
    pygame.draw.ellipse(s, (200, 150, 20), (SIZE // 2 - w // 2, SIZE // 2 - 10, w, 20), 2)
    save(s, f"coin_{i}")

# Flag (goal)
s = new_surface()
pygame.draw.rect(s, (120, 90, 60), (SIZE // 2 - 2, 4, 4, 40))
pygame.draw.polygon(s, (60, 200, 90), [(SIZE // 2 + 2, 6), (SIZE // 2 + 22, 14), (SIZE // 2 + 2, 22)])
save(s, "flag")

# Simple button image (idle look, hover uses a lighter tint drawn in-code instead)
s = pygame.Surface((220, 60), pygame.SRCALPHA)
pygame.draw.rect(s, (50, 70, 110), s.get_rect(), border_radius=10)
pygame.draw.rect(s, (110, 150, 220), s.get_rect(), 3, border_radius=10)
save(s, "button")

print("Images generated.")


def write_tone(filename, freq_sequence, volume=0.35, sample_rate=22050):
    """Write a short WAV file made of one or more (frequency, duration) tones."""
    frames = []
    for freq, duration in freq_sequence:
        n_samples = int(sample_rate * duration)
        for n in range(n_samples):
            t = n / sample_rate
            fade = min(1.0, (n_samples - n) / (sample_rate * 0.02) if n > n_samples * 0.7 else 1.0)
            value = math.sin(2 * math.pi * freq * t) * volume * fade
            frames.append(struct.pack("<h", int(value * 32767)))
    with wave.open(filename, "w") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(b"".join(frames))


write_tone("sounds/jump.wav", [(500, 0.08), (750, 0.08)])
write_tone("sounds/coin.wav", [(880, 0.06), (1320, 0.08)])
write_tone("sounds/hit.wav", [(180, 0.15), (110, 0.15)])
write_tone("sounds/win.wav", [(523, 0.12), (659, 0.12), (784, 0.18)])
write_tone("sounds/click.wav", [(440, 0.05)])

# A tiny looping background "music" bed (simple arpeggio)
notes = [262, 330, 392, 330, 294, 370, 440, 370]
write_tone("music/bg_music.wav", [(f, 0.22) for f in notes], volume=0.2)

print("Sounds generated.")
