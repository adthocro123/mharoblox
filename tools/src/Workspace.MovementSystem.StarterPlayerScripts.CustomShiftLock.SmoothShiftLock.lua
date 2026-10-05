local SmoothShiftLock = {}
SmoothShiftLock.__index = SmoothShiftLock;

-- [[ Variables ]]:

--// Services and requires
local Players = game:GetService("Players");
local WorkspaceService = game:GetService("Workspace");
local RunService = game:GetService("RunService");
local UserInputService = game:GetService("UserInputService");
local TweenService = game:GetService("TweenService");
local Maid = require(script.Utils:WaitForChild("Maid"));
local Spring = require(script.Utils:WaitForChild("Spring"));

--// Instances
local LocalPlayer = Players.LocalPlayer;

--// Bindables
local ToggleEvent = script:WaitForChild("ToggleShiftLock");
local EditConfig = script:WaitForChild("EditConfig");

--// Configuration
local config = {
	["CHARACTER_SMOOTH_ROTATION"]   = false,                      --// If your character should rotate smoothly or not (patched for this game, round 65: off - the body turns with the camera the same frame, like JJS; Config.Look.InstantShiftLock)
	["MANUALLY_TOGGLEABLE"]         = true,                       --// If the shift lock an be toggled manually by player
	["CHARACTER_ROTATION_SPEED"]    = 3,                          --// How quickly character rotates smoothly
	["TRANSITION_SPRING_DAMPER"]    = 0.7,                        --// Camera transition spring damper, test it out to see what works for you
	["CAMERA_TRANSITION_IN_SPEED"]  = 10,                         --// How quickly locked camera moves to offset position
	["CAMERA_TRANSITION_OUT_SPEED"] = 14,                         --// How quickly locked camera moves back from offset position
	["LOCKED_CAMERA_OFFSET"]        = Vector3.new(1.75, 0.25, 0), --// Locked camera offset
	--["LOCKED_CAMERA_OFFSET"]        = Vector3.new(1.75, 0.25, 0), --// Locked camera offset
	["LOCKED_MOUSE_ICON"]           =                             --// Locked mouse icon
		"http://www.roblox.com/asset/?id=11783958279",
	["SHIFT_LOCK_KEYBINDS"]         =                             --// Shift lock keybinds
		{Enum.KeyCode.LeftShift, Enum.KeyCode.DPadDown} -- (patched: Left Ctrl is Sprint in this game; D-pad down like JJS)
}

local ENABLED = false;
local current = nil; --// (patched for this game) the one live per-character instance
local wanted = false; --// (patched for this game) on / off as the player last set it: kept through a respawn or a body swap, like Roblox's own shift lock

--// Setup
local maid = Maid.new();

--// (patched for this game) a controller: the last input came off a gamepad
local function usingGamepad()
	local last = UserInputService:GetLastInputType();
	return last ~= nil and string.sub(last.Name, 1, 7) == "Gamepad";
end;

--// (patched for this game) a controller has no mouse cursor to show where
--// the middle of the screen is - and the camera sits over his shoulder, so
--// the body isn't there either. Moves go where the middle of the screen
--// points: a small reticle marks it while the lock is on.
local reticle = nil;
local function showReticle(on)
	if on and not reticle then
		local playerGui = LocalPlayer:FindFirstChildOfClass("PlayerGui");
		if not playerGui then return end;
		reticle = Instance.new("ScreenGui");
		reticle.Name = "ShiftLockReticle";
		reticle.IgnoreGuiInset = true;
		reticle.ResetOnSpawn = false;
		reticle.DisplayOrder = 4;
		local ring = Instance.new("Frame");
		ring.Name = "Ring";
		ring.AnchorPoint = Vector2.new(0.5, 0.5);
		ring.Position = UDim2.fromScale(0.5, 0.5);
		ring.Size = UDim2.fromOffset(20, 20);
		ring.BackgroundTransparency = 1;
		ring.Parent = reticle;
		local ringCorner = Instance.new("UICorner");
		ringCorner.CornerRadius = UDim.new(0.5, 0);
		ringCorner.Parent = ring;
		local ringStroke = Instance.new("UIStroke");
		ringStroke.Color = Color3.new(1, 1, 1);
		ringStroke.Thickness = 1.5;
		ringStroke.Transparency = 0.35;
		ringStroke.Parent = ring;
		local dot = Instance.new("Frame");
		dot.Name = "Dot";
		dot.AnchorPoint = Vector2.new(0.5, 0.5);
		dot.Position = UDim2.fromScale(0.5, 0.5);
		dot.Size = UDim2.fromOffset(5, 5);
		dot.BackgroundColor3 = Color3.new(1, 1, 1);
		dot.BorderSizePixel = 0;
		dot.Parent = reticle;
		local dotCorner = Instance.new("UICorner");
		dotCorner.CornerRadius = UDim.new(0.5, 0);
		dotCorner.Parent = dot;
		local dotStroke = Instance.new("UIStroke");
		dotStroke.Thickness = 1;
		dotStroke.Transparency = 0.4;
		dotStroke.Parent = dot;
		reticle.Parent = playerGui;
	end;
	if reticle then
		reticle.Enabled = on;
	end;
