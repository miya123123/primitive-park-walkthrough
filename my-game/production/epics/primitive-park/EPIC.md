# EPIC-001: Primitive Park Vertical Slice

**Status:** In Progress
**Governing ADR:** `docs/architecture/adr-0001-procedural-primitive-park.md`
**GDDs:** `game-concept.md`, `game-pillars.md`, `third-person-movement.md`, `primitive-park-layout.md`, `landmark-guidance.md`

## Goal

Deliver a playable Godot 4.6.2 desktop and browser vertical slice where the player can enter and freely walk around a colorful primitive-only amusement park.

## Stories

| ID | Story | Type | Dependency | Status |
|---|---|---|---|---|
| EPIC-001-S01 | Project and data foundation | Config/Data | None | Complete |
| EPIC-001-S02 | Third-person movement and camera | Logic | S01 | Complete |
| EPIC-001-S03 | Procedural primitive park and collisions | Integration | S01, S02 | In Progress |
| EPIC-001-S04 | Attraction motion and landmark guidance | Integration | S03 | In Progress |
| EPIC-001-S05 | Minimal HUD and visual QA | UI/Visual | S04 | Complete |
| EPIC-001-S06 | Ride interaction and one-cycle boarding | Gameplay/UI | S04, S05 | Complete |
| EPIC-001-S07 | Free-fall and go-kart interactive rides | Gameplay/UI | S06 | Complete |

## Out of Scope

Combat, NPCs, multiplayer, imported assets, and audio. Ride-specific save data is limited to the local go-kart best time.
