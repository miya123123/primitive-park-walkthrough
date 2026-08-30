# EPIC-001-S02: Third-person movement and camera

**Status:** Complete
**Type:** Logic
**TR-ID:** TR-MOV-001
**ADR Governing Implementation:** `docs/architecture/adr-0001-procedural-primitive-park.md`
**Manifest Version:** 2026-08-25
**Dependencies:** EPIC-001-S01

## Acceptance Criteria

- [x] WASD moves the CharacterBody3D relative to the camera's horizontal yaw.
- [x] Mouse motion controls third-person orbit yaw and clamped pitch.
- [x] Space jumps only while grounded; Shift applies the configured sprint multiplier.
- [x] Esc releases the mouse and left click recaptures it.
- [x] Movement math normalizes diagonal input.
- [x] The primitive visitor model turns toward movement and animates its limbs.
- [x] SpringArm3D shortens the camera against park geometry.

## Test Evidence

`tests/unit/movement_math_test.gd` and documented real-window playtest.
