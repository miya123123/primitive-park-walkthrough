# EPIC-001-S04: Attraction motion and landmark guidance

**Status:** Complete
**Type:** Integration
**TR-ID:** TR-PRESENT-001
**ADR Governing Implementation:** `docs/architecture/adr-0001-procedural-primitive-park.md`
**Manifest Version:** 2026-08-25
**Dependencies:** EPIC-001-S03

## Acceptance Criteria

- [x] Ferris wheel and carousel rotate slowly using configured speeds.
- [x] Roller coaster cart follows a closed route and loops.
- [x] Each landmark has a readable sign and a proximity event.
- [x] Re-entering a landmark can emit the event again.

## Test Evidence

`tests/integration/park_scene_test.gd` and real-window playtest.
