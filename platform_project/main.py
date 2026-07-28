# -*- coding: utf-8 -*-
"""
Skyline Dash - a small platformer built with Pygame Zero.

Run with:
    pgzrun main.py

Controls:
    LEFT / RIGHT or A / D  - move
    SPACE / UP             - jump
    Mouse                  - click menu buttons
"""

import math
import random

WIDTH = 800
HEIGHT = 480
TITLE = "Skyline Dash"

GRAVITY = 0.6
JUMP_SPEED = -11
MOVE_SPEED = 3.2
GROUND_Y = HEIGHT - 60

STATE_MENU = "menu"
STATE_PLAYING = "playing"
STATE_WIN = "win"
STATE_LOSE = "lose"


class Button:
    """A simple clickable rectangular menu button."""

    def __init__(self, label, center):
        self.label = label
        self.rect = Rect((0, 0), (220, 60))
        self.rect.center = center

    def is_hovered(self, mouse_pos):
        return self.rect.collidepoint(mouse_pos)

    def draw(self, mouse_pos):
        screen.blit("button", self.rect.topleft)
        color = "yellow" if self.is_hovered(mouse_pos) else "white"
        screen.draw.text(
            self.label, center=self.rect.center, fontsize=28, color=color, owidth=1, ocolor="black"
        )


class AnimatedActor:
    """Base class adding simple frame-based sprite animation to an Actor."""

    def __init__(self, idle_frames, walk_frames, pos, animation_speed=0.15):
        self.idle_frames = idle_frames
        self.walk_frames = walk_frames
        self.actor = Actor(idle_frames[0], pos)
        self.animation_speed = animation_speed
        self.frame_timer = 0.0
        self.frame_index = 0
        self.is_moving = False
        self.facing_right = True

    def advance_animation(self, dt):
        frames = self.walk_frames if self.is_moving else self.idle_frames
        self.frame_timer += dt
        if self.frame_timer >= self.animation_speed:
            self.frame_timer = 0.0
            self.frame_index = (self.frame_index + 1) % len(frames)
        self.actor.image = frames[self.frame_index]
        self.actor.flip_x = not self.facing_right

    @property
    def pos(self):
        return self.actor.pos

    @pos.setter
    def pos(self, value):
        self.actor.pos = value

    def draw(self):
        self.actor.draw()


class Hero(AnimatedActor):
    """The player-controlled character."""

    def __init__(self, pos):
        idle = ["hero_idle_0", "hero_idle_1"]
        walk = ["hero_walk_0", "hero_walk_1", "hero_walk_2", "hero_walk_3"]
        super().__init__(idle, walk, pos, animation_speed=0.1)
        self.velocity_y = 0
        self.on_ground = True
        self.lives = 3
        self.invulnerable_timer = 0.0

    def handle_input(self):
        moving_horizontally = False
        if keyboard.left or keyboard.a:
            self.actor.x -= MOVE_SPEED
            self.facing_right = False
            moving_horizontally = True
        if keyboard.right or keyboard.d:
            self.actor.x += MOVE_SPEED
            self.facing_right = True
            moving_horizontally = True
        self.is_moving = moving_horizontally and self.on_ground
        self.actor.x = max(24, min(WIDTH - 24, self.actor.x))

    def jump(self):
        if self.on_ground:
            self.velocity_y = JUMP_SPEED
            self.on_ground = False
            play_sound("jump")

    def apply_physics(self, platforms):
        self.velocity_y += GRAVITY
        self.actor.y += self.velocity_y
        self.on_ground = False
        for plat in platforms:
            feet_rect = Rect((self.actor.x - 10, self.actor.y), (20, 6))
            if feet_rect.colliderect(plat) and self.velocity_y >= 0:
                if self.actor.y - self.velocity_y <= plat.top + 1:
                    self.actor.y = plat.top
                    self.velocity_y = 0
                    self.on_ground = True

    def update(self, dt, platforms):
        self.handle_input()
        self.apply_physics(platforms)
        if not self.on_ground:
            self.actor.image = "hero_jump"
        else:
            self.advance_animation(dt)
        if self.invulnerable_timer > 0:
            self.invulnerable_timer -= dt

    def take_hit(self):
        if self.invulnerable_timer <= 0:
            self.lives -= 1
            self.invulnerable_timer = 1.2
            play_sound("hit")
            return True
        return False


