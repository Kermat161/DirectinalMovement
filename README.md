# Directional Movement Controller

This repository contains a Roblox Lua controller that drives a full directional animation set for a humanoid character. It supports the following animation clips:

```
Idle, Walk, WalkRight, WalkLeft, BackWalk, WalkEnd, RightWalkEnd, LeftWalkEnd, BackWalkEnd,
ToRun, Run, RunLeft, RunRight, BackRun, RunStop, ToWalk, Crouch, CrouchIdle, Jump, Fall, Land, Climb,
HurtIdle, HurtWalk, HurtWalkRight, HurtWalkLeft, HurtBackWalk, HurtRun, HurtRunLeft, HurtRunRight, HurtBackRun
```

## Usage

1. Place `DirectionalMovement.lua` in a `StarterPlayerScripts` `LocalScript` or require it from another client-side script.
2. Provide your own animation IDs mapped by the animation names listed above.
3. (Optional) Pass configuration for sprint/crouch bindings and speeds.

```lua
local DirectionalMovement = require(script:WaitForChild("DirectionalMovement"))

local controller = DirectionalMovement.new(
	nil,
	{
		Idle = "rbxassetid://IDLE_ID",
		Walk = "rbxassetid://WALK_ID",
		WalkRight = "rbxassetid://WALK_RIGHT_ID",
		WalkLeft = "rbxassetid://WALK_LEFT_ID",
		BackWalk = "rbxassetid://BACK_WALK_ID",
		WalkEnd = "rbxassetid://WALK_END_ID",
		RightWalkEnd = "rbxassetid://RIGHT_WALK_END_ID",
		LeftWalkEnd = "rbxassetid://LEFT_WALK_END_ID",
		BackWalkEnd = "rbxassetid://BACK_WALK_END_ID",
		ToRun = "rbxassetid://TO_RUN_ID",
		Run = "rbxassetid://RUN_ID",
		RunLeft = "rbxassetid://RUN_LEFT_ID",
		RunRight = "rbxassetid://RUN_RIGHT_ID",
		BackRun = "rbxassetid://BACK_RUN_ID",
		RunStop = "rbxassetid://RUN_STOP_ID",
		ToWalk = "rbxassetid://TO_WALK_ID",
		Crouch = "rbxassetid://CROUCH_ID",
		CrouchIdle = "rbxassetid://CROUCH_IDLE_ID",
		Jump = "rbxassetid://JUMP_ID",
		Fall = "rbxassetid://FALL_ID",
		Land = "rbxassetid://LAND_ID",
		Climb = "rbxassetid://CLIMB_ID",
		HurtIdle = "rbxassetid://HURT_IDLE_ID",
		HurtWalk = "rbxassetid://HURT_WALK_ID",
		HurtWalkRight = "rbxassetid://HURT_WALK_RIGHT_ID",
		HurtWalkLeft = "rbxassetid://HURT_WALK_LEFT_ID",
		HurtBackWalk = "rbxassetid://HURT_BACK_WALK_ID",
		HurtRun = "rbxassetid://HURT_RUN_ID",
		HurtRunLeft = "rbxassetid://HURT_RUN_LEFT_ID",
		HurtRunRight = "rbxassetid://HURT_RUN_RIGHT_ID",
		HurtBackRun = "rbxassetid://HURT_BACK_RUN_ID",
		},
		{
			SprintSpeed = 20, -- default: humanoid.WalkSpeed * 1.6
			SprintBind = Enum.KeyCode.LeftShift,
			CrouchSpeed = 8, -- default: humanoid.WalkSpeed * 0.5
			CroughHeight = 1.8, -- default: humanoid.HipHeight
			CrouchBind = Enum.KeyCode.C,
			WalkAnimSpeed = 1, -- default: 1
			RunAnimSpeed = 1, -- default: 1
			CrouchAnimSpeed = 1, -- default: 1
			UseRunWalkTransitions = true, -- default: true. Set false to skip ToRun/ToWalk overlay
			UseEndAnimations = true, -- default: true. Set false to skip walk/run end clips
			UseTouchButtons = true, -- default: true. Shows CAS touch buttons for run/crouch
			MaxStamina = 100, -- default: 100
			StaminaRegenRate = 15, -- default: 15 per second
			StaminaDrainRate = 25, -- default: 25 per second while running
			LowHealthThreshold = 30, -- default: 30
			HurtAnimationName = "Hurt", -- default: "Hurt"
			UseHideSpots = true, -- default: true
			HideAnimations = {
				Under = "rbxassetid://HIDE_UNDER_ID",
			},
			UseCameraRelative = true, -- default: true. Set false to use character facing (3rd-person movement)
		}
	)
```

