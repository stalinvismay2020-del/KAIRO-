# Eclipse Strikers — Unity prototype

A minimal Unity 2022.3 LTS project scaffold for an original offline anime-inspired 3D football game.

## Current prototype implementation
- Runtime-generated pitch, centre line, goals and directional lighting
- Eight placeholder 3D footballers (4v4) and a physics-driven football
- Third-person follow camera
- Basic movement and pursuit AI
- Shoot, pass, sprint and ultimate ability controls
- Five-minute timer, score display, kickoff reset and full-time screen
- Runtime geometry avoids external asset dependencies

## Open and run
1. Download or clone this repository.
2. Open the `UnityPort` directory in Unity Hub using Unity 2022.3 LTS.
3. Install Android Build Support, Android SDK & NDK Tools, and OpenJDK through Unity Hub if building for Android.
4. Open the included `Main` scene and press Play. The runtime bootstrap creates the prototype.
5. For Android, switch Build Settings to Android, set package identifier and orientation, then build a debug APK.

## Important limitations
This is an early playable-prototype scaffold, not a finished commercial-quality game. Character meshes are primitive placeholders; the visuals are not yet a complete cel-shaded art pipeline. AI tactics, goal detection, touch controls and device performance need testing and iteration. It has not been compiled by Unity, installed on a phone, or verified as an APK. No APK is included.