class PatrollingEnemy(AnimatedActor):
    """
    An enemy that moves back and forth within a bounded patrol area.
    Two flavours are used: a ground Walker and an airborne Flyer.
    """

    def __init__(self, idle_frames, walk_frames, pos, patrol_min, patrol_max,
                 speed, vertical=False):
        super().__init__(idle_frames, walk_frames, pos, animation_speed=0.14)
        self.patrol_min = patrol_min
        self.patrol_max = patrol_max
        self.speed = speed
        self.vertical = vertical
        self.direction = 1
        self.is_moving = True

    def update(self, dt):
        axis_value = self.actor.y if self.vertical else self.actor.x
        axis_value += self.speed * self.direction
        if axis_value >= self.patrol_max:
            axis_value = self.patrol_max
            self.direction = -1
        elif axis_value <= self.patrol_min:
            axis_value = self.patrol_min
            self.direction = 1
        if self.vertical:
            self.actor.y = axis_value
        else:
            self.actor.x = axis_value
            self.facing_right = self.direction > 0
        self.advance_animation(dt)


class Coin:
    def __init__(self, pos):
        self.actor = Actor("coin_0", pos)
        self.collected = False
        self.frame_timer = 0.0
        self.frame_index = 0

    def update(self, dt):
        self.frame_timer += dt
        if self.frame_timer >= 0.2:
            self.frame_timer = 0.0
            self.frame_index = (self.frame_index + 1) % 2
            self.actor.image = f"coin_{self.frame_index}"

    def draw(self):
        if not self.collected:
            self.actor.draw()


def play_sound(name):
    if sound_enabled:
        try:
            getattr(sounds, name).play()
        except Exception:
            pass


def build_level():
    """Create the platforms, enemies and coins for the single level."""
    platforms = [
        Rect((0, GROUND_Y), (WIDTH, 60)),
        Rect((180, 340), (140, 20)),
        Rect((380, 270), (140, 20)),
        Rect((580, 200), (160, 20)),
    ]

    walkers = [
        PatrollingEnemy(
            ["walker_idle_0", "walker_idle_1"],
            ["walker_walk_0", "walker_walk_1", "walker_walk_2", "walker_walk_3"],
            (260, GROUND_Y - 4), 120, 380, 1.4,
        ),
        PatrollingEnemy(
            ["walker_idle_0", "walker_idle_1"],
            ["walker_walk_0", "walker_walk_1", "walker_walk_2", "walker_walk_3"],
            (430, 250), 400, 500, 1.1,
        ),
    ]

    flyers = [
        PatrollingEnemy(
            ["flyer_idle_0", "flyer_idle_1"],
            ["flyer_walk_0", "flyer_walk_1", "flyer_walk_2", "flyer_walk_3"],
            (620, 120), 90, 190, 1.0, vertical=True,
        ),
    ]

    coins = [
        Coin((220, 300)),
        Coin((420, 230)),
        Coin((640, 160)),
        Coin((700, GROUND_Y - 30)),
    ]

    return platforms, walkers + flyers, coins


class Game:
    def __init__(self):
        self.state = STATE_MENU
        self.hero = None
        self.platforms = []
        self.enemies = []
        self.coins = []
        self.score = 0
        self.goal = Actor("flag", (WIDTH - 40, GROUND_Y - 26))
        self.buttons = {
            "start": Button("Start Game", (WIDTH / 2, 190)),
            "sound": Button("Sound: On", (WIDTH / 2, 265)),
            "exit": Button("Exit", (WIDTH / 2, 340)),
        }

    def start_new_game(self):
        self.platforms, self.enemies, self.coins = build_level()
        self.hero = Hero((60, GROUND_Y - 4))
        self.score = 0
        self.state = STATE_PLAYING

    def update(self, dt):
        if self.state != STATE_PLAYING:
            return
        self.hero.update(dt, self.platforms)
        for enemy in self.enemies:
            enemy.update(dt)
        for coin in self.coins:
            coin.update(dt)
            if not coin.collected and self.hero.actor.colliderect(coin.actor):
                coin.collected = True
                self.score += 1
                play_sound("coin")
        for enemy in self.enemies:
            if self.hero.actor.colliderect(enemy.actor):
                if self.hero.take_hit():
                    if self.hero.lives <= 0:
                        self.state = STATE_LOSE
        if self.hero.actor.y > HEIGHT + 40:
            self.hero.take_hit()
            self.hero.actor.pos = (60, GROUND_Y - 4)
            self.hero.velocity_y = 0
            if self.hero.lives <= 0:
                self.state = STATE_LOSE
        if self.hero.actor.colliderect(self.goal):
            self.state = STATE_WIN
            play_sound("win")


