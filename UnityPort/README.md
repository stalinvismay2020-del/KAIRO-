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

## Open and run locally
1. Download or clone this repository.
2. Open the `UnityPort` directory in Unity Hub using Unity 2022.3 LTS.
3. Install Android Build Support, Android SDK & NDK Tools, and OpenJDK through Unity Hub if building for Android.
4. Open the included `Main` scene and press Play. The runtime bootstrap creates the prototype.
5. For Android, switch Build Settings to Android and build a debug APK.

## Build an APK with GitHub Actions
The repository includes a manual workflow at `.github/workflows/build-eclipse-strikers.yml`. Before running it, configure Unity licensing secrets in GitHub:
- `UNITY_LICENSE`: the Unity license file contents supported by GameCI
- `UNITY_EMAIL` and `UNITY_PASSWORD`: only if your chosen Unity licensing method requires them

Then open the repository's **Actions** tab, select **Build Eclipse Strikers Android APK**, and choose **Run workflow**. If the build succeeds, download the `EclipseStrikers-Android-APK` artifact from that run. Do not share your Unity password or license publicly. Build availability depends on a valid Unity license and GitHub Actions access.

## Important limitations
This is an early prototype scaffold, not a finished commercial-quality game. Character meshes are primitive placeholders; cel-shaded art, polished animations, unique character-specific abilities, improved AI tactics, robust multi-touch controls, goal/physics edge cases and device performance still need implementation and testing. It has not been compiled by Unity, installed on a phone, or verified as an APK. No APK is included until a build workflow completes successfully.
