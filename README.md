# Football Rivals — Android 3D football game

An original offline 4v4 football prototype built with Godot 4. This is a native game project, not a website.

## Core gameplay prototype
- Third-person follow camera behind the controlled footballer
- 4v4 teams: one user-controlled player and seven AI footballers
- Five-minute match timer and score display
- Touch joystick, shoot, pass, and sprint/ability controls
- Procedurally generated 3D pitch, goals, players, and ball

## Build status
The initial source and a GitHub Actions workflow are committed. An APK is **not verified until the Android build workflow succeeds**. The first version uses procedural placeholder player models and basic AI; it is not a finished commercial-quality game.

## Build an APK
1. Open this repository's **Actions** tab.
2. Run **Build Football Rivals APK**.
3. Wait for the workflow to finish.
4. On a successful run, download the `football-rivals-debug-apk` artifact and extract the APK.

The debug APK is for testing, not Play Store release-signed.

## Controls
- Left virtual joystick: move
- SHOOT: kick the ball toward the opponent's goal
- PASS: pass toward a nearby teammate
- BURST: temporary speed boost (cooldown applies)

## Current limitations
- Offline only; no online multiplayer
- Procedural placeholder visuals, not licensed real-player assets
- Basic bot tactics and ball physics; gameplay needs device testing and iteration
- Build workflow success and on-device installation must be confirmed before calling the APK tested
