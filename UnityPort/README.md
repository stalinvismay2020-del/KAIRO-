# Eclipse Strikers — Unity Port

## Approved specification
- Engine: Unity
- Visual style: 3D cel-shaded anime, original characters and effects
- Platform: Android
- Match mode: offline 4v4 (8 players total)
- Match length: 5 minutes
- Camera: third-person, following the controlled player from behind
- Controls: mobile touch joystick plus kick, pass, sprint and ability buttons
- Physics: ball movement, kicks, collisions, goal detection
- AI: offline teammates and opponents
- Advanced abilities: character-specific special moves, ultimate moves, cooldowns and cinematic effects
- Later stage: local settings and unlocks

## Required implementation order
1. Playable foundation: pitch, player movement, follow camera, ball physics and touch controls.
2. Complete match: 4v4 teams, AI, goals, scoring, timer, kickoff and match-end screen.
3. Anime abilities: original character kits, cooldowns, special moves and animations.
4. Polish: menus, audio, lighting, celebrations, settings and performance optimisation.
5. Android release: compile, install on a physical Android device, test offline, fix crashes and verify the final APK artifact.

## Migration and release integrity
The existing repository currently contains a Godot 4 project. Keep it intact while adding the Unity port in a separate directory. Do not report an APK as built, installed or tested unless a successful build artifact and the relevant test evidence exist.

## Current status
Specification approved. Unity implementation, Android compilation, and physical-device verification are not yet confirmed.