## Controls

- **Shift**: Toggle run (plays `ToRun`, `Run`, and `RunStop`).
- **C**: Toggle crouch (plays `Crouch`).
- Standard movement controls drive walking or running directional clips based on your `MoveDirection` relative to the current camera.
- On mobile, ContextActionService touch buttons are shown for run/crouch by default (configurable via `UseTouchButtons`), and you can also wire your own UI buttons using the helper in `MobileControls.lua`.

## Configuration

`DirectionalMovement.new` accepts an optional config table:

- `SprintSpeed` (number): WalkSpeed while running. Defaults to `Humanoid.WalkSpeed * 1.6`.
- `SprintBind` (KeyCode): Key to enter sprint. Defaults to `LeftShift`.
- `CrouchSpeed` (number): WalkSpeed while crouched. Defaults to `Humanoid.WalkSpeed * 0.5`.
- `CroughHeight` (number): HipHeight while crouched. Defaults to current `Humanoid.HipHeight`.
- `CrouchBind` (KeyCode): Key to toggle crouch. Defaults to `C`.
- `WalkAnimSpeed` (number): Playback speed for walking clips. Defaults to `1`.
- `RunAnimSpeed` (number): Playback speed for running clips. Defaults to `1`.
- `CrouchAnimSpeed` (number): Playback speed for crouch clips. Defaults to `1`.
- `UseRunWalkTransitions` (boolean): If true (default) plays `ToRun`/`ToWalk` overlays when changing speed; set false to jump directly to Run/Walk.
- `UseEndAnimations` (boolean): If true (default) plays walk/run stop/end transition clips; set false to stop directly on idle.
- `UseTouchButtons` (boolean): If true (default) shows touch buttons for run/crouch via `ContextActionService`; set false to hide them.
- `MaxStamina` (number): Max stamina/energy value. Defaults to `100`.
- `StaminaRegenRate` (number): Stamina regen per second when not running. Defaults to `15`.
- `StaminaDrainRate` (number): Stamina drain per second while running. Defaults to `25`.
- `LowHealthThreshold` (number): Health value at or below which hurt locomotion variants are used. Defaults to `30`.
- `HurtAnimationName` (string): Optional single hurt animation name (legacy). Defaults to `"Hurt"`; if you provide per-state hurt clips, those are preferred.
- `UseHideSpots` (boolean): Enables proximity prompt hiding spots under `workspace.HidingSpots`. Defaults to `true`.
- `HideAnimations` (table): Mapping of hide type to animation ID, e.g. `{ Under = "rbxassetid://..." }`. These are written into the `HideAnimations` config folder.
- `UseCameraRelative` (boolean): If true (default) movement directions are evaluated relative to the camera; set false to orient using the character/root part (3rd-person).

## Live Config Values

When the controller is created it adds a `DirectionalMovementConfig` folder under the player. It exposes editable values like `SprintSpeed`, `RunAnimSpeed`, `MaxStamina`, and `LowHealthThreshold` that can be updated live by other scripts. It also exposes read-only values like `CurrentStamina` and `IsHurt` that update in real time.

The config folder also exposes a `Hidden` BoolValue that is true while the player is attached to a hide spot.

### Hide Animations

Create a `HideAnimations` folder under `DirectionalMovementConfig` (it is created automatically) and add `StringValue` entries named after the hide type. For example, a part named `Hide_Under` looks up `HideAnimations/Under` for the animation asset ID. When a `ProximityPrompt` on the hide part is triggered, the player is welded to the part center and the hide animation plays at Action priority, freezing on the final pose until the prompt is triggered again to play the clip in reverse.

Example value setup:

```
Player
└─ DirectionalMovementConfig
   └─ HideAnimations
      └─ Under (StringValue = rbxassetid://HIDE_UNDER_ID)
```

## Cleanup

When the controller is no longer needed, call `controller:Destroy()` to disconnect events and destroy animation tracks.
