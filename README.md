# Rebound

A complete small 2D arcade game for Godot 4. Bounce through three crystal formations; turn a falling ball into a comeback with a rechargeable rescue pulse.

## Play

Open `project.godot` in Godot 4.7 and press **F5**.

- **A / D, arrow keys, or mouse:** move the paddle. Moving the mouse switches to mouse control; pressing a movement key switches back.
- **Space / left click:** start, launch, or reverse a falling ball. Rescue recharges in five seconds.
- **P / Escape:** pause and resume.
- **R:** start a fresh run.

The paddle's edges aim the ball. Dotted crystals need two hits. You have three chances to clear all three stages. Your best completed-run score is saved locally in Godot's user data folder.

All visuals are drawn in code, with no external asset dependencies. The fixed 1152 × 768 canvas scales with the window while preserving its aspect ratio.

## Validation

Run `Godot --headless --path . --script res://tests/smoke.gd` to exercise launching, collision response, scoring, rescue cooldown, lost lives, stage progression, victory, and pause/resume.
