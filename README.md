# gsom_pawns

## Shutdown verification on Godot 4.7.2

The demo fields `Main.__instance` and `Teleport.__teleports` use the base types Node3D/Node. Methods validate each value and use a local variable of the specific Main/Teleport type. The static Main reference is cleared when the scene exits the tree. These changes do not alter the Pawns core API.

All 38 scripts compile and the complete demo loads. Removing the scene and allowing subsequent frames to run produces a clean shutdown. A direct quit during playback can report remaining audio resources in a Godot 4.7.2 headless run on Windows; the same behavior reproduces with a single standard AudioStreamPlayer without Pawns. No audio-system workarounds were added to the addon. Whether this differs from a regular run with an audio device has not been established.

Modular **Godot 4** framework for **character pawns**. Pawns interact
with environment and triggers through handler nodes.

The addon provides a **framework** for creating characters (pawns)
with different movement styles. It does **not** handle input
directly - pass your player or AI input into pawns through the provided API.

The concept of a *Pawn* is inspired by Unreal Engine's definition:
> A Pawn is the physical representation of a player or AI entity within the world.

This addon adapts that idea to the Godot workflow.

[![screenshot_1](gdignore/thumbnail_1.jpg)](gdignore/screenshot_1.jpg)
[![screenshot_2](gdignore/thumbnail_2.jpg)](gdignore/screenshot_2.jpg)

- **Multiplayer-ready?** - Not right now. No multiplayer-specific stuff. Just some nodes.
- **Performance?** - As good or bad as any GDScript-based controllers.
- **Debug?** - Nothing addon-specific. In most cases you need to debug the collisions.
- **Project organization?** - Examples provided by the demo project.
- **2D Support?** - Not right now. But it should be easy to add.

## Installation

1. Copy the `addons/gsom_pawns/` folder into your project.
2. Enable the plugin in **Project Settings → Plugins**.

The demo scenes and controllers are **not required** for the addon
to work - they are provided for reference.

## Integration Notes

- **Input Handling:** The addon does not process inputs.
	Pass processed actions to pawns via `set_action` or similar API.
- **Pawn Body:** can be any `Node3D`.
	Can optionally track linear and angular velocities to
	obtain acceleration measurements.
- **Scene Lifecycle:** the pawn body is automatically instantiated when `GsomPawn`
	node is "ready". It becomes a child node of `GsomPawn` and is automatically
	removed when the `GsomPawn` node is removed.
- **Camera/Head Sync:** Use `moved` signal to update the camera and/or UI.
	Additionaly, use `moved_head` signal or poll `head_y` to
	adjust your camera position if the body needs to dynamically offset it.

---

## GsomPawn

**Purpose:** Represents a controllable or AI-driven entity.
Must be placed as a child of your **character** node.
Assign `GsomPawn.scene` to define the pawn's physical body.

A pawn is the physical representation of a player or AI entity within the world. The pawn determines how the entity interacts with the world in terms of collisions and other physical interactions. Some types of games may not have a visible player mesh or avatar within the game. Regardless, the Pawn still represents the physical location, rotation, etc. of a player or entity within the game. You will need a Controller to possess a pawn and generate input signals for it.

**Scene Structure Example:**

```gdscript
MainScene
|---Controller # not a child of pawn or character
|   |---Camera # <-- the actual camera is inside controller
|   |---Hud
|   |---EscMenu
|
|---Character # <-- this is yours, attach a script here
	|---GsomPawn # <-- this is the GsomPawn node
	|   |   [GsomPawn.scene] # <-- your scene defines the body
	|   |---PawnHandler1
	|   |---PawnHandler2
	|   |---PawnHandler3 # <-- extends GsomPawnHandler
	|   
	|---Mesh # anything else that you need for a character
	|---Audio
```

**Framework concerns:**
- Instantiate the body scene and track it during runtime and in Editor.
- Interpolate the perceived head/camera position during shape changes.
- Run the attached pawn handlers according to pawn state and filters.
- Store pawn info fields and facilitate interactions with triggers and envs.

**Your concerns:**
- What the character looks and sound like.
- What the character body can physically do (e.g. change shape, use physics, etc.).
- How you attach controllers and how they interact with the characters.
- How exactly the character moves in different contexts.

**Signals**

- `signal moved(pos: Vector3)` - The pawn has finished the `_physics_process` logic. This is the right time
	to use the position to update cameras or other stuff.

- `signal accelerated_linear(dv: Vector3)` - The body changed its linear speed - only emits if `track_accel_linear`.

- `signal accelerated_angular(dv: Vector3)` - The body changed its angular speed - only emits if `track_accel_angular`.

- `signal moved_head(head_y: float)` - The relative position of the head changed.

