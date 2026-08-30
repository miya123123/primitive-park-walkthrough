# Control Manifest

Manifest Version: 2026-08-28

## Required

- Gameplay values must be loaded from `assets/data/park_config.json`.
- GDScript must use explicit parameter and return types.
- Fixed geometry uses matching CollisionShape3D resources.
- UI receives state through signals and uses anchors/containers.
- Ride interaction uses an event-driven state machine and keeps the single player lease in one coordinator.
- Ride-specific behavior is isolated behind `RideProvider`; progress reaches HUD through signals.
- Go-kart input is W/S/A/D + Shift brake, R checkpoint reset, E exit; free-fall stage timing is config-driven.
- Only BoxMesh, CylinderMesh, SphereMesh, and CapsuleMesh may be used by the park builder.

## Forbidden

- Imported 3D models, image textures, external audio, or unreviewed addons.
- Global singleton state for player, park, or HUD.
- Per-frame HUD polling of player internals.
- Teleporting into a moving seat without waiting for the next station arrival.
- Moving StaticBody3D parts for decorative animation.
- Hardcoded gameplay tuning values in gameplay scripts.

## Guardrails

- Target 60 FPS and 250 or fewer draw calls in the compact scene.
- Keep the playable world within 72m × 72m.
- Run headless tests with an explicit writable log path.
- Stop the running game after manual playtest evidence is captured.