game = Game()
sound_enabled = True
music_started = False


def draw():
    screen.fill((120, 190, 235))
    mouse_pos = last_mouse_pos
    if game.state == STATE_MENU:
        draw_menu(mouse_pos)
    elif game.state == STATE_PLAYING:
        draw_gameplay()
    elif game.state == STATE_WIN:
        draw_gameplay()
        draw_overlay("You made it!", "Click anywhere to return to the menu")
    elif game.state == STATE_LOSE:
        draw_gameplay()
        draw_overlay("Game Over", "Click anywhere to return to the menu")


def draw_menu(mouse_pos):
    screen.draw.text(TITLE, center=(WIDTH / 2, 90), fontsize=56, color="white",
                      owidth=2, ocolor=(30, 60, 100))
    for button in game.buttons.values():
        button.draw(mouse_pos)


def draw_gameplay():
    for i, plat in enumerate(game.platforms):
        screen.draw.filled_rect(plat, (90, 160, 90) if i > 0 else (80, 140, 80))
        screen.draw.filled_rect(Rect(plat.topleft, (plat.width, 6)), (120, 200, 120))
    for coin in game.coins:
        coin.draw()
    game.goal.draw()
    for enemy in game.enemies:
        enemy.draw()
    game.hero.draw()
    screen.draw.text(f"Score: {game.score}", topleft=(12, 10), fontsize=26, color="white",
                      owidth=1, ocolor="black")
    screen.draw.text(f"Lives: {game.hero.lives}", topleft=(12, 38), fontsize=26, color="white",
                      owidth=1, ocolor="black")


def draw_overlay(title, subtitle):
    box = Rect((0, 0), (420, 140))
    box.center = (WIDTH / 2, HEIGHT / 2)
    screen.draw.filled_rect(box, (20, 20, 40))
    screen.draw.rect(box, (150, 180, 255))
    screen.draw.text(title, center=(WIDTH / 2, HEIGHT / 2 - 20), fontsize=40, color="white")
    screen.draw.text(subtitle, center=(WIDTH / 2, HEIGHT / 2 + 25), fontsize=20, color="white")


last_mouse_pos = (0, 0)


def on_mouse_move(pos):
    global last_mouse_pos
    last_mouse_pos = pos


def on_mouse_down(pos):
    global sound_enabled, music_started
    if game.state == STATE_MENU:
        if game.buttons["start"].is_hovered(pos):
            play_sound("click")
            game.start_new_game()
            ensure_music_playing()
        elif game.buttons["sound"].is_hovered(pos):
            sound_enabled = not sound_enabled
            game.buttons["sound"].label = f"Sound: {'On' if sound_enabled else 'Off'}"
            if sound_enabled:
                ensure_music_playing()
            else:
                music.stop()
            play_sound("click")
        elif game.buttons["exit"].is_hovered(pos):
            exit()
    elif game.state in (STATE_WIN, STATE_LOSE):
        game.state = STATE_MENU


def ensure_music_playing():
    global music_started
    if sound_enabled:
        try:
            music.play("bg_music")
            music.set_volume(0.4)
        except Exception:
            pass
        music_started = True


def update(dt):
    game.update(dt)


def on_key_down(key):
    if game.state == STATE_PLAYING and key in (keys.SPACE, keys.UP, keys.W):
        game.hero.jump()
