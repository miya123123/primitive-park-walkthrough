# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6.2
- **Language**: GDScript
- **Rendering**: Forward+
- **Physics**: Jolt Physics3D (Godot 4.6 default)

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: PC desktop
- **Input Methods**: Keyboard/Mouse, partial gamepad action-map support
- **Primary Input**: Keyboard/Mouse
- **Gamepad Support**: Partial
- **Touch Support**: None
- **Platform Notes**: 1280×720 reference viewport; HUD expands with the window and remains anchored to safe margins.

## Naming Conventions

- **Classes**: PascalCase
- **Variables**: snake_case; private fields use a leading underscore
- **Signals/Events**: snake_case past tense
- **Files**: snake_case matching the main script type
- **Scenes/Prefabs**: PascalCase matching the root node
- **Constants**: UPPER_SNAKE_CASE

## Performance Budgets

- **Target Framerate**: 60 FPS
- **Frame Budget**: 16.6 ms
- **Draw Calls**: 250 or fewer in the compact park target scene
- **Memory Ceiling**: 512 MB for the desktop prototype

## Testing

- **Framework**: Dependency-free GDScript test runner invoked headlessly
- **Minimum Coverage**: All config validation, movement math, scene construction, and landmark event paths
- **Required Tests**: Balance formulas, gameplay systems, networking (if applicable)

## Forbidden Patterns

- External 3D models, textures, audio assets, or runtime dependencies in the vertical slice.
- Hard-coded gameplay tuning that belongs in `assets/data/park_config.json`.
- UI polling of gameplay state; HUD updates must arrive through signals/events.
- Moving `StaticBody3D` nodes; animated attractions move visual `Node3D` children only.

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [ADR-0001: JSON-driven procedural primitive park](../../docs/architecture/adr-0001-procedural-primitive-park.md)

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist
- **Shader Specialist**: godot-shader-specialist
- **UI Specialist**: godot-specialist
- **Additional Specialists**: godot-gdextension-specialist only if native code is later introduced
- **Routing Notes**: Use the Godot specialist for scenes/UI/architecture, the GDScript specialist for `.gd`, and the shader specialist only for `.gdshader` files. This project intentionally has no native extensions or custom shaders.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (`.gd` files) | godot-gdscript-specialist |
| Shader / material files (`.gdshader`) | godot-shader-specialist |
| UI / screen files (`Control`, `CanvasLayer`) | godot-specialist |
| Scene / prefab / level files (`.tscn`, `.tres`) | godot-specialist |
| Native extension / plugin files | godot-gdextension-specialist |
| General architecture review | Primary |
