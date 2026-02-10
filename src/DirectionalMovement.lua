--[[
DirectionalMovement.lua

Client-side controller that drives a directional movement animation set for a character.
Supports the following animation names:
Idle, Walk, WalkRight, WalkLeft, BackWalk, WalkEnd, RightWalkEnd, LeftWalkEnd, BackWalkEnd,
ToRun, Run, RunLeft, RunRight, BackRun, RunStop, ToWalk, Crouch, CrouchIdle, Jump, Fall, Land, Climb
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local DirectionalMovement = {}
DirectionalMovement.__index = DirectionalMovement

local ACTION_RUN = "DirectionalMovementRun"
local ACTION_CROUCH = "DirectionalMovementCrouch"

local LOOPING_TRACKS = {
	Idle = true,
	Walk = true,
	WalkRight = true,
	WalkLeft = true,
	BackWalk = true,
	Run = true,
	RunLeft = true,
	RunRight = true,
	BackRun = true,
	Crouch = true,
	CrouchIdle = true,
	Fall = true,
	Climb = true,
	HurtIdle = true,
	HurtWalk = true,
	HurtWalkRight = true,
	HurtWalkLeft = true,
	HurtBackWalk = true,
	HurtRun = true,
	HurtRunLeft = true,
	HurtRunRight = true,
	HurtBackRun = true,
	HurtCrouch = true,
	HurtCrouchIdle = true,
}

local ZERO = Vector3.new()

local function createAnimationTrack(animator: Animator, name: string, animationId: string)
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local track = animator:LoadAnimation(animation)
	track.Looped = LOOPING_TRACKS[name] == true
	track.Priority = Enum.AnimationPriority.Movement
	track:AdjustSpeed(1)
	return track
end

local function getOrCreateAnimator(humanoid: Humanoid)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		return animator
	end

	local newAnimator = Instance.new("Animator")
	newAnimator.Parent = humanoid
	return newAnimator
end

local function classifyDirection(cameraCFrame: CFrame, moveDirection: Vector3)
	if moveDirection == ZERO then
		return nil
	end

	local flatMove = Vector3.new(moveDirection.X, 0, moveDirection.Z)
	local localDir = cameraCFrame:VectorToObjectSpace(flatMove)
	local forward = -localDir.Z
	local sideways = localDir.X

	local mag = math.sqrt(forward * forward + sideways * sideways)
	if mag < 1e-3 then
		return nil
	end

	return Vector2.new(sideways / mag, forward / mag)
end

function DirectionalMovement.new(
	character: Model,
	animations: { [string]: string },
	config: {
		SprintSpeed: number?,
		CrouchSpeed: number?,
		CroughHeight: number?,
		SprintBind: Enum.KeyCode?,
		CrouchBind: Enum.KeyCode?,
		UseEndAnimations: boolean?,
		UseRunWalkTransitions: boolean?,
		UseTouchButtons: boolean?,
		RunToggle: boolean?,
		MaxStamina: number?,
		StaminaRegenRate: number?,
		StaminaDrainRate: number?,
		LowHealthThreshold: number?,
		HurtAnimationName: string?,
		UseHideSpots: boolean?,
		HideAnimations: { [string]: string }?,
		UseCameraRelative: boolean?,
	}?
)
	local player = Players.LocalPlayer
	local resolvedCharacter = character or player.Character or player.CharacterAdded:Wait()
	local humanoid = resolvedCharacter:WaitForChild("Humanoid")
	local animator = getOrCreateAnimator(humanoid)

	local options = config or {}
	local sprintBind = options.SprintBind or Enum.KeyCode.LeftShift
	local crouchBind = options.CrouchBind or Enum.KeyCode.C
	local sprintSpeed = options.SprintSpeed or humanoid.WalkSpeed * 1.6
	local crouchSpeed = options.CrouchSpeed or humanoid.WalkSpeed * 0.5
	local walkAnimSpeed = options.WalkAnimSpeed or 1
	local runAnimSpeed = options.RunAnimSpeed or 1
	local crouchAnimSpeed = options.CrouchAnimSpeed or 1
	local useEndAnimations = options.UseEndAnimations
	if useEndAnimations == nil then
		useEndAnimations = true
	end
	local useRunWalkTransitions = options.UseRunWalkTransitions
	if useRunWalkTransitions == nil then
		useRunWalkTransitions = true
	end
	local crouchHeight = options.CroughHeight or humanoid.HipHeight
	local useCameraRelative = options.UseCameraRelative
	if useCameraRelative == nil then
		useCameraRelative = true
	end
	local useTouchButtons = options.UseTouchButtons
	if useTouchButtons == nil then
		useTouchButtons = true
	end
	local runToggle = options.RunToggle
	if runToggle == nil then
		runToggle = useTouchButtons
	end
	local maxStamina = options.MaxStamina or 100
	local staminaRegenRate = options.StaminaRegenRate or 15
	local staminaDrainRate = options.StaminaDrainRate or 25
	local lowHealthThreshold = options.LowHealthThreshold or 30
	local hurtAnimationName = options.HurtAnimationName or "Hurt"
	local useHideSpots = options.UseHideSpots
	if useHideSpots == nil then
		useHideSpots = true
	end
	local hideAnimations = options.HideAnimations or {}

	local self = setmetatable({
		Player = player,
		Character = resolvedCharacter,
		Humanoid = humanoid,
		Animator = animator,
		Tracks = {},
		CurrentTrackName = nil,
		UseCameraRelative = useCameraRelative,
		TransitionName = nil,
		TransitionEndTime = 0,
		TransitionBlendWeight = 1,
		Running = false,
		Crouching = false,
		LastDirection = nil,
		HoldAnimationUntil = 0,
		Airborne = false,
		DefaultWalkSpeed = humanoid.WalkSpeed,
		DefaultHipHeight = humanoid.HipHeight,
		SprintSpeed = sprintSpeed,
		CrouchSpeed = crouchSpeed,
		CroughHeight = crouchHeight,
		SprintBind = sprintBind,
		CrouchBind = crouchBind,
		WalkAnimSpeed = walkAnimSpeed,
		RunAnimSpeed = runAnimSpeed,
		CrouchAnimSpeed = crouchAnimSpeed,
		UseEndAnimations = useEndAnimations,
		UseRunWalkTransitions = useRunWalkTransitions,
		UseTouchButtons = useTouchButtons,
		RunToggle = runToggle,
		MaxStamina = maxStamina,
		StaminaRegenRate = staminaRegenRate,
		StaminaDrainRate = staminaDrainRate,
		CurrentStamina = maxStamina,
		LowHealthThreshold = lowHealthThreshold,
		HurtAnimationName = hurtAnimationName,
		IsHurt = false,
		UseHideSpots = useHideSpots,
		Hiding = false,
		HideRoot = nil,
		HideWeld = nil,
		HideTrack = nil,
		HideType = nil,
		HideAnimations = hideAnimations,
		HideFreezeConnection = nil,
		HideStopConnection = nil,
		HideExiting = false,
		HideHoldPosition = 0,
		Climbing = false,
	}, DirectionalMovement)

	for name, id in pairs(animations) do
		self.Tracks[name] = createAnimationTrack(animator, name, id)
	end

	self:setupConfigFolder()
	self:bindInputs()
	self:connectSignals()
	self:bindHideSpots()
	self:play("Idle")

	return self
end

function DirectionalMovement:play(name: string, fadeTime: number?)
	if self.Hiding then
		return
	end
	local resolvedName = self:resolveHurtName(name)
	local track = self.Tracks[resolvedName]
	if not track then
		return
	end

	if self.CurrentTrackName == resolvedName and track.IsPlaying then
		return
	end

	local fade = fadeTime or 0.15
	for otherName, otherTrack in pairs(self.Tracks) do
		if otherTrack.IsPlaying and otherName ~= resolvedName then
			otherTrack:Stop(fade)
		end
	end

	if not track.IsPlaying then
		track.TimePosition = 0
	end
	track:Play(fade)
	local speed = self:getTrackSpeed(resolvedName)
	track:AdjustSpeed(speed)
	self.CurrentTrackName = resolvedName
	if not LOOPING_TRACKS[resolvedName] then
		local duration = track.Length > 0 and (track.Length / track.Speed) or 0.25
		self.HoldAnimationUntil = math.max(self.HoldAnimationUntil, os.clock() + duration)
	end
end

function DirectionalMovement:setTrackWeights(targetWeights: { [string]: number }, fadeTime: number?)
	if self.Hiding then
		return
	end
	local fade = fadeTime or 0.12
	local active = {}

	for name, weight in pairs(targetWeights) do
		local resolvedName = self:resolveHurtName(name)
		local track = self.Tracks[resolvedName]
		if track then
			active[resolvedName] = true
			if not track.IsPlaying then
				track:Play(fade)
			end
			track:AdjustSpeed(self:getTrackSpeed(resolvedName))
			track:AdjustWeight(weight, fade)
		end
	end

	if self.TransitionName and self.TransitionEndTime > os.clock() then
		local transitionTrack = self.Tracks[self.TransitionName]
		if transitionTrack then
			active[self.TransitionName] = true
			if not transitionTrack.IsPlaying then
				transitionTrack:Play(fade)
			end
			transitionTrack:AdjustSpeed(self:getTrackSpeed(self.TransitionName))
			transitionTrack:AdjustWeight(self.TransitionBlendWeight, fade)
		end
	else
		self.TransitionName = nil
		self.TransitionEndTime = 0
		self.TransitionBlendWeight = 1
	end

	for name, track in pairs(self.Tracks) do
		if not active[name] and track.IsPlaying then
			track:Stop(fade)
		end
	end

	self.CurrentTrackName = nil
end

function DirectionalMovement:setupConfigFolder()
	local folder = Instance.new("Folder")
	folder.Name = "DirectionalMovementConfig"
	folder.Parent = self.Player

	local function numberValue(name: string, initial: number, onChanged)
		local value = Instance.new("NumberValue")
		value.Name = name
		value.Value = initial
		value.Parent = folder
		if onChanged then
			value.Changed:Connect(function(newValue)
				onChanged(newValue)
			end)
		end
		return value
	end

	local function boolValue(name: string, initial: boolean, onChanged)
		local value = Instance.new("BoolValue")
		value.Name = name
		value.Value = initial
		value.Parent = folder
		if onChanged then
			value.Changed:Connect(function(newValue)
				onChanged(newValue)
			end)
		end
		return value
	end

	numberValue("SprintSpeed", self.SprintSpeed, function(v)
		self.SprintSpeed = v
	end)
	numberValue("CrouchSpeed", self.CrouchSpeed, function(v)
		self.CrouchSpeed = v
	end)
	numberValue("CroughHeight", self.CroughHeight, function(v)
		self.CroughHeight = v
	end)
	numberValue("WalkAnimSpeed", self.WalkAnimSpeed, function(v)
		self.WalkAnimSpeed = v
	end)
	numberValue("RunAnimSpeed", self.RunAnimSpeed, function(v)
		self.RunAnimSpeed = v
	end)
	numberValue("CrouchAnimSpeed", self.CrouchAnimSpeed, function(v)
		self.CrouchAnimSpeed = v
	end)
	numberValue("MaxStamina", self.MaxStamina, function(v)
		self.MaxStamina = v
		self.CurrentStamina = math.clamp(self.CurrentStamina, 0, self.MaxStamina)
	end)
	numberValue("StaminaRegenRate", self.StaminaRegenRate, function(v)
		self.StaminaRegenRate = v
	end)
	numberValue("StaminaDrainRate", self.StaminaDrainRate, function(v)
		self.StaminaDrainRate = v
	end)
	numberValue("LowHealthThreshold", self.LowHealthThreshold, function(v)
		self.LowHealthThreshold = v
	end)

	boolValue("UseEndAnimations", self.UseEndAnimations, function(v)
		self.UseEndAnimations = v
	end)
	boolValue("UseRunWalkTransitions", self.UseRunWalkTransitions, function(v)
		self.UseRunWalkTransitions = v
	end)
	boolValue("UseTouchButtons", self.UseTouchButtons, function(v)
		self.UseTouchButtons = v
		self:rebindInputs()
	end)
	boolValue("RunToggle", self.RunToggle, function(v)
		self.RunToggle = v
	end)
	boolValue("UseCameraRelative", self.UseCameraRelative, function(v)
		self.UseCameraRelative = v
	end)

	local hurtNameValue = Instance.new("StringValue")
	hurtNameValue.Name = "HurtAnimationName"
	hurtNameValue.Value = self.HurtAnimationName
	hurtNameValue.Parent = folder
	hurtNameValue.Changed:Connect(function(newValue)
		self.HurtAnimationName = newValue
	end)

	local hideFolder = Instance.new("Folder")
	hideFolder.Name = "HideAnimations"
	hideFolder.Parent = folder
	for hideType, animationId in pairs(self.HideAnimations) do
		local value = Instance.new("StringValue")
		value.Name = hideType
		value.Value = animationId
		value.Parent = hideFolder
	end

	self.CurrentStaminaValue = numberValue("CurrentStamina", self.CurrentStamina)
	self.IsHurtValue = boolValue("IsHurt", self.IsHurt)
	self.HiddenValue = boolValue("Hidden", self.Hiding)
end

function DirectionalMovement:resolveHurtName(name: string): string
	if not self.IsHurt then
		return name
	end

	local hurtName = "Hurt" .. name
	if self.Tracks[hurtName] then
		return hurtName
	end

	if name == "Idle" and self.Tracks[self.HurtAnimationName] then
		return self.HurtAnimationName
	end

	return name
end

function DirectionalMovement:getHideAnimationId(hideType: string): string?
	local config = self.Player:FindFirstChild("DirectionalMovementConfig")
	if not config then
		return nil
	end

	local hideFolder = config:FindFirstChild("HideAnimations")
	if not hideFolder then
		return nil
	end

	local value = hideFolder:FindFirstChild(hideType)
	if value and value:IsA("StringValue") then
		return value.Value
	end

	return nil
end

function DirectionalMovement:enterHide(hidePart: BasePart, hideType: string)
	if self.Hiding then
		return
	end

	local animationId = self:getHideAnimationId(hideType)
	if not animationId or animationId == "" then
		return
	end

	local root = self.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	self.Hiding = true
	self.HideExiting = false
	if self.HiddenValue then
		self.HiddenValue.Value = true
	end
	self.HideType = hideType
	self.HideRoot = hidePart

	root.CFrame = hidePart.CFrame
	self.Humanoid.AutoRotate = false
	self.Humanoid.WalkSpeed = 0
	self.Running = false
	for _, track in pairs(self.Tracks) do
		if track.IsPlaying then
			track:Stop(0.1)
		end
	end

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = hidePart
	weld.Parent = root
	self.HideWeld = weld

	local track = createAnimationTrack(self.Animator, "Hide", animationId)
	self.HideTrack = track
	track.Looped = false
	track.Priority = Enum.AnimationPriority.Action
	track.TimePosition = 0
	track:AdjustSpeed(1)
	track:Play(0.1)
	if self.HideFreezeConnection then
		self.HideFreezeConnection:Disconnect()
	end
	self.HideFreezeConnection = RunService.Heartbeat:Connect(function()
		if not self.Hiding or not track.IsPlaying then
			return
		end
		local length = track.Length
		if length <= 0 then
			return
		end
		self.HideHoldPosition = math.max(length - 0.08, 0)
		if track.TimePosition >= self.HideHoldPosition then
			track.TimePosition = self.HideHoldPosition
			track:AdjustSpeed(0)
			if self.HideFreezeConnection then
				self.HideFreezeConnection:Disconnect()
				self.HideFreezeConnection = nil
			end
		end
	end)
end

function DirectionalMovement:finalizeHideExit()
	self.Hiding = false
	self.HideExiting = false
	self.HideHoldPosition = 0
	if self.HiddenValue then
		self.HiddenValue.Value = false
	end
	self.Humanoid.AutoRotate = true
	local targetSpeed = self.Running and self.SprintSpeed or self.DefaultWalkSpeed
	self.Humanoid.WalkSpeed = targetSpeed
	self.HideRoot = nil
	self.HideType = nil
	if self.HideWeld then
		self.HideWeld:Destroy()
		self.HideWeld = nil
	end
end

function DirectionalMovement:exitHide()
	if not self.Hiding then
		return
	end

	if self.HideTrack then
		self.HideExiting = true
		if self.HideFreezeConnection then
			self.HideFreezeConnection:Disconnect()
			self.HideFreezeConnection = nil
		end
		if self.HideStopConnection then
			self.HideStopConnection:Disconnect()
			self.HideStopConnection = nil
		end
		local track = self.HideTrack
		local length = track.Length
		if length > 0 then
			local startPosition = self.HideHoldPosition > 0 and self.HideHoldPosition or math.max(length - 0.05, 0)
			if not track.IsPlaying then
				track:Play(0)
			end
			track.TimePosition = startPosition
			track:AdjustSpeed(-1)
			task.delay(startPosition, function()
				if track.IsPlaying then
					track:Stop(0.05)
				end
				track:Destroy()
				self:finalizeHideExit()
			end)
		else
			track:Stop(0.05)
			track:Destroy()
			self:finalizeHideExit()
		end
		self.HideTrack = nil
	else
		self:finalizeHideExit()
	end
end

function DirectionalMovement:bindHideSpots()
	if not self.UseHideSpots then
		return
	end

	self.HidePromptConnection = ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if player ~= self.Player then
			return
		end

		local part = prompt.Parent
		if not part or not part:IsA("BasePart") then
			return
		end
		local hidingFolder = workspace:FindFirstChild("HidingSpots")
		if not hidingFolder or not part:IsDescendantOf(hidingFolder) then
			return
		end

		if not part.Name:match("^Hide_") then
			return
		end

		local hideType = part.Name:gsub("^Hide_", "")
		if self.Hiding then
			self:exitHide()
		else
			self:enterHide(part, hideType)
		end
	end)
end

local WALK_TRACKS = {
	Forward = "Walk",
	Back = "BackWalk",
	Left = "WalkLeft",
	Right = "WalkRight",
}

local RUN_TRACKS = {
	Forward = "Run",
	Back = "BackRun",
	Left = "RunLeft",
	Right = "RunRight",
}

function DirectionalMovement:getTrackSpeed(name: string): number
	if name == "Crouch" or name == "CrouchIdle" then
		return self.CrouchAnimSpeed
	end

	for _, walkName in pairs(WALK_TRACKS) do
		if name == walkName then
			return self.WalkAnimSpeed
		end
	end

	for _, runName in pairs(RUN_TRACKS) do
		if name == runName then
			return self.RunAnimSpeed
		end
	end

	if name == "Run" then
		return self.RunAnimSpeed
	elseif name == "Walk" then
		return self.WalkAnimSpeed
	elseif name == "Crouch" then
		return self.CrouchAnimSpeed
	end

	return 1
end

local function majorDirection(dir: Vector2): string
	local forward = dir.Y
	local sideways = dir.X
	if math.abs(forward) >= math.abs(sideways) then
		if forward >= 0 then
			return "Forward"
		end
		return "Back"
	end

	if sideways >= 0 then
		return "Right"
	end
	return "Left"
end

function DirectionalMovement:applyDirectionalBlend(dir: Vector2, running: boolean)
	local mapping = running and RUN_TRACKS or WALK_TRACKS
	local forward = math.max(0, dir.Y)
	local back = math.max(0, -dir.Y)
	local right = math.max(0, dir.X)
	local left = math.max(0, -dir.X)

	local total = forward + back + right + left
	if total <= 0 then
		return
	end

	local weights = {}
	if forward > 0 then
		weights[mapping.Forward] = forward / total
	end
	if back > 0 then
		weights[mapping.Back] = back / total
	end
	if right > 0 then
		weights[mapping.Right] = right / total
	end
	if left > 0 then
		weights[mapping.Left] = left / total
	end

	self:setTrackWeights(weights, 0.12)
	self.LastDirection = majorDirection(dir)
end

function DirectionalMovement:getReferenceCFrame(): CFrame?
	if self.UseCameraRelative and workspace.CurrentCamera then
		return workspace.CurrentCamera.CFrame
	end

	if self.Character and self.Character.PrimaryPart then
		return self.Character.PrimaryPart.CFrame
	end

	return nil
end

function DirectionalMovement:stopAirborneTracks()
	local jump = self.Tracks["Jump"]
	if jump and jump.IsPlaying then
		jump:Stop(0.05)
	end

	local fall = self.Tracks["Fall"]
	if fall and fall.IsPlaying then
		fall:Stop(0.05)
	end

	local climb = self.Tracks["Climb"]
	if climb and climb.IsPlaying then
		climb:Stop(0.05)
	end
end

function DirectionalMovement:updateHurtState()
	local isHurt = self.Humanoid.Health <= self.LowHealthThreshold
	if isHurt == self.IsHurt then
		return
	end

	self.IsHurt = isHurt
	if self.IsHurtValue then
		self.IsHurtValue.Value = isHurt
	end
end

function DirectionalMovement:startTransition(name: string, speed: number?, weight: number?, fadeTime: number?)
	local track = self.Tracks[name]
	if not track then
		return
	end

	if not track.IsPlaying then
		track.TimePosition = 0
		track:Play(fadeTime or 0.08)
	end

	track:AdjustSpeed(speed or self:getTrackSpeed(name))
	local blendWeight = weight or 1
	track:AdjustWeight(blendWeight, 0.12)

	local length = track.Length > 0 and (track.Length / track.Speed) or 0.25
	self.TransitionName = name
	self.TransitionEndTime = os.clock() + length
	self.TransitionBlendWeight = blendWeight
end

function DirectionalMovement:bindInputs()
	ContextActionService:BindAction(
		ACTION_RUN,
		function(_, state)
			if self.RunToggle then
				if state == Enum.UserInputState.Begin then
					if self.Running then
						self:endRun()
					else
						self:beginRun()
					end
				end
			else
				if state == Enum.UserInputState.Begin then
					self:beginRun()
				elseif state == Enum.UserInputState.End then
					self:endRun()
				end
			end
		end,
		self.UseTouchButtons,
		self.SprintBind
	)

	ContextActionService:BindAction(
		ACTION_CROUCH,
		function(_, state)
			if state == Enum.UserInputState.Begin then
				self:toggleCrouch()
			end
		end,
		self.UseTouchButtons,
		self.CrouchBind
	)
end

function DirectionalMovement:rebindInputs()
	ContextActionService:UnbindAction(ACTION_RUN)
	ContextActionService:UnbindAction(ACTION_CROUCH)
	self:bindInputs()
end

function DirectionalMovement:connectSignals()
	self.MovementConnection = RunService.RenderStepped:Connect(function(dt)
		self:updateMovement(dt)
	end)

	self.StateConnection = self.Humanoid.StateChanged:Connect(function(_, newState)
		self:onStateChanged(newState)
	end)

	self.HealthConnection = self.Humanoid.HealthChanged:Connect(function()
		self:updateHurtState()
	end)
end

function DirectionalMovement:beginRun()
	if self.CurrentStamina <= 0 then
		return
	end
	if self.Crouching then
		self.Crouching = false
		self.Humanoid.HipHeight = self.DefaultHipHeight
		self.Humanoid.WalkSpeed = self.DefaultWalkSpeed
	end
	self.Running = true
	self.Humanoid.WalkSpeed = self.SprintSpeed
	if self.Humanoid.MoveDirection.Magnitude > 0 and not self.Airborne then
		if self.UseRunWalkTransitions then
			self:startTransition("ToRun", self.RunAnimSpeed, 1)
		else
			self:play("Run")
		end
	end
end

function DirectionalMovement:endRun()
	if self.Running then
		self.Running = false
		self.Humanoid.WalkSpeed = self.DefaultWalkSpeed
		if self.Humanoid.MoveDirection.Magnitude > 0 then
			self:play("RunStop")
			if self.UseRunWalkTransitions then
				self:startTransition("ToWalk", self.WalkAnimSpeed, 1)
			else
				self:play("Walk")
			end
		end
	end
end

function DirectionalMovement:toggleCrouch()
	self.Crouching = not self.Crouching
	if self.Crouching then
		self.Running = false
		self.Humanoid.WalkSpeed = self.CrouchSpeed
		self.Humanoid.HipHeight = self.CroughHeight
		if not self.Airborne then
			self:play("Crouch")
		end
	else
		self.Humanoid.WalkSpeed = self.DefaultWalkSpeed
		self.Humanoid.HipHeight = self.DefaultHipHeight
		if not self.Airborne then
			self:play("Idle")
		end
	end
end

function DirectionalMovement:onStateChanged(newState: Enum.HumanoidStateType)
	local wasClimbing = self.Climbing

	if newState == Enum.HumanoidStateType.Climbing then
		self.Airborne = false
		self.Climbing = true
		self:play("Climb")
		return
	end

	if wasClimbing and newState ~= Enum.HumanoidStateType.Climbing then
		self.Climbing = false
		self:stopAirborneTracks()
	end

	if newState == Enum.HumanoidStateType.Jumping then
		self.Airborne = true
		self:play("Jump")
	elseif newState == Enum.HumanoidStateType.Freefall then
		self.Airborne = true
		self:play("Fall")
	elseif newState == Enum.HumanoidStateType.Landed then
		self.Airborne = false
		self:stopAirborneTracks()

		local referenceCFrame = self:getReferenceCFrame()
		local moveDirection = self.Humanoid.MoveDirection
		local direction = referenceCFrame and classifyDirection(referenceCFrame, moveDirection) or nil

		if self.Crouching then
			self:setTrackWeights({ Crouch = 1 }, 0.1)
		elseif moveDirection.Magnitude > 0 and direction then
			self:applyDirectionalBlend(direction, self.Running)
		else
			self:setTrackWeights({ Idle = 1 }, 0.1)
		end

		self:startTransition("Land", self:getTrackSpeed("Land"), 0.65, 0.08)
	end
end

function DirectionalMovement:handleMovementDirection(direction: Vector2?, magnitude: number)
	if magnitude < 0.05 then
		if self.TransitionName == "Land" then
			if self.Crouching then
				self:setTrackWeights({ CrouchIdle = 1 }, 0.08)
			else
				self:setTrackWeights({ Idle = 1 }, 0.08)
			end
			self.LastDirection = nil
			return
		end

		if self.Crouching then
			self:setTrackWeights({ CrouchIdle = 1 }, 0.1)
		elseif self.LastDirection then
			if self.IsHurt then
				self:setTrackWeights({ Idle = 1 }, 0.1)
			elseif self.Running and self.UseEndAnimations then
				self:play("RunStop")
			elseif self.UseEndAnimations and self.LastDirection == "Forward" then
				self:play("WalkEnd")
			elseif self.UseEndAnimations and self.LastDirection == "Back" then
				self:play("BackWalkEnd")
			elseif self.UseEndAnimations and self.LastDirection == "Left" then
				self:play("LeftWalkEnd")
			elseif self.UseEndAnimations and self.LastDirection == "Right" then
				self:play("RightWalkEnd")
			else
				self:setTrackWeights({ Idle = 1 }, 0.1)
			end
		else
			self:setTrackWeights({ Idle = 1 }, 0.1)
		end
		self.LastDirection = nil
		return
	end

	if self.Crouching then
		self:setTrackWeights({ Crouch = 1 }, 0.1)
		return
	end

	if not direction then
		self:setTrackWeights({ Idle = 1 }, 0.1)
		return
	end

	self:applyDirectionalBlend(direction, self.Running)
end

function DirectionalMovement:updateStamina(deltaTime: number)
	local drain = 0
	local regen = 0

	if self.Running and self.Humanoid.MoveDirection.Magnitude > 0 then
		drain = self.StaminaDrainRate * deltaTime
	else
		regen = self.StaminaRegenRate * deltaTime
	end

	self.CurrentStamina = math.clamp(self.CurrentStamina - drain + regen, 0, self.MaxStamina)
	if self.CurrentStaminaValue then
		self.CurrentStaminaValue.Value = self.CurrentStamina
	end

	if self.CurrentStamina <= 0 and self.Running then
		self:endRun()
	end
end

function DirectionalMovement:updateMovement(deltaTime: number)
	self:updateStamina(deltaTime)
	self:updateHurtState()

	if self.Hiding or self.Airborne or self.Climbing then
		return
	end

	if self.HoldAnimationUntil and self.HoldAnimationUntil > os.clock() then
		if self.Humanoid.MoveDirection.Magnitude < 0.05 then
			return
		end
		self.HoldAnimationUntil = 0
	end

	local moveDirection = self.Humanoid.MoveDirection
	local referenceCFrame = self:getReferenceCFrame()

	if not referenceCFrame then
		return
	end

	local direction = classifyDirection(referenceCFrame, moveDirection)
	self:handleMovementDirection(direction, moveDirection.Magnitude)
end

function DirectionalMovement:Destroy()
	if self.MovementConnection then
		self.MovementConnection:Disconnect()
	end

	if self.StateConnection then
		self.StateConnection:Disconnect()
	end
	if self.HealthConnection then
		self.HealthConnection:Disconnect()
	end
	if self.HidePromptConnection then
		self.HidePromptConnection:Disconnect()
	end
	if self.HideFreezeConnection then
		self.HideFreezeConnection:Disconnect()
	end
	if self.HideStopConnection then
		self.HideStopConnection:Disconnect()
	end

	ContextActionService:UnbindAction(ACTION_RUN)
	ContextActionService:UnbindAction(ACTION_CROUCH)

	for _, track in pairs(self.Tracks) do
		if track.IsPlaying then
			track:Stop(0.1)
		end
		track:Destroy()
	end

	if self.HideTrack then
		self.HideTrack:Stop(0.1)
		self.HideTrack:Destroy()
		self.HideTrack = nil
	end
end

return DirectionalMovement