- `signal triggered(trigger_name: String, value: Variant)` - The body has produced an event with optional data.


**Properties**

- `readonly Vector3 angular_velocity` - Angular velocity vector, only updated if has_velocity_angular.

- `readonly Node3D body` - Get the cached physical body object as instantiated from scene.

- `bool has_velocity_angular [default: false]` - If the pawn needs to track its angular velocity.

- `bool has_velocity_linear [default: false]` - If the pawn needs to track its linear velocity.

- `bool track_accel_angular [default: false]` - If the pawn needs to track its angular acceleration.

- `bool track_accel_linear [default: false]` - If the pawn needs to track its linear acceleration.

- `readonly Vector3 linear_velocity` - Linear velocity vector, only updated if has_velocity_linear.

- `readonly Vector3 position` - Get position of the body.

- `float head_speed [default: 1.0]` - How quickly the "head" moves towards the target position (m/s).

- `readonly float head_y` - Get the animated head/eye/camera position Y.
	This value is animated towards head_y_target with the speed of head_speed (meters per second).

- `float head_y_target [default: 0.0]` - Set this value to define the intended head height of the body.
	When this value is set from _ready, it will be applied immediately without animation.

- `PackedScene scene` - Scene that will be instantiated for this pawn

**Methods**

- `void do_integrate(state: PhysicsDirectBodyState3D)` - Framework method, should be called by scene instance on `_integrate_forces`.

- `void do_physics(dt: float)` - Framework method, should be called by scene instance on `_physics_process`.

- `void do_process(dt: float)` - Framework method, should be called by scene instance on `_process`.

- `bool erase_action(field_name: String)` - Shortcut for `erase_info("actions", field_name)`.

- `bool erase_env(field_name: String)` - Shortcut for `erase_info("envs", field_name)`.

- `bool erase_info(group_name: String, field_name: String)` - Erase the input value.

- `bool erase_state(field_name: String)` - Shortcut for `erase_info("states", field_name)`.

- `bool erase_trait(field_name: String)` - Shortcut for `erase_info("traits", field_name)`.

- `Variant get_action(field_name: String, default_value: Variant = null)` - Shortcut for `get_info("actions", field_name, default_value)`.

- `Variant get_env(field_name: String, default_value: Variant = null)` - Shortcut for `get_info("envs", field_name, default_value)`.

- `Variant get_info(group_name: String, field_name: String, default_value: Variant = null)` - Fetch an info field by group name and field name. 
	If the field has never been set or reset_info has just been called,
	this method returns default_value.

- `Variant get_state(field_name: String, default_value: Variant = null)` - Shortcut for `get_info("states", field_name, default_value)`.

- `Variant get_trait(field_name: String, default_value: Variant = null)` - Shortcut for `get_info("traits", field_name, default_value)`.

- `bool has_action(field_name: String)` - Shortcut for `has_info("actions", field_name)`.

- `bool has_env(field_name: String)` - Shortcut for `has_info("envs", field_name)`.

- `bool has_info(group_name: String, field_name: String)` - Check if the input info exists.

- `bool has_state(field_name: String)` - Shortcut for `has_info("states", field_name)`.

- `bool has_trait(field_name: String)` - Shortcut for `has_info("traits", field_name)`.

- `void reset_actions()` - Shortcut for `reset_info("actions")`.

- `void reset_envs()` - Shortcut for `reset_info("envs")`.

- `void reset_info(group_name: String = "")` - Clear an info group by name, or wipe all groups if name is empty.

- `void reset_states()` - Shortcut for `reset_info("states")`.

- `void reset_traits()` - Shortcut for `reset_info("traits")`.

- `void set_action(field_name: String, value: Variant)` - Shortcut for `set_info("actions", field_name, value)`.

- `void set_env(field_name: String, value: Variant)` - Shortcut for `set_info("envs", field_name, value)`.

- `void set_info(group_name: String, field_name: String, value: Variant)` - Set an arbitrary info field in an info group.
	Such as `("actions", "jump", true)`, or `("env", "surface", "wood")`.
	The info can be read and written by any party to determine
	the state and evolution of the model.
	Suggested groups:
	- `actions` - processed input from controllers: where to go, how fast, etc.
	- `envs` - pawn surrounding environment: surface, sound filters, wind, gravity.
	- `states` - pawn internal state: crouch, swim, ladder.
	- `traits` - pawn specific abilities, items and levels: hp, boosts, inventory.

- `void set_state(field_name: String, value: Variant)` - Shortcut for `set_info("states", field_name, value)`.

- `void set_trait(field_name: String, value: Variant)` - Shortcut for `set_info("traits", field_name, value)`.

- `void trigger(trigger_name: String, value: Variant = null)` - Produce an event from this pawn with optional data.

---

## GsomPawnHandler

