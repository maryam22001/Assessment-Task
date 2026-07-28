SKYLINE DASH
============
A small side-view platformer built with Pygame Zero.


LIBRARIES USED
--------------
- Pygame Zero (pgzero)   -- game framework (Actor, screen, sounds, music, keyboard, Rect, etc.)
- math                   -- Python standard library
- random                 -- Python standard library

No other third-party libraries are used or required by the game itself.
(The Rect class comes from Pygame Zero's own namespace, so the raw
"pygame" library is never imported directly by the game.)

Note on assets: the files in images/, sounds/ and music/ are small
placeholder sprites and sound effects that were generated ahead of time
by a separate one-off helper script, build_assets.py. That script uses
pygame's drawing/saving functions and the standard "wave"/"struct"
modules purely to produce the .png/.wav files on disk; it is a build
tool, not part of the game, and does not need to be run to play the
game -- the generated files are already included.


REQUIREMENTS
------------
- Python 3.8+
- Pygame Zero (installs pygame automatically as a dependency)


HOW TO INSTALL
---------------
1. Install Pygame Zero:

       pip install pgzero

HOW TO RUN
----------
1. Open a terminal in this project folder (the one containing main.py).
2. Run:

       pgzrun main.py

   (If "pgzrun" is not recognized, you can instead run:
       python -m pgzero.runner main.py   )


CONTROLS
--------
- LEFT / RIGHT arrow keys or A / D  : move the hero
- SPACE or UP arrow                : jump
- Mouse click                      : use the menu buttons


HOW TO PLAY
-----------
From the main menu you can:
  - Start Game            : begins the level
  - Sound: On/Off          : toggles music and sound effects
  - Exit                   : closes the game

In the level, guide the hero across platforms to the flag on the far
right to win. Two kinds of enemies patrol fixed areas and must be
avoided or jumped past:
  - the red "Walker" patrols back and forth along the ground/platforms
  - the purple "Flyer" hovers up and down in the air within a fixed range
Touching an enemy costs one life (with a brief invulnerability window
afterwards); falling off the level also costs a life. Losing all 3
lives ends the game in defeat. Collect the spinning coins along the
way to raise your score. Reaching the flag ends the game in victory.


PROJECT STRUCTURE
------------------
main.py            - the game (only imports pgzero, math, random)
build_assets.py     - one-off helper used to generate the placeholder
                      art/sound files (not required to run the game)
images/             - sprite frames (hero, two enemy types, coin, flag, button)
sounds/             - short sound effects (jump, coin, hit, win, click)
music/              - looping background music bed
readme.txt          - this file