end;

--// (patched for this game) the locked mouse icon is drawn in the middle of
--// the screen even when the last input was a pad - two dots with the
--// reticle. On a pad the reticle is the only marker: the icon hides.
local iconHidden = false;
local function hideMouseIcon(hide)
	if hide == iconHidden then return end;
	iconHidden = hide;
	UserInputService.MouseIconEnabled = not hide;
end;

-- [[ Functions ]]:

--// Setup smooth shift lock on client (Run once and on a LocalScript)
function SmoothShiftLock:Init()
	local managerMaid = Maid.new();

	managerMaid:GiveTask(LocalPlayer.CharacterAdded:Connect(function()
		self:CharacterAdded();
	end));
end;

--// Character added event function
function SmoothShiftLock:CharacterAdded()
	--// (patched for this game) a body can be swapped without dying or a
	--// CharacterRemoving (R15 -> R6): retire the old instance, or both answer
	--// one key press and the two toggles cancel out
	if current then
		current:CharacterDiedOrRemoved();
	end;
	local self = setmetatable({}, SmoothShiftLock);
	current = self;
	--// Instances
	self.Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait();
	self.RootPart = self.Character:WaitForChild("HumanoidRootPart");
	self.Humanoid = self.Character:WaitForChild("Humanoid");
	self.Head = self.Character:WaitForChild("Head");
	--// Other
	self.Camera = WorkspaceService.CurrentCamera;
	--// Setup
	self.connectionsMaid = Maid.new();
	self.camOffsetSpring = Spring.new(Vector3.new(0, 0, 0));
	self.camOffsetSpring.Damper = config.TRANSITION_SPRING_DAMPER;
	
	--// Bind keybinds
	self.connectionsMaid:GiveTask(UserInputService.InputBegan:Connect(function(input, gpe)
		if not config.MANUALLY_TOGGLEABLE then return end;
		--// (patched for this game) Shift can come in already "processed" (a
		--// ContextActionService bind on it), so only typing in a text box or
		--// a gamepad driving a menu blocks the toggle
		if UserInputService:GetFocusedTextBox() then return end;
		if (gpe) and input.UserInputType ~= Enum.UserInputType.Keyboard then return end;
		if LocalPlayer.Character ~= self.Character then return end;

		for _, keyBind in pairs(config.SHIFT_LOCK_KEYBINDS) do
			if (input.KeyCode == keyBind) and (self.Humanoid and self.Humanoid.Health ~= 0) then
				self:ToggleShiftLock(not ENABLED);
			end;
		end;
	end));

	--// Update camera offset
	self.connectionsMaid:GiveTask(RunService.RenderStepped:Connect(function()
		if self.Head.LocalTransparencyModifier > 0.6 then return end;
		
		local camCF = self.Camera.CFrame; 
		local distance = (self.Head.Position - camCF.Position).magnitude;

		--// Camera offset
		if (distance > 1) then	
			self.Camera.CFrame = (self.Camera.CFrame * CFrame.new(self.camOffsetSpring.Position)); 
			local pad = ENABLED and usingGamepad();
			showReticle(pad); --// (patched) where moves go, on a controller
			hideMouseIcon(pad); --// (patched) ...and only that one marker
			
			if (ENABLED) and (UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter) then
				self:SetMouseState(ENABLED);
			end;
		end;
	end));
	
	--// Bindables
	self.connectionsMaid:GiveTask(ToggleEvent.Event:Connect(function(toggle: boolean)
		if (self.Humanoid and self.Humanoid.Health ~= 0) then
			self:ToggleShiftLock(toggle);
		end;
	end));
	
	self.connectionsMaid:GiveTask(EditConfig.Event:Connect(function(toChange, value)
		if config[toChange] ~= nil then
			config[toChange] = value;
		end;
	end));
	
	--// On death
	self.connectionsMaid:GiveTask(self.Humanoid.Died:Connect(function()
		self:CharacterDiedOrRemoved();
		return;
	end));
	
	--// On character removing
	self.connectionsMaid:GiveTask(LocalPlayer.CharacterRemoving:Connect(function(removed)
		if removed ~= self.Character then return end; --// (patched) not ours
		self:CharacterDiedOrRemoved();
		return;
	end));

	--// (patched for this game) it was on: the new body has it on too
	if wanted and self.Humanoid.Health > 0 then
		self:ToggleShiftLock(true, true);
	end;

	return self;
end;