**Purpose:** Defines a piece of pawn behavior (movement, special abilities, interactions).
You can attach multiple handlers to a pawn.

**Filtering:** Handlers can be conditionally active based on pawn states or environments.

Execution **order** of handlers is determined by how they are ordered as
children of the `GsomPawn` node.

Handlers define the pawn behavior. You can implement everything into a single handler,
but it would be more convenient to divide the behavior into small manageable pieces.

For example, a separate handler for movement on **ladders** or **underwater**.
Or a **reusable** walk handler that can be utilized for both players and enemies.
A separate handler can define **interaction with triggers**,
so those triggers will only interact with pawns that have such handler.

**Properties**

`bool disabled [default: false]`
	- Disabled handlers are skipped.

`PackedStringArray exclude_envs [default: []]`
	- Prevent processing while the body is in these envs.

`PackedStringArray exclude_states [default: []]`
	- Prevent processing while the body is in these states.

`PackedStringArray include_envs [default: []]`
	- Only process while in these envs. Ignored if empty.

`PackedStringArray include_states [default: []]`
	- Only process while in these states. Ignored if empty.

**Methods**

`void _do_integrate(pawn: GsomPawn, state: PhysicsDirectBodyState3D)`
	- Reimplement this to update the body on _integrate_forces.

`void _do_physics(pawn: GsomPawn, delta: float)`
	- Reimplement this to update the body on _physics_process.

`void _do_process(pawn: GsomPawn, dt: float)`
	- Reimplement this to update the body on _process.

---

## GsomPawnTrigger

**Purpose:** Emits signals when pawns enter/exit an `Area3D`, optionally passing custom data.

Attach a trigger to Area3D. Depending on behavior,
it will trigger a signal on all entering and/or exiting pawns.
The additional trigger data can be assigned separately for enter and exit.

**TriggerBehavior**

- `ON_ENTER` - Default: trigger when pawn enters.
- `ON_EXIT` - Inverse: trigger when pawn exits.
- `ON_ENTER_AND_EXIT` - Trigger both when pawn enters and exits.

**Properties**

`TriggerBehavior behavior [default: 0]`
	- When the trigger should emit signal.

`bool disabled [default: false]`
	- Doesn't do anything, when disabled.

`String trigger_name [default: ""]`
	- Trigger name to emit.

`Dictionary value_enter [default: {}]`
	- Trigger value passed on pawn enter. Default is {}, empty dictionary.

`Dictionary value_exit [default: {}]`
	- Trigger value passed on pawn exit. Default is {}, empty dictionary.

**Methods**

`void _trigger_enter(pawn: GsomPawn)`
	- Called when a body enters the trigger.  Override this for custom triggers.

`void _trigger_exit(pawn: GsomPawn)`
	- Called when a body exits from trigger.  Override this for custom triggers.

`void attach()`
	- Call this from `_ready()` if you override it.

---

## GsomPawnEnv

**Purpose:** Assigns or removes environment state fields to pawns entering/exiting an `Area3D`.

Attach an env to Area3D. Depending on behavior,
it will apply and/or remove an env field on all entering and/or exiting pawns.

**EnvBehavior**
- `ENTER_APPLY` - Only apply the Env when pawn enters the area, do nothing on exit.
- `ENTER_REMOVE` - Only remove the Env when pawn enters the area, do nothing on exit.
- `ENTER_APPLY_EXIT_REMOVE` - Default: apply when pawn enters, remove on exit.
- `ENTER_REMOVE_EXIT_APPLY` - Inverse: remove when pawn enters, apply on exit.
- `EXIT_APPLY` - Only apply the Env when pawn exits the area, do nothing on enter.
- `EXIT_REMOVE` - Only remove the Env when pawn exits the area, do nothing on enter.


**Properties**

`EnvBehavior behavior [default: ENTER_APPLY_EXIT_REMOVE]`
	- When the Env should be applied and removed.

`bool disabled [default: false]`
	- Doesn't do anything, when disabled.

`String env_name [default: ""]`
	- Env info field name to edit.

`Dictionary env_value [default: {}]`
	- Env value to be assigned. Default is {}, empty dictionary.


**Methods**

`void _apply_env(pawn: GsomPawn)`
	- Called to assign the env value.  Override this for custom envs.

`void _erase_env(pawn: GsomPawn)`
	- Called to remove the env value.  Override this for custom envs.

`void attach()`
	- Call this from `_ready()` if you override it.

---

## Demo Project

The addon only consists of the `addons/gsom_pawns/` content - that's what you
would install from Godot Asset Library. But this repository also contains
several examples of how the addon can be used.

The main file `preview.gd` initiates async loading of all other scenes.
There are 2 main controllers: FPS and RTS. You can switch between them in
ESC menu that is available from both. In FPS controller you can use mouse wheel
to zoom into a third-person view, but that's just a gimmick.

