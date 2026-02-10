local MobileControls = {}
MobileControls.__index = MobileControls

local function connectButtonPress(button: GuiButton, onDown, onUp)
	local conns = {}

	if button.Activated then
		conns[#conns + 1] = button.Activated:Connect(function()
			onDown()
		end)
	end

	if button.InputBegan then
		conns[#conns + 1] = button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				onDown()
			end
		end)
	end

	if button.InputEnded and onUp then
		conns[#conns + 1] = button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
				onUp()
			end
		end)
	end

	return conns
end

function MobileControls.new(controller, buttons, options)
	local self = setmetatable({
		Controller = controller,
		Connections = {},
	}, MobileControls)

	local runToggle = options and options.RunToggle
	if runToggle == nil and controller then
		runToggle = controller.RunToggle
	end
	if runToggle == nil then
		runToggle = false
	end

	if buttons.RunButton then
		local runConns
		if runToggle then
			runConns = connectButtonPress(buttons.RunButton, function()
				if controller.Running then
					controller:endRun()
				else
					controller:beginRun()
				end
			end)
		else
			runConns = connectButtonPress(buttons.RunButton, function()
				controller:beginRun()
			end, function()
				controller:endRun()
			end)
		end
		for _, c in ipairs(runConns) do
			self.Connections[#self.Connections + 1] = c
		end
	end

	if buttons.CrouchButton then
		local crouchConns = connectButtonPress(buttons.CrouchButton, function()
			controller:toggleCrouch()
		end)
		for _, c in ipairs(crouchConns) do
			self.Connections[#self.Connections + 1] = c
		end
	end

	if buttons.JumpButton then
		local jumpConns = connectButtonPress(buttons.JumpButton, function()
			controller.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end)
		for _, c in ipairs(jumpConns) do
			self.Connections[#self.Connections + 1] = c
		end
	end

	return self
end

function MobileControls:Destroy()
	for _, conn in ipairs(self.Connections) do
		conn:Disconnect()
	end
	self.Connections = {}
end

return MobileControls