--// (patched for this game) a body can arrive without a CharacterAdded (the
--// server's R15 -> R6 swap isn't always announced), and then the old body's
--// removal retires the lock with nothing to take over: Shift did nothing
--// until you died. Bind to whatever living body the player has now - the
--// game calls this twice a second (cheap when nothing changed).
function SmoothShiftLock:Ensure()
	local char = LocalPlayer.Character;
	local hum = char and char:FindFirstChildOfClass("Humanoid");
	if hum and hum.Health > 0 and (current == nil or current.Character ~= char) then
		task.spawn(function()
			SmoothShiftLock:CharacterAdded();
		end);
	end;
end;

--// Stop shiftlock upon character death or removal
function SmoothShiftLock:CharacterDiedOrRemoved()
	if current == self then
		current = nil;
	end;
	self:ToggleShiftLock(false, true); --// (patched) off while dead, but remembered
	showReticle(false);
	hideMouseIcon(false);
	
	if self.connectionsMaid ~= nil then
		self.connectionsMaid:Destroy();
		self.connectionsMaid = nil;
	end;
	
	maid:DoCleaning();
end;

--// Return shiftlock enabled state
function SmoothShiftLock:IsEnabled(): boolean
	return ENABLED;
end;

--// Set Enum.MouseBehavior to LockCenter or Default depending on shiftlock enabled
function SmoothShiftLock:SetMouseState(enable : boolean)
	UserInputService.MouseBehavior = (enable and Enum.MouseBehavior.LockCenter) or (Enum.MouseBehavior.Default);
end;

--// Change mouse icon depending on shiftlock enabled
function SmoothShiftLock:SetMouseIcon(enable : boolean)
	UserInputService.MouseIcon = (enable and config.LOCKED_MOUSE_ICON :: string) or "";
end;

--// Tween locked camera offset position
function SmoothShiftLock:TransitionLockOffset(enable : boolean)
	if (enable) then
		self.camOffsetSpring.Speed = config.CAMERA_TRANSITION_IN_SPEED;
		self.camOffsetSpring.Target = config.LOCKED_CAMERA_OFFSET;
	else
		self.camOffsetSpring.Speed = config.CAMERA_TRANSITION_OUT_SPEED;
		self.camOffsetSpring.Target = Vector3.new(0, 0, 0);
	end;
end;

--// Toggle shift lock
--// (patched for this game) keepWanted: a switch the player didn't ask for
--// (dying, a body swap) - what they chose is kept for the next body
function SmoothShiftLock:ToggleShiftLock(enable : boolean, keepWanted : boolean?)
	assert(typeof(enable) == typeof(false), "Enable value is not a boolean.");
	ENABLED = enable;
	if not keepWanted then
		wanted = enable;
	end;

	self:SetMouseState(ENABLED);
	self:SetMouseIcon(ENABLED);
	self:TransitionLockOffset(ENABLED);
	if not ENABLED then
		showReticle(false);
		hideMouseIcon(false);
	end;
	
	--// Start
	maid:DoCleaning(); --// (patched) never two rotation loops at once
	--// (patched for this game) switching it off hands turning back to the
	--// Humanoid right away (the loop that used to do it on its last frame
	--// is gone by now)
	if not ENABLED and self.Humanoid and self.Humanoid.Parent then
		self.Humanoid.AutoRotate = true;
	end;
	if (ENABLED) then
		maid:GiveTask(RunService.RenderStepped:Connect(function(delta)
			if (self.Humanoid and self.RootPart) then 
				self.Humanoid.AutoRotate = not ENABLED;
			end;
			
			--// Rotate character
			--// (patched for this game) parkour moves the body itself
			--// (and a move that holds the body itself - BodyLocked: Bakugo's blitz
			--// flies him flat out, then hangs him upside down)
			--// (patched, round 86) nor a dev in flight: his body lies along where he flies (DevFlyLocal: his own machine's, at once)
			if (ENABLED) and not self.Character:GetAttribute("Stunned") and not self.Character:GetAttribute("Parkour")
				and not self.Character:GetAttribute("BodyLocked") and not self.Character:GetAttribute("DevFlyLocal") then
				--// (patched for this game) a controller turns the camera with a stick, on
				--// and on: easing the body after it left him always a few degrees
				--// behind where he was looking. On a controller he turns with it.
				if not (self.Humanoid.Sit) and (config.CHARACTER_SMOOTH_ROTATION) and not usingGamepad() then
					local x, y, z = self.Camera.CFrame:ToOrientation();
					self.RootPart.CFrame = self.RootPart.CFrame:Lerp(CFrame.new(self.RootPart.Position) * CFrame.Angles(0, y, 0), delta * 5 * config.CHARACTER_ROTATION_SPEED);
				elseif not (self.Humanoid.Sit) then
					local x, y, z = self.Camera.CFrame:ToOrientation();
					self.RootPart.CFrame = CFrame.new(self.RootPart.Position) * CFrame.Angles(0, y, 0);
				end;
			end;
			
			--// Stop
			if not (ENABLED) then 
				maid:Destroy() end;
		end));
	end;
	
	return self;
end;

return SmoothShiftLock;