The FPS controller and demo are focused on running around with WASD and mouse-look.
- Human Character - a normal humanoid character that can jump and crouch. The controls
	are extremely similar to Half-Life 1 or even AG (Quake 1 too). To a
	point where you can traverse the original `agtricks` and `destructo_hops`.
	Also they are included in the demo, so you can try for yourself!
- Vtol Character - a small aircraft that can go up/down and forward. It's kind of
	rudimentary, mostly as a proof of concept. A better aircraft demo would
	need a larger and different map.
- Spec Character - spectator mode. Similar to Counter-Strike free camera spectator.
	You can fly around the rooms with noclip.

The role of RTS controller is to showcase a project structure where you can
switch between several controllers, and to demonstrate how pawns can be
partially or fully AI controlled. The RTS pawns use a nav mesh and some
additional HUD considerations. You can control multiple pawns at once in this mode.

The particular ways how all these pawns behave - are part of the demo and not the addon.
Still you might want to copy the implementation and tweek it instead of writing
it from scratch.

Notable **example files:**
- `res://maps/gdtricks/misc/teleport.tscn` - an example of `extends GsomPawnTrigger`,
	this is a special trigger that teleports entering pawns (if they have a collision body).
- `res://maps/gdtricks/misc/snap-env.tscn` - an example of `extends GsomPawnEnv`,
	a special env that snaps facilitates snapping to moving platforms.
- `res://controllers/fps/controller_fps.tscn` - how to control and switch between
	several pawns, based on FPS-style input.
- `res://characters/spec/char_spec.tscn` - a very simple no-clip character and pawn.
- `res://characters/human/char_human.tscn` - a complex solution to control a humanoid
	pawn in a set of different states and environments.
- `res://maps/test_chamber/test_chamber.tscn` - uses several triggers and envs:
	water, ladder, zero-g, jump pad.

A few notes on FPS **human movement**:
- Under crosshair, you have a speedometer - it only measures the horizontal speed.
- Holding spacebar will allow you to bhop perfectly.
- The movement speed is set to the Adrenaline Gamer standard value of **300**.
- See `res://characters/human/pawn/handler_rigid_walk.gd` for more specific values.
- Air acceleration works the same as in Q1 or HL1,
	see [in-depth explanation here](https://www.youtube.com/watch?v=v3zT3Z5apaM).
- Both AT (agtricks) and DH (destructo_hops) can be traversed in this demo and
	are very similar to [HL1 version](https://www.youtube.com/watch?v=VbA7Dc4i898).
	Maybe even slightly easier.

## Contribution language

Use English for all project-authored repository content and official communication, including source code, identifiers, comments, documentation, examples, configuration text, file and directory names, commit messages, issues, pull request titles and descriptions, reviews, and release notes.


## Environment ownership and lifecycle

With `ENTER_APPLY_EXIT_REMOVE`, sources with the same `env_name` form an ordered set:
the last entered area wins, leaving it restores the last remaining source, and leaving
all sources removes the field. Removing a source or its pawn body from the tree also
cleans up its contribution. `GsomPawnEnv.sources_of(pawn, env_name)` returns the active
sources in entry order. Internal pawn metadata in `GsomPawnEnv.SOURCES` contains weak
references; consumers should use the query rather than editing that metadata.

The other five behaviors remain event commands: values applied by them can persist
after leaving or deleting the area. They do not participate in source ownership.
Avoid mixing these commands with owned sources for the same field. Configure
`behavior` and `env_name` before entry; changing them while occupied is unsupported.
Disabling ignores new entries; existing owned contributions are still removed on exit.
Subclasses overriding `_apply_env` or `_erase_env` must call `super` to retain ownership
handling, and must call `super._exit_tree()` if they override lifecycle cleanup.
`attach()` is safe to call more than once.

Initial `head_y_target` changes, including from a parent `_ready()`, apply immediately
until the first pawn process frame. Later changes interpolate using `head_speed`.

### Isolated regression suite

Run outside the demo project to test only the distributable core, without Blender,
network examples, or an external test framework. Supply your pinned Godot shell wrapper
and a new output directory (the runner refuses to overwrite an existing directory):

```sh
python tests/environments/run.py --godot-wrapper /path/to/tools/godot.sh --output /path/to/build/pawns-env
```

The suite covers overlap restoration, source/body deletion, reentry, repeated attachment,
legacy event modes, and initial versus interpolated head height. Import/runtime diagnostics
and a missing success marker fail the run. `--addon-source` can select an older payload
for comparison. On Godot 4.7.2 the original core failed five assertions and reported two
duplicate signal connections; the updated core reports `PAWNS_REGRESSION failures=0`.
