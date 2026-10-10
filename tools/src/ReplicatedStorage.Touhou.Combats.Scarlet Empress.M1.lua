local Debris = game:GetService("Debris")
local ResourceFolder = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat
local Packages = game.ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local Module = require(game.ReplicatedStorage.Modules.Util.RockScript)
local Basemd = require(game.ReplicatedStorage.Modules.Util.baseassets)

local function RayCastOnMap(origin,direction,returnAll)
	local raycastSettings = RaycastParams.new()
	raycastSettings.FilterDescendantsInstances = {workspace.Ignore}
	raycastSettings.FilterType = Enum.RaycastFilterType.Blacklist
	local ray = workspace:Raycast(origin, direction, raycastSettings)

	if returnAll then return ray end
	if ray then
		return ray.Position
	else
		return origin
	end
end
local function emitsum152(instance,modelclone,cframe)
	coroutine.resume(coroutine.create(function()
		local modelclone25 = instance:Clone()
		modelclone25.Parent = workspace.Ignore.Effects
		game.Debris:AddItem(modelclone25,8)
		modelclone25.CFrame = cframe.CFrame * instance.CFrame
		modelclone25.Anchored = false
		local Weld = Instance.new("WeldConstraint")
		Weld.Part0 = modelclone25
		Weld.Part1 = cframe
		Weld.Name = instance.Name
		Weld.Parent = cframe	
		if modelclone25.Name == ("GroundSlash2") then
			local floorInstance = RayCastOnMap(modelclone25.Position,Vector3.new(0,-8,0),true)
			if floorInstance then
				modelclone25.Position = floorInstance.Position + Vector3.new(0,0.5,0)
				for i,v in pairs(modelclone25:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
		else
			for i,v in pairs(modelclone25:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
	end))
end
local function miserablefate(startpart,endpart,addtill)
	local beam1 = ResourceFolder.remremakemisfate.Beam1.Beam1:Clone()
	beam1.Parent = startpart
	local beam2 = ResourceFolder.remremakemisfate.Beam2.Beam2:Clone()
	beam2.Parent = endpart
	for i,v in pairs(beam1:GetChildren()) do
		if v:IsA("Beam") then
			v.Attachment0 = beam1
			v.Attachment1 = beam2
			local originalwidth0 = v.Width0
			local originalwidth1 = v.Width1
			v.Width0 = 0
			v.Width1 = 0
			v.Enabled = true
			game:GetService("TweenService"):Create(v,TweenInfo.new(.1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Width0 = originalwidth0}):Play()
			game:GetService("TweenService"):Create(v,TweenInfo.new(.1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Width1 = originalwidth1}):Play()
		end
	end
	for i,v in pairs(beam2:GetChildren()) do
		if v:IsA("ParticleEmitter") then
			v:Emit(v:GetAttribute("EmitCount") or 1)
		end
	end
	task.delay(addtill or 10/60,function()
		game.Debris:AddItem(beam2,.5)
		game.Debris:AddItem(beam1,.5)
		for i,v in pairs(beam1:GetChildren()) do
			if v:IsA('Beam') then
				game:GetService("TweenService"):Create(v,TweenInfo.new(.1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Width0 = 0}):Play()
				game:GetService("TweenService"):Create(v,TweenInfo.new(.1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Width1 = 0}):Play()
			end
		end
	end)
end
local function emitsum(instance,modelclone,cframe,Character)
	coroutine.resume(coroutine.create(function()
		local modelclone25 = instance:Clone()
		modelclone25.Parent = workspace.Ignore.Effects
		game.Debris:AddItem(modelclone25,8)
		modelclone25.CFrame = cframe * instance.CFrame
		if modelclone25.Name == ("GroundSlash2") then
			local floorInstance = RayCastOnMap(modelclone25.Position,Vector3.new(0,-8,0),true)
			if floorInstance then
				modelclone25.Position = floorInstance.Position + Vector3.new(0,0.5,0)
				for i,v in pairs(modelclone25:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if Character then
							if Character["Right Arm"]:FindFirstChild("remiliaspear") then
								if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
									v.Color = ColorSequence.new{
										ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 2555))
									}
								end
							end
						end
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
		else
			for i,v in pairs(modelclone25:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if Character then
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
					end
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
	end))
end
local function emitsum25(instance)
	coroutine.resume(coroutine.create(function()
		for i,v in pairs(instance:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
					v:Emit((v:GetAttribute('EmitCount') or 1)/6)
				else
					v:Emit((v:GetAttribute('EmitCount')) or 1)
				end
			end
		end
	end))
end
local numberofrocksrubbleslam = math.random(3,4)
local dashLimbs = game.ReplicatedStorage.Assets.VFX:WaitForChild("dash_limbs")
local dashSmoke = game.ReplicatedStorage.Assets.VFX:WaitForChild("dash_smoke")
local function calculateClosestPartSide(target, dest)
	local targetPos = target.Position
	local destPos = dest.Position
	local destSize = dest.Size

	local positions = {
		Vector3.new(destPos.X + (destSize.X / 2), destPos.Y, destPos.Z),
		Vector3.new(destPos.X - (destSize.X / 2), destPos.Y, destPos.Z),
		Vector3.new(destPos.X, destPos.Y + (destSize.Y / 2), destPos.Z),
		Vector3.new(destPos.X, destPos.Y - (destSize.Y / 2), destPos.Z),
		Vector3.new(destPos.X, destPos.Y, destPos.Z + (destSize.Z / 2)),
		Vector3.new(destPos.X, destPos.Y, destPos.Z - (destSize.Z / 2))
	}

	local closestPos = positions[1]
	local smallestMagnitude = math.abs((positions[1] - targetPos).Magnitude)

	for _,pos in positions do
		local currentMagnitude = math.abs((pos - targetPos).Magnitude)
		if (currentMagnitude < smallestMagnitude) then
			closestPos = pos
			smallestMagnitude = currentMagnitude
		end
	end

	if closestPos == nil then
		warn("nil position")
	end

	return {closestPos, smallestMagnitude}
end
local fullfiendmodedelay = 53/60
local dashtime2 = 110/60
local CameraShaker=require(game.ReplicatedStorage.Modules.Util.shaker)
local Camera = workspace.CurrentCamera
local mathrandomlimb = {
	[1] = "Torso",
	[2] = "Head",
	[3] = "Right Arm",
	[4] = "Left Arm",
	[5] = "Right Leg",
	[6] = "Left Leg",
}
function CreateTween(val1, val2, val3, val4)
	local hmmm = game:GetService("TweenService"):Create(val1, TweenInfo.new(unpack(val2)), val3);
	if val4 then
		hmmm:Play();
	end;
	return hmmm;
end;


local function redvignette2()
	local vignet = game.ReplicatedStorage.Assets.Vignette:Clone()
	vignet.ImageLabel.ImageColor3 = Color3.fromRGB(255,10,10)
	vignet.Parent = game.Players.LocalPlayer.PlayerGui
	game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(4/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = .85}):Play()
	task.delay(5/60,function()
		game.Debris:AddItem(vignet,5/60)
		game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(5/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = 1}):Play()
	end)
end

local function redvignette()
	local vignet = game.ReplicatedStorage.Assets.Vignette:Clone()
	vignet.ImageLabel.ImageColor3 = Color3.fromRGB(255,10,10)
	vignet.Parent = game.Players.LocalPlayer.PlayerGui
	game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(8/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = .7}):Play()
	task.delay(8/60,function()
		game.Debris:AddItem(vignet,15/60)
		game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(15/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = 1}):Play()
	end)
end
return {
	["HEARTBREAKHIT"] = function(Character,Enemy)
		local RedFX=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.HitHeartBreak:Clone()	
		local sound1 = RedFX.VFX["h"..math.random(1,5)]:Clone()
		sound1.Parent=Enemy[mathrandomlimb[math.random(1,6)]]
		sound1:Play()
		game.Debris:AddItem(sound1,3)

		local sound2 = RedFX.VFX["b"..math.random(1,4)]:Clone()
		sound2.Parent=Enemy[mathrandomlimb[math.random(1,6)]]
		game.Debris:AddItem(sound2,3)
		sound2:Play()
		RedFX.VFX.bloodhit:Play()
		RedFX.CFrame = Enemy.HumanoidRootPart.CFrame
		game.Debris:AddItem(RedFX,1.6)
		RedFX.Parent= workspace.Ignore.Effects
		for i,v in pairs(RedFX:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
					v:Emit((v:GetAttribute('EmitCount') or 1)/6)
				else
					v:Emit((v:GetAttribute('EmitCount')) or 1)
				end
			end
		end
	end,
	["CLOTHAWAKENING2"] = function(Character)
		local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.ClothAwakening2:Clone()
		RedFX2425.Parent = Character.HumanoidRootPart
		game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
		RedFX2425:Play()
	end,
	["DEVOURCOLORCORRECTION"] = function(Character,toggle)
		--if toggle == true then
		--	game.Lighting.DevourColorCorrection.Enabled = toggle
		--	game:GetService("TweenService"):Create(game.Lighting.DevourColorCorrection, TweenInfo.new(.5, Enum.EasingStyle.Sine), {TintColor = Color3.fromRGB(255, 0, 0)}):Play()

		--elseif toggle == false then
		--	game:GetService("TweenService"):Create(game.Lighting.DevourColorCorrection, TweenInfo.new(.5, Enum.EasingStyle.Sine), {TintColor = Color3.fromRGB(255, 255, 255)}):Play()
		--	task.delay(.5,function()
		--		game.Lighting.DevourColorCorrection.Enabled = toggle
		--	end)
		--end
	end,
	["GUNGNIRSOUND"] = function(Character)
		task.delay(.02,function()
			local RedFX24215=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.gungnirsound:Clone()
			RedFX24215.Parent = Character.HumanoidRootPart
			game.Debris:AddItem(RedFX24215,3)
			RedFX24215:Play()
		end)
	end,
	["GUNGNIRSOUND2"] = function(Character)
			local RedFX24215=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.gungnirsound2:Clone()
			RedFX24215.Parent = Character.HumanoidRootPart
			game.Debris:AddItem(RedFX24215,3)
			RedFX24215:Play()
	end,
	["BOUNCETHRUSTVFX"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local function jump(number)
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].BOUNCETHRUSTVFX["Jump"..number]:Clone()
			RedFX15.Parent = Character.HumanoidRootPart
			game.Debris:AddItem(RedFX15,5)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		local function bounce()
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].BOUNCETHRUSTVFX.bouunce:Clone()
			RedFX15.Parent = Character.HumanoidRootPart
			game.Debris:AddItem(RedFX15,5)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		local function thrust()
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].BOUNCETHRUSTVFX.Thrust:Clone()
			RedFX15.Parent = Character.HumanoidRootPart
			game.Debris:AddItem(RedFX15,5)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.jumpsfx:Clone()
		RedFX2425.Parent = Character.Torso
		game.Debris:AddItem(RedFX2425,2)
		RedFX2425:Play()
		task.delay(25/60,function()
			jump(2)
			local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.madokajump:Clone()
			RedFX2425.Parent = Character.Torso
			game.Debris:AddItem(RedFX2425,2)
			RedFX2425:Play()
			local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.movesound:Clone()
			RedFX2425.Parent = Character.Torso
			game.Debris:AddItem(RedFX2425,2)
			RedFX2425:Play()
		end)
		task.delay(29/60,function()
			local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.bounce1:Clone()
			RedFX2425.Parent = Character.Torso
			game.Debris:AddItem(RedFX2425,2)
			RedFX2425:Play()
			local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.bounce2:Clone()
			RedFX2425.Parent = Character.Torso
			game.Debris:AddItem(RedFX2425,2)
			RedFX2425:Play()
			local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.bounce3:Clone()
			RedFX2425.Parent = Character.Torso
			game.Debris:AddItem(RedFX2425,2)
			RedFX2425:Play()
			bounce()
		end)
		task.delay(58/60,function()
			jump(2)
			jump(1)
		end)
		task.delay(63/60,function()
			thrust()
			local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.spear152:Clone()
			RedFX2425.Parent = Character.Torso
			game.Debris:AddItem(RedFX2425,2)
			RedFX2425:Play()
			Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir"..math.random(1,2)]:Play()
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
				Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
			end
			local highlight = script.Parent.Highlight:Clone()
			highlight.Parent = Character
			game:GetService("TweenService"):Create(highlight, TweenInfo.new(5/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 0}):Play()
			task.delay(5/60,function()
				game:GetService("TweenService"):Create(highlight, TweenInfo.new(15/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 1}):Play()
				game.Debris:AddItem(highlight,1)
			end)
			local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.BigThrust:Clone()
			RedFX2425.Parent = Character.Torso
			game.Debris:AddItem(RedFX2425,2)
			RedFX2425:Play()
		end)
	end,
	["REDVIGNETTE"] = function(Character)
		local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
			Camera.CFrame = Camera.CFrame * shakeCf
		end)
		camShake:ShakeOnce(2, 2, .5,.5)
		--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
		camShake:Start()
		redvignette()
	end,
	["MISERABLEMULTITUDEVELOCITY"] = function(Character,theenemy)
		--if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local hrp = Character.HumanoidRootPart
		local lv = Instance.new("LinearVelocity")
		lv.Name = "Dashing"
		lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		lv.MaxAxesForce = Vector3.new(14000,10000,14000)
		lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
		lv.Parent = hrp
		game:GetService("TweenService"):Create(lv, TweenInfo.new((44/60), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {VectorVelocity = Vector3.new(0,0,-60)}):Play()
		task.delay(53/60,function()
			redvignette()
		end)
		task.delay(142/60,function()
			redvignette()
		end)
		task.delay(219/60,function()
			redvignette()
		end)
		task.delay(268/60,function()
			redvignette()
		end)
		--task.delay(285/60,function()
		--	redvignette()
		--end)
		task.delay(44/60,function()
			game:GetService("TweenService"):Create(lv, TweenInfo.new(.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {VectorVelocity = Vector3.new(0,0,0)}):Play()
			game.Debris:AddItem(lv,.4)
		end)
		task.delay(105/60,function()
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(14000,0,14000)
			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			game:GetService("TweenService"):Create(lv, TweenInfo.new(.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {VectorVelocity = Vector3.new(0,0,-95)}):Play()

			task.delay((120-105)/60,function()
				game:GetService("TweenService"):Create(lv, TweenInfo.new(.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {VectorVelocity = Vector3.new(0,0,0)}):Play()
				game.Debris:AddItem(lv,.3)
			end)
		end)
		task.delay(136/60,function()
		end)
		task.delay(218/60,function()
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(14000,0,14000)
			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			game:GetService("TweenService"):Create(lv, TweenInfo.new(.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {VectorVelocity = Vector3.new(0,0,-50)}):Play()
			task.delay(.2,function()
				game:GetService("TweenService"):Create(lv, TweenInfo.new(.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {VectorVelocity = Vector3.new(0,0,0)}):Play()
				game.Debris:AddItem(lv,.2)
			end)
		end)
		task.delay(250/60,function()
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(14000,0,14000)
			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			lv.Name = ("SECONDDASHYT4T")
			game:GetService("TweenService"):Create(lv, TweenInfo.new(.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {VectorVelocity = Vector3.new(0,0,-50)}):Play()
--			task.delay(.7,function()
--				if lv ~= nil then
--				game:GetService("TweenService"):Create(lv, TweenInfo.new(.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {VectorVelocity = Vector3.new(0,0,0)}):Play()
--				game.Debris:AddItem(lv,.35)
--end
--			end)
		end)
		task.delay(228/60,function()
		end)
		task.delay(264/60,function()
		end)
		task.delay(290/60,function()
		end)
		task.delay(304/60,function()
			local vignet = game.ReplicatedStorage.Assets.Vignette:Clone()
			vignet.ImageLabel.ImageColor3 = Color3.fromRGB(0,0,0)
			vignet.Parent = game.Players.LocalPlayer.PlayerGui
			game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(8/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = .5}):Play()
			local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
				Camera.CFrame = Camera.CFrame * shakeCf
			end)
			camShake:ShakeSustain(CameraShaker.Presets.BatSwarm)
			camShake:Start()
			if hrp:FindFirstChild("SECONDDASHYT4T") then
				hrp:FindFirstChild("SECONDDASHYT4T"):Destroy()
			end
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(20000,0,20000)
			lv.Attachment0 = Character.HumanoidRootPart:FindFirstChild("RootAttachment")
			lv.Parent = Character.HumanoidRootPart
			local tween = game:GetService("TweenService"):Create(lv, TweenInfo.new(.1, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {VectorVelocity = Vector3.new(0,0,-80)})
			tween:Play()
			task.delay(.1,function()
				local tween = game:GetService("TweenService"):Create(lv, TweenInfo.new(2.5 + .15, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {VectorVelocity = Vector3.new(0,0,0)})
				tween:Play()
			end)
			task.delay((458-304)/60,function()
				camShake:Stop()
				lv:Destroy()
				game.Debris:AddItem(vignet,15/60)
				game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(15/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = 1}):Play()
			end)
		end)
	end,
	["SMALLVELOCITY2"] = function(Character)
		if not Character.Values:FindFirstChild("Stunned") then
			if Character.HumanoidRootPart:FindFirstChild("loalzoa5ew") then
				Character.HumanoidRootPart:FindFirstChild("loalzoa5ew"):Destroy()
			end
			local hrp = Character.HumanoidRootPart
			local lv = Instance.new("LinearVelocity")
			lv.Name = "loalzoa5ew"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(20000,0,20000)
			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			local delay1 = .1
			local delay1 = .2
			game:GetService("TweenService"):Create(lv, TweenInfo.new(delay1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {VectorVelocity = Vector3.new(0,0,-25)}):Play()
			task.delay(delay1,function()
				game:GetService("TweenService"):Create(lv, TweenInfo.new(delay1 , Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {VectorVelocity = Vector3.new(0,0,0)}):Play()
				game.Debris:AddItem(lv,delay1)
			end)
		end
	end,
	["M1TRAILCIRNORIGHT"] = function(Character)
		local FX2= game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.DashTrail2:Clone()
		FX2.Parent=Character
		FX2.w.Part0= Character['Right Arm']
		task.delay(.7,function()
			--if FX ~= nil then
			--	game.Debris:AddItem(FX,2)
			--	for i ,v in pairs(FX:GetDescendants())do
			--		if  v:IsA('Trail') then
			--			v.Enabled = false
			--		end
			--		if  v:IsA('ParticleEmitter') then
			--			v.Enabled = false
			--		end
			--	end
			--end
			if FX2 ~= nil then
				game.Debris:AddItem(FX2,1)
				for i ,v in pairs(FX2:GetDescendants())do
					if  v:IsA('Trail') then
						v.Enabled = false
					end
					if  v:IsA('ParticleEmitter') then
						v.Enabled = false
					end
					if v:IsA("PointLight") then
						game:GetService("TweenService"):Create(v, TweenInfo.new(.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Range = 0}):Play()
					end
				end
			end
		end)
	end,
	["M1TRAILCIRNOLEFT"] = function(Character)
		local FX2= game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.DashTrail2:Clone()
		FX2.Parent=Character
		FX2.w.Part0= Character['Left Arm']
		task.delay(.7,function()
			if FX2 ~= nil then
				game.Debris:AddItem(FX2,1)
				for i ,v in pairs(FX2:GetDescendants())do
					if  v:IsA('Trail') then
						v.Enabled = false
					end
					if  v:IsA('ParticleEmitter') then
						v.Enabled = false
					end
					if v:IsA("PointLight") then
						game:GetService("TweenService"):Create(v, TweenInfo.new(.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Range = 0}):Play()
					end
				end
			end
		end)
	end,
	['FOVCHANGE2'] = function(Character)
		local hrp = Character.HumanoidRootPart
		coroutine.resume(coroutine.create(function()
			local originalfov = 70
			local attacking = false
			local cancelled = false
			game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(25/60, Enum.EasingStyle.Linear, Enum.EasingDirection.In,0,false), {FieldOfView = originalfov/1.15}):Play()
			task.delay(30/60,function()
				if cancelled == false then
					attacking = true
					game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(10/60, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut,0,false), {FieldOfView = originalfov * 1.2}):Play()
				end
			end)

			local Hit = false

			local HitRay = false

			local Time = 0
			local function vineta()
				--redvignette2()
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(1.2, 1.2, .12,.12)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
			repeat
				local dt = .05
				if (attacking == true) and Character:FindFirstChild("HEARTBREAKCLOSEVARIANTHIT") then
					vineta()
				end
				wait(dt)
				Time += dt
			until
			not Character:FindFirstChild("HEARTBREAKCLOSEVARIANTHOLD") or Character.Values:FindFirstChild("Stunned")
			cancelled = true
			local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
				Camera.CFrame = Camera.CFrame * shakeCf
			end)
			camShake:ShakeOnce(4, 4, .4,.4)
			--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
			camShake:Start()
			game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(15/60, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut,0,false), {FieldOfView = originalfov}):Play()
		end))
	end,

	["SPAWNVFX"] = function(Character)
		local modelclone2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX
		--modelclone2.Parent = workspace.Ignore.Effects
		--game.Debris:AddItem(modelclone2,150/60)
		local cframe = Character.HumanoidRootPart.CFrame * CFrame.new(0,0,7)
		--modelclone2:SetPrimaryPartCFrame(cframe)
		--local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
		--local Directory2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
		local Directory = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local function emit(instance,weld,characterc)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = characterc.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = characterc.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = characterc.HumanoidRootPart	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(characterc.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = game.Workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame,Size = modelclone:FindFirstChild("End").Size}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,4)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if Character["Right Arm"]:FindFirstChild("remiliaspear") then
						if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
							v.Color = ColorSequence.new{
								ColorSequenceKeypoint.new(0, Character["Right Arm"]:FindFirstChild("remiliaspear").Color),
								ColorSequenceKeypoint.new(1, Character["Right Arm"]:FindFirstChild("remiliaspear").Color)
							}
						end
					end
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		local function vineta()
coroutine.resume(coroutine.create(function()
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 40 then
				redvignette()
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(5, 5, .4,.6)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
end))
		end
		emit(Directory.impact5REMI,false,Character)
		emit(Directory.impact5REMIVAMPIREton,false,Character)
		emitsum(modelclone2["Spawn 84"],modelclone2,cframe,Character)
		emitsum(modelclone2["SpawnHit 84"],modelclone2,cframe,Character)
		emitsum(modelclone2["Wind2 84"],modelclone2,cframe,Character)
		vineta()
	end,
	["SKILL1OLDVELOCITY"] = function(Character)
		local function slashfast(direction)
			if Character.HumanoidRootPart:FindFirstChild("loalzoaew") then
				Character.HumanoidRootPart:FindFirstChild("loalzoaew"):Destroy()
			end
			Character.HumanoidRootPart.Velocity = Vector3.new(0,0,0)
			local velocity = Instance.new('BodyVelocity')
			velocity.MaxForce = Vector3.new(15000,0,15000)
			velocity.Velocity = Character.HumanoidRootPart.CFrame.LookVector * 25
			velocity.Parent = Character.HumanoidRootPart
			game.Debris:AddItem(velocity,.25)
			velocity.Name = ("loalzoaew")
		end
		task.delay((137/60),function()
			slashfast("Right")
		end)
		task.delay((164/60),function()
			slashfast("Right")
		end)
		task.delay((194/60),function()
			slashfast("Right")
		end)
		task.delay((223/60),function()
			slashfast("Right")
		end)
		task.delay((254/60),function()
			slashfast("Right")
		end)
		task.delay((284/60),function()
			slashfast("Right")
		end)

		task.delay((156/60),function()
			slashfast("Left")
		end)
		task.delay((178/60),function()
			slashfast("Left")
		end)
		task.delay((209/60),function()
			slashfast("Left")
		end)
		task.delay((239/60),function()
			slashfast("Left")
		end)
		task.delay((269/60),function()
			slashfast("Left")
		end)
		task.delay((299/60),function()
			slashfast("Left")
		end)
	end,
	["SKILL1OLDVFX"] = function(Character)
		local function vortex()
			for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Attachm122ent:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		local function slashfast(direction)
			local lolslash = ResourceFolder.Parent.StabBarrage[direction]:Clone()
			lolslash.Parent = game.Workspace.Ignore.Effects
			lolslash.CFrame = Character.HumanoidRootPart.CFrame
			lolslash.sfx1:Play()
			lolslash["bat"..math.random(1,3)]:Play()
			for i,v in pairs(lolslash:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute("EmitCount") or 1)
				end
			end
			game.Debris:AddItem(lolslash,4)
			for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Attachm122ent:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		task.delay((137/60),function()
			slashfast("Right")
		end)
		task.delay((164/60),function()
			slashfast("Right")
		end)
		task.delay((194/60),function()
			slashfast("Right")
		end)
		task.delay((223/60),function()
			slashfast("Right")
		end)
		task.delay((254/60),function()
			slashfast("Right")
		end)
		task.delay((284/60),function()
			slashfast("Right")
		end)

		task.delay((156/60),function()
			slashfast("Left")
		end)
		task.delay((178/60),function()
			slashfast("Left")
		end)
		task.delay((209/60),function()
			slashfast("Left")
		end)
		task.delay((239/60),function()
			slashfast("Left")
		end)
		task.delay((269/60),function()
			slashfast("Left")
		end)
		task.delay((299/60),function()
			slashfast("Left")
		end)
		task.delay(135/60,function()
			vortex()
		end)
		task.delay(150/60,function()
			vortex()
		end)
		task.delay(170/60,function()
			vortex()
		end)
		task.delay(190/60,function()
			vortex()
		end)
		task.delay(210/60,function()
			vortex()
		end)
		task.delay(225/60,function()
			vortex()
		end)
		task.delay(245/60,function()
			vortex()
		end)
		task.delay(260/60,function()
			vortex()
		end)
		task.delay(275/60,function()
			vortex()
		end)
		task.delay(295/60,function()
			vortex()
		end)
		task.delay((7/60),function()
			local a = ResourceFolder.Parent.AWAKENVFX.avampirek:Clone()
			a.Parent = workspace.Ignore.Effects
			a.CFrame = Character["Left Arm"].CFrame * CFrame.new(0,-1,0)
			local enabled = true
			for i,v in pairs(a:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						while enabled == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							v:Emit(1)
						end
					end
				end))
			end
			coroutine.resume(coroutine.create(function()
				while enabled == true do
					if a ~= nil then
						a.CFrame = Character["Left Arm"].CFrame * CFrame.new(0,-1.4,0)
					else
						break
					end
					wait()
				end
			end))
			task.delay((49/60) - (7/60),function()
				enabled = false
				game.Debris:AddItem(a,1.5)
			end)
		end)
		task.delay(347/60,function()
			local RootCF = Character.HumanoidRootPart.CFrame * CFrame.new(0,-3.8,-7)
			coroutine.resume(coroutine.create(function()
				--for i = 1,4 do
				coroutine.resume(coroutine.create(function()
					for i = 1,10 do
						Basemd.SmashTile(RootCF * CFrame.new(math.random(-5,5),0,math.random(-5,5)))
						Basemd.SmashTrees(RootCF * CFrame.new(math.random(-5,5),0,math.random(-5,5)))
						--task.wait(.1)
					end
				end))
				local AppearTime = .17
				local Tilt = 25
				local Distance = 9
				local CollectAfter = 4.5
				local CollectLength = 7
				local HeightOffset = -2
				local HowMuchDown = -5 --how below the ground it is when it appears
				local HowMuchDownCollect = -10 --how below the ground it goes 
				local HowMuchUp = 15
				local DownRayLength = -20
				local NumberOfRocks =7
				--Module.RockSpawn1(script.Parent, NumberOfRocks, SizeX, SizeY, SizeZ, Distance)
				--	Module.RockSpawn2(RootCF , NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset-1.8,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --inside and smal;er
				--Module.RockSpawn2(RootCF, NumberOfRocks , SizeX, SizeY, SizeZ, Distance+.7,CollectAfter,HeightOffset-2.1,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --outside and bigger

				-- Rock Flying ==
				local Height = 100

				local SizeX = 1.3
				local SizeY = 1.3
				local SizeZ = 1.3
				local CollideAfter = .5
				local Spread = 30

				Module.RockFlying(RootCF , Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)
				local SizeX = 1.5
				local SizeY = 1.5
				local SizeZ = 1.5
				Module.RockFlying(RootCF , Height, SizeX*2.3, SizeY/10, SizeZ*2.3, NumberOfRocks,CollideAfter,Spread)
				Module.RockFlying(RootCF, Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)

				--Round 2
				local AppearTime = .19

				local CollectLength =5.6
				local HowMuchDown = -7
				local AppearTime = .21
				local HowMuchUp = 14
				--Round 3


				local SizeX = 5 
				local SizeY = 5
				local SizeZ = 5
				local Tilt =18
				-- Ground spawn --
				local Distance = 7

				local NumberOfRocks = 8
				RootCF = RootCF * CFrame.Angles(0,math.rad(40),0)
				Module.RockSpawn2(RootCF, NumberOfRocks, SizeX, SizeY, SizeZ, Distance,CollectAfter,HeightOffset,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --inside and smal;er
				local NumberOfRocks = 6
				RootCF = RootCF * CFrame.Angles(0,math.rad(60),0)
				local CollectLength =9
				local Distance = 6
				local Tilt = 34
				Module.RockSpawn2(RootCF, NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset+.15,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect)

				local AppearTime = .17
				local Tilt = 25
				local Distance = 9
				local CollectAfter = 4.5
				local CollectLength = 7
				local HeightOffset = -2
				local HowMuchDown = -5 --how below the ground it is when it appears
				local HowMuchDownCollect = -10 --how below the ground it goes 
				local HowMuchUp = 15
				local DownRayLength = -20
				local NumberOfRocks =7
				--Module.RockSpawn1(script.Parent, NumberOfRocks, SizeX, SizeY, SizeZ, Distance)
				--	Module.RockSpawn2(RootCF , NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset-1.8,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --inside and smal;er
				--Module.RockSpawn2(RootCF, NumberOfRocks , SizeX, SizeY, SizeZ, Distance+.7,CollectAfter,HeightOffset-2.1,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --outside and bigger

				-- Rock Flying ==
				local Height = 100

				local SizeX = 1.3
				local SizeY = 1.3
				local SizeZ = 1.3
				local CollideAfter = .5
				local Spread = 30

				Module.RockFlying(RootCF , Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)
				local SizeX = 1.5
				local SizeY = 1.5
				local SizeZ = 1.5
				Module.RockFlying(RootCF , Height, SizeX*2.3, SizeY/10, SizeZ*2.3, NumberOfRocks,CollideAfter,Spread)
				Module.RockFlying(RootCF, Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)

				--Round 2
				local AppearTime = .19

				local CollectLength =5.6
				local HowMuchDown = -7
				local AppearTime = .21
				local HowMuchUp = 14
				--Round 3


				local SizeX = 5 
				local SizeY = 5
				local SizeZ = 5
				local Tilt =18
				-- Ground spawn --
				local Distance = 16

				local NumberOfRocks = 8
				RootCF = RootCF * CFrame.Angles(0,math.rad(40),0)
				Module.RockSpawn2(RootCF, NumberOfRocks, SizeX, SizeY, SizeZ, Distance,CollectAfter,HeightOffset,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --inside and smal;er
				local NumberOfRocks = 6
				RootCF = RootCF * CFrame.Angles(0,math.rad(60),0)
				local CollectLength =9
				local Distance = 15
				local Tilt = 34
				Module.RockSpawn2(RootCF, NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset+.15,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect)
				--	task.wait(.1)
				--end
			end))
			local RedFX=ResourceFolder.Parent.Smash.SmashBigger:Clone()
			RedFX.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0,30,-6.2)
			Debris:AddItem(RedFX,5)
			RedFX.Parent = workspace.Ignore.Effects
			RedFX.sfx1:Play()
			RedFX.sfx2:Play()
			RedFX.sfx3:Play()
			local enabled1 = true
			for i,v in pairs(RedFX:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') and v.Enabled == true then
						v.Enabled = false
						while (enabled1 == true) do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							v:Emit(1)
						end
					end
				end))
			end
			task.delay(2,function()
				enabled1 = false
				for i,v in pairs(RedFX:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v.Enabled = false
					end
					if v:IsA('PointLight') then
						game.TweenService:Create(v,TweenInfo.new(.1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,0,false,.95),{Brightness = 0,Range = 0}):Play()
					end
					if v:IsA('Beam') then
						game:GetService("TweenService"):Create(v,TweenInfo.new(.7,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0}):Play()
						game:GetService("TweenService"):Create(v,TweenInfo.new(.7,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width1 = 0}):Play()
					end
				end
			end)

			if (game.Players.LocalPlayer:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 45 then
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(14, 14, .5,.5)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end)
	end,
	["BEATDOWNVFX"] = function(Character,Enemy)
		local modelclone2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].BEATDOWNVFX
		local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
		local Directory2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
		local Directory3 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local function emit(instance,weld,characterc)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = characterc.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = characterc.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = characterc.HumanoidRootPart	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(characterc.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = game.Workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame,Size = modelclone:FindFirstChild("End").Size}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,14)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.beatdownsfx:Clone()
		sound1.Parent = Enemy.Torso
		sound1:Play()
		game.Debris:AddItem(sound1,17)
		--emit(Directory2.appear2,true,Character)
		local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
		for _,l in limbs do
			if Character[l]:FindFirstChild("dash0") then
				for _,thing in Character[l]:GetChildren() do
					if thing:IsA("Trail") and string.find(thing.Name, "dash") then
						thing.Enabled = true
					end
				end
			else
				local dash_vfx = dashLimbs:Clone():GetChildren()
				for _,p in dash_vfx do
					p.Parent = Character[l]
					if p:IsA("Trail") then
						p.Enabled = true
					end
				end
			end
		end
		for _,l in limbs do
			if Enemy[l]:FindFirstChild("dash0") then
				for _,thing in Enemy[l]:GetChildren() do
					if thing:IsA("Trail") and string.find(thing.Name, "dash") then
						thing.Enabled = true
					end
				end
			else
				local dash_vfx = dashLimbs:Clone():GetChildren()
				for _,p in dash_vfx do
					p.Parent = Enemy[l]
					if p:IsA("Trail") then
						p.Enabled = true
					end
				end
			end
		end
		task.delay(938/60,function()
			for _,l in limbs do
				if Character[l]:FindFirstChild("dash0") then
					for _,thing in Character[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = false
						end
					end
				end
			end
		end)
		task.delay(870/60,function()
			for _,l in limbs do
				if Enemy[l]:FindFirstChild("dash0") then
					for _,thing in Enemy[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = false
						end
					end
				end
			end
		end)
		local function vineta()
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 50 then
				redvignette()
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(5, 5, .4,.6)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end
		task.delay(260/60,function()
			emit(Directory.slash2cutsc,false,Character)
		end)
		task.delay(305/60,function()
			for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Shine1:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
			emit(Directory3.impact3DownslamREMI1x2cutc,false,Character)
		end)
		task.delay(199/60,function()
			miserablefate(Character["Left Arm"],Enemy["Torso"],((261-199)/60))
		end)
		task.delay(924/60,function()
			local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.heartbreakstartupsfx2end:Clone()
			sound1.Parent = Character.HumanoidRootPart
			sound1:Play()
			game.Debris:AddItem(sound1,2)
		end)
		task.delay(50/60,function()
			local floorInstance = RayCastOnMap(Enemy.Torso.Position,Vector3.new(0,-25,0),true)
			if floorInstance then
				local RedFX2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.GroundHit:Clone()
				RedFX2.Parent = workspace.Ignore.Effects
				game.Debris:AddItem(RedFX2,4)
				RedFX2.Position = floorInstance.Position + Vector3.new(0,0.6,0)
				for i,v in pairs(RedFX2:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
		end)
		local enabled51 = true
		local enabled25 = true
		local enabled = true
		task.delay(260/60,function()
			enabled51 = false
		end)
		task.delay(310/60,function()
			enabled25 = false
		end)
		task.delay(140/60,function()
			enabled = false
		end)
		local function blackflash()
			coroutine.resume(coroutine.create(function()
				local RedFX=ResourceFolder.Hitfisttd.VFX:Clone()
				RedFX.Parent=Enemy.Head
				RedFX.BlackFlash:Play()
				RedFX.BlackFlash1:Play()
				Debris:AddItem(RedFX,1.7)
				for i,v in pairs(RedFX:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
				local RedFX=ResourceFolder.Hitblackfla.VFX:Clone()
				RedFX.Parent=Enemy.Head
				Debris:AddItem(RedFX,1.7)
				for i,v in pairs(RedFX:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
				if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 40 then
					redvignette()
					game.Lighting.BlackFlash.Enabled = true
					task.delay(6.3/60,function()
						game.Lighting.BlackFlash.Enabled = false
					end)
					local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
						Camera.CFrame = Camera.CFrame * shakeCf
					end)
					camShake:ShakeOnce(5, 5, .4,.6)
					--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
					camShake:Start()
				end
			end))
		end
		task.delay(873/60,function()
			blackflash()
		end)
		task.delay(843/60,function()
			emitsum(modelclone2["fortnitehit843"],modelclone2,Character.HumanoidRootPart.CFrame)
			emit(modelclone2["fortnitehithigheremit"],false,Character)
			local RedFX=ResourceFolder.Hitfisttd.VFX:Clone()
			RedFX.Parent=Enemy.Head
			RedFX.BlackFlash1:Play()
			Debris:AddItem(RedFX,1.7)
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 40 then
				redvignette()
				game.Lighting.BlackFlash.Enabled = true
				task.delay(2/60,function()
					game.Lighting.BlackFlash.Enabled = false
				end)
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(3, 3, .3,.5)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end)
		task.delay(539/60,function()
			emitsum(modelclone2["secondhit539"],modelclone2,Character.HumanoidRootPart.CFrame)
		end)
		task.delay(568/60,function()
			emitsum(modelclone2["secondhit568"],modelclone2,Character.HumanoidRootPart.CFrame)
		end)
		task.delay(447/60,function()
			emitsum(modelclone2["smallhit447"],modelclone2,Character.HumanoidRootPart.CFrame)
		end)
		task.delay(260/60,function()
			emitsum(modelclone2["smokehit260"],modelclone2,Character.HumanoidRootPart.CFrame)
		end)
		task.delay(609/60,function()
			emitsum(modelclone2["smokepart609"],modelclone2,Character.HumanoidRootPart.CFrame)
		end)
		task.delay(402/60,function()
			emitsum(modelclone2["thirdhit402"],modelclone2,Character.HumanoidRootPart.CFrame)
			emitsum(modelclone2["thirdhit402"],modelclone2,Character.HumanoidRootPart.CFrame)
		end)
		emit(modelclone2["firsthithigheremit"],false,Character)
		task.delay(97/60,function()
			coroutine.resume(coroutine.create(function()
				while enabled == true do
					--a.CFrame = CFrame.new(Character.Torso.Position)
					local modelclone1 = Directory2.rotate5:Clone()
					modelclone1:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * Directory2.rotate5.Tets1.Start.CFrame)
					modelclone1.Parent = workspace.Ignore.Effects
					game.Debris:AddItem(modelclone1,2)
					for i,v in pairs(modelclone1:GetChildren()) do
						if v:IsA('Model') and v:FindFirstChild("Start") then
							local modelclone = v
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame,Size = modelclone:FindFirstChild("End").Size}):Play()
							modelclone.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end
					end
					wait(.1)
				end
			end))
		end)
		task.delay(160/60,function()
			local a = Directory2.avampirek:Clone()
			a.Parent = workspace.Ignore.Effects
			a.CFrame = Character["Left Arm"].CFrame * CFrame.new(0,-1,0)
			for i,v in pairs(a:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						v.Enabled = false
						while enabled51 == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							v:Emit(1)
						end
					end
				end))
			end
			game:GetService("TweenService"):Create(a.Sound,TweenInfo.new(.4,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = .15}):Play()
			coroutine.resume(coroutine.create(function()
				while enabled25 == true do
					if a ~= nil then
						a.CFrame = Character["Left Arm"].CFrame * CFrame.new(0,-1.4,0)
					else
						break
					end
					wait()
				end
				game:GetService("TweenService"):Create(a.Sound,TweenInfo.new(.4,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 0}):Play()
				game.Debris:AddItem(a,4)
			end))
		end)
		local RedFX=ResourceFolder.Hit:Clone()
		RedFX.Parent=workspace.Ignore.Effects
		RedFX.CFrame = CFrame.lookAt(Enemy.HumanoidRootPart.Position,Character.HumanoidRootPart.Position)
		RedFX.VFX['h'..4]:Play()
		Debris:AddItem(RedFX,2)
		for i,v in pairs(RedFX:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
					v:Emit((v:GetAttribute('EmitCount') or 1)/6)
				else
					v:Emit((v:GetAttribute('EmitCount')) or 1)
				end
			end
		end
		task.delay(665/60,function()
			local enabled = true
			task.delay((755-665)/60,function()
				enabled = false
			end)
			for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') and v:GetAttribute("aurae") then
						v.Enabled = false
						while enabled == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							v:Emit(3)
						end
					end
				end))
			end
		end)
		task.delay(851/60,function()
			local enabled = true
			task.delay((928-851)/60,function()
				enabled = false
			end)
			for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') and v:GetAttribute("aurae") then
						v.Enabled = false
						while enabled == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							v:Emit(3)
						end
					end
				end))
			end
		end)
		task.delay(748/60,function()
			for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
				if v:IsA("BasePart") then
					local sizeado = v.Size
					local transparenciado = v.Transparency
					game:GetService("TweenService"):Create(v,TweenInfo.new(.15,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Size = Vector3.new(0,0,0),Transparency = 1}):Play()
					task.delay((915-748)/60,function()
						v.Transparency = transparenciado
						v.Size = sizeado
					end)
				end
			end
		end)
		task.delay(926/60,function()
			for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Shine1:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
			for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
				if v:IsA("BasePart") then
					local sizeado = v.Size
					v.Size = Vector3.new(0,0,0)
					v.Transparency = 1
					game:GetService("TweenService"):Create(v,TweenInfo.new(.15,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Size = sizeado,Transparency = 0}):Play()
				end
			end
		end)
		--task.delay(15/60,function()
		--	emitsum(modelclone2["Slash1 15"],modelclone2,Character.HumanoidRootPart.CFrame)
		--	vineta()
		--end)
		--task.delay(35/60,function()
		--	--emit(Directory.slash4,false,Character)
		--	emitsum(modelclone2["Slash2 35"],modelclone2,Character.HumanoidRootPart.CFrame)
		--	vineta()
		--end)
		--task.delay(60/60,function()
		--	emitsum(modelclone2["Slash3 60"],modelclone2,Character.HumanoidRootPart.CFrame)
		--	emitsum(modelclone2["GroundSlash1 60"],modelclone2,Character.HumanoidRootPart.CFrame)
		--	vineta()
		--end)
		--task.delay(84/60,function()
		--	emitsum(modelclone2["Wind2 84"],modelclone2,Character.HumanoidRootPart.CFrame)
		--	emitsum(modelclone2["Spawn 84"],modelclone2,Character.HumanoidRootPart.CFrame)
		--	emitsum(modelclone2["SpawnHit 84"],modelclone2,Character.HumanoidRootPart.CFrame)
		--	vineta()
		--end)
		--if Character["Right Arm"]:FindFirstChild("remiliaspear") then
		--	for i ,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants())do
		--		if  v:IsA('Trail') then
		--			if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad") then
		--				Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad"):Destroy()
		--			end
		--			local v1 = v:Clone()
		--			v1.Enabled = true
		--			v1.Name = ("lolazoverdad")
		--			v1.Parent =Character["Right Arm"]:FindFirstChild("remiliaspear")
		--			task.delay(350/60,function()
		--				v1.Enabled = false
		--				game.Debris:AddItem(v1,.8)
		--			end)
		--		end
		--	end
		--end
		--local enabled1 = true
		--task.delay(160/60,function()
		--	enabled1 = false
		--end)
		--task.delay(110/60,function()
		--	local modelclone25 = modelclone2["Wind3 110"]:Clone()
		--	modelclone25.Parent = workspace.Ignore.Effects
		--	game.Debris:AddItem(modelclone25,8)
		--	modelclone25.CFrame = Character.HumanoidRootPart.CFrame * modelclone2["Wind3 110"].CFrame
		--	for i,v in pairs(modelclone25:GetDescendants()) do
		--		if v:IsA('ParticleEmitter') then
		--			v:Emit(v:GetAttribute('EmitCount') or 1)
		--		end
		--	end
		--	for i,v in pairs(modelclone25:GetDescendants()) do
		--		coroutine.resume(coroutine.create(function()
		--			if v:IsA('ParticleEmitter') then
		--				while enabled1 == true do
		--local rate = v.Rate
		--if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
		--	rate = v.Rate / 5
		--end
		--wait(1/rate)
		--					v:Emit(5)
		--				end
		--			end
		--		end))
		--	end
		--end)
		--task.delay(168/60,function()
		--	emitsum(modelclone2["Slash4 168"],modelclone2,Character.HumanoidRootPart.CFrame)
		--	emitsum(modelclone2["GroundSlash2 168"],modelclone2,Character.HumanoidRootPart.CFrame)
		--	vineta()
		--end)
		--task.delay(185/60,function()
		--	emitsum(modelclone2["Slash5 185"],modelclone2,Character.HumanoidRootPart.CFrame)
		--	vineta()
		--end)
		--task.delay(210/60,function()
		--	emitsum(modelclone2["Slash6 210"],modelclone2,Character.HumanoidRootPart.CFrame)
		--	vineta()
		--end)
		--task.delay(212/60,function()
		--	emitsum(modelclone2["GroundSlash3 212"],modelclone2,Character.HumanoidRootPart.CFrame)
		--end)
		--task.delay(237/60,function()
		--	emitsum(modelclone2["Wind 237"],modelclone2,Character.HumanoidRootPart.CFrame)
		--end)
		--task.delay(234/60,function()
		--	emitsum(modelclone2["GroundSlash4 246"],modelclone2,Character.HumanoidRootPart.CFrame)
		--	emitsum(modelclone2["Slash7 246"],modelclone2,Character.HumanoidRootPart.CFrame)
		--	vineta()
		--end)
		--task.delay(277/60,function()
		--	emitsum(modelclone2["Wind4 277"],modelclone2,Character.HumanoidRootPart.CFrame)
		--end)
		--task.delay(315/60,function()
		--	emit(Directory.ground11,false,Character)
		--end)
		--task.delay(281/60,function()
		--	emit(Directory.ground22,false,Character)
		--	emitsum(modelclone2["GroundLast 281"],modelclone2,Character.HumanoidRootPart.CFrame)
		--	emitsum(modelclone2["ExplosionLast 281"],modelclone2,Character.HumanoidRootPart.CFrame)
		--	if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 50 then
		--		local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
		--			Camera.CFrame = Camera.CFrame * shakeCf
		--		end)
		--		camShake:ShakeOnce(7, 7, .6,.7)
		--		camShake:Start()
		--	end
		--end)
	end,
	["COUNTERVFX"] = function(Character,Enemy)
		local modelclone2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX
		local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
		local Directory2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
		local Directory3 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local function emit(instance,weld,characterc)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = characterc.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = characterc.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = characterc.HumanoidRootPart	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(characterc.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = game.Workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame,Size = modelclone:FindFirstChild("End").Size}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,4)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.ultcountersfx:Clone()
		sound1.Parent = Enemy.Torso
		sound1:Play()
		game.Debris:AddItem(sound1,8.5)
		emit(Directory3.ground151bat,true,Character)

		local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
		for _,l in limbs do
			if Character[l]:FindFirstChild("dash0") then
				for _,thing in Character[l]:GetChildren() do
					if thing:IsA("Trail") and string.find(thing.Name, "dash") then
						thing.Enabled = true
					end
				end
			else
				local dash_vfx = dashLimbs:Clone():GetChildren()
				for _,p in dash_vfx do
					p.Parent = Character[l]
					if p:IsA("Trail") then
						p.Enabled = true
					end
				end
			end
		end
		for _,l in limbs do
			if Enemy[l]:FindFirstChild("dash0") then
				for _,thing in Enemy[l]:GetChildren() do
					if thing:IsA("Trail") and string.find(thing.Name, "dash") then
						thing.Enabled = true
					end
				end
			else
				local dash_vfx = dashLimbs:Clone():GetChildren()
				for _,p in dash_vfx do
					p.Parent = Enemy[l]
					if p:IsA("Trail") then
						p.Enabled = true
					end
				end
			end
		end
		task.delay(355/60,function()
			for _,l in limbs do
				if Character[l]:FindFirstChild("dash0") then
					for _,thing in Character[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = false
						end
					end
				end
			end
		end)
		task.delay(283/60,function()
			for _,l in limbs do
				if Enemy[l]:FindFirstChild("dash0") then
					for _,thing in Enemy[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = false
						end
					end
				end
			end
		end)
		local function vineta()
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 50 then
				redvignette()
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(5, 5, .4,.6)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end
		task.delay(15/60,function()
			emitsum(modelclone2["Slash1 15"],modelclone2,Character.HumanoidRootPart.CFrame)
			vineta()
		end)
		task.delay(35/60,function()
			--emit(Directory.slash4,false,Character)
			emitsum(modelclone2["Slash2 35"],modelclone2,Character.HumanoidRootPart.CFrame)
			vineta()
		end)
		task.delay(60/60,function()
			emitsum(modelclone2["Slash3 60"],modelclone2,Character.HumanoidRootPart.CFrame)
			emitsum(modelclone2["GroundSlash1 60"],modelclone2,Character.HumanoidRootPart.CFrame)
			vineta()
		end)
		task.delay(84/60,function()
			emitsum(modelclone2["Wind2 84"],modelclone2,Character.HumanoidRootPart.CFrame)
			emitsum(modelclone2["Spawn 84"],modelclone2,Character.HumanoidRootPart.CFrame)
			emitsum(modelclone2["SpawnHit 84"],modelclone2,Character.HumanoidRootPart.CFrame)
			vineta()
		end)
		--if Character["Right Arm"]:FindFirstChild("remiliaspear") then
		--	for i ,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants())do
		--		if  v:IsA('Trail') then
		--			if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad") then
		--				Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad"):Destroy()
		--			end
		--			local v1 = v:Clone()
		--			v1.Enabled = true
		--			v1.Name = ("lolazoverdad")
		--			v1.Parent =Character["Right Arm"]:FindFirstChild("remiliaspear")
		--			task.delay(350/60,function()
		--				v1.Enabled = false
		--				game.Debris:AddItem(v1,.8)
		--			end)
		--		end
		--	end
		--end
		local enabled1 = true
		task.delay(160/60,function()
			enabled1 = false
		end)
		task.delay(110/60,function()
			local modelclone25 = modelclone2["Wind3 110"]:Clone()
			modelclone25.Parent = workspace.Ignore.Effects
			game.Debris:AddItem(modelclone25,8)
			modelclone25.CFrame = Character.HumanoidRootPart.CFrame * modelclone2["Wind3 110"].CFrame
			for i,v in pairs(modelclone25:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
			for i,v in pairs(modelclone25:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						while enabled1 == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							v:Emit(5)
						end
					end
				end))
			end
		end)
		task.delay(168/60,function()
			emitsum(modelclone2["Slash4 168"],modelclone2,Character.HumanoidRootPart.CFrame)
			emitsum(modelclone2["GroundSlash2 168"],modelclone2,Character.HumanoidRootPart.CFrame)
			vineta()
		end)
		task.delay(185/60,function()
			emitsum(modelclone2["Slash5 185"],modelclone2,Character.HumanoidRootPart.CFrame)
			vineta()
		end)
		task.delay(210/60,function()
			emitsum(modelclone2["Slash6 210"],modelclone2,Character.HumanoidRootPart.CFrame)
			vineta()
		end)
		task.delay(212/60,function()
			emitsum(modelclone2["GroundSlash3 212"],modelclone2,Character.HumanoidRootPart.CFrame)
		end)
		task.delay(237/60,function()
			emitsum(modelclone2["Wind 237"],modelclone2,Character.HumanoidRootPart.CFrame)
		end)
		task.delay(234/60,function()
			emitsum(modelclone2["GroundSlash4 246"],modelclone2,Character.HumanoidRootPart.CFrame)
			emitsum(modelclone2["Slash7 246"],modelclone2,Character.HumanoidRootPart.CFrame)
			vineta()
		end)
		task.delay(277/60,function()
			emitsum(modelclone2["Wind4 277"],modelclone2,Character.HumanoidRootPart.CFrame)
		end)
		task.delay(315/60,function()
			emit(Directory.ground11,false,Character)
		end)
		task.delay(281/60,function()
			emit(Directory.ground22,false,Character)
			emitsum(modelclone2["GroundLast 281"],modelclone2,Character.HumanoidRootPart.CFrame)
			emitsum(modelclone2["ExplosionLast 281"],modelclone2,Character.HumanoidRootPart.CFrame)
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 50 then
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(7, 7, .6,.7)
				camShake:Start()
			end
		end)
	end,
	["AIMEDEXPL2"] = function(Projectile)
		local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.Anchored = true
			instanceclone.CFrame = Projectile
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Projectile.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		emit(Directory.expl2heart,false)
		--game:GetService("TweenService"):Create(Projectile,TweenInfo.new(.5,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
		--for i,v in pairs(Projectile:GetDescendants()) do
		--	if v:IsA('ParticleEmitter') then
		--		v.Enabled = false
		--	end
		--	if v:IsA('BasePart') then
		--		game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
		--	end
		--	if v:IsA('Decal') then
		--		v.Transparency = 1
		--	end
		--	if v:IsA('Trail') then
		--		v.Enabled = false
		--		v.Lifetime = .3
		--	end
		--	if v:IsA('Beam') then
		--		game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0}):Play()
		--		game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width1 = 0}):Play()
		--	end
		--	if v:IsA('PointLight') then
		--		game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Range = 0}):Play()
		--	end
		--end
	end,
	["SPECIALSTARTVFX"] = function(Character)
		local Directory3 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local Directory2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
		local modelclone2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX
		local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.enragedSFX:Clone()
		sound1.Parent = Character.Torso
		sound1:Play()
		game.Debris:AddItem(sound1,7)
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("redmisthorion") then
				local sound2=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.geburaSFX:Clone()
				sound2.Parent = Character.Torso
				sound2:Play()
				game.Debris:AddItem(sound2,7)
			end
		end
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if Character then
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
					end
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		local function flare()
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
				Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
			end
		end
		local function shine()
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Shine1:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
		end
		local function vortex()
			for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Attachm122ent:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		--local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.vampirekissSTARTSFX:Clone()
		--sound1.Parent = Character.Torso
		--sound1:Play()
		--game.Debris:AddItem(sound1,3)
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
			Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
		end
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Shine2:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
		for _,l in limbs do
			if Character[l]:FindFirstChild("dash0") then
				for _,thing in Character[l]:GetChildren() do
					if thing:IsA("Trail") and string.find(thing.Name, "dash") then
						thing.Enabled = true
					end
				end
			else
				local dash_vfx = dashLimbs:Clone():GetChildren()
				for _,p in dash_vfx do
					p.Parent = Character[l]
					if p:IsA("Trail") then
						p.Enabled = true
					end
				end
			end
		end
		local cancelled = false
		local conn1
		conn1 = Character.Values.ChildAdded:Connect(function(Child)
			if Child.Name == ("Stunned") then
				if conn1 then 
					conn1:Disconnect()
				end
				cancelled = true
			end
		end)
		task.delay(230/60,function()
			if conn1 then 
				conn1:Disconnect()
			end
			for _,l in limbs do
				if Character[l]:FindFirstChild("dash0") then
					for _,thing in Character[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = false
						end
					end
				end
			end
		end)
		flare()
		task.delay(7/60,function()
			if cancelled == true then return end
			vortex()
		end)
		task.delay(124/60,function()
			if cancelled == true then return end
			emit(Directory3.ground151bat5,true)
		end)
		task.delay(64/60,function()
			if cancelled == true then return end
			emit(Directory3.ground151bat52,true)
		end)
		task.delay(208/60,function()
			if cancelled == true then return end
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				local miliaspear =  Character["Right Arm"]:FindFirstChild("remiliaspear")
				local floorInstance = RayCastOnMap(miliaspear.Position,Vector3.new(0,-15,0),true)
				if floorInstance then
					local RedFX2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.GroundHit251:Clone()
					RedFX2.Parent = workspace.Ignore.Effects
					game.Debris:AddItem(RedFX2,3)
					RedFX2.Position = floorInstance.Position + Vector3.new(0,0.15,0)
					for i,v in pairs(RedFX2:GetDescendants()) do
						if v:IsA('ParticleEmitter') then
							if Character then
								if Character["Right Arm"]:FindFirstChild("remiliaspear") then
									if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
										v.Color = ColorSequence.new{
											ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
										}
									end
								end
							end
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								v:Emit((v:GetAttribute('EmitCount') or 1)/6)
							else
								v:Emit((v:GetAttribute('EmitCount')) or 1)
							end
						end
					end
				end
			end
		end)
		task.delay(20/60,function()
			if cancelled == true then return end
			shine()
		end)
		--task.delay(187/60,function()
		--	shine()
		--end)
		task.delay(23/60,function()
			if cancelled == true then return end
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				local miliaspear =  Character["Right Arm"]:FindFirstChild("remiliaspear")
				local floorInstance = RayCastOnMap(miliaspear.Position,Vector3.new(0,-15,0),true)
				if floorInstance then
					local RedFX2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.GroundHitbatz:Clone()
					RedFX2.Parent = workspace.Ignore.Effects
					game.Debris:AddItem(RedFX2,4)
					RedFX2.Position = floorInstance.Position + Vector3.new(0,0.15,0)
					for i,v in pairs(RedFX2:GetDescendants()) do
						if v:IsA('ParticleEmitter') then
							if Character then
								if Character["Right Arm"]:FindFirstChild("remiliaspear") then
									if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
										v.Color = ColorSequence.new{
											ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
										}
									end
								end
							end
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								v:Emit((v:GetAttribute('EmitCount') or 1)/6)
							else
								v:Emit((v:GetAttribute('EmitCount')) or 1)
							end
						end
					end
					local RootCF = CFrame.new(miliaspear.CFrame.Position)
					local AppearTime = .17
					local Tilt = 25
					local Distance = 7
					local CollectAfter = 4.5
					local CollectLength = 7
					local HeightOffset = -2
					local HowMuchDown = -5 --how below the ground it is when it appears
					local HowMuchDownCollect = -10 --how below the ground it goes 
					local HowMuchUp = 15
					local DownRayLength = -20
					local NumberOfRocks =5 
					--Module.RockSpawn1(script.Parent, NumberOfRocks, SizeX, SizeY, SizeZ, Distance)
					--	Module.RockSpawn2(RootCF , NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset-1.8,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --inside and smal;er
					--Module.RockSpawn2(RootCF, NumberOfRocks , SizeX, SizeY, SizeZ, Distance+.7,CollectAfter,HeightOffset-2.1,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --outside and bigger

					-- Rock Flying ==
					local Height = 75

					local SizeX = 1.3
					local SizeY = 1.3
					local SizeZ = 1.3
					local CollideAfter = .5
					local Spread = 25
					coroutine.resume(coroutine.create(function()
						for i = 1,12 do
							Basemd.SmashTile(RootCF * CFrame.new(math.random(-6,6),0,math.random(-6,6)))
						end
					end))
					Module.RockFlying(RootCF , Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)
					local SizeX = 1.5
					local SizeY = 1.5
					local SizeZ = 1.5
					Module.RockFlying(RootCF , Height, SizeX*2.3, SizeY/10, SizeZ*2.3, NumberOfRocks,CollideAfter,Spread)
					Module.RockFlying(RootCF, Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)
					if math.random(1,2) == 1 then 
						RootCF = RootCF * CFrame.Angles(0,math.rad(90),0)
					end
					--Round 2
					local AppearTime = .19

					local CollectLength =5.6
					local HowMuchDown = -7
					local AppearTime = .21
					local HowMuchUp = 15


					--Round 2
					local AppearTime = .19

					local CollectLength =5.6
					local HowMuchDown = -7
					local AppearTime = .21
					local HowMuchUp = 35
					--Round 3


					local AppearTime = .17
					local Tilt = 27
					local Distance = 1
					local CollectAfter = 4.5
					local CollectLength = 4
					local HeightOffset = -1.2
					local HowMuchDown = -5 --how below the ground it is when it appears
					local HowMuchDownCollect = -10 --how below the ground it goes 
					local HowMuchUp = 15
					local DownRayLength = -20
					local NumberOfRocks =3 
					--Module.RockSpawn1(script.Parent, NumberOfRocks, SizeX, SizeY, SizeZ, Distance)
					--	Module.RockSpawn2(RootCF , NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset-1.8,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --inside and smal;er
					--Module.RockSpawn2(RootCF, NumberOfRocks , SizeX, SizeY, SizeZ, Distance+.7,CollectAfter,HeightOffset-2.1,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --outside and bigger

					-- Rock Flying ==
					local Height = 70

					local SizeX = 1.1
					local SizeY = 1.1
					local SizeZ = 1.1
					local CollideAfter = .5
					local Spread = 20
					local SizeX = 1.2
					local SizeY = 1.2
					local SizeZ = 1.2
					local SizeX = 2.2
					local SizeY = 2.2
					local SizeZ = 3.2
					local Tilt = 37

					-- Ground spawn --
					local Distance = 1.4

					local NumberOfRocks = 1
					Module.RockSpawn2(RootCF, NumberOfRocks, SizeX, SizeY, SizeZ, Distance,CollectAfter,HeightOffset,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true) --inside and smal;er
				end
			end
		end)
		--task.delay(19/60,function()
		--	local cframe = Character.HumanoidRootPart.CFrame * CFrame.new(0,0,7)
		--	--emit(Directory3.impact5REMI5,false)
		--	--emit(Directory3.impact5REMIVAMPIREton2,false)
		--	emitsum(modelclone2["Spawn 84"],modelclone2,cframe)
		--	emitsum(modelclone2["Wind2 84"],modelclone2,cframe)
		--end)
		--task.delay(7/60,function()
		--	emit(Directory2.ground11555,false)
		--end)
		--task.delay(20/60,function()
		--	emit(Directory2.ground11,false)
		--end)
	end,
	["3STARTVFX25"] = function(Character)
		local Directory3 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local Directory2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
		local modelclone2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX
task.delay(4/60,function()
		local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.stingerSTARTSFX:Clone()
		sound1.Parent = Character.Torso
sound1.PlaybackSpeed = .9
		sound1:Play()
		game.Debris:AddItem(sound1,4)
end)
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		--local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.vampirekissSTARTSFX:Clone()
		--sound1.Parent = Character.Torso
		--sound1:Play()
		--game.Debris:AddItem(sound1,3)
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
			Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
		end
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Shine2:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
		for _,l in limbs do
			if Character[l]:FindFirstChild("dash0") then
				for _,thing in Character[l]:GetChildren() do
					if thing:IsA("Trail") and string.find(thing.Name, "dash") then
						thing.Enabled = true
					end
				end
			else
				local dash_vfx = dashLimbs:Clone():GetChildren()
				for _,p in dash_vfx do
					p.Parent = Character[l]
					if p:IsA("Trail") then
						p.Enabled = true
					end
				end
			end
		end
		task.delay(45/60,function()
			for _,l in limbs do
				if Character[l]:FindFirstChild("dash0") then
					for _,thing in Character[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = false
						end
					end
				end
			end
		end)
		task.delay(31/60,function()
			emit(Directory2.ground11,false)
		end)
		task.delay(30/60,function()
			local cframe = Character.HumanoidRootPart.CFrame * CFrame.new(0,0,7)
			--emit(Directory3.impact5REMI5,false)
			--emit(Directory3.impact5REMIVAMPIREton2,false)
			emitsum(modelclone2["Spawn 84"],modelclone2,cframe)
			emitsum(modelclone2["Wind2 84"],modelclone2,cframe)
		end)
		task.delay(7/60,function()
			emit(Directory2.ground11555,false)
		end)
		task.delay(20/60,function()
			emit(Directory2.ground11,false)
		end)
	end,
	["3STARTVFX"] = function(Character)
		local Directory3 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local Directory2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
		local modelclone2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX
		local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.stingerSTARTSFX:Clone()
		sound1.Parent = Character.Torso
		sound1:Play()
		game.Debris:AddItem(sound1,2)
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if Character then
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
					end
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		--local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.vampirekissSTARTSFX:Clone()
		--sound1.Parent = Character.Torso
		--sound1:Play()
		--game.Debris:AddItem(sound1,3)
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
				Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
			end
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Shine2:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if Character then
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
					end
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
				end
			end
		local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
		for _,l in limbs do
			if Character[l]:FindFirstChild("dash0") then
				for _,thing in Character[l]:GetChildren() do
					if thing:IsA("Trail") and string.find(thing.Name, "dash") then
						thing.Enabled = true
					end
				end
			else
				local dash_vfx = dashLimbs:Clone():GetChildren()
				for _,p in dash_vfx do
					p.Parent = Character[l]
					if p:IsA("Trail") then
						p.Enabled = true
					end
				end
			end
		end
		task.delay(17/60,function()
			for _,l in limbs do
				if Character[l]:FindFirstChild("dash0") then
					for _,thing in Character[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = false
						end
					end
				end
			end
		end)
		task.delay(19/60,function()
			local cframe = Character.HumanoidRootPart.CFrame * CFrame.new(0,0,7)
			--emit(Directory3.impact5REMI5,false)
			--emit(Directory3.impact5REMIVAMPIREton2,false)
			emitsum(modelclone2["Spawn 84"],modelclone2,cframe,Character)
			emitsum(modelclone2["Wind2 84"],modelclone2,cframe,Character)
		end)
		task.delay(7/60,function()
			emit(Directory2.ground11555,false)
		end)
		task.delay(20/60,function()
			emit(Directory2.ground11,false)
		end)
	end,
	["KISSTARTVFX"] = function(Character)
		local Directory2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.vampirekissSTARTSFX:Clone()
		sound1.Parent = Character.Torso
		sound1:Play()
		game.Debris:AddItem(sound1,3)
		task.delay(9/60,function()
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
				Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
			end
		end)
		task.delay(14/60,function()
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Shine2:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
		end)
		task.delay(7/60,function()
			emit(Directory2.ground11555,false)
		end)
		task.delay(40/60,function()
			emit(Directory2.ground11,false)
		end)
	end,
	["17pieceswoman"] = function(Character,Enemy)
		if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Enemy.HumanoidRootPart.Position).Magnitude <= 45 then
			local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
				Camera.CFrame = Camera.CFrame * shakeCf
			end)
			camShake:ShakeOnce(8, 8, .4,.6)
			camShake:Start()
		end
		if Enemy then
			--local sound1 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat["bloodmedium"..math.random(1,2)]:Clone()
			--sound1.Parent = Enemy.HumanoidRootPart
			--sound1:Play()
			--game.Debris:AddItem(sound1,sound1.TimeLength)
			--local sound2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat["crush"..math.random(1,3)]:Clone()
			--sound2.Parent = Enemy.HumanoidRootPart
			--sound2:Play()
			--game.Debris:AddItem(sound2,sound2.TimeLength)
				for i,v3 in pairs(Enemy:GetChildren()) do
					if v3:IsA("BasePart") then
						for i,v in pairs(ResourceFolder.Parent.bloodsucky:GetChildren()) do
							local clone = v:Clone()
							clone.Parent = v3
							if clone:IsA('ParticleEmitter') or clone:IsA('Trail') then
								clone.Enabled = true
							elseif clone:IsA("Attachment") then
								for i,v in pairs(clone:GetDescendants()) do
									if v:IsA('Trail') then
										v.Enabled = true
									end
									if v:IsA('ParticleEmitter') then
										v.Enabled = true
									end
								end
							end
							task.delay(.2,function()
								local floorInstance = RayCastOnMap(v3.Position,Vector3.new(0,-25,0),true)
								if floorInstance then
									local RedFX21 = ResourceFolder.Parent.Snatch.bloodsmash:Clone()
									RedFX21[math.random(1,3)]:Play()
									RedFX21.Position = floorInstance.Position + Vector3.new(0,0.08,0)
									RedFX21.Parent = workspace.Ignore.Effects
									game.Debris:AddItem(RedFX21,10)			--RedFX21.sfx:Play()
									for i,v in pairs(RedFX21:GetDescendants()) do
										if v:IsA('ParticleEmitter') then
											v:Emit(1)
										end
									end
								end
							end)
							task.delay(.5,function()
								local floorInstance = RayCastOnMap(v3.Position,Vector3.new(0,-25,0),true)
								if floorInstance then
									local RedFX21 = ResourceFolder.Parent.Snatch.bloodsmash:Clone()
									RedFX21[math.random(1,3)]:Play()
									RedFX21.Position = floorInstance.Position + Vector3.new(0,0.08,0)
									RedFX21.Parent = workspace.Ignore.Effects
									game.Debris:AddItem(RedFX21,10)			--RedFX21.sfx:Play()
									for i,v in pairs(RedFX21:GetDescendants()) do
										if v:IsA('ParticleEmitter') then
											v:Emit(1)
										end
									end
								end
							end)
							task.delay(1,function()
								local floorInstance = RayCastOnMap(v3.Position,Vector3.new(0,-25,0),true)
								if floorInstance then
									local RedFX21 = ResourceFolder.Parent.Snatch.bloodsmash:Clone()
									RedFX21[math.random(1,3)]:Play()
									RedFX21.Position = floorInstance.Position + Vector3.new(0,0.08,0)
									RedFX21.Parent = workspace.Ignore.Effects
									game.Debris:AddItem(RedFX21,10)			--RedFX21.sfx:Play()
									for i,v in pairs(RedFX21:GetDescendants()) do
										if v:IsA('ParticleEmitter') then
											v:Emit(1)
										end
									end
								end
								game.Debris:AddItem(clone,1.5)

								if clone:IsA('ParticleEmitter') or clone:IsA('Trail') then
									clone.Enabled = false
								elseif clone:IsA("Attachment") then
									for i,v in pairs(clone:GetDescendants()) do
										if v:IsA('ParticleEmitter') or v:IsA('Trail') then
											v.Enabled = false
										end
									end
								end
							end)
						end
						if v3:FindFirstChild("trail") then
							v3:FindFirstChild("trail").Trail.Attachment0 = v3:FindFirstChild("trail")
							v3:FindFirstChild("trail").Trail.Attachment1 = v3:FindFirstChild("trail2")
						end
					end
				end

				for i,v in pairs(ResourceFolder.Parent.SKILL3AIRHIT:GetChildren()) do
					local clone = v:Clone()
					clone.Parent = Enemy.Torso
					game.Debris:AddItem(clone,1.7)
					if clone:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							clone:Emit((clone:GetAttribute('EmitCount')/6) or 1)
						else
							clone:Emit((clone:GetAttribute('EmitCount')) or 1)
						end
					elseif clone:IsA("Attachment") then
						for i,v in pairs(clone:GetDescendants()) do
							if v:IsA('ParticleEmitter') then
								if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
									v:Emit((v:GetAttribute('EmitCount') or 1)/6)
								else
									v:Emit((v:GetAttribute('EmitCount')) or 1)
								end
							end
						end
					end
				end
			end
	end,
	["SKILL2FINISHERVFX"] = function(Character,Enemy)
		if Enemy then
			local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.SKILL2FINISHERSFX:Clone()
			sound1.Parent = Enemy.Torso
			sound1:Play()
			game.Debris:AddItem(sound1,8.5)
		end
		local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		local enabled = true
		task.delay(390/60,function ()
			enabled = false
			emit(Directory.expl2heart2,false)
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Enemy.HumanoidRootPart.Position).Magnitude <= 45 then
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(10, 10, .4,.6)
				camShake:Start()
			end
			if (Enemy.Humanoid.Health <= 6) then
				if Enemy then
					for i,v3 in pairs(Enemy:GetChildren()) do
						if v3:IsA("BasePart") then
							for i,v in pairs(ResourceFolder.Parent.bloodsucky:GetChildren()) do
								local clone = v:Clone()
								clone.Parent = v3
								if clone:IsA('ParticleEmitter') or clone:IsA('Trail') then
									clone.Enabled = true
								elseif clone:IsA("Attachment") then
									for i,v in pairs(clone:GetDescendants()) do
										if v:IsA('Trail') then
											v.Enabled = true
										end
										if v:IsA('ParticleEmitter') then
											v.Enabled = true
										end
									end
								end
								task.delay(.2,function()
									local floorInstance = RayCastOnMap(v3.Position,Vector3.new(0,-25,0),true)
									if floorInstance then
										local RedFX21 = ResourceFolder.Parent.Snatch.bloodsmash:Clone()
										RedFX21[math.random(1,3)]:Play()
										RedFX21.Position = floorInstance.Position + Vector3.new(0,0.08,0)
										RedFX21.Parent = workspace.Ignore.Effects
										game.Debris:AddItem(RedFX21,10)			--RedFX21.sfx:Play()
										for i,v in pairs(RedFX21:GetDescendants()) do
											if v:IsA('ParticleEmitter') then
												v:Emit(1)
											end
										end
									end
								end)
								task.delay(.5,function()
									local floorInstance = RayCastOnMap(v3.Position,Vector3.new(0,-25,0),true)
									if floorInstance then
										local RedFX21 = ResourceFolder.Parent.Snatch.bloodsmash:Clone()
										RedFX21[math.random(1,3)]:Play()
										RedFX21.Position = floorInstance.Position + Vector3.new(0,0.08,0)
										RedFX21.Parent = workspace.Ignore.Effects
										game.Debris:AddItem(RedFX21,10)			--RedFX21.sfx:Play()
										for i,v in pairs(RedFX21:GetDescendants()) do
											if v:IsA('ParticleEmitter') then
												v:Emit(1)
											end
										end
									end
								end)
								task.delay(1,function()
									local floorInstance = RayCastOnMap(v3.Position,Vector3.new(0,-25,0),true)
									if floorInstance then
										local RedFX21 = ResourceFolder.Parent.Snatch.bloodsmash:Clone()
										RedFX21[math.random(1,3)]:Play()
										RedFX21.Position = floorInstance.Position + Vector3.new(0,0.08,0)
										RedFX21.Parent = workspace.Ignore.Effects
										game.Debris:AddItem(RedFX21,10)			--RedFX21.sfx:Play()
										for i,v in pairs(RedFX21:GetDescendants()) do
											if v:IsA('ParticleEmitter') then
												v:Emit(1)
											end
										end
									end
									game.Debris:AddItem(clone,1.5)

									if clone:IsA('ParticleEmitter') or clone:IsA('Trail') then
										clone.Enabled = false
									elseif clone:IsA("Attachment") then
										for i,v in pairs(clone:GetDescendants()) do
											if v:IsA('ParticleEmitter') or v:IsA('Trail') then
												v.Enabled = false
											end
										end
									end
								end)
							end
							if v3:FindFirstChild("trail") then
								v3:FindFirstChild("trail").Trail.Attachment0 = v3:FindFirstChild("trail")
								v3:FindFirstChild("trail").Trail.Attachment1 = v3:FindFirstChild("trail2")
							end
						end
					end
					local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.SKILL2FINISHEREXPL2SFX:Clone()
					sound1.Parent = Enemy.Torso
					sound1:Play()
					game.Debris:AddItem(sound1,5)
					--local floorInstance = RayCastOnMap(Enemy.Torso.Position,Vector3.new(0,-25,0),true)
					--if floorInstance then
					--	local RedFX21 = ResourceFolder.Parent.Snatch.bloodsmash:Clone()
					--	RedFX21[math.random(1,3)]:Play()
					--	RedFX21.Position = floorInstance.Position + Vector3.new(math.random(-5,5),0.08,math.random(-5,5))
					--	RedFX21.Parent = workspace.Ignore.Effects
					--	game.Debris:AddItem(RedFX21,10)			--RedFX21.sfx:Play()
					--	for i,v in pairs(RedFX21:GetDescendants()) do
					--		if v:IsA('ParticleEmitter') then
					--			v:Emit(4)
					--		end
					--	end
					--end
					for i,v in pairs(ResourceFolder.Parent.SKILL3AIRHIT:GetChildren()) do
						local clone = v:Clone()
						clone.Parent = Enemy.Torso
						game.Debris:AddItem(clone,1.7)
						if clone:IsA('ParticleEmitter') then
								if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
									clone:Emit((clone:GetAttribute('EmitCount')/6) or 1)
								else
									clone:Emit((clone:GetAttribute('EmitCount')) or 1)
								end
						elseif clone:IsA("Attachment") then
							for i,v in pairs(clone:GetDescendants()) do
								if v:IsA('ParticleEmitter') then
									if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
										v:Emit((v:GetAttribute('EmitCount') or 1)/6)
									else
										v:Emit((v:GetAttribute('EmitCount')) or 1)
									end
								end
							end
						end
					end
				end
			else
				if Enemy then
					local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.SKILL2FINISHEREXPL1SFX:Clone()
					sound1.Parent = Enemy.Torso
					sound1:Play()
					game.Debris:AddItem(sound1,5)
				end
			end
		end)
		local newremiliaspear = game.ReplicatedStorage.Assets.remiliaspear25:Clone()
		newremiliaspear.Parent = Character
		newremiliaspear.Weld.Part0 = Character.HumanoidRootPart
		newremiliaspear.Weld.Part1 = newremiliaspear
		newremiliaspear.Name = ("remiliaspear")
		local function vortex()
			if newremiliaspear then
				for i,v in pairs(newremiliaspear.Attachm122ent:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
		end
		task.delay(11/60,function()
			vortex()
		end)
		task.delay(22/60,function()
			vortex()
		end)
		task.delay(30/60,function()
			vortex()
		end)
		task.delay(41/60,function()
			vortex()
		end)
		task.delay(55/60,function()
			vortex()
		end)
		task.delay(70/60,function()
			vortex()
		end)
		task.delay(90/60,function()
			vortex()
		end)
		task.delay(110/60,function()
			vortex()
		end)
		task.delay(230/60,function()
			emit(Directory.appear522,false)
		end)
		task.delay(250/60,function()
			emit(Directory.appear522,false)
		end)
		task.delay(270/60,function()
			emit(Directory.appear522,false)
		end)
		task.delay(290/60,function()
			emit(Directory.appear522,false)
		end)
		task.delay(310/60,function()
			emit(Directory.appear522,false)
		end)
		task.delay(330/60,function()
			emit(Directory.appear522,false)
		end)
		task.delay(350/60,function()
			emit(Directory.appear522,false)
		end)
		task.delay(370/60,function()
			emit(Directory.appear522,false)
		end)
		task.delay(392/60,function()
			emit(Directory.appear522,false)
		end)
		task.delay(115/60,function()
			for i,v in pairs(newremiliaspear:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') and v:GetAttribute("aurae") then
						v.Enabled = false
						while enabled == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							v:Emit(4)
						end
					end
				end))
			end
		end)
		task.delay(391/60,function()
			if newremiliaspear ~= nil then
				newremiliaspear:Destroy()
			end
		end)
	end,
	["REMILIASPEARSPIN"] = function(Character)
		if Character:FindFirstChild("remiliaspearspinlolz") then
			local modelclone2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX
			--modelclone2.Parent = workspace.Ignore.Effects
			--game.Debris:AddItem(modelclone2,150/60)
			local cframe = Character.HumanoidRootPart.CFrame * CFrame.new(0,0,7)
			--modelclone2:SetPrimaryPartCFrame(cframe)
			--local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
			--local Directory2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
			local Directory = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
			local function emit(instance,weld,characterc)
				local instanceclone = instance:Clone()
				instanceclone.CFrame = characterc.HumanoidRootPart.CFrame * instance.CFrame
				if weld == true then
					local Weld = Instance.new("WeldConstraint")
					Weld.Part0 = characterc.HumanoidRootPart
					Weld.Part1 = instanceclone
					Weld.Name = instanceclone.Name
					Weld.Parent = characterc.HumanoidRootPart	
				else
					instanceclone.Anchored = true
				end
				instanceclone.Parent = workspace.Ignore.Effects
				if instanceclone:FindFirstChildOfClass("Model") then
					for i,v in pairs(instanceclone:GetDescendants()) do
						if v:IsA('Model') and v:FindFirstChild("Start") then
							local modelclone = v
							modelclone:SetPrimaryPartCFrame(characterc.HumanoidRootPart.CFrame * v.Start.CFrame)
							modelclone.Parent = game.Workspace.Ignore.Effects
							task.delay(modelclone:GetAttribute("EmitDelay"),function()
								local decalparams
								if modelclone:GetAttribute("Decal_TweenParams") then
									decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
								else
									local decalparams2 = "Cubic,Out"
									decalparams = string.split(decalparams2, ",")
								end
								local partparams
								if modelclone:GetAttribute("Part_TweenParams") then
									partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
								else
									local partparams2 = "Cubic,Out"
									partparams = string.split(partparams2, ",")
								end
								game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame,Size = modelclone:FindFirstChild("End").Size}):Play()
								v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
								game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
							end)
							--for ie,ve in pairs(modelclone:GetChildren()) do
							--end
						end
					end
				end

				game.Debris:AddItem(instanceclone,4)
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if characterc["Right Arm"]:FindFirstChild("remiliaspear") then
							if characterc["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
			local function vineta()
				coroutine.resume(coroutine.create(function()
					if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 40 then
						redvignette()
						local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
							Camera.CFrame = Camera.CFrame * shakeCf
						end)
						camShake:ShakeOnce(5, 5, .4,.6)
						--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
						camShake:Start()
					end
				end))
			end
			emit(Directory.impact5REMI,false,Character)
			emit(Directory.impact5REMIVAMPIREton,false,Character)
			emitsum(modelclone2["Spawn 84"],modelclone2,cframe,Character)
			emitsum(modelclone2["SpawnHit 84"],modelclone2,cframe,Character)
			emitsum(modelclone2["Wind2 84"],modelclone2,cframe,Character)
			vineta()
			local spearspinname = ("SpinningRemiliaSpear")
			if (Character["Right Arm"]:FindFirstChild("remiliaspear")) then
				if (Character["Right Arm"]:FindFirstChild("remiliaspear")):FindFirstChild("SKINDATA") then
					if game.ReplicatedStorage.Assets.VFX["Scarlet Empress"]:FindFirstChild(spearspinname..(Character["Right Arm"]:FindFirstChild("remiliaspear")):FindFirstChild("SKINDATA").Value) then
					spearspinname = spearspinname..(Character["Right Arm"]:FindFirstChild("remiliaspear")):FindFirstChild("SKINDATA").Value
					end
				end
			end
			local remiliaspearspin = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"][spearspinname]:Clone()
			remiliaspearspin.Parent = workspace.Ignore.Effects
			remiliaspearspin.HumanoidRootPart.CFrame = Character.HumanoidRootPart.CFrame
			local shide = remiliaspearspin
			local animation = shide.MainAnimation
			local humanoid = shide.AnimationController
			local mainAnim = humanoid:LoadAnimation(animation)
			mainAnim:Play()
			mainAnim:AdjustSpeed(1)
			local attacking = true
			local enablorou = true
			coroutine.resume(coroutine.create(function()
				for i,v in pairs(remiliaspearspin.remiliaspear:GetDescendants()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA('ParticleEmitter') then
							while enablorou do
								local rate = v.Rate
								if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
									rate = v.Rate / 5
								end
								wait(1/rate)
								v:Emit(3)
							end
						end
					end))
				end
			end))
			if (Character["Right Arm"]:FindFirstChild("remiliaspear")) then
				for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
					if v:IsA("BasePart") and v.Transparency == 0 then
						v.Transparency = 5
					end
				end
			end
			local bigcsframe = CFrame.new(0,0,-15)
			local conn1
			local conn2
			local finished = false
			conn2 = Character.ChildAdded:Connect(function(child)
				if child.Name == ("SKILL2FINISHERATT") then
					if conn2 then 
						conn2:Disconnect()
					end
					finished = true
					if Character["Right Arm"]:FindFirstChild("remiliaspear") then
						if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("redmisthorion") then
							task.delay(.1,function()
								enablorou = false
							end)
						else
							enablorou = false
						end
					else
						enablorou = false
					end
					if remiliaspearspin then
						for i,v in pairs(remiliaspearspin:GetDescendants()) do
							if v:IsA("BasePart") then
								if v.Transparency == 0 then
									v.Transparency = 5
								end
							end
						end
						for i,v in pairs(remiliaspearspin:GetDescendants()) do
							if v:IsA('ParticleEmitter') then
								if Character["Right Arm"]:FindFirstChild("remiliaspear") then
									if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("redmisthorion") then
									else
										v:Destroy()
									end
								else
									v:Destroy()
								end
							end
							if v:IsA('Decal') then
								v.Transparency = 1
							end
							if v:IsA('Trail') then
								v.Enabled = false
							end
							if v:IsA('Beam') then
								v.Enabled = false
							end
							if v:IsA('PointLight') then
								v.Enabled = false
							end
						end
					end

					bigcsframe = CFrame.new(0,11,-13)
					game:GetService("TweenService"):Create(remiliaspearspin.remiliaspear.spinloop,TweenInfo.new(.5,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 0}):Play()
				end
			end)
			conn1 = Character:FindFirstChild("remiliaspearspinlolz").Destroying:Connect(function()
				if conn1 then 
					conn1:Disconnect()
				end
				if conn2 then 
					conn2:Disconnect()
				end
				attacking = false
				if Character["Right Arm"]:FindFirstChild("remiliaspear") then
					if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("redmisthorion") then
						task.delay(.1,function()
							enablorou = false
						end)
					else
						enablorou = false
					end
				else
					enablorou = false
				end
				if remiliaspearspin then
					if finished == true then
						remiliaspearspin.remiliaspear.spinloop.Volume = .5
						for i,v in pairs(remiliaspearspin:GetDescendants()) do
							if v:IsA("BasePart") then
								if v.Transparency == 5 then
									v.Transparency = 0
								end
							end
						end
						for i,v in pairs(remiliaspearspin:GetDescendants()) do
							if v:IsA('ParticleEmitter') then
								if Character["Right Arm"]:FindFirstChild("remiliaspear") then
									if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("redmisthorion") then
									else
										v:Destroy()
									end
								else
									v:Destroy()
								end
							end
							if v:IsA('Decal') then
								v.Transparency = 0
							end
							if v:IsA('Trail') then
								v.Enabled = true
							end
							if v:IsA('Beam') then
								v.Enabled = true
							end
							if v:IsA('PointLight') then
								v.Enabled = true
							end
						end
					end
					local waittime = .12
					game:GetService("TweenService"):Create(remiliaspearspin.HumanoidRootPart,TweenInfo.new(waittime,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{CFrame = Character.HumanoidRootPart.CFrame}):Play()
					game:GetService("TweenService"):Create(remiliaspearspin.remiliaspear.spinloop,TweenInfo.new(.5,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 0}):Play()
					local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.heartbreakstartupsfx2end:Clone()
					sound1.Parent = Character.HumanoidRootPart
					sound1:Play()
					game.Debris:AddItem(sound1,2)
					task.delay(waittime,function()
						for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Shine1:GetDescendants()) do
							if v:IsA('ParticleEmitter') then
								if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
									v:Emit((v:GetAttribute('EmitCount') or 1)/6)
								else
									v:Emit((v:GetAttribute('EmitCount')) or 1)
								end
							end
						end
						coroutine.resume(coroutine.create(function()
							if remiliaspearspin then
								for i,v in pairs(remiliaspearspin:GetDescendants()) do
									if v:IsA("BasePart") then
										v.Transparency = 1
									end
								end
							end
						end))
						if (Character["Right Arm"]:FindFirstChild("remiliaspear")) then
							for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
								if v:IsA("BasePart") and v.Transparency == 5 then
									v.Transparency = 0
								end
							end
						end
					end)
					if Character["Right Arm"]:FindFirstChild("remiliaspear") then
						if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("redmisthorion") then
							game.Debris:AddItem(remiliaspearspin,2.1)
						else
							game.Debris:AddItem(remiliaspearspin,1)
						end
					else
						game.Debris:AddItem(remiliaspearspin,1)
					end
					for i,v in pairs(remiliaspearspin:GetDescendants()) do
						if v:IsA('ParticleEmitter') then
							if Character["Right Arm"]:FindFirstChild("remiliaspear") then
								if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("redmisthorion") then
								else
									v:Destroy()
								end
							else
								v:Destroy()
							end
						end
						--if v:IsA('BasePart') then
						--	game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
						--end
						if v:IsA('Decal') then
							v.Transparency = 1
						end
						if v:IsA('Trail') then
							v.Enabled = false
							v.Lifetime = .3
						end
						if v:IsA('Beam') then
							game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0}):Play()
							game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width1 = 0}):Play()
						end
						if v:IsA('PointLight') then
							game:GetService("TweenService"):Create(v,TweenInfo.new(.4,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Range = 0}):Play()
						end
					end
				end
			end)
			game:GetService("TweenService"):Create(remiliaspearspin.remiliaspear.spinloop,TweenInfo.new(.4,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = .5}):Play()
			while attacking do
				game:GetService("TweenService"):Create(remiliaspearspin.HumanoidRootPart,TweenInfo.new(.06,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{CFrame = Character.HumanoidRootPart.CFrame * bigcsframe}):Play()
				task.wait(.06)
			end
		end
	end,
	["SPEARTHROW1"] = function(EXPLCFRAME,Character)
		local Projectile = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].heartbreakult:clone()
		Projectile.Parent = workspace.Ignore.Effects
		Projectile.Anchored = true
		Projectile.CFrame = CFrame.lookAt((Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-3) * CFrame.Angles(0,0,0)).p,EXPLCFRAME)
		--if not Projectile:FindFirstChild("FINISHERKNIFE") then
		local tweenzo = game:GetService("TweenService"):Create(Projectile,TweenInfo.new(.2,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{CFrame = CFrame.new(EXPLCFRAME) * Projectile.CFrame.Rotation})
		tweenzo:Play()
		local enabled = true
		for i,v in pairs(Projectile:GetDescendants()) do
			coroutine.resume(coroutine.create(function()
				if v:IsA('ParticleEmitter') and v.Enabled == true then
					v.Enabled = false
					while enabled == true do
						local rate = v.Rate
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							rate = v.Rate / 5
						end
						wait(1/rate)
						v:Emit(4)
					end
				end
			end))
		end
		local Directory5 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
		local a = Directory.aheartk:Clone()
		a.Parent = workspace.Ignore.Effects
		a.CFrame = Projectile.CFrame
		for i,v in pairs(a:GetDescendants()) do
			coroutine.resume(coroutine.create(function()
				if v:IsA('ParticleEmitter') then
					while enabled == true do
						local rate = v.Rate
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							rate = v.Rate / 5
						end
						wait(1/rate)
						v:Emit(1)
					end
				end
			end))
		end
		local Directory3 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol

		local function emit1(instance,weld,enable)
			coroutine.resume(coroutine.create(function()
				local instanceclone = instance:Clone()
				if instanceclone:IsA("Model") then
					instanceclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * instance.PrimaryPart.CFrame)
				else
					instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
					instanceclone.Massless = true
					instanceclone.CanCollide = false
					instanceclone.RootPriority = -127
				end
				coroutine.resume(coroutine.create(function()
					for i,v in pairs(instanceclone:GetDescendants()) do
						coroutine.resume(coroutine.create(function()
							if v:IsA('ParticleEmitter') and (v:GetAttribute("BaseRate") or v:GetAttribute("BaseEmitCount")) and v:GetAttribute("EmitDuration")  then
								if v:GetAttribute("EmitDelay") then
									wait(v:GetAttribute("EmitDelay"))
								end
								local enabled = true
								local start = os.clock()
								coroutine.resume(coroutine.create(function()
									while enabled == true do
										wait()
										if (os.clock() - start >= v:GetAttribute("EmitDuration")) then
											enabled = false
										end
									end
								end))
								while enabled == true do
									wait(1/v:GetAttribute("BaseRate"))
									v:Emit(v:GetAttribute("BaseEmitCount") or v:GetAttribute("EmitCount"))
								end
							end
						end))
					end
				end))
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('BasePart') then
						v.Massless = true
						v.CanCollide = false
						v.RootPriority = -127
					end
				end
				if weld == true then
					local Weld = Instance.new("WeldConstraint")
					Weld.Part0 = Character.HumanoidRootPart
					Weld.Part1 = instanceclone
					Weld.Name = instanceclone.Name
					Weld.Parent = instanceclone	
				else
					instanceclone.Anchored = true
				end
				instanceclone.Parent = workspace.Ignore.Effects
				instanceclone:SetAttribute(Character.Name.."VFX")
				if instanceclone:IsA("Model") then
					for i,v in pairs(instanceclone:GetDescendants()) do
						if v:IsA('BasePart') then
							v.Anchored = true
						end
					end
					instanceclone:BreakJoints()
				end
				if instanceclone:FindFirstChild("impact5") then
					task.delay((136/60)-(100/60),function()
						for i,v in pairs(instanceclone.bl22:GetDescendants()) do
							if v:IsA('ParticleEmitter') then
								v.Enabled = true
								task.delay(24/60,function()
									v.Enabled = false
								end)
							end
						end
						for i,v in pairs(instanceclone.bl2:GetDescendants()) do
							if v:IsA('ParticleEmitter') then
								v.Enabled = true
								task.delay(24/60,function()
									v.Enabled = false
								end)
							end
						end
					end)
				end
				game.Debris:AddItem(instanceclone,5)
				if enable == true then
					for i,v in pairs(instanceclone:GetDescendants()) do
						coroutine.resume(coroutine.create(function()
							if v:IsA('ParticleEmitter') then
								if v:GetAttribute("EmitDelay") then
									wait(v:GetAttribute("EmitDelay"))
								end
								local enabled = true
								task.delay((458-304)/60,function()
									enabled = false
								end)
								local start = os.clock()
								coroutine.resume(coroutine.create(function()
									while enabled == true do
										wait()
										if (os.clock() - start >= v:GetAttribute("EmitDuration")) then
											enabled = false
										end
									end
								end))
								while enabled == true do
									local rate = v.Rate
									if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
										rate = v.Rate / 5
									end
									wait(1/rate)
									--if v:GetAttribute("BaseEmitCount") and v:GetAttribute("BaseEmitCount") >= 20 then
									v:Emit(1)
									--else
									--	v:Emit(v:GetAttribute("BaseEmitCount") or v:GetAttribute("EmitCount"))
									--end
								end
							end
						end))
					end
				else
					for i,v in pairs(instanceclone:GetDescendants()) do
						if v:IsA('ParticleEmitter') then
							--if enable == true then
							--	v.Enabled = true
							--	task.delay((458-304)/60,function()
							--		v.Enabled = false
							--	end)
							--end
							if v:GetAttribute("EmitDelay") then
								task.delay(v:GetAttribute("EmitDelay"),function()
									if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
										v:Emit((v:GetAttribute('EmitCount') or 1)/6)
									else
										v:Emit((v:GetAttribute('EmitCount')) or 1)
									end
								end)
							else
								if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
									v:Emit((v:GetAttribute('EmitCount') or 1)/6)
								else
									v:Emit((v:GetAttribute('EmitCount')) or 1)
								end
							end
						end
					end
				end
				if instanceclone:FindFirstChildOfClass("Model") then
					for i,v in pairs(instanceclone:GetDescendants()) do
						if v:IsA('Model') and v:FindFirstChild("Start") then
							local modelclone = v
							--modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.PrimaryPart.CFrame)
							modelclone.Parent = game.Workspace.Ignore.Effects
							task.delay(modelclone:GetAttribute("EmitDelay"),function()
								local decalparams
								if modelclone:GetAttribute("Decal_TweenParams") then
									decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
								else
									local decalparams2 = "Cubic,Out"
									decalparams = string.split(decalparams2, ",")
								end
								local partparams
								if modelclone:GetAttribute("Part_TweenParams") then
									partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
								else
									local partparams2 = "Cubic,Out"
									partparams = string.split(partparams2, ",")
								end
								game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration") or modelclone:GetAttribute("EmitDuration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame,Size = modelclone:FindFirstChild("End").Size}):Play()
								if not v.Start:FindFirstChildOfClass("Decal") then
									if modelclone:GetAttribute("Duration") or modelclone:GetAttribute("EmitDuration") then
										game.Debris:AddItem(modelclone,(modelclone:GetAttribute("Duration") or modelclone:GetAttribute("EmitDuration")) +.003)
									end
								end
								if v.Start:FindFirstChildOfClass("Decal") then
									v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
									game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration")  or modelclone:GetAttribute("EmitDuration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
								end
							end)
						end
					end
				end
			end))
		end
		emit1(Directory3.impact5REMI,true)
		--emit1(Directory3.impact5REMIVAMPIREton,true)
		local RedFX24215=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.gungnirsound2:Clone()
		RedFX24215.Parent = Character.HumanoidRootPart
		game.Debris:AddItem(RedFX24215,3)
		RedFX24215:Play()
		game:GetService("TweenService"):Create(a.Sound,TweenInfo.new(.15,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 1}):Play()
		coroutine.resume(coroutine.create(function()
			--emit(Directory5.impact5REMI,false)
			--emit(Directory5.impact5REMIVAMPIREton,false)
			--local RedFX=ResourceFolder.Emit:Clone()
			--RedFX.CFrame = Projectile.CFrame * CFrame.new(1.2,0,4)
			--Debris:AddItem(RedFX,2.6)
			--RedFX.Parent = workspace.Ignore.Effects
			--RedFX.sfx:Play()
			--RedFX.sfx2:Play()
			--RedFX.sfx3:Play()
			--RedFX.CanQuery = false
			--RedFX.CanCollide = false

			--local p5=ResourceFolder.Parent.Parent["Scarlet Empress"].Combat.wind2:Clone()
			--Debris:AddItem(p5,.31)
			--p5.Parent= workspace.Ignore.Effects
			--p5.CFrame=  Projectile.CFrame * CFrame.new(1.2,.4,-4) * CFrame.Angles(0,math.rad(90),0)

			--local TweenFX = game:GetService("TweenService"):Create(p5, TweenInfo.new(0.3, Enum.EasingStyle.Sine,Enum.EasingDirection.Out), {Transparency = 1,Size = Vector3.new(0.15, 15.92, 15.92) })
			--TweenFX:Play()
			--if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 1 then
			--	local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
			--		Camera.CFrame = Camera.CFrame * shakeCf
			--	end)
			--	camShake:ShakeOnce(6, 6, .4,.4)
			--	--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
			--	camShake:Start()
			--end
		end))
		coroutine.resume(coroutine.create(function()
			while enabled == true do
				if a ~= nil then
					game:GetService("TweenService"):Create(a,TweenInfo.new(.1,Enum.EasingStyle.Linear),{CFrame = Projectile.CFrame}):Play()
				else
					break
				end
				wait()
			end
		end))
		for i,v in pairs(Projectile:GetChildren()) do
			if v.Name:match("launch") then
				for ie,ve in pairs(v:GetDescendants()) do
					if ve:IsA('ParticleEmitter') then
						ve:Emit(ve:GetAttribute("EmitCount") or 5)
					end
				end
			end
		end
		local function emit25122(instance,weld,enable)
			local instanceclone = instance
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			coroutine.resume(coroutine.create(function()
				for i,v in pairs(instanceclone:GetDescendants()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA("ParticleEmitter") then
							v.Enabled = false
						end
						if v:IsA('ParticleEmitter') and (v:GetAttribute("BaseRate") or v:GetAttribute("BaseEmitCount")) and v:GetAttribute("EmitDuration")  then
							if v:GetAttribute("EmitDelay") then
								wait(v:GetAttribute("EmitDelay"))
							end
							local enabled = true
							local start = os.clock()
							coroutine.resume(coroutine.create(function()
								while enabled == true do
									wait()
									if (os.clock() - start >= 1.5) then
										enabled = false
									end
								end
							end))
							while enabled == true do
								wait(1/v:GetAttribute("BaseRate"))
								v:Emit(1)
							end
						end
					end))
				end
			end))
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('BasePart') then
					v.Massless = true
					v.CanCollide = false
					v.RootPriority = -127
				end
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							--local decalparams
							--if modelclone:GetAttribute("Decal_TweenParams") then
							--	decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							--else
							--	local decalparams2 = "Cubic,Out"
							--	decalparams = string.split(decalparams2, ",")
							--end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							--v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							--game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)

					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end

		tweenzo.Completed:Wait()
		for i,v in pairs(Projectile:GetDescendants()) do
			if v:IsA('BasePart') or v:IsA('Decal') or v:IsA('Texture') then
				coroutine.resume(coroutine.create(function()
					if v ~= nil then
						game:GetService("TweenService"):Create(v,TweenInfo.new(.4,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 1,Size = Vector3.new(0,0,0)}):Play()
					end
				end))
			end
			if v:IsA('ParticleEmitter') or v:IsA('Beam') or v:IsA('Trail') then
				coroutine.resume(coroutine.create(function()
					v.Enabled = false
				end))
			end
		end
		local crossenable=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].crossenable:Clone()
		local explcross=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].explcross:Clone()
		explcross.Parent = workspace.Ignore.Effects
		crossenable.Parent = workspace.Ignore.Effects
		explcross.CFrame = Character.HumanoidRootPart.CFrame
		crossenable.CFrame = Character.HumanoidRootPart.CFrame
		local rotation = crossenable.CFrame.Rotation
		explcross.CFrame = CFrame.new(EXPLCFRAME + Vector3.new(0,explcross.Size.Y/2,0)) * rotation
		crossenable.CFrame = CFrame.new(EXPLCFRAME + Vector3.new(0,crossenable.Size.Y/2,0))* rotation
		game.Debris:AddItem(crossenable,5)
		game.Debris:AddItem(explcross,5)
		local sound2=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.ncrsfxexpl:Clone()
		sound2.Parent = crossenable
		sound2:Play()
		game.Debris:AddItem(sound2,6)
		--emit25122(crossenable,false,false)
		coroutine.resume(coroutine.create(function()
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - crossenable.Position).Magnitude <= 110 then
				redvignette()
				game.Lighting.BlackFlash.Enabled = true
				task.delay(8/60,function()
					game.Lighting.BlackFlash.Enabled = false
				end)
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(12, 12, .3,1)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end))
		local enabled5215 = true
		for i,v in pairs(crossenable:GetDescendants()) do
			coroutine.resume(coroutine.create(function()
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute("EmitCount") or 1)
				end
				if v:IsA('Beam') then
					local width0 = v.Width0
					local width1 = v.Width1
					v.Width0 = 0
					v.Width1 = 0
					game:GetService("TweenService"):Create(v,TweenInfo.new(.2,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = width0,Width1 = width1}):Play()
				end
			end))
		end
		for i,v in pairs(crossenable:GetDescendants()) do
			coroutine.resume(coroutine.create(function()
				if v:IsA('ParticleEmitter') and v.Enabled == true then
					v.Enabled = false
					while enabled5215 == true do
						local rate = v.Rate
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							rate = v.Rate / 5
						end
						wait(1/rate)
						v:Emit(1)
					end
				end
			end))
		end
		coroutine.resume(coroutine.create(function()
			while enabled5215 == true do
				for i,v in pairs(crossenable:GetChildren()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v:Clone()
						modelclone.Parent = workspace.Ignore.Effects
						game.Debris:AddItem(modelclone,4)
						--local decalparams
						--if modelclone:GetAttribute("Decal_TweenParams") then
						--	decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
						--else
						--	local decalparams2 = "Cubic,Out"
						--	decalparams = string.split(decalparams2, ",")
						--end
						local partparams
						if modelclone:GetAttribute("Part_TweenParams") then
							partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
						else
							local partparams2 = "Cubic,Out"
							partparams = string.split(partparams2, ",")
						end
						modelclone.Start.Transparency = .6
						game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame,Size = modelclone:FindFirstChild("End").Size,Transparency = 1}):Play()
						--modelclone.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
						--game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
					end
				end
				wait(1/5)
			end
		end))
		task.delay(1.5,function()
			enabled5215 = false
			for i,v in pairs(crossenable:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
				if v:IsA('PointLight') then
					game.TweenService:Create(v,TweenInfo.new(.1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,0,false,.95),{Brightness = 0,Range = 0}):Play()
				end
				if v:IsA('Beam') then
					game:GetService("TweenService"):Create(v,TweenInfo.new(.7,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0}):Play()
					game:GetService("TweenService"):Create(v,TweenInfo.new(.7,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width1 = 0}):Play()
				end
			end
			for i,v in pairs(explcross:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA("ParticleEmitter") then
						v:Emit(v:GetAttribute("EmitCount") or 1)
					end
				end))
			end
			for i,v in pairs(crossenable:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA("ParticleEmitter") then
						v:Emit(v:GetAttribute("EmitCount") or 1)
					end
				end))
			end
		end)
		--local conn1
		--conn1 = Projectile.ChildAdded:Connect(function(Child)
		--if Child.Name == ("FINISHERKNIFE") then
		--	if conn1 then 
		--		conn1:Disconnect()
		--	end
		--wait(.037)
		game:GetService("TweenService"):Create(a,TweenInfo.new(.4,Enum.EasingStyle.Linear),{CFrame = Projectile.CFrame}):Play()
		Projectile.HeartbreakExplosionSFX:Play()
		game.Debris:AddItem(Projectile,.7)
		--emit(Directory.expl2heart,false)
		--game.Debris:AddItem(Projectile,5)
		game:GetService("TweenService"):Create(a.Sound,TweenInfo.new(.3,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 0}):Play()
		game.Debris:AddItem(a,.4)
		--for i,v in pairs(Projectile:GetChildren()) do
		--	if not v:IsA("Sound") then
		--		v:Destroy()
		--	end
		--end
		--task.delay(2,function()
		--	game:GetService("TweenService"):Create(Projectile,TweenInfo.new(.5,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
		--	for i,v in pairs(Projectile:GetDescendants()) do
		--		if v:IsA('ParticleEmitter') then
		--			v.Enabled = false
		--		end
		--		if v:IsA('BasePart') then
		--			game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
		--		end
		--		if v:IsA('Decal') then
		--			v.Transparency = 1
		--		end
		--		if v:IsA('Trail') then
		--			v.Enabled = false
		--			v.Lifetime = .3
		--		end
		--		if v:IsA('Beam') then
		--			game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0}):Play()
		--			game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width1 = 0}):Play()
		--		end
		--		if v:IsA('PointLight') then
		--			game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Range = 0}):Play()
		--		end
		--	end
		--end)
		enabled = false
		--end
		--end)
		--end
	end,
	["HEARTBREAKLOOPVFX2"] = function(EXPLCFRAME,Character,CharacterCFrame)
		local throwableknivesname = ("heartbreak")
		if (Character["Right Arm"]:FindFirstChild("remiliaspear")) then
			if (Character["Right Arm"]:FindFirstChild("remiliaspear")):FindFirstChild("SKINDATA") then
				if game.ReplicatedStorage.Modules["RemiliaSpearsThrowable"]:FindFirstChild(throwableknivesname..(Character["Right Arm"]:FindFirstChild("remiliaspear")):FindFirstChild("SKINDATA").Value) then
					throwableknivesname = throwableknivesname..(Character["Right Arm"]:FindFirstChild("remiliaspear")):FindFirstChild("SKINDATA").Value
				end
			end
		end
		local Projectile = game.ReplicatedStorage.Modules.RemiliaSpearsThrowable[throwableknivesname]:Clone()
		Projectile.Parent = workspace.Ignore.Effects
		Projectile.Anchored = true
		Projectile.CFrame = CharacterCFrame * CFrame.new(0,0,-1) * CFrame.Angles(0,0,0)
		local time15 = (((CharacterCFrame).Position - EXPLCFRAME.Position).magnitude) / 100
		local tweenzo = game:GetService("TweenService"):Create(Projectile,TweenInfo.new(time15,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{CFrame = CFrame.new(EXPLCFRAME.Position) * CharacterCFrame.Rotation})
		tweenzo:Play()
		local enabled = true
			for i,v in pairs(Projectile:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') and v.Enabled == true then
						v.Enabled = false
						while enabled == true do
						local rate = v.Rate
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							rate = v.Rate / 5
						end
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
										v.Color = ColorSequence.new{
											ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
											ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
										}
							end
						end
						wait(1/rate)
						v:Emit(1)
						end
					end
				end))
			end
			local Directory5 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
			local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
			local a = Directory.aheartk:Clone()
			a.Parent = workspace.Ignore.Effects
			a.CFrame = Projectile.CFrame
		--	for i,v in pairs(a:GetDescendants()) do
		--		coroutine.resume(coroutine.create(function()
		--			if v:IsA('ParticleEmitter') then
		--				while enabled == true do
		--local rate = v.Rate
		--if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
		--	rate = v.Rate / 5
		--end
		--wait(1/rate)
		--					v:Emit(1)
		--				end
		--			end
		--		end))
		--end
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Projectile.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = Character.HumanoidRootPart	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Projectile.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
					end
				end
			end
		end
		local RedFX24215=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.gungnirsound2:Clone()
		RedFX24215.Parent = Character.HumanoidRootPart
		game.Debris:AddItem(RedFX24215,3)
		RedFX24215:Play()
		game:GetService("TweenService"):Create(a.Sound,TweenInfo.new(.15,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 1}):Play()
		coroutine.resume(coroutine.create(function()
			emit(Directory5.impact5REMI,false)
			emit(Directory5.impact5REMIVAMPIREton,false)
			local RedFX=ResourceFolder.Emit:Clone()
			RedFX.CFrame = Projectile.CFrame * CFrame.new(1.2,0,4)
			Debris:AddItem(RedFX,2.6)
			RedFX.Parent = workspace.Ignore.Effects
			RedFX.sfx:Play()
			RedFX.sfx2:Play()
			RedFX.sfx3:Play()
			RedFX.CanQuery = false
			RedFX.CanCollide = false

			local p5=ResourceFolder.Parent.Parent["Scarlet Empress"].Combat.wind2:Clone()
			Debris:AddItem(p5,.31)
			p5.Parent= workspace.Ignore.Effects
			p5.CFrame=  Projectile.CFrame * CFrame.new(1.2,.4,-4) * CFrame.Angles(0,math.rad(90),0)

			local TweenFX = game:GetService("TweenService"):Create(p5, TweenInfo.new(0.3, Enum.EasingStyle.Sine,Enum.EasingDirection.Out), {Transparency = 1,Size = Vector3.new(0.15, 15.92, 15.92) })
			TweenFX:Play()
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 1 then
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(6, 6, .4,.4)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end))
		coroutine.resume(coroutine.create(function()
			while enabled == true do
				if a ~= nil then
					game:GetService("TweenService"):Create(a,TweenInfo.new(.1,Enum.EasingStyle.Linear),{CFrame = Projectile.CFrame}):Play()
				else
					break
				end
				wait()
			end
		end))
		for i,v in pairs(Projectile:GetChildren()) do
			if v.Name:match("launch") then
				for ie,ve in pairs(v:GetDescendants()) do
					if ve:IsA('ParticleEmitter') then
						ve:Emit(ve:GetAttribute("EmitCount") or 1)
					end
				end
			end
		end
tweenzo.Completed:Wait()
			--local conn1
			--conn1 = Projectile.ChildAdded:Connect(function(Child)
				--if Child.Name == ("FINISHERKNIFE") then
				--	if conn1 then 
				--		conn1:Disconnect()
				--	end
					--wait(.037)
					game:GetService("TweenService"):Create(a,TweenInfo.new(.4,Enum.EasingStyle.Linear),{CFrame = Projectile.CFrame}):Play()
					Projectile.HeartbreakExplosionSFX:Play()
					emit(Directory.expl2heart,false)
					game.Debris:AddItem(Projectile,5)
					game:GetService("TweenService"):Create(a.Sound,TweenInfo.new(.3,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 0}):Play()
					game.Debris:AddItem(a,.4)
					for i,v in pairs(Projectile:GetChildren()) do
						if not v:IsA("Sound") then
							v:Destroy()
						end
					end
					game:GetService("TweenService"):Create(Projectile,TweenInfo.new(.5,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
					for i,v in pairs(Projectile:GetDescendants()) do
						if v:IsA('ParticleEmitter') then
							v.Enabled = false
						end
						if v:IsA('BasePart') then
							game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
						end
						if v:IsA('Decal') then
							v.Transparency = 1
						end
						if v:IsA('Trail') then
							v.Enabled = false
							v.Lifetime = .3
						end
						if v:IsA('Beam') then
							game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0}):Play()
							game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width1 = 0}):Play()
						end
						if v:IsA('PointLight') then
							game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Range = 0}):Play()
						end
					end
					enabled = false
				--end
			--end)
		--end
	end,
	["HEARTBREAKLOOPVFX"] = function(Projectile,Character)
		if not Projectile:FindFirstChild("FINISHERKNIFE") then
			local enabled = true
			for i,v in pairs(Projectile:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') and v.Enabled == true then
						v.Enabled = false
						while enabled == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							v:Emit(1)
						end
					end
				end))
			end
			local Directory5 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
			local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
			local a = Directory.aheartk:Clone()
			a.Parent = workspace.Ignore.Effects
			a.CFrame = Projectile.CFrame
			for i,v in pairs(a:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						while enabled == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							v:Emit(1)
						end
					end
				end))
			end
			local function emit(instance,weld,enable)
				local instanceclone = instance:Clone()
				instanceclone.CFrame = Projectile.CFrame * instance.CFrame
				if weld == true then
					local Weld = Instance.new("WeldConstraint")
					Weld.Part0 = Character.HumanoidRootPart
					Weld.Part1 = instanceclone
					Weld.Name = instanceclone.Name
					Weld.Parent = Character.HumanoidRootPart	
				else
					instanceclone.Anchored = true
				end
				instanceclone.Parent = workspace.Ignore.Effects
				if instanceclone:FindFirstChildOfClass("Model") then
					for i,v in pairs(instanceclone:GetDescendants()) do
						if v:IsA('Model') and v:FindFirstChild("Start") then
							local modelclone = v
							modelclone:SetPrimaryPartCFrame(Projectile.CFrame * v.Start.CFrame)
							modelclone.Parent = workspace.Ignore.Effects
							task.delay(modelclone:GetAttribute("EmitDelay"),function()
								local decalparams
								if modelclone:GetAttribute("Decal_TweenParams") then
									decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
								else
									local decalparams2 = "Cubic,Out"
									decalparams = string.split(decalparams2, ",")
								end
								local partparams
								if modelclone:GetAttribute("Part_TweenParams") then
									partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
								else
									local partparams2 = "Cubic,Out"
									partparams = string.split(partparams2, ",")
								end
								game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
								v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
								game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
							end)
						end
					end
				end

				game.Debris:AddItem(instanceclone,5)
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
			local RedFX24215=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.gungnirsound2:Clone()
			RedFX24215.Parent = Character.HumanoidRootPart
			game.Debris:AddItem(RedFX24215,3)
			RedFX24215:Play()
			game:GetService("TweenService"):Create(a.Sound,TweenInfo.new(.15,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 1}):Play()
			coroutine.resume(coroutine.create(function()
				emit(Directory5.impact5REMI,false)
				emit(Directory5.impact5REMIVAMPIREton,false)
				local RedFX=ResourceFolder.Emit:Clone()
				RedFX.CFrame = Projectile.CFrame * CFrame.new(1.2,0,4)
				Debris:AddItem(RedFX,2.6)
				RedFX.Parent = workspace.Ignore.Effects
				RedFX.sfx:Play()
				RedFX.sfx2:Play()
				RedFX.sfx3:Play()
				RedFX.CanQuery = false
				RedFX.CanCollide = false

				local p5=ResourceFolder.Parent.Parent["Scarlet Empress"].Combat.wind2:Clone()
				Debris:AddItem(p5,.31)
				p5.Parent= workspace.Ignore.Effects
				p5.CFrame=  Projectile.CFrame * CFrame.new(1.2,.4,-4) * CFrame.Angles(0,math.rad(90),0)

				local TweenFX = game:GetService("TweenService"):Create(p5, TweenInfo.new(0.3, Enum.EasingStyle.Sine,Enum.EasingDirection.Out), {Transparency = 1,Size = Vector3.new(0.15, 15.92, 15.92) })
				TweenFX:Play()
				if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 1 then
					local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
						Camera.CFrame = Camera.CFrame * shakeCf
					end)
					camShake:ShakeOnce(6, 6, .4,.4)
					--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
					camShake:Start()
				end
			end))
			local conn1
			conn1 = Projectile.ChildAdded:Connect(function(Child)
				if Child.Name == ("FINISHERKNIFE") then
					if conn1 then 
						conn1:Disconnect()
					end
					wait(.037)
					game:GetService("TweenService"):Create(a,TweenInfo.new(.4,Enum.EasingStyle.Linear),{CFrame = Projectile.CFrame}):Play()
					Projectile.HeartbreakExplosionSFX:Play()
					emit(Directory.expl2heart,false)
					game.Debris:AddItem(Projectile,5)
					game:GetService("TweenService"):Create(a.Sound,TweenInfo.new(.3,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 0}):Play()
					game.Debris:AddItem(a,.4)
					for i,v in pairs(Projectile:GetChildren()) do
						if not v:IsA("Sound") then
							v:Destroy()
						end
					end
					game:GetService("TweenService"):Create(Projectile,TweenInfo.new(.5,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
					for i,v in pairs(Projectile:GetDescendants()) do
						if v:IsA('ParticleEmitter') then
							v.Enabled = false
						end
						if v:IsA('BasePart') then
							game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
						end
						if v:IsA('Decal') then
							v.Transparency = 1
						end
						if v:IsA('Trail') then
							v.Enabled = false
							v.Lifetime = .3
						end
						if v:IsA('Beam') then
							game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0}):Play()
							game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width1 = 0}):Play()
						end
						if v:IsA('PointLight') then
							game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Range = 0}):Play()
						end
					end
					enabled = false
				end
			end)
			coroutine.resume(coroutine.create(function()
				while enabled == true do
					if a ~= nil then
						game:GetService("TweenService"):Create(a,TweenInfo.new(.1,Enum.EasingStyle.Linear),{CFrame = Projectile.CFrame}):Play()
					else
						break
					end
					wait()
				end
			end))
			for i,v in pairs(Projectile:GetChildren()) do
				if v.Name:match("launch") then
					for ie,ve in pairs(v:GetDescendants()) do
						if ve:IsA('ParticleEmitter') then
							ve:Emit(ve:GetAttribute("EmitCount") or 1)
						end
					end
				end
			end
		end
	end,
	["NCRNEWSTART"] = function(Character)
		local Directory3 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
		local Directory2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
		--local a = Directory.avampirek:Clone()
		--a.Parent = workspace.Ignore.Effects
		--a.CFrame = Character["Right Arm"].CFrame * CFrame.new(0,-1,0)
		local modelclone2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].UppercutMoveVFX
		local enabled = true
		local enabled25 = true
		--for i,v in pairs(a:GetDescendants()) do
		--	coroutine.resume(coroutine.create(function()
		--		if v:IsA('ParticleEmitter') then
		--			while enabled == true do
		--local rate = v.Rate
		--if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
		--	rate = v.Rate / 5
		--end
		--wait(1/rate)
		--				v:Emit(1)
		--			end
		--		end
		--	end))
		--end
		local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.ncrsfx:Clone()
		sound1.Parent = Character.Torso
		sound1:Play()
		game.Debris:AddItem(sound1,6)
		local function emit(instance,weld,enable)
			coroutine.resume(coroutine.create(function()
				local instanceclone = instance:Clone()
				if instanceclone:IsA("Model") then
					instanceclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * instance.PrimaryPart.CFrame)
				else
					instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
					instanceclone.Massless = true
					instanceclone.CanCollide = false
					instanceclone.RootPriority = -127
				end
				coroutine.resume(coroutine.create(function()
					for i,v in pairs(instanceclone:GetDescendants()) do
						coroutine.resume(coroutine.create(function()
							if v:IsA('ParticleEmitter') and (v:GetAttribute("BaseRate") or v:GetAttribute("BaseEmitCount")) and v:GetAttribute("EmitDuration")  then
								if v:GetAttribute("EmitDelay") then
									wait(v:GetAttribute("EmitDelay"))
								end
								local enabled = true
								local start = os.clock()
								coroutine.resume(coroutine.create(function()
									while enabled == true do
										wait()
										if (os.clock() - start >= v:GetAttribute("EmitDuration")) then
											enabled = false
										end
									end
								end))
								while enabled == true do
									wait(1/v:GetAttribute("BaseRate"))
									v:Emit(v:GetAttribute("BaseEmitCount") or v:GetAttribute("EmitCount"))
								end
							end
						end))
					end
				end))
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('BasePart') then
						v.Massless = true
						v.CanCollide = false
						v.RootPriority = -127
					end
				end
				if weld == true then
					local Weld = Instance.new("WeldConstraint")
					Weld.Part0 = Character.HumanoidRootPart
					Weld.Part1 = instanceclone
					Weld.Name = instanceclone.Name
					Weld.Parent = instanceclone	
				else
					instanceclone.Anchored = true
				end
				instanceclone.Parent = workspace.Ignore.Effects
				instanceclone:SetAttribute(Character.Name.."VFX")
				if instanceclone:IsA("Model") then
					for i,v in pairs(instanceclone:GetDescendants()) do
						if v:IsA('BasePart') then
							v.Anchored = true
						end
					end
					instanceclone:BreakJoints()
				end
				if instanceclone:FindFirstChild("impact5") then
					task.delay((136/60)-(100/60),function()
						for i,v in pairs(instanceclone.bl22:GetDescendants()) do
							if v:IsA('ParticleEmitter') then
								v.Enabled = true
								task.delay(24/60,function()
									v.Enabled = false
								end)
							end
						end
						for i,v in pairs(instanceclone.bl2:GetDescendants()) do
							if v:IsA('ParticleEmitter') then
								v.Enabled = true
								task.delay(24/60,function()
									v.Enabled = false
								end)
							end
						end
					end)
				end
				game.Debris:AddItem(instanceclone,5)
				if enable == true then
					for i,v in pairs(instanceclone:GetDescendants()) do
						coroutine.resume(coroutine.create(function()
							if v:IsA('ParticleEmitter') then
								if v:GetAttribute("EmitDelay") then
									wait(v:GetAttribute("EmitDelay"))
								end
								local enabled = true
								task.delay((458-304)/60,function()
									enabled = false
								end)
								local start = os.clock()
								coroutine.resume(coroutine.create(function()
									while enabled == true do
										wait()
										if (os.clock() - start >= v:GetAttribute("EmitDuration")) then
											enabled = false
										end
									end
								end))
								while enabled == true do
									local rate = v.Rate
									if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
										rate = v.Rate / 5
									end
									wait(1/rate)
									--if v:GetAttribute("BaseEmitCount") and v:GetAttribute("BaseEmitCount") >= 20 then
									v:Emit(1)
									--else
									--	v:Emit(v:GetAttribute("BaseEmitCount") or v:GetAttribute("EmitCount"))
									--end
								end
							end
						end))
					end
				else
					for i,v in pairs(instanceclone:GetDescendants()) do
						if v:IsA('ParticleEmitter') then
							--if enable == true then
							--	v.Enabled = true
							--	task.delay((458-304)/60,function()
							--		v.Enabled = false
							--	end)
							--end
							if v:GetAttribute("EmitDelay") then
								task.delay(v:GetAttribute("EmitDelay"),function()
									if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
										v:Emit((v:GetAttribute('EmitCount') or 1)/6)
									else
										v:Emit((v:GetAttribute('EmitCount')) or 1)
									end
								end)
							else
								if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
									v:Emit((v:GetAttribute('EmitCount') or 1)/6)
								else
									v:Emit((v:GetAttribute('EmitCount')) or 1)
								end
							end
						end
					end
				end
				if instanceclone:FindFirstChildOfClass("Model") then
					for i,v in pairs(instanceclone:GetDescendants()) do
						if v:IsA('Model') and v:FindFirstChild("Start") then
							local modelclone = v
							--modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.PrimaryPart.CFrame)
							modelclone.Parent = game.Workspace.Ignore.Effects
							task.delay(modelclone:GetAttribute("EmitDelay"),function()
								local decalparams
								if modelclone:GetAttribute("Decal_TweenParams") then
									decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
								else
									local decalparams2 = "Cubic,Out"
									decalparams = string.split(decalparams2, ",")
								end
								local partparams
								if modelclone:GetAttribute("Part_TweenParams") then
									partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
								else
									local partparams2 = "Cubic,Out"
									partparams = string.split(partparams2, ",")
								end
								game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration") or modelclone:GetAttribute("EmitDuration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame,Size = modelclone:FindFirstChild("End").Size}):Play()
								if not v.Start:FindFirstChildOfClass("Decal") then
									if modelclone:GetAttribute("Duration") or modelclone:GetAttribute("EmitDuration") then
										game.Debris:AddItem(modelclone,(modelclone:GetAttribute("Duration") or modelclone:GetAttribute("EmitDuration")) +.003)
									end
								end
								if v.Start:FindFirstChildOfClass("Decal") then
									v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
									game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration")  or modelclone:GetAttribute("EmitDuration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
								end
							end)
						end
					end
				end
			end))
		end
		local function emit2512(instance,weld,enable,OBJECT)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = OBJECT.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)

					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		local function slash()
			--if math.random(1,3) == 3 then
			emitsum152(modelclone2["Slash2125"],modelclone2,Character.HumanoidRootPart)
			--end		
			--emit(Directory3.impact5REMIVAMPIREton,true)
			--emit(Directory3.impact5REMIVAMPIREton2,true)
			--emit(Directory3.impact5UpperCutREMI,true)
			--emit(Directory3.impact4FrontDashWindREMI,true)
			emit(Directory2.slash1152,true)
			emitsum(modelclone2["GroundSlash2"],modelclone2,Character.HumanoidRootPart.CFrame)
		end
		task.delay(104/60,function()
			emit(Directory.ground1,false)

			local cframet2 = Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-10)
			local floorInstance = RayCastOnMap(cframet2.Position,Vector3.new(0,-5,0),true)
			--emitsum152(modelclone2["Slash2125"],modelclone2,Character.HumanoidRootPart)
			--emit(Directory2.slash1152,true)
			--emitsum(modelclone2["GroundSlash2"],modelclone2,Character.HumanoidRootPart.CFrame)
			--emit(Directory3.impact5DownslamREMI,true)
			if floorInstance then

				--emit(Directory3.impact3DownslamREMI1x,true)

				local crossenable=Directory2.slash2appr:Clone()
				crossenable.Parent = workspace.Ignore.Effects
				crossenable.CFrame = cframet2
				crossenable.Position = floorInstance.Position + Vector3.new(0,0.1,0)
				game.Debris:AddItem(crossenable,5)
				for i,v in pairs(crossenable:GetDescendants()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA('ParticleEmitter') then
							v:Emit(v:GetAttribute("EmitCount") or 1)
						end
					end))
				end
			end
		end)
		local attacking = true 
		task.delay(187/60,function()
			--emit(Directory.ground2,false)
			emit(Directory2.ground115,false)
			emit(Directory2.ground11,false)
		end)
		task.delay(80/60,function()
			attacking = false
		end)
		task.delay(28/60,function()
			coroutine.resume(coroutine.create(function()
				while attacking == true do
					slash()
					if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 50 then
						redvignette()
						local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
							Camera.CFrame = Camera.CFrame * shakeCf
						end)
						camShake:ShakeOnce(3, 3, .4,.5)
						--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
						camShake:Start()
						local vignet = game.ReplicatedStorage.Assets.Vignette:Clone()
						vignet.ImageLabel.ImageColor3 = Color3.fromRGB(255,10,10)
						vignet.Parent = game.Players.LocalPlayer.PlayerGui
						game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(8/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = .6}):Play()
						task.delay(3/60,function()
							game.Debris:AddItem(vignet,10/60)
							game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(10/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = 1}):Play()
						end)
					end
					wait(.2)
				end
			end))
			--emitsom(modelclone["GroundSlash2"])
			--vineta()
		end)
		if (Character["Right Arm"]:FindFirstChild("remiliaspear")) then
			local delaytime = 250
			task.delay((delaytime)/60, function()
				emit2512(Directory.appear215,true,nil,Character["Right Arm"]:FindFirstChild("remiliaspear"))
			end)
			for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
				if v:IsA('BasePart') or v:IsA('Decal') or v:IsA('Texture') then
					coroutine.resume(coroutine.create(function()
						local originaltransparency = v.Transparency
						local originalsize = v.Size
						v.Transparency = 1
						v.Size = Vector3.new(0,0,0)
						task.delay((delaytime)/60, function()
							if v ~= nil then
								--v.Transparency = originaltransparency
								game:GetService("TweenService"):Create(v,TweenInfo.new(.1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = originaltransparency,Size = originalsize}):Play()
							end
						end)
					end))
				end
				if v:IsA('ParticleEmitter') or v:IsA('Beam') or v:IsA('Trail') then
					coroutine.resume(coroutine.create(function()
						local originalenabled = v.Enabled
						v.Enabled = false
						task.delay((delaytime)/60, function()
							if v ~= nil then
								v.Enabled = originalenabled
							end
						end)
					end))
				end
			end
			local newremiliaspear = game.ReplicatedStorage.Assets.remiliaspear:Clone()
			newremiliaspear.Parent = Character
			newremiliaspear.Weld.Part0 = Character.HumanoidRootPart
			newremiliaspear.Weld.Part1 = newremiliaspear
			task.delay((157)/60, function()
				if newremiliaspear ~= nil then
					newremiliaspear:Destroy()
				end
			end)
		end

		local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
		for _,l in limbs do
			if Character[l]:FindFirstChild("dash0") then
				for _,thing in Character[l]:GetChildren() do
					if thing:IsA("Trail") and string.find(thing.Name, "dash") then
						thing.Enabled = true
					end
				end
			else
				local dash_vfx = dashLimbs:Clone():GetChildren()
				for _,p in dash_vfx do
					p.Parent = Character[l]
					if p:IsA("Trail") then
						p.Enabled = true
					end
				end
			end
		end
		local a2 = ResourceFolder.windtrail:Clone()
		a2.Parent = workspace.Ignore.Effects
		a2.CFrame = CFrame.new(Character.Torso.Position)
		game.Debris:AddItem(a2,5)
		for i,v in pairs(a2:GetDescendants()) do
			coroutine.resume(coroutine.create(function()
				if v:IsA('ParticleEmitter') then
					while enabled == true do
						local rate = v.Rate
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							rate = v.Rate / 5
						end
						wait(1/rate)
						a2.CFrame = CFrame.new(Character["Torso"].Position)
						v:Emit(4)
					end
				end
			end))
		end
		for i,v in pairs(a2:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				v.Enabled = false
			end
		end
		local modelclone2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX
		local function vineta()
			coroutine.resume(coroutine.create(function()
				if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 40 then
					redvignette()
					local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
						Camera.CFrame = Camera.CFrame * shakeCf
					end)
					camShake:ShakeOnce(5, 5, .4,.6)
					--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
					camShake:Start()
				end
			end))
		end
		--emit(Directory3.impact3DownslamREMI,false)
		task.delay(175/60,function()
			enabled25 = false
			enabled = false
			if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then
				for _,l in limbs do
					if Character[l]:FindFirstChild("dash0") then
						for _,thing in Character[l]:GetChildren() do
							if thing:IsA("Trail") and string.find(thing.Name, "dash") then
								thing.Enabled = false
							end
						end
					end
				end
			else
				task.delay(40/60,function()
					for _,l in limbs do
						if Character[l]:FindFirstChild("dash0") then
							for _,thing in Character[l]:GetChildren() do
								if thing:IsA("Trail") and string.find(thing.Name, "dash") then
									thing.Enabled = false
								end
							end
						end
					end
				end)
			end
			game.Debris:AddItem(a2,5)
		end)
	end,
	["MILLVAMP2"] = function(Character)
		if Character:FindFirstChild("MilleniumFakepire") then
			local highlight = script.Parent.MilleniumVampireHighlight:Clone()
			highlight.Parent = Character
			game:GetService("TweenService"):Create(highlight, TweenInfo.new(.6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 1.4,OutlineTransparency = .9}):Play()
			local RedFX251 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MilleniumSmoke.Attachment:Clone()
			RedFX251.Parent = Character.Torso
			local RedFX251515 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MilleniumSmoke.Attachment1:Clone()
			RedFX251515.Parent = Character.Torso
			local enabled = true
			for i,v in pairs(RedFX251:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						v.Enabled = false
						while enabled == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							if Character.Torso.Transparency == 0 then
								v:Emit(1)
							end
						end
					end
				end))
			end
			for i,v in pairs(RedFX251515:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						v.Enabled = false
						while enabled == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							if Character.Torso.Transparency == 0 then
								v:Emit(1)
							end
						end
					end
				end))
			end
			coroutine.resume(coroutine.create(function()
				wait(.6)
				if enabled == false then return end
				while enabled == true do
					if enabled == false then break end
					game:GetService("TweenService"):Create(highlight, TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 2}):Play()
					wait(2)	
					if enabled == false then break end
					game:GetService("TweenService"):Create(highlight, TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 1.4}):Play()
					if enabled == false then break end
					wait(2)	
					if enabled == false then break end
				end
			end))
			local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.AURALOOPSFX:Clone()
			sound1.Parent = Character.Torso
			sound1:Play()
			game:GetService("TweenService"):Create(sound1,TweenInfo.new(.5,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 1}):Play()
			local conn1
			conn1 = Character:FindFirstChild("MilleniumFakepire").Destroying:Connect(function()
				coroutine.resume(coroutine.create(function()
					if conn1 then 
						conn1:Disconnect()
					end
					enabled = false
					game.Debris:AddItem(sound1,1.5)
					game:GetService("TweenService"):Create(sound1,TweenInfo.new(1.2,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 0}):Play()
					game:GetService("TweenService"):Create(highlight, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 1,OutlineTransparency = 1}):Play()
					game.Debris:AddItem(highlight,2)
					game.Debris:AddItem(RedFX251,5)
					game.Debris:AddItem(RedFX251515,5)
				end))
			end)
		end
	end,
	["MILLVAMP1"] = function(Character)
		if Character:FindFirstChild("MilleniumFakepire") then return end
			if Character:FindFirstChild("MilleniumVampire") then
			local highlightname = ("MilleniumVampireHighlight")
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
					highlightname = ("MilleniumVampireHighlightThor")
				end
			end
			local highlight = script.Parent[highlightname]:Clone()
			highlight.Parent = Character
			game:GetService("TweenService"):Create(highlight, TweenInfo.new(.6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 1.4,OutlineTransparency = .9}):Play()
			local RedFX251 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MilleniumSmoke.Attachment:Clone()
			RedFX251.Parent = Character.Torso
			local RedFX251515 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MilleniumSmoke.Attachment1:Clone()
			RedFX251515.Parent = Character.Torso
			local enabled = true
			for i,v in pairs(RedFX251:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
						v.Enabled = false
						while enabled == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							if Character.Torso.Transparency == 0 then
								v:Emit(1)
							end
						end
					end
				end))
			end
			for i,v in pairs(RedFX251515:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
						v.Enabled = false
						while enabled == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							if Character.Torso.Transparency == 0 then
								v:Emit(1)
							end
						end
					end
				end))
			end
			coroutine.resume(coroutine.create(function()
				wait(.6)
				if enabled == false then return end
				while enabled == true do
					if enabled == false then break end
					game:GetService("TweenService"):Create(highlight, TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 2}):Play()
					wait(2)	
					if enabled == false then break end
					game:GetService("TweenService"):Create(highlight, TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 1.4}):Play()
					if enabled == false then break end
					wait(2)	
					if enabled == false then break end
				end
			end))
			local namae = ("AURALOOPSFX")
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("redmisthorion") then
					Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("redmisthorion"):Play()
					namae = ("AURALOOPSFXGEBURA")
				end
			end
			local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat[namae]:Clone()
			sound1.Parent = Character.Torso
			sound1:Play()
			game:GetService("TweenService"):Create(sound1,TweenInfo.new(.5,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 1}):Play()
			local conn1
			conn1 = Character:FindFirstChild("MilleniumVampire").Destroying:Connect(function()
				coroutine.resume(coroutine.create(function()
					if conn1 then 
						conn1:Disconnect()
					end
					enabled = false
					game.Debris:AddItem(sound1,1.5)
					game:GetService("TweenService"):Create(sound1,TweenInfo.new(1.2,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 0}):Play()
					game:GetService("TweenService"):Create(highlight, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 1,OutlineTransparency = 1}):Play()
					game.Debris:AddItem(highlight,2)
					game.Debris:AddItem(RedFX251,5)
					game.Debris:AddItem(RedFX251515,5)
				end))
			end)
		end
	end,
	["LEROY3SKILL"] = function(Character)
		if Character:FindFirstChild("LEROY") then
			local Directory3 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
			local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
			local Directory2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
			local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.stingerAIRSTARTSFX:Clone()
			sound1.Parent = Character.Torso
			sound1:Play()
			game.Debris:AddItem(sound1,3)
			local a = Directory.avampirek:Clone()
			a.Parent = workspace.Ignore.Effects
			a.CFrame = Character["Right Arm"].CFrame * CFrame.new(0,-1,0)
			local enabled = true
			local enabled25 = true
			for i,v in pairs(a:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
						while enabled == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							v:Emit(1)
						end
					end
				end))
			end
			local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
			for _,l in limbs do
				if Character[l]:FindFirstChild("dash0") then
					for _,thing in Character[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = true
						end
					end
				else
					local dash_vfx = dashLimbs:Clone():GetChildren()
					for _,p in dash_vfx do
						p.Parent = Character[l]
						if p:IsA("Trail") then
							p.Enabled = true
						end
					end
				end
			end
			local a2 = ResourceFolder.windtrail:Clone()
			a2.Parent = workspace.Ignore.Effects
			a2.CFrame = CFrame.new(Character.Torso.Position)
			game.Debris:AddItem(a2,5)
			for i,v in pairs(a2:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
						while enabled == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							a2.CFrame = CFrame.new(Character["Right Arm"].Position)
							v:Emit(3)
						end
					end
				end))
			end
			for i,v in pairs(a:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if Character["Right Arm"]:FindFirstChild("remiliaspear") then
						if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
							v.Color = ColorSequence.new{
								ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
							}
						end
					end
					v.Enabled = false
				end
			end
			for i,v in pairs(a2:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if Character["Right Arm"]:FindFirstChild("remiliaspear") then
						if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
							v.Color = ColorSequence.new{
								ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
							}
						end
					end
					v.Enabled = false
				end
			end
			local function emit(instance,weld,enable)
				local instanceclone = instance:Clone()
				instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
				if weld == true then
					local Weld = Instance.new("WeldConstraint")
					Weld.Part0 = Character.HumanoidRootPart
					Weld.Part1 = instanceclone
					Weld.Name = instanceclone.Name
					Weld.Parent = instanceclone	
				else
					instanceclone.Anchored = true
				end
				instanceclone.Parent = workspace.Ignore.Effects
				if instanceclone:FindFirstChildOfClass("Model") then
					for i,v in pairs(instanceclone:GetDescendants()) do
						if v:IsA('Model') and v:FindFirstChild("Start") then
							local modelclone = v
							modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
							modelclone.Parent = workspace.Ignore.Effects
							task.delay(modelclone:GetAttribute("EmitDelay"),function()
								local decalparams
								if modelclone:GetAttribute("Decal_TweenParams") then
									decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
								else
									local decalparams2 = "Cubic,Out"
									decalparams = string.split(decalparams2, ",")
								end
								local partparams
								if modelclone:GetAttribute("Part_TweenParams") then
									partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
								else
									local partparams2 = "Cubic,Out"
									partparams = string.split(partparams2, ",")
								end
								game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
								v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
								game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
							end)

						end
					end
				end

				game.Debris:AddItem(instanceclone,5)
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
			local modelclone2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX
			local function vineta()
				coroutine.resume(coroutine.create(function()
					if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 40 then
						redvignette()
						local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
							Camera.CFrame = Camera.CFrame * shakeCf
						end)
						camShake:ShakeOnce(5, 5, .4,.6)
						--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
						camShake:Start()
					end
				end))
			end
			local cframe = Character.HumanoidRootPart.CFrame * CFrame.new(0,0,7)
			--emit(Directory3.impact4FrontDashWindREMI,false)
			game:GetService("TweenService"):Create(a.Sound,TweenInfo.new(.4,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = .5}):Play()
			--emit(Directory3.impact5REMI,false,Character)
			--emit(Directory3.impact5REMIVAMPIREton,false,Character)
			--vineta()
			emit(Directory3.impact3DownslamREMI1x2,false)
			local conn1
			conn1 = Character:FindFirstChild("LEROY").Destroying:Connect(function()
				if conn1 then 
					conn1:Disconnect()
				end
				if Character:FindFirstChild("createdhitbox3") then
					--local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.vampirekissENDSFX:Clone()
					--sound1.Parent = Character.Torso
					--sound1:Play()
					--game.Debris:AddItem(sound1,2)
					--emit(Directory3.impact5REMI2,false)
					--emit(Directory2.slash3151,true)
					--task.delay(36/60,function()
					--	emit(Directory2.ground115,false,Character)
					--end)
					--task.delay(55/60,function()
					--	emit(Directory2.ground1152,false,Character)
					--end)
					--task.delay(53/60,function()
					--	emit(Directory2.ground1152,false,Character)
					--end)
					emit(Directory2.slash2,false)
					emit(Directory3.impact5DownslamREMI,false)
					local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.stingerEXPLSFX:Clone()
					sound1.Parent = Character.Torso
					sound1:Play()
					game.Debris:AddItem(sound1,3)
					local floorInstance = RayCastOnMap((Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-5.772)).p,Vector3.new(0,-15,0),true)
					if floorInstance then
						local RedFX=ResourceFolder.Parent.Smash.SmashBigger2:Clone()
						RedFX.CFrame = (Character.HumanoidRootPart.CFrame * ResourceFolder.Parent.Smash.SmashBigger2.CFrame)
			local rotation = RedFX.CFrame.Rotation
			local EXPLCFRAME = floorInstance.Position
			RedFX.CFrame = CFrame.new(EXPLCFRAME + Vector3.new(0,RedFX.Size.Y/2,0))* rotation
			--CFrame.new(floorInstance.Position + Vector3.new(0,10.5,0)) * CFrame.fromOrientation()
						Debris:AddItem(RedFX,5)
						RedFX.Parent = workspace.Ignore.Effects
						local enabled1 = true
						for i,v in pairs(RedFX:GetDescendants()) do
							coroutine.resume(coroutine.create(function()
								if v:IsA('ParticleEmitter') then
									if Character["Right Arm"]:FindFirstChild("remiliaspear") then
										if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
											v.Color = ColorSequence.new{
												ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
												ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
											}
										end
									end
									v:Emit(v:GetAttribute("EmitCount") or 1)
								end
								if v:IsA('Beam') then
									local width0 = v.Width0
									local width1 = v.Width1
									v.Width0 = 0
									v.Width1 = 0
										if Character["Right Arm"]:FindFirstChild("remiliaspear") then
											if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then return end
										end
									game:GetService("TweenService"):Create(v,TweenInfo.new(.2,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = width0,Width1 = width1}):Play()
								end
							end))
						end
						for i,v in pairs(RedFX:GetDescendants()) do
							coroutine.resume(coroutine.create(function()

								if v:IsA('ParticleEmitter') and v.Enabled == true then
									if Character["Right Arm"]:FindFirstChild("remiliaspear") then
										if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
											v.Color = ColorSequence.new{
												ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
												ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
											}
										end
									end
									v.Enabled = false
									while (enabled1 == true) do
										wait(1/(v.Rate/1.8))
										v:Emit(1)
									end
								end
							end))
						end
						task.delay(.7,function()
							enabled1 = false
							for i,v in pairs(RedFX:GetDescendants()) do
								if v:IsA('ParticleEmitter') then
									if Character["Right Arm"]:FindFirstChild("remiliaspear") then
										if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
											v.Color = ColorSequence.new{
												ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
												ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
											}
										end
									end
									v.Enabled = false
								end
								if v:IsA('PointLight') then
									game.TweenService:Create(v,TweenInfo.new(.1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,0,false,.95),{Brightness = 0,Range = 0}):Play()
								end
								if v:IsA('Beam') then
									game:GetService("TweenService"):Create(v,TweenInfo.new(.7,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0}):Play()
									game:GetService("TweenService"):Create(v,TweenInfo.new(.7,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width1 = 0}):Play()
								end
							end
						end)
					end
					task.delay(1.5/60,function()
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
							Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
						end
					end)
				end
				enabled25 = false
				enabled = false
				game:GetService("TweenService"):Create(a.Sound,TweenInfo.new(.3,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 0}):Play()

				if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then
					for _,l in limbs do
						if Character[l]:FindFirstChild("dash0") then
							for _,thing in Character[l]:GetChildren() do
								if thing:IsA("Trail") and string.find(thing.Name, "dash") then
									thing.Enabled = false
								end
							end
						end
					end
				else
					task.delay(40/60,function()
						for _,l in limbs do
							if Character[l]:FindFirstChild("dash0") then
								for _,thing in Character[l]:GetChildren() do
									if thing:IsA("Trail") and string.find(thing.Name, "dash") then
										thing.Enabled = false
									end
								end
							end
						end
					end)
				end
				for i,v in pairs(a:GetChildren()) do
					if not v:IsA("Sound") then
						v:Destroy()
					end
				end
				game.Debris:AddItem(a,5)
				game.Debris:AddItem(a2,5)
			end)
			coroutine.resume(coroutine.create(function()
				while enabled25 == true do
					if a ~= nil then
						a.CFrame = Character["Right Arm"].CFrame * CFrame.new(0,-1.4,0)
					else
						break
					end
					wait()
				end
			end))
		end
	end,
	["LUNGELOOPVFX3SKILL"] = function(Character)
		if Character:FindFirstChild("STINGERLUNGE") then
			local Directory3 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
			local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
			local Directory2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
			--local a = Directory.avampirek:Clone()
			--a.Parent = workspace.Ignore.Effects
			--a.CFrame = Character["Right Arm"].CFrame * CFrame.new(0,-1,0)
			local enabled = true
			local enabled25 = true
			--for i,v in pairs(a:GetDescendants()) do
			--	coroutine.resume(coroutine.create(function()
			--		if v:IsA('ParticleEmitter') then
			--			while enabled == true do
			--local rate = v.Rate
			--if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
			--	rate = v.Rate / 5
			--end
			--wait(1/rate)
			--				v:Emit(3)
			--			end
			--		end
			--	end))
			--end
			local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
			for _,l in limbs do
				if Character[l]:FindFirstChild("dash0") then
					for _,thing in Character[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = true
						end
					end
				else
					local dash_vfx = dashLimbs:Clone():GetChildren()
					for _,p in dash_vfx do
						p.Parent = Character[l]
						if p:IsA("Trail") then
							p.Enabled = true
						end
					end
				end
			end
			local a2 = ResourceFolder.windtrail:Clone()
			a2.Parent = workspace.Ignore.Effects
			a2.CFrame = CFrame.new(Character.Torso.Position)
			game.Debris:AddItem(a2,5)
			for i,v in pairs(a2:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
						while enabled == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							a2.CFrame = CFrame.new(Character.Torso.Position)
							v:Emit(2)
						end
					end
				end))
			end
			--for i,v in pairs(a:GetDescendants()) do
			--	if v:IsA('ParticleEmitter') then
			--		v.Enabled = false
			--	end
			--end
			for i,v in pairs(a2:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if Character["Right Arm"]:FindFirstChild("remiliaspear") then
						if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
							v.Color = ColorSequence.new{
								ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
							}
						end
					end
					v.Enabled = false
				end
			end
			local function emit(instance,weld,enable)
				local instanceclone = instance:Clone()
				instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
				if weld == true then
					local Weld = Instance.new("WeldConstraint")
					Weld.Part0 = Character.HumanoidRootPart
					Weld.Part1 = instanceclone
					Weld.Name = instanceclone.Name
					Weld.Parent = instanceclone	
				else
					instanceclone.Anchored = true
				end
				instanceclone.Parent = workspace.Ignore.Effects
				if instanceclone:FindFirstChildOfClass("Model") then
					for i,v in pairs(instanceclone:GetDescendants()) do
						if v:IsA('Model') and v:FindFirstChild("Start") then
							local modelclone = v
							modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
							modelclone.Parent = workspace.Ignore.Effects
							task.delay(modelclone:GetAttribute("EmitDelay"),function()
								local decalparams
								if modelclone:GetAttribute("Decal_TweenParams") then
									decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
								else
									local decalparams2 = "Cubic,Out"
									decalparams = string.split(decalparams2, ",")
								end
								local partparams
								if modelclone:GetAttribute("Part_TweenParams") then
									partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
								else
									local partparams2 = "Cubic,Out"
									partparams = string.split(partparams2, ",")
								end
								game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
								v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
								game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
							end)

						end
					end
				end

				game.Debris:AddItem(instanceclone,5)
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
			local modelclone2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX
			local function vineta()
				coroutine.resume(coroutine.create(function()
					if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 40 then
						redvignette()
						local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
							Camera.CFrame = Camera.CFrame * shakeCf
						end)
						camShake:ShakeOnce(5, 5, .4,.6)
						--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
						camShake:Start()
					end
				end))
			end
			local cframe = Character.HumanoidRootPart.CFrame * CFrame.new(0,0,7)
			--emit(Directory3.impact4FrontDashWindREMI,false)
			--game:GetService("TweenService"):Create(a.Sound,TweenInfo.new(.4,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = .5}):Play()
			--emit(Directory3.impact5REMI,false,Character)
			--emit(Directory3.impact5REMIVAMPIREton,false,Character)
			vineta()
			local conn1
			conn1 = Character:FindFirstChild("STINGERLUNGE").Destroying:Connect(function()
				if conn1 then 
					conn1:Disconnect()
				end
				if not Character.HumanoidRootPart:FindFirstChild("GrabWeld") then
					--local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.vampirekissENDSFX:Clone()
					--sound1.Parent = Character.Torso
					--sound1:Play()
					--game.Debris:AddItem(sound1,2)
					--emit(Directory3.impact5REMI2,false)
					emit(Directory2.slash3151,true)
					task.delay(36/60,function()
						emit(Directory2.ground115,false,Character)
					end)
					--task.delay(55/60,function()
					--	emit(Directory2.ground1152,false,Character)
					--end)
					task.delay(53/60,function()
						emit(Directory2.ground1152,false,Character)
					end)
					task.delay(43/60,function()
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
							Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
						end
					end)
				end
				task.delay(20/60,function()
					enabled25 = false
					enabled = false
				end)
				--game:GetService("TweenService"):Create(a.Sound,TweenInfo.new(.3,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 0}):Play()

				if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then
					for _,l in limbs do
						if Character[l]:FindFirstChild("dash0") then
							for _,thing in Character[l]:GetChildren() do
								if thing:IsA("Trail") and string.find(thing.Name, "dash") then
									thing.Enabled = false
								end
							end
						end
					end
				else
					task.delay(40/60,function()
						for _,l in limbs do
							if Character[l]:FindFirstChild("dash0") then
								for _,thing in Character[l]:GetChildren() do
									if thing:IsA("Trail") and string.find(thing.Name, "dash") then
										thing.Enabled = false
									end
								end
							end
						end
					end)
				end
				--for i,v in pairs(a:GetChildren()) do
				--	if not v:IsA("Sound") then
				--		v:Destroy()
				--	end
				--end
				--game.Debris:AddItem(a,5)
				game.Debris:AddItem(a2,5)
			end)
			--coroutine.resume(coroutine.create(function()
			--	while enabled25 == true do
			--		if a ~= nil then
			--			a.CFrame = Character["Right Arm"].CFrame * CFrame.new(0,-1.4,0)
			--		else
			--			break
			--		end
			--		wait()
			--	end
			--end))
		end
	end,
	["LUNGELOOPVFX"] = function(Character)
		if Character:FindFirstChild("VAMPIREKISSLUNGE") then
			local Directory3 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
			local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
			local Directory2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
			local a = Directory.avampirek:Clone()
			a.Parent = workspace.Ignore.Effects
			a.CFrame = Character["Left Arm"].CFrame * CFrame.new(0,-1,0)
			local enabled = true
			local enabled25 = true
			for i,v in pairs(a:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
						while enabled == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							v:Emit(1)
						end
					end
				end))
			end
			--local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
			--for _,l in limbs do
			--	local dash_vfx = dashLimbs:Clone():GetChildren()
			--	for _,p in dash_vfx do
			--		p.Parent = Character[l]
			--		coroutine.resume(coroutine.create(function()
			--			while wait() do
			--				if not Character:FindFirstChild("VAMPIREKISSLUNGE")  then
			--					if p:IsA("Trail") then
			--						game.Debris:AddItem(p,3)
			--						p.Enabled = false
			--					end
			--				end
			--			end
			--		end))
			--		if p:IsA("Trail") then
			--			p.Enabled = true
			--		end
			--	end
			--end
			local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
			for _,l in limbs do
				if Character[l]:FindFirstChild("dash0") then
					for _,thing in Character[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = true
						end
					end
				else
					local dash_vfx = dashLimbs:Clone():GetChildren()
					for _,p in dash_vfx do
						p.Parent = Character[l]
						if p:IsA("Trail") then
							p.Enabled = true
						end
					end
				end
			end
			local a2 = ResourceFolder.windtrail:Clone()
			a2.Parent = workspace.Ignore.Effects
			a2.CFrame = CFrame.new(Character.Torso.Position)
			game.Debris:AddItem(a2,5)
			for i,v in pairs(a2:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
						while enabled == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							a2.CFrame = CFrame.new(Character.Torso.Position)
							v:Emit(3)
						end
					end
				end))
			end
			for i,v in pairs(a:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if Character["Right Arm"]:FindFirstChild("remiliaspear") then
						if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
							v.Color = ColorSequence.new{
								ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
							}
						end
					end
					v.Enabled = false
				end
			end
		for i,v in pairs(a2:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if Character["Right Arm"]:FindFirstChild("remiliaspear") then
						if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
							v.Color = ColorSequence.new{
								ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
							}
						end
					end
					v.Enabled = false
				end
			end
			local function emit(instance,weld,enable)
				local instanceclone = instance:Clone()
				instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
				if weld == true then
					local Weld = Instance.new("WeldConstraint")
					Weld.Part0 = Character.HumanoidRootPart
					Weld.Part1 = instanceclone
					Weld.Name = instanceclone.Name
					Weld.Parent = instanceclone	
				else
					instanceclone.Anchored = true
				end
				instanceclone.Parent = workspace.Ignore.Effects
				if instanceclone:FindFirstChildOfClass("Model") then
					for i,v in pairs(instanceclone:GetDescendants()) do
						if v:IsA('Model') and v:FindFirstChild("Start") then
							local modelclone = v
							modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
							modelclone.Parent = workspace.Ignore.Effects
							task.delay(modelclone:GetAttribute("EmitDelay"),function()
								local decalparams
								if modelclone:GetAttribute("Decal_TweenParams") then
									decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
								else
									local decalparams2 = "Cubic,Out"
									decalparams = string.split(decalparams2, ",")
								end
								local partparams
								if modelclone:GetAttribute("Part_TweenParams") then
									partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
								else
									local partparams2 = "Cubic,Out"
									partparams = string.split(partparams2, ",")
								end
								game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
								v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
								game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
							end)
							--for ie,ve in pairs(modelclone:GetChildren()) do
							--end
						end
					end
				end

				game.Debris:AddItem(instanceclone,5)
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
			emit(Directory3.impact4FrontDashWindREMI,false)
			game:GetService("TweenService"):Create(a.Sound,TweenInfo.new(.4,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = .5}):Play()

			local conn1
			conn1 = Character:FindFirstChild("VAMPIREKISSLUNGE").Destroying:Connect(function()
				if conn1 then 
					conn1:Disconnect()
				end
				if not Character.HumanoidRootPart:FindFirstChild("GrabWeld") then
					local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.vampirekissENDSFX:Clone()
					sound1.Parent = Character.Torso
					sound1:Play()
					game.Debris:AddItem(sound1,2)
					emit(Directory3.impact5REMI2,false)
					emit(Directory2.slash33,true)
					task.delay(5/60,function()
						emit(Directory2.ground115,false,Character)
					end)
					task.delay(11/60,function()
						emit(Directory2.ground1152,false,Character)
					end)
					task.delay(29/60,function()
						emit(Directory2.ground115,false,Character)
					end)
					task.delay(16/60,function()
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
							Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
						end
					end)
				end
				enabled25 = false
				enabled = false
				game:GetService("TweenService"):Create(a.Sound,TweenInfo.new(.3,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 0}):Play()

				if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then
					for _,l in limbs do
						if Character[l]:FindFirstChild("dash0") then
							for _,thing in Character[l]:GetChildren() do
								if thing:IsA("Trail") and string.find(thing.Name, "dash") then
									thing.Enabled = false
								end
							end
						end
					end
				else
					task.delay(40/60,function()
						for _,l in limbs do
							if Character[l]:FindFirstChild("dash0") then
								for _,thing in Character[l]:GetChildren() do
									if thing:IsA("Trail") and string.find(thing.Name, "dash") then
										thing.Enabled = false
									end
								end
							end
						end
					end)
				end
				for i,v in pairs(a:GetChildren()) do
					if not v:IsA("Sound") then
						v:Destroy()
					end
				end
				game.Debris:AddItem(a,5)
				game.Debris:AddItem(a2,5)
			end)
			coroutine.resume(coroutine.create(function()
				while enabled25 == true do
					if a ~= nil then
						a.CFrame = Character["Left Arm"].CFrame * CFrame.new(0,-1.4,0)
					else
						break
					end
					wait()
				end
			end))
		end
	end,
	["AWAKENVFX"] = function(Character,theenemy)
		--if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
		--local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.MMSFX:Clone()
		--sound1.Parent = Character.HumanoidRootPart
		--sound1:Play()
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					--if enable == true then
					--	v.Enabled = true
					--	task.delay((458-304)/60,function()
					--		v.Enabled = false
					--	end)
					--end
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit(v:GetAttribute('EmitCount') or 1)
					end
				end
			end
		end
		local sfx1 = ResourceFolder.remiliasfx:Clone()
		sfx1.Parent = Character.HumanoidRootPart
		sfx1:Play()
		game.Debris:AddItem(sfx1,17)
		task.delay(71/60,function()
			--if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 50 then
			--	local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
			--		Camera.CFrame = Camera.CFrame * shakeCf
			--	end)
			--	camShake:ShakeOnce(5, 5, .4,.6)
			--	--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
			--	camShake:Start()
			--end
			emit(Directory.ground1,true)
		end)
		local enabled = true
		task.delay(75/60,function()
			if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
			local a = Directory.a:Clone()
			a.Parent = workspace.Ignore.Effects
			a.CFrame = CFrame.new(Character.Torso.Position)
			for i,v in pairs(a:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						while enabled == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							v:Emit(1)
						end
					end
				end))
			end
			--for i,v in pairs(a:GetDescendants()) do
			--	if v:IsA('ParticleEmitter') then
			--		v.Enabled = true
			--	end
			--end
			--task.delay((215/60)-(75/60),function()
				for i,v in pairs(a:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v.Enabled = false
					end
				end
			game.Debris:AddItem(a,215/60)
			--end)
			coroutine.resume(coroutine.create(function()
				while enabled == true do
					a.CFrame = CFrame.new(Character.Torso.Position)
					local modelclone1 = Directory.rotate:Clone()
					modelclone1:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * Directory.rotate.Tets1.Start.CFrame)
					modelclone1.Parent = workspace.Ignore.Effects
					game.Debris:AddItem(modelclone1,2)
					for i,v in pairs(modelclone1:GetChildren()) do
						if v:IsA('Model') and v:FindFirstChild("Start") then
							local modelclone = v
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame,Size = modelclone:FindFirstChild("End").Size}):Play()
							modelclone.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end
					end
					wait(.2)
				end
			end))
		end)
		task.delay(215/60,function()
			if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
			enabled = false
			emit(Directory.ground2,true)
		end)
		task.delay(272/60,function()
			emit(Directory.appear,true)
			local orb = Directory.orb:Clone()
			orb.Parent = workspace.Ignore.Effects
			orb.CFrame = Character.HumanoidRootPart.CFrame * Directory.orb.CFrame
			--for i,v in pairs(orb:GetDescendants()) do
			--	if v:IsA('ParticleEmitter') then
			--		v.Enabled = true
			--	end
			--end
			local enabled25 = true
			for i,v in pairs(orb:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
			end
			for i,v in pairs(orb:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						while enabled25 == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							v:Emit(1)
						end
					end
				end))
			end
			task.delay((501/60)-(272/60),function()
				--for i,v in pairs(orb:GetDescendants()) do
				--	if v:IsA('ParticleEmitter') then
				--		v.Enabled = false
				--	end
				--end
				enabled25 = false
				game.Debris:AddItem(orb,3)
			end)
		end)
		task.delay(501/60,function()
			emit(Directory.expl,true)
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 100 then
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(10, 10, .4,.6)
				camShake:Start()
			end
		end)
		task.delay(737/60,function()
			if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
			emit(Directory.appear2,true)
		end)
	end,
	["MOVEFRONT3"] = function(Character)
		local pos = Character.HumanoidRootPart.CFrame
		local raycastParams  = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
		raycastParams.FilterDescendantsInstances = {Character,workspace.Ignore.Effects,workspace.Ignore.Rocks,workspace.Ignore}
		local raycastResult = workspace:Raycast(pos.p, pos.LookVector*3.707271099090576, raycastParams)

		local TPD = -3.707271099090576

		if raycastResult then

			local magnitude  = (pos.p - raycastResult.Position).Magnitude

			TPD =  -magnitude
		else
			Character.HumanoidRootPart.CFrame = pos * CFrame.new(-0.694,0,TPD)
		end
		Knit.GetController("AnimationController"):stopAnimation(game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.Success,0)
	end,
	["AFTERIMAGES"] = function(Enemy,Character)
		local attacking = false
		local cloneeadoomanoo = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AfterimageVictimTorso:Clone()
		cloneeadoomanoo.Parent = workspace.Ignore.Effects
		cloneeadoomanoo.HumanoidRootPart.Anchored = true
		cloneeadoomanoo:SetPrimaryPartCFrame(Enemy.HumanoidRootPart.CFrame)
		local originalhealth = Character.Humanoid.HealthDisplayDistance
		local originalname = Character.Humanoid.NameDisplayDistance
		Character.Humanoid.HealthDisplayDistance = 0
		Character.Humanoid.NameDisplayDistance = 0
		Character.Archivable = true
		for i,v in pairs(workspace.Ignore.Effects:GetDescendants()) do
			if v:GetAttribute(Character.Name.."VFX") then
				v:Destroy()
			end
		end
		for i,v in pairs(Character:GetDescendants()) do
			if v:IsA('BasePart') or v:IsA('Decal') or v:IsA('Texture') then
				if v.Transparency == 0 then
					local originaltransparency = v.Transparency
					v.Transparency = 2
					task.delay(8/60,function()
						v.Transparency = originaltransparency
					end)
				end
			end
		end
		--for i,v in pairs(Character:GetDescendants()) do
		--	if v:IsA('BasePart') or v:IsA('Decal') or v:IsA('Texture') then
		--		if v.Transparency == 0 then
		--			local originaltransparency = v.Transparency
		--			v.Transparency = 2
		--			task.delay(148/60,function()
		--				v.Transparency = originaltransparency
		--			end)
		--		end
		--	end
		--end
		local function emit(instance,weld,characterc)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = characterc.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = characterc.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(characterc.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = game.Workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame,Size = modelclone:FindFirstChild("End").Size}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,4)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if (instanceclone.Name == ("flashstep2") or instanceclone.Name == ("flashstep")) and attacking == true then
						v:Emit(v:GetAttribute('EmitCount')/2 or 1)
					else
						v:Emit(v:GetAttribute('EmitCount') or 1)
					end
				end
			end
		end
		local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
		emit(Directory.flashstep,false,Character)
		task.delay(184/60,function()
			emit(Directory.ground1,false,Character)
			emit(Directory.slash2,false,Character)
		end)

		task.delay(149/60,function()
			attacking = false
			Character.Archivable = false
			Character.Humanoid.HealthDisplayDistance = originalhealth
			Character.Humanoid.NameDisplayDistance = originalname
			emit(Directory.flashstep2,false,Character)
		end)
attacking = true
		for i,v in pairs(workspace.Ignore.Effects:GetDescendants()) do
			if v:GetAttribute(Character.Name.."VFX") then
				v:Destroy()
			end
		end
		local parttoavoid = 1
		while attacking == true do
			wait(.1)
			cloneeadoomanoo:SetPrimaryPartCFrame(Enemy.HumanoidRootPart.CFrame)
			local chrclone = Character:Clone()
			chrclone.Parent = workspace.Ignore.Effects
			for i,v in pairs(chrclone:GetDescendants()) do
				if v:IsA('Sound') or v:IsA('PointLight') then
					v:Destroy()
				end
				if v:IsA('BasePart') or v:IsA('Decal') or v:IsA('Texture') then
					if v.Transparency == 2 then
						v.Transparency = 0
					end
				end
				if v:IsA('BasePart') then
					v.CanCollide = false
					v.RootPriority = -127
				end
			end
			chrclone.HumanoidRootPart.Anchored = true
			chrclone.HumanoidRootPart.CanCollide = false
			local chosen = math.random(1,8)
			if chosen == parttoavoid then
				repeat wait()
					chosen = math.random(1,8)
				until chosen ~= parttoavoid
			end
			chrclone.HumanoidRootPart.CFrame = cloneeadoomanoo[chosen].CFrame
			parttoavoid = chosen
			local mathe = math.random(1,2)
			if mathe == 2 then
				emit(Directory.flashstep2,false,chrclone)
			end
			local anim = game.ReplicatedStorage.Assets.Animations.BLSRAFTERIMAGES["BLSR "..math.random(1,4)]
			Knit.GetController("AnimationController"):playAnimationRINNOSUKE(chrclone, anim,1,false,0)
			game.Debris:AddItem(chrclone,16/60)
			--if mathe == 2 then
			--	task.delay(15/60,function()
			--		emit(Directory.flashstep2,false,chrclone)
			--	end)
			--end
			task.delay(14/60,function()
				for i,v in pairs(chrclone:GetDescendants()) do
					if v:IsA('BasePart') or v:IsA('Decal') or v:IsA('Texture') then
						coroutine.resume(coroutine.create(function()
							if v.Transparency == 2 then
								v.Transparency = 0
							end
							game:GetService("TweenService"):Create(v,TweenInfo.new(5/60,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
						end))
					end
				end
			end)
		end
	end,
	["MISERABLEMULTITUDE"] = function(Character,theenemy)
		--if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
		local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.MMSFX:Clone()
		sound1.Parent = Character.HumanoidRootPart
		sound1:Play()
		local function emit(instance,weld,enable)
			coroutine.resume(coroutine.create(function()
				local instanceclone = instance:Clone()
				if instanceclone:IsA("Model") then
					instanceclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * instance.PrimaryPart.CFrame)
				else
					instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
					instanceclone.Massless = true
					instanceclone.CanCollide = false
					instanceclone.RootPriority = -127
				end
				coroutine.resume(coroutine.create(function()
					for i,v in pairs(instanceclone:GetDescendants()) do
						coroutine.resume(coroutine.create(function()
							if v:IsA('ParticleEmitter') and (v:GetAttribute("BaseRate") or v:GetAttribute("BaseEmitCount")) and v:GetAttribute("EmitDuration")  then
								if v:GetAttribute("EmitDelay") then
									wait(v:GetAttribute("EmitDelay"))
								end
								local enabled = true
								local start = os.clock()
								coroutine.resume(coroutine.create(function()
									while enabled == true do
										wait()
										if (os.clock() - start >= v:GetAttribute("EmitDuration")) then
											enabled = false
										end
									end
								end))
								while enabled == true do
									wait(1/v:GetAttribute("BaseRate"))
									v:Emit(v:GetAttribute("BaseEmitCount") or v:GetAttribute("EmitCount"))
								end
							end
						end))
					end
				end))
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('BasePart') then
						v.Massless = true
						v.CanCollide = false
						v.RootPriority = -127
					end
				end
				if weld == true then
					local Weld = Instance.new("WeldConstraint")
					Weld.Part0 = Character.HumanoidRootPart
					Weld.Part1 = instanceclone
					Weld.Name = instanceclone.Name
					Weld.Parent = instanceclone	
				else
					instanceclone.Anchored = true
				end
				instanceclone.Parent = workspace.Ignore.Effects
				instanceclone:SetAttribute(Character.Name.."VFX")
				if instanceclone:IsA("Model") then
					for i,v in pairs(instanceclone:GetDescendants()) do
						if v:IsA('BasePart') then
							v.Anchored = true
						end
					end
					instanceclone:BreakJoints()
				end
				if instanceclone:FindFirstChild("impact5") then
					task.delay((136/60)-(100/60),function()
						for i,v in pairs(instanceclone.bl22:GetDescendants()) do
							if v:IsA('ParticleEmitter') then
								v.Enabled = true
								task.delay(24/60,function()
									v.Enabled = false
								end)
							end
						end
						for i,v in pairs(instanceclone.bl2:GetDescendants()) do
							if v:IsA('ParticleEmitter') then
								v.Enabled = true
								task.delay(24/60,function()
									v.Enabled = false
								end)
							end
						end
					end)
				end
				game.Debris:AddItem(instanceclone,5)
				if enable == true then
					for i,v in pairs(instanceclone:GetDescendants()) do
						coroutine.resume(coroutine.create(function()
							if v:IsA('ParticleEmitter') then
								if v:GetAttribute("EmitDelay") then
									wait(v:GetAttribute("EmitDelay"))
								end
								local enabled = true
								task.delay((458-304)/60,function()
									enabled = false
								end)
								local start = os.clock()
								coroutine.resume(coroutine.create(function()
									while enabled == true do
										wait()
										if (os.clock() - start >= v:GetAttribute("EmitDuration")) then
											enabled = false
										end
									end
								end))
								while enabled == true do
									local rate = v.Rate
									if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
										rate = v.Rate / 5
									end
									wait(1/rate)
									--if v:GetAttribute("BaseEmitCount") and v:GetAttribute("BaseEmitCount") >= 20 then
									v:Emit(1)
									--else
									--	v:Emit(v:GetAttribute("BaseEmitCount") or v:GetAttribute("EmitCount"))
									--end
								end
							end
						end))
					end
				else
					for i,v in pairs(instanceclone:GetDescendants()) do
						if v:IsA('ParticleEmitter') then
							--if enable == true then
							--	v.Enabled = true
							--	task.delay((458-304)/60,function()
							--		v.Enabled = false
							--	end)
							--end
							if v:GetAttribute("EmitDelay") then
								task.delay(v:GetAttribute("EmitDelay"),function()
									if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
										v:Emit((v:GetAttribute('EmitCount') or 1)/6)
									else
										v:Emit((v:GetAttribute('EmitCount')) or 1)
									end
								end)
							else
								if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
									v:Emit((v:GetAttribute('EmitCount') or 1)/6)
								else
									v:Emit((v:GetAttribute('EmitCount')) or 1)
								end
							end
						end
					end
				end
				if instanceclone:FindFirstChildOfClass("Model") then
					for i,v in pairs(instanceclone:GetDescendants()) do
						if v:IsA('Model') and v:FindFirstChild("Start") then
							local modelclone = v
							--modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.PrimaryPart.CFrame)
							modelclone.Parent = game.Workspace.Ignore.Effects
							task.delay(modelclone:GetAttribute("EmitDelay"),function()
								local decalparams
								if modelclone:GetAttribute("Decal_TweenParams") then
									decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
								else
									local decalparams2 = "Cubic,Out"
									decalparams = string.split(decalparams2, ",")
								end
								local partparams
								if modelclone:GetAttribute("Part_TweenParams") then
									partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
								else
									local partparams2 = "Cubic,Out"
									partparams = string.split(partparams2, ",")
								end
								game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration") or modelclone:GetAttribute("EmitDuration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame,Size = modelclone:FindFirstChild("End").Size}):Play()
								if not v.Start:FindFirstChildOfClass("Decal") then
									if modelclone:GetAttribute("Duration") or modelclone:GetAttribute("EmitDuration") then
										game.Debris:AddItem(modelclone,(modelclone:GetAttribute("Duration") or modelclone:GetAttribute("EmitDuration")) +.003)
									end
								end
								if v.Start:FindFirstChildOfClass("Decal") then
									v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
									game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration")  or modelclone:GetAttribute("EmitDuration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
								end
							end)
						end
					end
				end
			end))
		end
--		local function emit(instance,weld,enable)
--			local instanceclone = instance:Clone()
--			instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
--			instanceclone.Massless = true
--			instanceclone.CanCollide = false
--			instanceclone.RootPriority = -127
--			for i,v in pairs(instanceclone:GetDescendants()) do
--				if v:IsA('BasePart') then
--					v.Massless = true
--					v.CanCollide = false
--					v.RootPriority = -127
--				end
--			end
--			if weld == true then
--				local Weld = Instance.new("WeldConstraint")
--				Weld.Part0 = Character.HumanoidRootPart
--				Weld.Part1 = instanceclone
--				Weld.Name = instanceclone.Name
--				Weld.Parent = instanceclone	
--			else
--				instanceclone.Anchored = true
--			end
--			instanceclone.Parent = workspace.Ignore.Effects
--			instanceclone:SetAttribute(Character.Name.."VFX")
--			if instanceclone:FindFirstChildOfClass("Model") then
--				for i,v in pairs(instanceclone:GetDescendants()) do
--					if v:IsA('Model') and v:FindFirstChild("Start") then
--						local modelclone = v
--						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
--						modelclone.Parent = game.Workspace.Ignore.Effects
--						task.delay(modelclone:GetAttribute("EmitDelay"),function()
--							local decalparams
--							if modelclone:GetAttribute("Decal_TweenParams") then
--								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
--							else
--								local decalparams2 = "Cubic,Out"
--								decalparams = string.split(decalparams2, ",")
--							end
--							local partparams
--							if modelclone:GetAttribute("Part_TweenParams") then
--								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
--							else
--								local partparams2 = "Cubic,Out"
--								partparams = string.split(partparams2, ",")
--							end
--							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame,Size = modelclone:FindFirstChild("End").Size}):Play()
--							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
--							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
--						end)
--						--for ie,ve in pairs(modelclone:GetChildren()) do
--						--end
--					end
--				end
--			end

--			game.Debris:AddItem(instanceclone,5)
--			if enable == true then
--				for i,v in pairs(instanceclone:GetDescendants()) do
--					coroutine.resume(coroutine.create(function()
--						if v:IsA('ParticleEmitter') then
--							if v:GetAttribute("EmitDelay") then
--								wait(v:GetAttribute("EmitDelay"))
--							end
--							local enabled = true
--							task.delay((458-304)/60,function()
--								enabled = false
--							end)
--							local start = os.clock()
--							coroutine.resume(coroutine.create(function()
--								while enabled == true do
--									wait()
--									if (os.clock() - start >= v:GetAttribute("EmitDuration")) then
--										enabled = false
--									end
--								end
--							end))
--							while enabled == true do
		--local rate = v.Rate
		--if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
		--	rate = v.Rate / 5
		--end
		--wait(1/rate)
--								--if v:GetAttribute("BaseEmitCount") and v:GetAttribute("BaseEmitCount") >= 20 then
--								v:Emit(1)
--								--else
--								--	v:Emit(v:GetAttribute("BaseEmitCount") or v:GetAttribute("EmitCount"))
--								--end
--							end
--						end
--					end))
--				end
--			else
--			for i,v in pairs(instanceclone:GetDescendants()) do
--				if v:IsA('ParticleEmitter') then
--					if enable == true then
--						v.Enabled = true
--						task.delay((458-304)/60,function()
--							v.Enabled = false
--						end)
--					end
--					v:Emit(v:GetAttribute('EmitCount') or 1)
--				end
--			end
--end
--		end
		task.delay(52/60,function()
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 50 then
				redvignette()
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(5, 5, .4,.6)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
			emit(Directory.slash1,true)
		end)
		task.delay(142/60,function()
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 40 then
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(4, 4, .3,.6)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end)
		task.delay(219/60,function()
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 40 then
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(4, 4, .3,.6)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end)
		task.delay(268/60,function()
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 40 then
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(4, 4, .3,.6)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end)
		task.delay(285/60,function()
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 40 then
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(2, 2, .5,.5)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end)
		task.delay(107/60,function()
			emit(Directory.ground1,true)
		end)
		task.delay(136/60,function()
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 55 then
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(7, 7, .4,.7)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
			emit(Directory.slash2,false)
		end)
		task.delay(218/60,function()
			emit(Directory.slash3,true)
		end)
		task.delay(228/60,function()
			emit(Directory.smoke,true)
		end)
		task.delay(264/60,function()
			emit(Directory.slash4,true)
		end)
		task.delay(290/60,function()
			emit(Directory.flashstep,true)
			for i,v in pairs(Character:GetDescendants()) do
				if v:IsA('BasePart') or v:IsA('Decal') or v:IsA('Texture') then
					coroutine.resume(coroutine.create(function()
						local originaltransparency = v.Transparency
						game:GetService("TweenService"):Create(v,TweenInfo.new(.4,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
						task.delay((458-290)/60, function()
							if v ~= nil then
								game:GetService("TweenService"):Create(v,TweenInfo.new(.4,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Transparency = originaltransparency}):Play()
							end
						end)
					end))
				end
				if v:IsA('ParticleEmitter') or v:IsA('Beam') or v:IsA('Trail') then
					coroutine.resume(coroutine.create(function()
						local originalenabled = v.Enabled
						v.Enabled = false
						task.delay((458-290)/60, function()
							if v ~= nil then
								v.Enabled = originalenabled
							end
						end)
					end))
				end
			end
		end)
		task.delay(304/60,function()
			emit(Directory.shadow,true,true)
		end)
		task.delay(458/60,function()
			emit(Directory.flashstep2,true)
		end)
	end,
	["BACKVFX1"] = function(Character,theenemy)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].BackVFX1.Attachment:Clone()
		RedFX15.Parent = theenemy.Torso
		game.Debris:AddItem(RedFX15,7)
		for i,v in pairs(RedFX15:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
					v:Emit((v:GetAttribute('EmitCount') or 1)/6)
				else
					v:Emit((v:GetAttribute('EmitCount')) or 1)
				end
			end
		end
		task.delay(140/60,function()
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
			end
		end)
	end,
	["HEADFX"] = function(Character,theenemy)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].HeadFX.Attachment:Clone()
		RedFX15.Parent = theenemy.Head
		game.Debris:AddItem(RedFX15,6)
		RedFX15["s"..math.random(1,4)]:Play()
		RedFX15.s55:Play()
		for i,v in pairs(RedFX15:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
					v:Emit((v:GetAttribute('EmitCount') or 1)/6)
				else
					v:Emit((v:GetAttribute('EmitCount')) or 1)
				end
			end
		end
	end,
	["EXTENDVFX"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.clothsfx15:Clone()
		RedFX2425.Parent = Character.HumanoidRootPart
		game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
		RedFX2425:Play()
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			for i ,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants())do
				if  v:IsA('Trail') then
					if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad") then
						Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad"):Destroy()
					end
					local v1 = v:Clone()
					v1.Enabled = true
					v1.Name = ("lolazoverdad")
					v1.Parent =Character["Right Arm"]:FindFirstChild("remiliaspear")
					task.delay(100/60,function()
						v1.Enabled = false
						game.Debris:AddItem(v1,.5)
					end)
				end
			end
		end
		local function flare()
			if not Character.Values:FindFirstChild("Stunned") then

				local mathrandom = math.random(1,2)
				if not Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir"..mathrandom].IsPlaying then
					Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir"..mathrandom]:Play()
				end
				if Character["Right Arm"]:FindFirstChild("remiliaspear") then
					Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
					Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
				end
				local highlight = script.Parent.Highlight:Clone()
				highlight.Parent = Character
				game:GetService("TweenService"):Create(highlight, TweenInfo.new(5/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 0}):Play()
				task.delay(5/60,function()
					game:GetService("TweenService"):Create(highlight, TweenInfo.new(15/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 1}):Play()
					game.Debris:AddItem(highlight,1)
				end)
			end
		end
		local function swingsoundspear()
			if not Character.Values:FindFirstChild("Stunned") then
				flare()
				local RedFX=ResourceFolder["movesound"]:Clone() 
				Debris:AddItem(RedFX,5)
				RedFX.Parent = Character.Torso
				RedFX:Play()
				local RedFX=ResourceFolder["spear152"]:Clone() 
				Debris:AddItem(RedFX,5)
				RedFX.Parent = Character.Torso
				RedFX:Play()
				RedFX.PlaybackSpeed = Random.new():NextNumber(0.95,1.2)
				local RedFX=ResourceFolder["spear35"]:Clone() 
				Debris:AddItem(RedFX,5)
				RedFX.Parent = Character.Torso
				RedFX:Play()
				RedFX.PlaybackSpeed = Random.new():NextNumber(0.95,1.2)

				task.delay(7/60,function()
					if not Character.Values:FindFirstChild("Stunned") then
						local RedFX=ResourceFolder.Sfx.Swings['s'..math.random(1,4)]:Clone() 
						Debris:AddItem(RedFX,5)
						RedFX.Parent = Character.Torso
						RedFX:Play()
						local RedFX=ResourceFolder["spear152"]:Clone() 
						Debris:AddItem(RedFX,5)
						RedFX.Parent = Character.Torso
						RedFX:Play()
						RedFX.PlaybackSpeed = Random.new():NextNumber(0.95,1.2)
					end
				end)
				local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.spearswing2:Clone()
				RedFX2425.Parent = Character.HumanoidRootPart
				game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .5)
				RedFX2425:Play()
				if Character["Right Arm"]:FindFirstChild("remiliaspear")["swing1"].IsPlaying then
					if not Character["Right Arm"]:FindFirstChild("remiliaspear")["swing2"].IsPlaying then
						Character["Right Arm"]:FindFirstChild("remiliaspear")["swing2"]:Play()
					end
				else
					if not Character["Right Arm"]:FindFirstChild("remiliaspear")["swing1"].IsPlaying then
						Character["Right Arm"]:FindFirstChild("remiliaspear")["swing1"]:Play()
					end	
				end
				Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir3"]:Play()
			end
		end
		task.delay(19/60,function()
			if not Character.Values:FindFirstChild("Stunned") then
				swingsoundspear()

				local RedFX156 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].ExtendSlash1["FIRSTSLASH"]:Clone()
				RedFX156.Parent = Character.HumanoidRootPart
				game.Debris:AddItem(RedFX156,1.5)
				for i,v in pairs(RedFX156:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
		end)
		task.delay(55/60,function()
			if not Character.Values:FindFirstChild("Stunned") then
				local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.clothsfx14:Clone()
				RedFX2425.Parent = Character.HumanoidRootPart
				game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
				RedFX2425:Play()
				swingsoundspear()
				--local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].ExtendSlash2.Attach221ment:Clone()
				--RedFX15.Parent = Character.HumanoidRootPart
				--game.Debris:AddItem(RedFX15,1.5)
				--for i,v in pairs(RedFX15:GetDescendants()) do
				--	if v:IsA('ParticleEmitter') then
				--		v:Emit(v:GetAttribute('EmitCount') or 1)
				--	end
				--end

				local RedFX156 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].ExtendSlash1["SECONDSLASH"]:Clone()
				RedFX156.Parent = Character.HumanoidRootPart
				game.Debris:AddItem(RedFX156,1.5)
				for i,v in pairs(RedFX156:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
		end)
	end,
	["BLOODSMASHVFX"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end

		local floorInstance = RayCastOnMap(Character.HumanoidRootPart.Position,Vector3.new(0,-15,0),true)
		if floorInstance then

			local RedFX21 = ResourceFolder.Parent.Snatch.bloodsmash:Clone()
			RedFX21[math.random(1,3)]:Play()
			RedFX21.Position = floorInstance.Position + Vector3.new(0,0.05,0)
			RedFX21.Parent = workspace.Ignore.Effects
			game.Debris:AddItem(RedFX21,10)			--RedFX21.sfx:Play()
			for i,v in pairs(RedFX21:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(3)
				end
			end
		end
	end,
	["WALLCOMBOVFX"] = function(Character,theenemy,rootpart51,rootpart56,v45)
		local RedFX2425=ResourceFolder.wallcombosfx:Clone()
		RedFX2425.Parent = Character.Torso
		game.Debris:AddItem(RedFX2425,5)
		RedFX2425:Play()
	    --local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.clothsfx14:Clone()
		--RedFX2425.Parent = Character.HumanoidRootPart
		--game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
		--RedFX2425:Play()
		local count = 0
		local count2 = 0
		local RedFX=ResourceFolder.Hit.VFX:Clone()
		RedFX.Parent=theenemy.Torso
		--RedFX['h'..math.random(1,4)]:Play()

		Debris:AddItem(RedFX,1.6)
		for i,v in pairs(RedFX:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
					v:Emit((v:GetAttribute('EmitCount') or 1)/6)
				else
					v:Emit((v:GetAttribute('EmitCount')) or 1)
				end
			end
		end
		--if Character["Right Arm"]:FindFirstChild("remiliaspear") then
		--	Character["Right Arm"]:FindFirstChild("remiliaspear")["Impale"]:Play()
		--end
		--task.delay(20/60,function()
		--	local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.jumpsfx:Clone()
		--	RedFX2425.Parent = Character.HumanoidRootPart
		--	game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
		--	RedFX2425:Play()
		--end)
		local function effectdownslam()
			if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
			local effectDowsnalm = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.WallHit:Clone()
			local position = v45:GetClosestPointOnSurface(Character.HumanoidRootPart.Position)
			effectDowsnalm.Parent = workspace.Ignore.Effects
			effectDowsnalm.Position = position
			effectDowsnalm.CFrame = CFrame.lookAt(effectDowsnalm.Position,Character.HumanoidRootPart.Position)
			--effectDowsnalm["ROCKIMPACT"..math.random(1,2)]:Play()
			for i,v in pairs(effectDowsnalm.GroundBounce:GetDescendants()) do
				if v:IsA("ParticleEmitter") then
					v:Emit(v:GetAttribute("EmitCount"))
				end
			end
			game.Debris:AddItem(effectDowsnalm,2.5)
		end
		effectdownslam()
		local function stab1()
			if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				local Directory = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
				local function emit(instance,weld,enable)
					local instanceclone = instance:Clone()
					instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
					if weld == true then
						local Weld = Instance.new("WeldConstraint")
						Weld.Part0 = Character.HumanoidRootPart
						Weld.Part1 = instanceclone
						Weld.Name = instanceclone.Name
						Weld.Parent = instanceclone	
					else
						instanceclone.Anchored = true
					end
					instanceclone.Parent = workspace.Ignore.Effects
					if instanceclone:FindFirstChildOfClass("Model") then
						for i,v in pairs(instanceclone:GetDescendants()) do
							if v:IsA('Model') and v:FindFirstChild("Start") then
								local modelclone = v
								modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
								modelclone.Parent = workspace.Ignore.Effects
								task.delay(modelclone:GetAttribute("EmitDelay"),function()
									local decalparams
									if modelclone:GetAttribute("Decal_TweenParams") then
										decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
									else
										local decalparams2 = "Cubic,Out"
										decalparams = string.split(decalparams2, ",")
									end
									local partparams
									if modelclone:GetAttribute("Part_TweenParams") then
										partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
									else
										local partparams2 = "Cubic,Out"
										partparams = string.split(partparams2, ",")
									end
									game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
									v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
									game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
								end)
								--for ie,ve in pairs(modelclone:GetChildren()) do
								--end
							end
						end
					end

					game.Debris:AddItem(instanceclone,5)
					for i,v in pairs(instanceclone:GetDescendants()) do
						if v:IsA('ParticleEmitter') then
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								v:Emit((v:GetAttribute('EmitCount') or 1)/6)
							else
								v:Emit((v:GetAttribute('EmitCount')) or 1)
							end
						end
					end
				end
				emit(Directory.impact5REMI,false)
			end
		end
		local function flare()
			if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
			--local mathrandom = math.random(1,2)
			--if not Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir"..mathrandom].IsPlaying then
			--	Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir"..mathrandom]:Play()
			--end
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
				Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
			end
			local highlight = script.Parent.Highlight:Clone()
			highlight.Parent = Character
			game:GetService("TweenService"):Create(highlight, TweenInfo.new(5/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 0}):Play()
			task.delay(5/60,function()
				game:GetService("TweenService"):Create(highlight, TweenInfo.new(15/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 1}):Play()
				game.Debris:AddItem(highlight,1)
			end)
		end
		local function swingsoundspear()
			--local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.spearswing2:Clone()
			--RedFX2425.Parent = Character.HumanoidRootPart
			--game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
			--RedFX2425:Play()
			flare()
			--if Character["Right Arm"]:FindFirstChild("remiliaspear")["swing1"].IsPlaying then
			--	if not Character["Right Arm"]:FindFirstChild("remiliaspear")["swing2"].IsPlaying then
			--		Character["Right Arm"]:FindFirstChild("remiliaspear")["swing2"]:Play()
			--	end
			--else
			--	if not Character["Right Arm"]:FindFirstChild("remiliaspear")["swing1"].IsPlaying then
			--		Character["Right Arm"]:FindFirstChild("remiliaspear")["swing1"]:Play()
			--	end	
			--end
			--Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir3"]:Play()
		end
		task.delay(121/60,function()
			effectdownslam()
			--if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			--	Character["Right Arm"]:FindFirstChild("remiliaspear")["Impale"]:Play()
			--end
			local RedFX=ResourceFolder.Hit.VFX:Clone()
			RedFX.Parent=theenemy.Torso
			--RedFX['h'..math.random(1,4)]:Play()
			Debris:AddItem(RedFX,1.6)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end)
		task.delay(74/60,function()
			--local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.clothsfx12:Clone()
			--RedFX2425.Parent = Character.HumanoidRootPart
			--game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
			--RedFX2425:Play()
			swingsoundspear()
		end)
		task.delay(45/60,function()
			swingsoundspear()
		end)
		task.delay(26/60,function()
			swingsoundspear()
		end)
		task.delay(76/60,function()
			if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
			local RedFX=ResourceFolder.Hit.VFX:Clone()
			RedFX.Parent=theenemy.Torso
			--RedFX['h'..math.random(1,4)]:Play()

			Debris:AddItem(RedFX,1.6)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Skill3SlashOverhead["OVERHEADSLASH"]:Clone()
			RedFX15.Parent = Character.HumanoidRootPart
			game.Debris:AddItem(RedFX15,1.5)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end)
		task.delay(191/60,function()
			swingsoundspear()
		end)
		task.delay(195/60,function()
			if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
			local RedFX=ResourceFolder.Hit.VFX:Clone()
			RedFX.Parent=theenemy.Torso
			--RedFX['h'..math.random(1,3)]:Play()

			Debris:AddItem(RedFX,1.6)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Skill3SlashOverhead.LASTSLASH:Clone()
			RedFX15.Parent = Character.HumanoidRootPart
			game.Debris:AddItem(RedFX15,1.5)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				Character["Right Arm"]:FindFirstChild("remiliaspear")["slash"]:Play()
			end
		end)
		task.delay(47/60,function()
			if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
			local RedFX=ResourceFolder.Hit.VFX:Clone()
			RedFX.Parent=theenemy.Torso
			--RedFX['h'..math.random(1,4)]:Play()

			Debris:AddItem(RedFX,1.6)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Skill3Slash["FIRSTSLASH"]:Clone()
			RedFX15.Parent = Character.HumanoidRootPart
			game.Debris:AddItem(RedFX15,1.5)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end)
		task.delay(163/60,function()
			if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
			local RedFX=ResourceFolder.Hit.VFX:Clone()
			RedFX.Parent=theenemy.Torso
			--RedFX['h'..math.random(1,4)]:Play()
			--local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.clothsfx15:Clone()
			--RedFX2425.Parent = Character.HumanoidRootPart
			--game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
			--RedFX2425:Play()
			--if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			--	Character["Right Arm"]:FindFirstChild("remiliaspear")["Impale2"]:Play()
			--end
			--if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			--	Character["Right Arm"]:FindFirstChild("remiliaspear")["smash"]:Play()
			--end
			Debris:AddItem(RedFX,1.6)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].WallComboSlam.Attachment1121:Clone()
			RedFX15.Parent = Character.HumanoidRootPart
			game.Debris:AddItem(RedFX15,1.5)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end)
		task.delay(32/60,function()
			if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
			local RedFX=ResourceFolder.Hit.VFX:Clone()
			RedFX.Parent=theenemy.Torso
			--RedFX['h'..math.random(1,4)]:Play()

			Debris:AddItem(RedFX,1.6)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Skill3SlashReverse["FIRSTSLASH"]:Clone()
			RedFX15.Parent = Character.HumanoidRootPart
			game.Debris:AddItem(RedFX15,1.5)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end)
		task.delay(14/60,function()
			--if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			--	Character["Right Arm"]:FindFirstChild("remiliaspear")["Impale2"]:Play()
			--end
			if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
			local RedFX=ResourceFolder.Hit.VFX:Clone()
			RedFX.Parent=theenemy.Torso
			--RedFX['h'..math.random(1,4)]:Play()

			Debris:AddItem(RedFX,1.6)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end)
		task.delay(114/60,function()
			stab1()
			swingsoundspear()
		end)
		local function vortex()
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Attachm122ent:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
		end
		local function vortex2()
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Attachm122ent:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
		end
		task.delay(176/60,function()
			vortex()
		end)
		task.delay(200/60,function()
			vortex2()
		end)
		task.delay(215/60,function()
			vortex2()
		end)
		task.delay(235/60,function()
			vortex()
		end)

		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
			for i ,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants())do
				if  v:IsA('Trail') then
					if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad") then
						Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad"):Destroy()
					end
					local v1 = v:Clone()
					v1.Enabled = true
					v1.Name = ("lolazoverdad")
					v1.Parent =Character["Right Arm"]:FindFirstChild("remiliaspear")
					task.delay(235/60,function()
						v1.Enabled = false
						game.Debris:AddItem(v1,.5)
					end)
				end
			end
		end
	end,
	["DRILLSFX"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		coroutine.resume(coroutine.create(function()
			local attacking = true
			coroutine.resume(coroutine.create(function()
				while attacking == true do
					local sound1 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat["bladespin"..math.random(1,3)]:Clone()	
					sound1.Parent = Character.HumanoidRootPart
					sound1:Play()
					game.Debris:AddItem(sound1,sound1.TimeLength)
					wait(.05)
				end
			end))
			wait((58/60) - (34/60))
			attacking = false
		end))
	end,
	["MISERABLEFATETWEEN"] = function(character,enemy,tweentime)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		character.HumanoidRootPart.Anchored = true
		game:GetService("TweenService"):Create(character.HumanoidRootPart, TweenInfo.new(tweentime, Enum.EasingStyle.Linear), {CFrame = (enemy.HumanoidRootPart.CFrame * CFrame.new(0,0,-2))*CFrame.Angles(0,math.rad(180),0)}):Play()
		task.delay(tweentime,function()
			character.HumanoidRootPart.Anchored = false
		end)
	end,
	["CHAINDESTROY"] = function(player,clone)
		coroutine.resume(coroutine.create(function()
			for _,v in pairs(clone:GetChildren()) do

				spawn(function()
					--for i = 1,math.random(6,8) do
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == false then
						if game.ReplicatedStorage.Assets.VFX:FindFirstChild(v.Name) then
							local newpart = game.ReplicatedStorage.Assets.VFX:FindFirstChild(v.Name):Clone()
							newpart.Anchored = false
							newpart.Parent = workspace.Ignore.Effects
							newpart.ParticleDot:Emit(20)
							--newpart.Size = Vector3.new(1,1,1)
							newpart.Position = v.Position
							newpart.CFrame = newpart.CFrame
							newpart.Name = "ef"
							game.Debris:AddItem(newpart,7)
							newpart.Reflectance = v.Reflectance
							newpart.Transparency = v.Transparency
							newpart.Material = v.Material or v.Parent.Material
							newpart.CanCollide = false

							newpart.BrickColor = v.BrickColor
							newpart.chainBreak:Play()

							newpart.Velocity = Vector3.new(math.random(-15,15),math.random(-5,25),math.random(-15,15))
							newpart.RotVelocity = Vector3.new(math.random(-10,10),math.random(-10,10),math.random(-10,10))
							--task.delay(5,function()

							--						end
							local BodyForce = Instance.new("BodyForce", newpart)
							BodyForce.Force = Vector3.new(0,newpart:GetMass()*170,0)
							spawn(function()
								wait(0.5)
								local v4 = CreateTween(newpart, { 1, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0 }, {
									Transparency = 1
								}, true);
								game.Debris:AddItem(newpart,1)
							end)
						end
					end
					v:Destroy()
				end)
			end
		end))
	end,
	["speartween1"] = function(Character)
		for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
			if v:IsA("BasePart") then
				local sizeado = v.Size
				v.Size = Vector3.new(0,0,0)
				v.Transparency = 1
				game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Size = sizeado,Transparency = 0}):Play()
			end
		end
	end,
	["KNOCKBACKRELATIVETO"] = function(Character,EXPLCFRAME)
		if Character then
			for _, Bodymover in pairs(Character.HumanoidRootPart:GetDescendants()) do
				if Bodymover.Name == ("GrabWeld") then return end
				if Bodymover:IsA("BodyMover") then
					Bodymover:Destroy()
				end
			end
			local lv = Instance.new("BodyVelocity")
			lv.Name = "GrabWeld"
			lv.MaxForce = Vector3.new(20000,20000,20000)
			lv.Parent = Character.HumanoidRootPart
			lv.Velocity = ((EXPLCFRAME.Position - Character.HumanoidRootPart.CFrame.Position).Unit *-(100)) + Vector3.new(0,40,0)
			game.Debris:AddItem(lv,.1)
		end
	end,
	["HEARTBREAKVELOCITY"] = function(Character)
		wait(.15)
		if not Character.Values:FindFirstChild("Stunned") then
			local pos = Character.HumanoidRootPart.CFrame
			local GoalPosition = RayCastOnMap(pos.p, Vector3.new(0,20,0))
			if GoalPosition == pos.p then
				GoalPosition = pos.p + Vector3.new(0,20,0)
			else
				GoalPosition = GoalPosition - Vector3.new(0,1.5,0)
			end
			local BP = Instance.new("BodyPosition")
			BP.D = 400
			BP.P = 1100
			BP.MaxForce = Vector3.new(20000,20000,20000)
			BP.Position = GoalPosition
			BP.Parent = Character.HumanoidRootPart
		end
	end,
	["SKILL3HITSTARTVFX"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			local Directory = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
			local function emit(instance,weld,enable)
				local instanceclone = instance:Clone()
				instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
				if weld == true then
					local Weld = Instance.new("WeldConstraint")
					Weld.Part0 = Character.HumanoidRootPart
					Weld.Part1 = instanceclone
					Weld.Name = instanceclone.Name
					Weld.Parent = instanceclone	
				else
					instanceclone.Anchored = true
				end
				instanceclone.Parent = workspace.Ignore.Effects
				if instanceclone:FindFirstChildOfClass("Model") then
					for i,v in pairs(instanceclone:GetDescendants()) do
						if v:IsA('Model') and v:FindFirstChild("Start") then
							local modelclone = v
							modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
							modelclone.Parent = workspace.Ignore.Effects
							task.delay(modelclone:GetAttribute("EmitDelay"),function()
								local decalparams
								if modelclone:GetAttribute("Decal_TweenParams") then
									decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
								else
									local decalparams2 = "Cubic,Out"
									decalparams = string.split(decalparams2, ",")
								end
								local partparams
								if modelclone:GetAttribute("Part_TweenParams") then
									partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
								else
									local partparams2 = "Cubic,Out"
									partparams = string.split(partparams2, ",")
								end
								game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
								v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
								game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
							end)
							--for ie,ve in pairs(modelclone:GetChildren()) do
							--end
						end
					end
				end

				game.Debris:AddItem(instanceclone,5)
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
			emit(Directory.impact5REMI,false)
		end
	end,
	["THEMISERABLEFATEVFX"] = function(Character,Enemy)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local T = os.clock()
		repeat 
			wait() 
		until ((Character.HumanoidRootPart.Position - Enemy.HumanoidRootPart.Position).Magnitude <= 5) or os.clock() - T >= 3
		local Directory = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		emit(Directory.impact5REMI,false)
	end,
	["DASHM1VFX"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
		local function emit(instance,weld,characterc)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = characterc.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = characterc.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = characterc.HumanoidRootPart	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(characterc.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = game.Workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame,Size = modelclone:FindFirstChild("End").Size}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
					end
				end
			end

			game.Debris:AddItem(instanceclone,4)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if Character["Right Arm"]:FindFirstChild("remiliaspear") then
						if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("thorhammerhit1") then
							v.Color = ColorSequence.new{
								ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
							}
						end
					end
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
		end
		--task.delay(.01,function()
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				if ((Character:GetAttribute("Awakened")) or (Character:FindFirstChild("MilleniumVampire"))) then
					emit(Directory.ground1,false,Character)
					emit(Directory.slash2,false,Character)
				else
					local Directory = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
					local function emit(instance,weld,enable)
						local instanceclone = instance:Clone()
						instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
						if weld == true then
							local Weld = Instance.new("WeldConstraint")
							Weld.Part0 = Character.HumanoidRootPart
							Weld.Part1 = instanceclone
							Weld.Name = instanceclone.Name
							Weld.Parent = instanceclone	
						else
							instanceclone.Anchored = true
						end
						instanceclone.Parent = workspace.Ignore.Effects
						if instanceclone:FindFirstChildOfClass("Model") then
							for i,v in pairs(instanceclone:GetDescendants()) do
								if v:IsA('Model') and v:FindFirstChild("Start") then
									local modelclone = v
									modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
									modelclone.Parent = workspace.Ignore.Effects
									task.delay(modelclone:GetAttribute("EmitDelay"),function()
										local decalparams
										if modelclone:GetAttribute("Decal_TweenParams") then
											decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
										else
											local decalparams2 = "Cubic,Out"
											decalparams = string.split(decalparams2, ",")
										end
										local partparams
										if modelclone:GetAttribute("Part_TweenParams") then
											partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
										else
											local partparams2 = "Cubic,Out"
											partparams = string.split(partparams2, ",")
										end
										game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
										v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
										game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
									end)
									--for ie,ve in pairs(modelclone:GetChildren()) do
									--end
								end
							end
						end

					game.Debris:AddItem(instanceclone,5)
					for i,v in pairs(instanceclone:GetDescendants()) do
						if v:IsA('ParticleEmitter') then
							if Character["Right Arm"]:FindFirstChild("remiliaspear") then
								if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("thorhammerhit1") then
									v.Color = ColorSequence.new{
										ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
									}
								end
							end
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								v:Emit((v:GetAttribute('EmitCount') or 1)/6)
							else
								v:Emit(v:GetAttribute('EmitCount') or 1)
							end
						end
					end
				end
				task.delay(.01,function()
					emit(Directory.impact5REMI,false)
end)
				end
				if Character:FindFirstChild("gunganire").Value == true then
					if Character["Right Arm"]:FindFirstChild("remiliaspear") then
						for i ,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants())do
							if  v:IsA('Trail') then
								if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad") then
									Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad"):Destroy()
								end
								local v1 = v:Clone()
								v1.Enabled = true
								v1.Name = ("lolazoverdad")
								v1.Parent =Character["Right Arm"]:FindFirstChild("remiliaspear")
								task.delay(.6,function()
									v1.Enabled = false
									game.Debris:AddItem(v1,.5)
								end)
							end
						end
					end
				end
				--elseif Character["Right Arm"]:FindFirstChild("LowRes_Gungir2_Body") then
				
			--	game.Debris:AddItem(RedFX15,5)
			--	for i ,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants())do
			--		if  v:IsA('Trail') then
			--			v.Enabled = true
			--		end
			--	end
			--	task.delay(.7,function()
			--		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			--			for i ,v in pairs(Character["Right Arm"]:FindFirstChild("LowRes_Gungir2_Body"):GetDescendants())do
			--				if  v:IsA('Trail') then
			--					v.Enabled = false
			--				end
			--			end
			--		end
			--	end)
			end
		--end)
	end,
	["ARMTRAIL"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local FX= game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.DashTrail:Clone()
		FX.Parent=Character
		FX.w.Part0= Character['Left Arm']
		game.Debris:AddItem(FX,2)
		task.delay(.5,function()
			for i ,v in pairs(FX:GetDescendants())do
				if v:IsA('Trail') then
					v.Enabled = false
				end
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
				if v:IsA("PointLight") then
					game:GetService("TweenService"):Create(v, TweenInfo.new(.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Range = 0}):Play()
				end
			end
		end)
	end,
	["SmashWhenGround"] = function(Enemy,Length)
		task.wait(.45)
		local detecting = true
		local hit = true
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = {workspace.Map}

		task.delay(Length,function()
			detecting = false
		end)

		while detecting and hit do
			for i ,Object in pairs(workspace:GetPartBoundsInBox(Enemy.HumanoidRootPart.CFrame,Vector3.new(10,10,10),params)) do			
				if Object:IsA("BasePart") then					
					detecting = false

					local RootCF = CFrame.new(Enemy.HumanoidRootPart.Position + Vector3.new(0,3,0))


					local AppearTime = .17
					local Tilt = 25
					local Distance = 7
					local CollectAfter = 4.5
					local CollectLength = 7
					local HeightOffset = -2
					local HowMuchDown = -5 --how below the ground it is when it appears
					local HowMuchDownCollect = -10 --how below the ground it goes 
					local HowMuchUp = 15
					local DownRayLength = -20
					local NumberOfRocks =5 
					--Module.RockSpawn1(script.Parent, NumberOfRocks, SizeX, SizeY, SizeZ, Distance)
					--	Module.RockSpawn2(RootCF , NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset-1.8,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --inside and smal;er
					--Module.RockSpawn2(RootCF, NumberOfRocks , SizeX, SizeY, SizeZ, Distance+.7,CollectAfter,HeightOffset-2.1,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --outside and bigger

					-- Rock Flying ==
					local Height = 100

					local SizeX = 1.3
					local SizeY = 1.3
					local SizeZ = 1.3
					local CollideAfter = .5
					local Spread = 30

					Module.RockFlying(RootCF , Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)
					local SizeX = 1.5
					local SizeY = 1.5
					local SizeZ = 1.5
					Module.RockFlying(RootCF , Height, SizeX*2.3, SizeY/10, SizeZ*2.3, NumberOfRocks,CollideAfter,Spread)
					Module.RockFlying(RootCF, Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)

					Basemd.SmashTile(RootCF)

					--Round 2
					local AppearTime = .19

					local CollectLength =5.6
					local HowMuchDown = -7
					local AppearTime = .21
					local HowMuchUp = 14
					--Round 3


					local SizeX = 5 
					local SizeY = 5
					local SizeZ = 5
					local Tilt = 34
					-- Ground spawn --
					local Distance = 2

					local NumberOfRocks = 7
					Module.RockSpawn2(RootCF, NumberOfRocks, SizeX, SizeY, SizeZ, Distance,CollectAfter,HeightOffset,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true) --inside and smal;er
					RootCF = RootCF * CFrame.Angles(0,math.rad(90),0)

					Module.RockSpawn2(RootCF, NumberOfRocks, SizeX/1.2, SizeY/1.2, SizeZ/1.2, Distance+4,CollectAfter,HeightOffset,Tilt+40,CollectLength+.3,AppearTime,HowMuchDown,HowMuchDownCollect,true)

					local CollectLength =9
					local Distance = 6
					--.RockSpawn2(RootCF, NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset+.15,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true)

					break
				end
			end

			task.wait()
		end

	end,
	["CEILINGFEARVFX"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local uno = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CEILINGFEAR["ceilingfear1"]:Clone()
		uno.Parent = Character.HumanoidRootPart
		game.Debris:AddItem(uno,((58/60)-(34/60)) + 1)
		local enabled = true
		for i,v in pairs(uno:GetDescendants()) do
			coroutine.resume(coroutine.create(function()
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
					while enabled == true do
						local rate = v.Rate
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							rate = v.Rate / 5
						end
						wait(1/rate)
						v:Emit(1)
					end
				end
			end))
		end
		local dos = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CEILINGFEAR["ceilingfear2"]:Clone()
		dos.Parent = Character.HumanoidRootPart
		game.Debris:AddItem(dos,((58/60)-(34/60)) + 1)
		for i,v in pairs(dos:GetDescendants()) do
			coroutine.resume(coroutine.create(function()
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
					while enabled == true do
						local rate = v.Rate
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							rate = v.Rate / 5
						end
						wait(1/rate)
						v:Emit(1)
					end
				end
			end))
		end
		local tres = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CEILINGFEAR["ceilingfear3"]:Clone()
		tres.Parent = Character.HumanoidRootPart
		game.Debris:AddItem(tres,((58/60)-(34/60)) + 1)
		for i,v in pairs(tres:GetDescendants()) do
			coroutine.resume(coroutine.create(function()
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
					while enabled == true do
						local rate = v.Rate
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							rate = v.Rate / 5
						end
						wait(1/rate)
						v:Emit(1)
					end
				end
			end))
		end
	--if Character["Right Arm"]:FindFirstChild("remiliaspear") then
		--	for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").ceilingfear1:GetChildren()) do
		--		if v:IsA("ParticleEmitter") then
		--			v.Enabled = true
		--		end
		--	end
		--	for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").ceilingfear2:GetChildren()) do
		--		if v:IsA("ParticleEmitter") then
		--			v.Enabled = true
		--		end
		--	end
		--	for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").ceilingfear3:GetChildren()) do
		--		if v:IsA("ParticleEmitter") then
		--			v.Enabled = true
		--		end
		--	end
		--end
		task.delay((58/60)-(34/60),function()
enabled = false
		--	if Character["Right Arm"]:FindFirstChild("remiliaspear") then
		--		for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").ceilingfear1:GetChildren()) do
		--			if v:IsA("ParticleEmitter") then
		--				v.Enabled = false
		--			end
		--		end
		--		for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").ceilingfear2:GetChildren()) do
		--			if v:IsA("ParticleEmitter") then
		--				v.Enabled = false
		--			end
		--		end
		--		for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").ceilingfear3:GetChildren()) do
		--			if v:IsA("ParticleEmitter") then
		--				v.Enabled = false
		--			end
		--		end
		--	end
		end)
	end,
	["RUBBLESLAM"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		coroutine.resume(coroutine.create(function()
			local RootCF = CFrame.new(Character.HumanoidRootPart.Position + Vector3.new(0,4,0))

			local AppearTime = .17
			local Tilt = 25
			local Distance = 8
			local CollectAfter = 4.5
			local CollectLength = 7
			local HeightOffset = -2
			local HowMuchDown = -5 --how below the ground it is when it appears
			local HowMuchDownCollect = -10 --how below the ground it goes 
			local HowMuchUp = 15
			local DownRayLength = -20
			local NumberOfRocks =4 
			--Module.RockSpawn1(script.Parent, NumberOfRocks, SizeX, SizeY, SizeZ, Distance)
			--	Module.RockSpawn2(RootCF , NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset-1.8,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --inside and smal;er
			--Module.RockSpawn2(RootCF, NumberOfRocks , SizeX, SizeY, SizeZ, Distance+.7,CollectAfter,HeightOffset-2.1,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --outside and bigger

			-- Rock Flying ==
			local Height = 75

			local SizeX =.5
			local SizeY = .5
			local SizeZ = .5
			local CollideAfter = .5
			local Spread = 30

			Module.RockFlying(RootCF , Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)
			local SizeX = 1.3
			local SizeY = 1.3
			local SizeZ = 1.3
			Module.RockFlying(RootCF , Height, SizeX*2.3, SizeY/10, SizeZ*2.3, NumberOfRocks,CollideAfter,Spread)
			Module.RockFlying(RootCF, Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)

			Basemd.SmashTile(RootCF)

			--Round 2
			local AppearTime = .19

			local CollectLength =5.6
			local HowMuchDown = -7
			local AppearTime = .21
			local HowMuchUp = 14
			--Round 3


			local SizeX = 4 
			local SizeY = 4
			local SizeZ = 4
			-- Ground spawn --
			local Distance = Random.new():NextNumber(1.4,1.6)
			if numberofrocksrubbleslam == 3 then
				numberofrocksrubbleslam = 4 
			elseif numberofrocksrubbleslam == 4 then
				numberofrocksrubbleslam = 3 
			end
			RootCF = CFrame.new(Character.Torso.Position + Vector3.new(0,math.random(8.5,9),0))
			Module.RockSpawn2(RootCF, numberofrocksrubbleslam, Random.new():NextNumber(4.1,4.6), Random.new():NextNumber(4.1,4.6), Random.new():NextNumber(4,4.7), Random.new():NextNumber(1,2.5),CollectAfter,HeightOffset,Random.new():NextNumber(19.4,20),CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true) --inside and smal;er
			RootCF = RootCF * CFrame.Angles(0,math.rad(90),0)

			local CollectLength =7
			local Distance = 6
			--.RockSpawn2(RootCF, NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset+.15,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true)

			local p5=ResourceFolder.wind:Clone()
			Debris:AddItem(p5,.31)
			p5.Parent= workspace.Ignore.Effects
			p5.CFrame= RootCF * CFrame.new(0,-4,0)
			p5.Orientation =Vector3.new(0, 0, -90)			
			local TweenFX = game:GetService("TweenService"):Create(p5, TweenInfo.new(0.3, Enum.EasingStyle.Sine,Enum.EasingDirection.Out), {Transparency = 1,Size = Vector3.new(0.35, 15.92, 15.92),Position = p5.Position + Vector3.new(0,-1.5,0) , Orientation = Vector3.new(0, 0, -90) })
			TweenFX:Play()

		end))
	end,
	["STARTHEARTBREAKRANGED"] = function(Character)
		local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.heartbreakstartupsfx:Clone()
		sound1.Parent = Character.HumanoidRootPart
		sound1:Play()
		game.Debris:AddItem(sound1,3)
		local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
		local function emit(instance,weld,characterc)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = characterc.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = characterc.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = characterc.HumanoidRootPart	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(characterc.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = game.Workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame,Size = modelclone:FindFirstChild("End").Size}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,4)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit(v:GetAttribute('EmitCount') or 1)
					end
					if Character["Right Arm"]:FindFirstChild("remiliaspear") then
						if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
							v.Color = ColorSequence.new{
								ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
							}
						end
					end
				end
			end
		end
		local floorInstance = RayCastOnMap(Character.Torso.Position,Vector3.new(0,-15,0),true)
		if floorInstance then
			local RedFX2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.jumpground:Clone()
			RedFX2.Parent = workspace.Ignore.Effects
			game.Debris:AddItem(RedFX2,2)
			RedFX2.Position = floorInstance.Position + Vector3.new(0,2,0)
			for i,v in pairs(RedFX2:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount') * 1.2) or 2)
					end
					if Character["Right Arm"]:FindFirstChild("remiliaspear") then
						if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
							v.Color = ColorSequence.new{
								ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
							}
						end
					end
				end
			end
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - RedFX2.Position).Magnitude <= 15 then
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(4, 4, .4,.5)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end
		--emit(Directory.ground1,false,Character)
		local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
		for _,l in limbs do
			if Character[l]:FindFirstChild("dash0") then
				for _,thing in Character[l]:GetChildren() do
					if thing:IsA("Trail") and string.find(thing.Name, "dash") then
						thing.Enabled = true
					end
				end
			else
				local dash_vfx = dashLimbs:Clone():GetChildren()
				for _,p in dash_vfx do
					p.Parent = Character[l]
					if p:IsA("Trail") then
						p.Enabled = true
					end
				end
			end
		end
		task.delay(35/60,function()
			for _,l in limbs do
				if Character[l]:FindFirstChild("dash0") then
					for _,thing in Character[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = false
						end
					end
				end
			end
		end)
		coroutine.resume(coroutine.create(function()
			local enabled = true
			task.delay(35/60,function()
				enabled = false
			end)
			local a = ResourceFolder.windtrail:Clone()
			a.Parent = workspace.Ignore.Effects
			a.CFrame = CFrame.new(Character.Torso.Position)
			game.Debris:AddItem(a,5)
			for i,v in pairs(a:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						while enabled == true do
							local rate = v.Rate
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								rate = v.Rate / 5
							end
							wait(1/rate)
							a.CFrame = CFrame.new(Character.Torso.Position)
							if Character["Right Arm"]:FindFirstChild("remiliaspear") then
								if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
									v.Color = ColorSequence.new{
										ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
									}
								end
							end
							v:Emit(3)
						end
					end
				end))
			end
		end))
	end,
	["GROUNDSLAM"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end

		--RedFX.sfx1:Play()
		--RedFX.sfx2:Play()
		local floorInstance = RayCastOnMap(Character.Torso.Position,Vector3.new(0,-25,0),true)
		if floorInstance then
			local RedFX2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.GroundHit:Clone()
			RedFX2.Parent = workspace.Ignore.Effects
			game.Debris:AddItem(RedFX2,2)
			RedFX2.Position = floorInstance.Position + Vector3.new(0,0.6,0)
			for i,v in pairs(RedFX2:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit(v:GetAttribute('EmitCount') or 1)
					end
				end
			end
			local RedFX = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.skill3grabslam:Clone()
			RedFX[math.random(1,3)]:Play()
			RedFX["bloodmedium"]:Play()
			RedFX["smash"]:Play()
			RedFX.Parent = workspace.Ignore.Effects
			game.Debris:AddItem(RedFX,2)
			RedFX.Position = floorInstance.Position + Vector3.new(0,0.6,0)
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - RedFX.Position).Magnitude <= 45 then
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(8, 8, .5,.7)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit(v:GetAttribute('EmitCount') or 1)
					end
				end
			end
		end
	end,
	["KISSFIRSTSKILLFINISHER"] = function(Character,Enemy)
		local Directory = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.vampirekissFINISHERSFX:Clone()
		sound1.Parent = Enemy.Head
		sound1:Play()
		game.Debris:AddItem(sound1,3.5)
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit(v:GetAttribute('EmitCount') or 1)
					end
				end
			end
		end
		local function groundslam()
			local floorInstance = RayCastOnMap(Enemy.Head.Position,Vector3.new(0,-15,0),true)
			if floorInstance then
				local RedFX21 = ResourceFolder.Parent.Snatch.bloodsmash2:Clone()
				RedFX21[math.random(1,3)]:Play()
				RedFX21.Position = floorInstance.Position + Vector3.new(0,0.05,0)
				RedFX21.Parent = workspace.Ignore.Effects
				game.Debris:AddItem(RedFX21,16)			--RedFX21.sfx:Play()
				for i,v in pairs(RedFX21:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v:Emit(4)
					end
				end
				local RedFX2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.HitGroundWeird:Clone()
				RedFX2.Parent = workspace.Ignore.Effects
				game.Debris:AddItem(RedFX2,2)
				RedFX2.Position = floorInstance.Position + Vector3.new(0,0.6,0)
				for i,v in pairs(RedFX2:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit(v:GetAttribute('EmitCount') or 1)
						end
					end
				end
				local RootCF = CFrame.new(Enemy.Head.CFrame.Position)
				local AppearTime = .17
				local Tilt = 25
				local Distance = 7
				local CollectAfter = 4.5
				local CollectLength = 7
				local HeightOffset = -2
				local HowMuchDown = -5 --how below the ground it is when it appears
				local HowMuchDownCollect = -10 --how below the ground it goes 
				local HowMuchUp = 15
				local DownRayLength = -20
				local NumberOfRocks =5 
				--Module.RockSpawn1(script.Parent, NumberOfRocks, SizeX, SizeY, SizeZ, Distance)
				--	Module.RockSpawn2(RootCF , NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset-1.8,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --inside and smal;er
				--Module.RockSpawn2(RootCF, NumberOfRocks , SizeX, SizeY, SizeZ, Distance+.7,CollectAfter,HeightOffset-2.1,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --outside and bigger

				-- Rock Flying ==
				local Height = 75

				local SizeX = 1.3
				local SizeY = 1.3
				local SizeZ = 1.3
				local CollideAfter = .5
				local Spread = 25
				coroutine.resume(coroutine.create(function()
					for i = 1,12 do
						Basemd.SmashTile(RootCF * CFrame.new(math.random(-6,6),0,math.random(-6,6)))
					end
				end))
				Module.RockFlying(RootCF , Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)
				local SizeX = 1.5
				local SizeY = 1.5
				local SizeZ = 1.5
				Module.RockFlying(RootCF , Height, SizeX*2.3, SizeY/10, SizeZ*2.3, NumberOfRocks,CollideAfter,Spread)
				Module.RockFlying(RootCF, Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)
				if math.random(1,2) == 1 then 
					RootCF = RootCF * CFrame.Angles(0,math.rad(90),0)
				end
				--Round 2
				local AppearTime = .19

				local CollectLength =5.6
				local HowMuchDown = -7
				local AppearTime = .21
				local HowMuchUp = 15


				--Round 2
				local AppearTime = .19

				local CollectLength =5.6
				local HowMuchDown = -7
				local AppearTime = .21
				local HowMuchUp = 35
				--Round 3


				local AppearTime = .17
				local Tilt = 27
				local Distance = 1
				local CollectAfter = 4.5
				local CollectLength = 4
				local HeightOffset = -1.2
				local HowMuchDown = -5 --how below the ground it is when it appears
				local HowMuchDownCollect = -10 --how below the ground it goes 
				local HowMuchUp = 15
				local DownRayLength = -20
				local NumberOfRocks =3 
				--Module.RockSpawn1(script.Parent, NumberOfRocks, SizeX, SizeY, SizeZ, Distance)
				--	Module.RockSpawn2(RootCF , NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset-1.8,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --inside and smal;er
				--Module.RockSpawn2(RootCF, NumberOfRocks , SizeX, SizeY, SizeZ, Distance+.7,CollectAfter,HeightOffset-2.1,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --outside and bigger

				-- Rock Flying ==
				local Height = 70

				local SizeX = 1.1
				local SizeY = 1.1
				local SizeZ = 1.1
				local CollideAfter = .5
				local Spread = 20
				local SizeX = 1.2
				local SizeY = 1.2
				local SizeZ = 1.2
				local SizeX = 2.2
				local SizeY = 2.2
				local SizeZ = 3.2
				local Tilt = 37

				-- Ground spawn --
				local Distance = 1.4

				local NumberOfRocks = 1
				Module.RockSpawn2(RootCF, NumberOfRocks, SizeX, SizeY, SizeZ, Distance,CollectAfter,HeightOffset,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true) --inside and smal;er
			end
		end
		local function flare()
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
				Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
			end
		end
		local function vortex()
			for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Attachm122ent:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit(v:GetAttribute('EmitCount') or 1)
					end
				end
			end
		end
		local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
		task.delay(15/60,function()
			for _,l in limbs do
				if Character[l]:FindFirstChild("dash0") then
					for _,thing in Character[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = true
						end
					end
				else
					local dash_vfx = dashLimbs:Clone():GetChildren()
					for _,p in dash_vfx do
						p.Parent = Character[l]
						if p:IsA("Trail") then
							p.Enabled = true
						end
					end
				end
			end
		end)
		local function vineta()
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 50 then
				redvignette()
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(5, 5, .4,.6)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end
		task.delay(174/60,function()
			for _,l in limbs do
				if Character[l]:FindFirstChild("dash0") then
					for _,thing in Character[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = false
						end
					end
				end
			end
		end)
		task.delay(144/60,function()
			local floorInstance = RayCastOnMap(Enemy.Head.Position,Vector3.new(0,-15,0),true)
			if floorInstance then
				local RedFX21 = ResourceFolder.Parent.Snatch.bloodsmash3:Clone()
				RedFX21[math.random(1,3)]:Play()
				RedFX21.Position = floorInstance.Position + Vector3.new(0,0.05,0)
				RedFX21.Parent = workspace.Ignore.Effects
				game.Debris:AddItem(RedFX21,10)			--RedFX21.sfx:Play()
				for i,v in pairs(RedFX21:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v:Emit(3)
					end
				end
			end
		local RedFX=ResourceFolder.Hit:Clone()
			RedFX.Parent=workspace.Ignore.Effects
			RedFX.CFrame = CFrame.lookAt(Enemy.Head.Position,Character.Torso.Position)
			Debris:AddItem(RedFX,1.7)
			if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
				for i,v in pairs(RedFX:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v:Destroy()
					end
				end
			else
				for i,v in pairs(RedFX:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit(v:GetAttribute('EmitCount') or 1)
						end
					end
				end
			end
			local RedFX21 = ResourceFolder.Parent.BloodHit215.Attachment:Clone()
			RedFX21.Parent = Enemy.Head
			game.Debris:AddItem(RedFX21,2)
			for i,v in pairs(RedFX21:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute("EmitCount") / 4)
				end
			end
			for i,v in pairs(ResourceFolder.Parent.BloodHit2:GetChildren()) do
				local clone = v:Clone()
				clone.Parent = Enemy.Head
				game.Debris:AddItem(clone,1)
				if clone:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						clone:Emit((clone:GetAttribute('EmitCount')/6) or 1)
					else
						clone:Emit((clone:GetAttribute('EmitCount') * 2) or 1)
					end
				elseif clone:IsA("Attachment") then
					for i,v in pairs(clone:GetDescendants()) do
						if v:IsA('ParticleEmitter') then
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								v:Emit((v:GetAttribute('EmitCount') or 1)/6)
							else
								v:Emit((v:GetAttribute('EmitCount') * 2) or 1)
							end
						end
					end
				end
			end
		end)
		task.delay(110/60,function()
			local floorInstance = RayCastOnMap(Enemy.Head.Position,Vector3.new(0,-15,0),true)
			if floorInstance then
				local RedFX21 = ResourceFolder.Parent.Snatch.bloodsmash:Clone()
				RedFX21[math.random(1,3)]:Play()
				RedFX21.Position = floorInstance.Position + Vector3.new(0,0.05,0)
				RedFX21.Parent = workspace.Ignore.Effects
				game.Debris:AddItem(RedFX21,10)			--RedFX21.sfx:Play()
				for i,v in pairs(RedFX21:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v:Emit(3)
					end
				end
			end
			emit(Directory.impact3DownslamREMI,false,Character)
			emit(Directory.impact5DownslamREMI,false,Character)
			local RedFX21 = ResourceFolder.Parent.BloodHit215.Attachment:Clone()
			RedFX21.Parent = Enemy.Head
			game.Debris:AddItem(RedFX21,2)
			for i,v in pairs(RedFX21:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute("EmitCount") or 1)
				end
			end
		end)
		task.delay(98/60,function()
			flare()
		end)
		task.delay(55/60,function()
			vortex()
		end)
		task.delay(75/60,function()
			vortex()
		end)
		task.delay(18/60,function()
			groundslam()
		end)
		task.delay(44/60,function()
			groundslam()
		end)
	end,
	["SKILL3GRAB"] = function(Character,Enemy)
		local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.stingerGRABSFX:Clone()
		sound1.Parent = Enemy.Torso
		sound1:Play()
		game.Debris:AddItem(sound1,3.2)
		--local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
		--for _,l in limbs do
		--	local dash_vfx = dashLimbs:Clone():GetChildren()
		--	for _,p in dash_vfx do
		--		p.Parent = Character[l]
		--		game.Debris:AddItem(p,145/60)
		--		if p:IsA("Trail") then
		--			p.Enabled = true
		--		end
		--	end
		--end
		--for _,l in limbs do
		--	local dash_vfx = dashLimbs:Clone():GetChildren()
		--	for _,p in dash_vfx do
		--		p.Parent = Enemy[l]
		--		game.Debris:AddItem(p,130/60)
		--		if p:IsA("Trail") then
		--			p.Enabled = true
		--		end
		--	end
		--end
		task.delay(10/60,function()
			local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
			for _,l in limbs do
				if Character[l]:FindFirstChild("dash0") then
					for _,thing in Character[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = true
						end
					end
				else
					local dash_vfx = dashLimbs:Clone():GetChildren()
					for _,p in dash_vfx do
						p.Parent = Character[l]
						if p:IsA("Trail") then
							p.Enabled = true
						end
					end
				end
			end
			for _,l in limbs do
				if Enemy[l]:FindFirstChild("dash0") then
					for _,thing in Enemy[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = true
						end
					end
				else
					local dash_vfx = dashLimbs:Clone():GetChildren()
					for _,p in dash_vfx do
						p.Parent = Enemy[l]
						if p:IsA("Trail") then
							p.Enabled = true
						end
					end
				end
			end
			task.delay(21/60,function()
				for _,l in limbs do
					if Enemy[l]:FindFirstChild("dash0") then
						for _,thing in Enemy[l]:GetChildren() do
							if thing:IsA("Trail") and string.find(thing.Name, "dash") then
								thing.Enabled = false
							end
						end
					end
				end
			end)
			task.delay(40/60,function()
				for _,l in limbs do
					if Character[l]:FindFirstChild("dash0") then
						for _,thing in Character[l]:GetChildren() do
							if thing:IsA("Trail") and string.find(thing.Name, "dash") then
								thing.Enabled = false
							end
						end
					end
				end
			end)
		end)
		local function vineta()
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 35 then
				redvignette()
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(5, 5, .4,.6)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end
		local Directory2 = ResourceFolder.Parent.MiserableMultitude
		local Directory = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if Character["Right Arm"]:FindFirstChild("remiliaspear") then
						if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
							v.Color = ColorSequence.new{
								ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
							}
						end
					end
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount') * 2) or 1)
					end
				end
			end
		end
		local modelclone2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX
		vineta()
		--emit(Directory.impact5REMIVAMPIREton,true,Character)
		local modelclone = modelclone2["SpawnHit2"].Attachment3:Clone()
		modelclone.Parent = Enemy.HumanoidRootPart
		game.Debris:AddItem(modelclone,4)
		local function blackflash()
			coroutine.resume(coroutine.create(function()
				if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 40 then
					redvignette()
					game.Lighting.BlackFlash.Enabled = true
					task.delay(6.3/60,function()
						game.Lighting.BlackFlash.Enabled = false
					end)
					local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
						Camera.CFrame = Camera.CFrame * shakeCf
					end)
					camShake:ShakeOnce(5, 5, .4,.6)
					--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
					camShake:Start()
				end
			end))
		end
		task.delay(25/60,function()
			blackflash()
			local RedFX=ResourceFolder.Hitfisttd.VFX:Clone()
			RedFX.Parent=Enemy.Head
			Debris:AddItem(RedFX,1.7)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then

					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount') * 2) or 1)
					end
				end
			end
		end)
		task.delay(30/60,function()
			vineta()
			local RedFX=ResourceFolder.Hitblackfla.VFX:Clone()
			RedFX.Parent=Enemy.Head
			Debris:AddItem(RedFX,1.7)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if Character["Right Arm"]:FindFirstChild("remiliaspear") then
						if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
							v.Color = ColorSequence.new{
								ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
							}
						end
					end
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount') * 2) or 1)
					end
				end
			end
		end)
		for i,v in pairs(modelclone:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				if Character["Right Arm"]:FindFirstChild("remiliaspear") then
					if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
						v.Color = ColorSequence.new{
							ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
						}
					end
				end
				if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
					v:Emit((v:GetAttribute('EmitCount') or 1)/6)
				else
					v:Emit((v:GetAttribute('EmitCount') * 2) or 1)
				end
			end
		end
		local function bloodsmash()
			local floorInstance = RayCastOnMap(Enemy.Head.Position,Vector3.new(0,-15,0),true)
			if floorInstance then

				local RedFX21 = ResourceFolder.Parent.Snatch.bloodsmash:Clone()
				--RedFX21[math.random(1,3)]:Play()
				RedFX21.Position = floorInstance.Position + Vector3.new(0,0.05,0)
				RedFX21.Parent = workspace.Ignore.Effects
				game.Debris:AddItem(RedFX21,8)
				--RedFX21.sfx:Play()
				for i,v in pairs(RedFX21:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v:Emit(2)
					end
				end
			end
		end
		bloodsmash()
		task.delay(10/60,function()
			bloodsmash()
		end)
		task.delay(20/60,function()
			bloodsmash()
		end)
		task.delay(30/60,function()
			bloodsmash()
		end)
		coroutine.resume(coroutine.create(function()
			for i,v in pairs(ResourceFolder.Parent.BloodHit2:GetChildren()) do
				local clone = v:Clone()
				clone.Parent = Enemy.Head
				game.Debris:AddItem(clone,1)
				if clone:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						clone:Emit((clone:GetAttribute('EmitCount')/6) or 1)
					else
						clone:Emit((clone:GetAttribute('EmitCount') * 2) or 1)
					end
				elseif clone:IsA("Attachment") then
					for i,v in pairs(clone:GetDescendants()) do
						if v:IsA('ParticleEmitter') then
							if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
								v:Emit((v:GetAttribute('EmitCount') or 1)/6)
							else
								v:Emit((v:GetAttribute('EmitCount') * 2) or 1)
							end
						end
					end
				end
			end
			--for i,v in pairs(ResourceFolder.Parent.BloodHit:GetChildren()) do
			--	local clone = v:Clone()
			--	clone.Parent = Character.HumanoidRootPart
			--	game.Debris:AddItem(clone,1.5)
			--	if clone:IsA('ParticleEmitter') then
			--		clone:Emit(v:GetAttribute('EmitCount') or 1)
			--	elseif clone:IsA("Attachment") then
			--		for i,v in pairs(clone:GetDescendants()) do
			--			if v:IsA('ParticleEmitter') then
			--				v:Emit(v:GetAttribute('EmitCount') or 1)
			--			end
			--		end
			--	end
			--end
		end))
		--local function sucky()
		--	vineta()
		--	for i,v in pairs(ResourceFolder.Parent.BloodHit2:GetChildren()) do
		--		local clone = v:Clone()
		--		clone.Parent = Enemy.Head
		--		game.Debris:AddItem(clone,1)
		--		if clone:IsA('ParticleEmitter') then
		--			clone:Emit(v:GetAttribute('EmitCount') or 1)
		--		elseif clone:IsA("Attachment") then
		--			for i,v in pairs(clone:GetDescendants()) do
		--				if v:IsA('ParticleEmitter') then
		--					v:Emit(v:GetAttribute('EmitCount') or 1)
		--				end
		--			end
		--		end
		--	end
		--	local floorInstance = RayCastOnMap(Enemy.Head.Position,Vector3.new(0,-15,0),true)
		--	if floorInstance then

		--		local RedFX21 = ResourceFolder.Parent.Snatch.bloodsmash:Clone()
		--		--RedFX21[math.random(1,3)]:Play()
		--		RedFX21.Position = floorInstance.Position + Vector3.new(0,0.05,0)
		--		RedFX21.Parent = workspace.Ignore.Effects
		--		game.Debris:AddItem(RedFX21,10)
		--		--RedFX21.sfx:Play()
		--		for i,v in pairs(RedFX21:GetDescendants()) do
		--			if v:IsA('ParticleEmitter') then
		--				v:Emit(3)
		--			end
		--		end
		--	end
		--end
		--task.delay(36/60,function()
		--	for i,v in pairs(ResourceFolder.Parent.bloodsucky:GetChildren()) do
		--		local clone = v:Clone()
		--		clone.Parent = Enemy.Head
		--		if clone:IsA('ParticleEmitter') or clone:IsA('Trail') then
		--			clone.Enabled = true
		--		elseif clone:IsA("Attachment") then
		--			for i,v in pairs(clone:GetDescendants()) do
		--				if v:IsA('Trail') then
		--					v.Enabled = true
		--				end
		--				if v:IsA('ParticleEmitter') then
		--					v.Enabled = true
		--				end
		--			end
		--		end
		--		task.delay((107-36)/60,function()
		--			game.Debris:AddItem(clone,1.5)

		--			if clone:IsA('ParticleEmitter') or clone:IsA('Trail') then
		--				clone.Enabled = false
		--			elseif clone:IsA("Attachment") then
		--				for i,v in pairs(clone:GetDescendants()) do
		--					if v:IsA('ParticleEmitter') or v:IsA('Trail') then
		--						v.Enabled = false
		--					end
		--				end
		--			end
		--		end)
		--	end
		--	if Enemy.Head:FindFirstChild("trail") then
		--		Enemy.Head:FindFirstChild("trail").Trail.Attachment0 = Enemy.Head:FindFirstChild("trail")
		--		Enemy.Head:FindFirstChild("trail").Trail.Attachment1 = Enemy.Head:FindFirstChild("trail2")
		--	end
		--end)
		--task.delay(36/60,function()
		--	sucky()
		--end)
		--task.delay(48/60,function()
		--	sucky()
		--end)
		--task.delay(57/60,function()
		--	sucky()
		--end)
		--task.delay(66/60,function()
		--	sucky()
		--end)
		--task.delay(68/60,function()
		--	sucky()
		--end)
		--task.delay(78/60,function()
		--	sucky()
		--end)
		--task.delay(95/60,function()
		--	local modelclone = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX.GroundLast2:Clone()
		--	modelclone.Parent = workspace.Ignore.Effects
		--	game.Debris:AddItem(modelclone,5)
		--	modelclone.CFrame = (Character.HumanoidRootPart.CFrame * CFrame.new(0,0,6)) * game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX.GroundLast2.CFrame
		--	emitsum25(modelclone)
		--end)
		--task.delay(84/60,function()
		--	emit(Directory2.ground11,false,Character)
		--end)
		--task.delay(105/60,function()
		--	local modelclone = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX.GroundLast2:Clone()
		--	modelclone.Parent = workspace.Ignore.Effects
		--	game.Debris:AddItem(modelclone,5)
		--	modelclone.CFrame = (Character.HumanoidRootPart.CFrame * CFrame.new(0,0,6)) * game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX.GroundLast2.CFrame
		--	emitsum25(modelclone)
		--	emit(Directory2.ground11,false,Character)
		--end)
		--task.delay(116/60,function()
		--	vineta()
		--	--if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 35 then
		--	--	local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
		--	--		Camera.CFrame = Camera.CFrame * shakeCf
		--	--	end)
		--	--	camShake:ShakeOnce(10, 10, .1,.5)
		--	--	camShake:Start()
		--	--end
		--	local RootCF = Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-5)
		--	--if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - RootCF.Position).Magnitude <= 45 then
		--	--	local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
		--	--		Camera.CFrame = Camera.CFrame * shakeCf
		--	--	end)
		--	--	camShake:ShakeOnce(7, 7, .4,.8)
		--	--	--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
		--	--	camShake:Start()
		--	--end
		--	coroutine.resume(coroutine.create(function()
		--		RootCF = Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-4)
		--		local AppearTime = .17
		--		local Tilt = 25
		--		local Distance = 7
		--		local CollectAfter = 4.5
		--		local CollectLength = 7
		--		local HeightOffset = -2
		--		local HowMuchDown = -5 --how below the ground it is when it appears
		--		local HowMuchDownCollect = -10 --how below the ground it goes 
		--		local HowMuchUp = 15
		--		local DownRayLength = -20
		--		local NumberOfRocks =5 
		--		-- Rock Flying ==
		--		local Height = 75

		--		local SizeX = 1.3
		--		local SizeY = 1.3
		--		local SizeZ = 1.3
		--		local CollideAfter = .5
		--		local Spread = 25

		--		Module.RockFlying(RootCF , Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)
		--		local SizeX = 1.5
		--		local SizeY = 1.5
		--		local SizeZ = 1.5
		--		Module.RockFlying(RootCF , Height, SizeX*2.3, SizeY/10, SizeZ*2.3, NumberOfRocks,CollideAfter,Spread)
		--		Module.RockFlying(RootCF, Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)


		--		--Round 2
		--		local AppearTime = .19

		--		local CollectLength =5.6
		--		local HowMuchDown = -7
		--		local AppearTime = .21
		--		local HowMuchUp = 15

		--		coroutine.resume(coroutine.create(function()
		--			for i = 1,10 do
		--				Basemd.SmashTile(RootCF * CFrame.new(math.random(-5,5),0,math.random(-5,5)))
		--				Basemd.SmashTrees(RootCF * CFrame.new(math.random(-5,5),0,math.random(-5,5)))
		--				--task.wait(.1)
		--			end
		--		end))
		--		--Round 2
		--		local AppearTime = .19

		--		local CollectLength =5.6
		--		local HowMuchDown = -7
		--		local AppearTime = .21
		--		local HowMuchUp = 35
		--		--Round 3


		--		local AppearTime = .17
		--		local Tilt = 27
		--		local Distance = 1
		--		local CollectAfter = 4.5
		--		local CollectLength = 7
		--		local HeightOffset = -1.2
		--		local HowMuchDown = -5 --how below the ground it is when it appears
		--		local HowMuchDownCollect = -10 --how below the ground it goes 
		--		local HowMuchUp = 15
		--		local DownRayLength = -20
		--		local NumberOfRocks =6 
		--		--Module.RockSpawn1(script.Parent, NumberOfRocks, SizeX, SizeY, SizeZ, Distance)
		--		--	Module.RockSpawn2(RootCF , NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset-1.8,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --inside and smal;er
		--		--Module.RockSpawn2(RootCF, NumberOfRocks , SizeX, SizeY, SizeZ, Distance+.7,CollectAfter,HeightOffset-2.1,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --outside and bigger

		--		-- Rock Flying ==
		--		local Height = 70

		--		local SizeX = 1.4
		--		local SizeY = 1.4
		--		local SizeZ = 1.4
		--		local CollideAfter = .5
		--		local Spread = 20
		--		local SizeX = 1.5
		--		local SizeY = 1.5
		--		local SizeZ = 1.5
		--		local SizeX = 2.5
		--		local SizeY = 2.5
		--		local SizeZ = 3.2
		--		local Tilt = 37

		--		-- Ground spawn --
		--		local Distance = 1.4

		--		local NumberOfRocks = 5
		--		Module.RockSpawn2(RootCF, NumberOfRocks, SizeX, SizeY, SizeZ, Distance,CollectAfter,HeightOffset,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true) --inside and smal;er
		--		RootCF = RootCF * CFrame.Angles(0,math.rad(90),0)

		--		-- Ground spawn 2 --
		--		Distance = 3.4

		--		NumberOfRocks = 4
		--		SizeX = 3
		--		SizeY = 3
		--		SizeZ = 3
		--		RootCF = RootCF * CFrame.new(0,2,0)
		--		Module.RockSpawn2(RootCF, NumberOfRocks, SizeX, SizeY, SizeZ, Distance,CollectAfter,HeightOffset,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true) --inside and smal;er

		--		local Params = RaycastParams.new()
		--		Params.FilterDescendantsInstances =  {workspace.Ignore.Effects}
		--		Params.FilterType = Enum.RaycastFilterType.Exclude

		--		local hrp = Character.HumanoidRootPart
		--		local VictimRootPart = Enemy.HumanoidRootPart
		--		emit(Directory.impact5DownslamREMI,false)

		--		local modelclone = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX.GroundLast2:Clone()
		--		modelclone.Parent = workspace.Ignore.Effects
		--		game.Debris:AddItem(modelclone,5)
		--		modelclone.CFrame = Character.HumanoidRootPart.CFrame * game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX.GroundLast2.CFrame

		--		--local modelclone2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX.ExplosionLast2:Clone()
		--		--modelclone2.Parent = workspace.Ignore.Effects
		--		--game.Debris:AddItem(modelclone2,5)
		--		--modelclone2.CFrame = Character.HumanoidRootPart.CFrame * game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX.ExplosionLast2.CFrame
		--		emit(Directory2.ground11,false,Character)
		--		--emit(Directory2.slash2555,false,Character)
		--		emit(Directory.impact3DownslamREMI,false,Character)
		--		emitsum25(modelclone)
		--		--emitsum25(modelclone2)
		--	end))
		--	coroutine.resume(coroutine.create(function()
		--		--local AppearTime = .17
		--		--local Tilt = 25
		--		--local Distance = 8
		--		--local CollectAfter = 4.5
		--		--local CollectLength = 7
		--		--local HeightOffset = -2
		--		--local HowMuchDown = -5 --how below the ground it is when it appears
		--		--local HowMuchDownCollect = -10 --how below the ground it goes 
		--		--local HowMuchUp = 15
		--		--local DownRayLength = -20
		--		--local NumberOfRocks =4 
		--		----Module.RockSpawn1(script.Parent, NumberOfRocks, SizeX, SizeY, SizeZ, Distance)
		--		----	Module.RockSpawn2(RootCF , NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset-1.8,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --inside and smal;er
		--		----Module.RockSpawn2(RootCF, NumberOfRocks , SizeX, SizeY, SizeZ, Distance+.7,CollectAfter,HeightOffset-2.1,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --outside and bigger

		--		---- Rock Flying ==
		--		--local Height = 75

		--		--local SizeX =.5
		--		--local SizeY = .5
		--		--local SizeZ = .5
		--		--local CollideAfter = .5
		--		--local Spread = 30

		--		--Module.RockFlying(RootCF , Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)
		--		--local SizeX = 1.3
		--		--local SizeY = 1.3
		--		--local SizeZ = 1.3
		--		--Module.RockFlying(RootCF , Height, SizeX*2.3, SizeY/10, SizeZ*2.3, NumberOfRocks,CollideAfter,Spread)
		--		--Module.RockFlying(RootCF, Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)

		--		--Basemd.SmashTile(RootCF)

		--		----Round 2
		--		--local AppearTime = .19

		--		--local CollectLength =5.6
		--		--local HowMuchDown = -7
		--		--local AppearTime = .21
		--		--local HowMuchUp = 14
		--		----Round 3


		--		--local SizeX = 4 
		--		--local SizeY = 4
		--		--local SizeZ = 4
		--		---- Ground spawn --
		--		--local Distance = Random.new():NextNumber(1.4,1.6)
		--		--if numberofrocksrubbleslam == 3 then
		--		--	numberofrocksrubbleslam = 4 
		--		--elseif numberofrocksrubbleslam == 4 then
		--		--	numberofrocksrubbleslam = 3 
		--		--end
		--		--Module.RockSpawn2(RootCF, numberofrocksrubbleslam, Random.new():NextNumber(4.1,4.6), Random.new():NextNumber(4.1,4.6), Random.new():NextNumber(4,4.7), Random.new():NextNumber(1,2.5),CollectAfter,HeightOffset,Random.new():NextNumber(19.4,20),CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true) --inside and smal;er
		--		--RootCF = RootCF * CFrame.Angles(0,math.rad(90),0)

		--		--local CollectLength =7
		--		--local Distance = 6
		--		----.RockSpawn2(RootCF, NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset+.15,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true)

		--		local p5=ResourceFolder.wind:Clone()
		--		Debris:AddItem(p5,.31)
		--		p5.Parent= workspace.Ignore.Effects
		--		p5.CFrame= RootCF * CFrame.new(0,-4,0)
		--		p5.Orientation =Vector3.new(0, 0, -90)			
		--		local TweenFX = game:GetService("TweenService"):Create(p5, TweenInfo.new(0.3, Enum.EasingStyle.Sine,Enum.EasingDirection.Out), {Transparency = 1,Size = Vector3.new(0.35, 15.92, 15.92),Position = p5.Position + Vector3.new(0,-1.5,0) , Orientation = Vector3.new(0, 0, -90) })
		--		TweenFX:Play()

		--	end))
		--	local floorInstance = RayCastOnMap(RootCF.Position,Vector3.new(0,-15,0),true)
		--	if floorInstance then
		--		local RedFX21 = ResourceFolder.Parent.smashfx:Clone()
		--		--RedFX21[math.random(1,3)]:Play()
		--		--RedFX21["bloodmedium"]:Play()
		--		--RedFX21["smash"]:Play()
		--		RedFX21.Position = floorInstance.Position + Vector3.new(0,0.1,0)
		--		RedFX21.Parent = workspace.Ignore.Effects
		--		game.Debris:AddItem(RedFX21,2)
		--		--RedFX21.sfx:Play()
		--		for i,v in pairs(RedFX21:GetDescendants()) do
		--			if v:IsA('ParticleEmitter') then
		--				v:Emit(v:GetAttribute('EmitCount') or 1)
		--			end
		--		end
		--	end
		--end)
	end,
	["KISSFIRSTSKILL"] = function(Character,Enemy)
		local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.vampirekissSFX:Clone()
		sound1.Parent = Enemy.Head
		sound1:Play()
		game.Debris:AddItem(sound1,4)
		--local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
		--for _,l in limbs do
		--	local dash_vfx = dashLimbs:Clone():GetChildren()
		--	for _,p in dash_vfx do
		--		p.Parent = Character[l]
		--		game.Debris:AddItem(p,145/60)
		--		if p:IsA("Trail") then
		--			p.Enabled = true
		--		end
		--	end
		--end
		--for _,l in limbs do
		--	local dash_vfx = dashLimbs:Clone():GetChildren()
		--	for _,p in dash_vfx do
		--		p.Parent = Enemy[l]
		--		game.Debris:AddItem(p,130/60)
		--		if p:IsA("Trail") then
		--			p.Enabled = true
		--		end
		--	end
		--end}
		local gebura = false
		local thor = false
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("redmisthorion") then
				gebura = true
			end
		end
		if Character["Right Arm"]:FindFirstChild("remiliaspear")  and Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("SKINDATA") then
			if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("SKINDATA").Value == ("Stormbreaker") then
				thor = true
			end
		end
		local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
		for _,l in limbs do
			if Character[l]:FindFirstChild("dash0") then
				for _,thing in Character[l]:GetChildren() do
					if thing:IsA("Trail") and string.find(thing.Name, "dash") then
						thing.Enabled = true
					end
				end
			else
				local dash_vfx = dashLimbs:Clone():GetChildren()
				for _,p in dash_vfx do
					p.Parent = Character[l]
					if p:IsA("Trail") then
						p.Enabled = true
					end
				end
			end
		end
		for _,l in limbs do
			if Enemy[l]:FindFirstChild("dash0") then
				for _,thing in Enemy[l]:GetChildren() do
					if thing:IsA("Trail") and string.find(thing.Name, "dash") then
						thing.Enabled = true
					end
				end
			else
				local dash_vfx = dashLimbs:Clone():GetChildren()
				for _,p in dash_vfx do
					p.Parent = Enemy[l]
					if p:IsA("Trail") then
						p.Enabled = true
					end
				end
			end
		end
		task.delay(118/60,function()
			for _,l in limbs do
				if Enemy[l]:FindFirstChild("dash0") then
					for _,thing in Enemy[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = false
						end
					end
				end
			end
		end)
		task.delay(125/60,function()
			for _,l in limbs do
				if Character[l]:FindFirstChild("dash0") then
					for _,thing in Character[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = false
						end
					end
				end
			end
		end)
		local function vineta()
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 35 then
				redvignette()
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(5, 5, .4,.6)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end
		local Directory2 = ResourceFolder.Parent.MiserableMultitude
		local Directory = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
			if thor then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v.Color = ColorSequence.new{
							ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
						}
					end
				end
			end
		end
		vineta()
		emit(Directory.impact5REMIVAMPIREton,false,Character)
		emit(Directory.impact5REMIVAMPIRE,false,Character)
		if gebura == false then
			coroutine.resume(coroutine.create(function()
				for i,v in pairs(ResourceFolder.Parent.BloodHit2:GetChildren()) do
					local clone = v:Clone()
					clone.Parent = Enemy.Head
					game.Debris:AddItem(clone,1)
					if clone:IsA('ParticleEmitter') then
						clone:Emit(v:GetAttribute('EmitCount') or 1)
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("thorhammerhit1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
					elseif clone:IsA("Attachment") then
						for i,v in pairs(clone:GetDescendants()) do
							if v:IsA('ParticleEmitter') then
								if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
									v:Emit((v:GetAttribute('EmitCount') or 1)/6)
								else
									v:Emit((v:GetAttribute('EmitCount')) or 1)
								end
							end
						end

					end
				end
				local floorInstance = RayCastOnMap(Enemy.Head.Position,Vector3.new(0,-15,0),true)
				if floorInstance then

					local RedFX21 = ResourceFolder.Parent.Snatch.bloodsmash:Clone()
					--RedFX21[math.random(1,3)]:Play()
					RedFX21.Position = floorInstance.Position + Vector3.new(0,0.05,0)
					RedFX21.Parent = workspace.Ignore.Effects
					game.Debris:AddItem(RedFX21,10)
					--RedFX21.sfx:Play()
					for i,v in pairs(RedFX21:GetDescendants()) do
						if v:IsA('ParticleEmitter') then
							v:Emit(3)
						end
					end
				end
			end))
		end
		local function blackflash51()
			coroutine.resume(coroutine.create(function()
				if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 40 then
					redvignette()
					game.Lighting.BlackFlash2.Enabled = true
					task.delay(2/60,function()
						game.Lighting.BlackFlash2.Enabled = false
					end)
					local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
						Camera.CFrame = Camera.CFrame * shakeCf
					end)
					camShake:ShakeOnce(5, 5, .4,.6)
					camShake:Start()
				end
			end))
		end
		local function sucky()
			if gebura == false then
				if thor == true then
					local RedFX=ResourceFolder.Hitfisttd.VFX:Clone()
					RedFX.Parent=Enemy.Head
					Debris:AddItem(RedFX,1.7)
					for i,v in pairs(RedFX:GetDescendants()) do
						if v:IsA('ParticleEmitter') then
							v.Color = ColorSequence.new{
								ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
							}
							v:Emit(((v:GetAttribute('EmitCount')) or 1)*2)
						end
					end
					local RedFX=ResourceFolder.Hitblackfla.VFX:Clone()
					RedFX.Parent=Enemy.Head
					--RedFX.BlackFlash:Play()
					RedFX.BlackFlash1:Play()
					Debris:AddItem(RedFX,1.7)
					for i,v in pairs(RedFX:GetDescendants()) do
						if v:IsA('ParticleEmitter') then
							v.Color = ColorSequence.new{
								ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
							}
							v:Emit(((v:GetAttribute('EmitCount')) or 1)/7)
						end
					end
					return
						end
					for i,v in pairs(ResourceFolder.Parent.BloodHit2:GetChildren()) do
						local clone = v:Clone()
						clone.Parent = Enemy.Head
						game.Debris:AddItem(clone,1)
						if clone:IsA('ParticleEmitter') then
							clone:Emit(v:GetAttribute('EmitCount') or 1)
						elseif clone:IsA("Attachment") then
							for i,v in pairs(clone:GetDescendants()) do
								if v:IsA('ParticleEmitter') then
									if Character["Right Arm"]:FindFirstChild("remiliaspear") then
										if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
											v.Color = ColorSequence.new{
												ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
												ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
											}
										end
									end
									if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
										v:Emit((v:GetAttribute('EmitCount') or 1)/6)
									else
										v:Emit((v:GetAttribute('EmitCount')) or 1)
									end
								end
							end
						end
					end
					local floorInstance = RayCastOnMap(Enemy.Head.Position,Vector3.new(0,-15,0),true)
					if floorInstance then

						local RedFX21 = ResourceFolder.Parent.Snatch.bloodsmash:Clone()
						--RedFX21[math.random(1,3)]:Play()
						RedFX21.Position = floorInstance.Position + Vector3.new(0,0.05,0)
						RedFX21.Parent = workspace.Ignore.Effects
						game.Debris:AddItem(RedFX21,10)
						--RedFX21.sfx:Play()
						for i,v in pairs(RedFX21:GetDescendants()) do
							if v:IsA('ParticleEmitter') then
								v:Emit(3)
							end
						end
				end
			end
		end
		task.delay(36/60,function()
			if gebura == false and thor == false then
				for i,v in pairs(ResourceFolder.Parent.bloodsucky:GetChildren()) do
					local clone = v:Clone()
					clone.Parent = Enemy.Head
					if clone:IsA('ParticleEmitter') or clone:IsA('Trail') then
						clone.Enabled = true
					elseif clone:IsA("Attachment") then
						for i,v in pairs(clone:GetDescendants()) do
							if v:IsA('Trail') then
								v.Enabled = true
							end
							if v:IsA('ParticleEmitter') then
								v.Enabled = true
							end
						end
					end
					task.delay((107-36)/60,function()
						game.Debris:AddItem(clone,1.5)

						if clone:IsA('ParticleEmitter') or clone:IsA('Trail') then
							clone.Enabled = false
						elseif clone:IsA("Attachment") then
							for i,v in pairs(clone:GetDescendants()) do
								if v:IsA('ParticleEmitter') or v:IsA('Trail') then
									v.Enabled = false
								end
							end
						end
					end)
					if Enemy.Head:FindFirstChild("trail") then
						Enemy.Head:FindFirstChild("trail").Trail.Attachment0 = Enemy.Head:FindFirstChild("trail")
						Enemy.Head:FindFirstChild("trail").Trail.Attachment1 = Enemy.Head:FindFirstChild("trail2")
					end
				end
			end
		end)
		task.delay(36/60,function()
			sucky()
		end)
		if (gebura == true) or (thor == true) then
			local TweenFX = game:GetService("TweenService"):Create(sound1, TweenInfo.new(20/60, Enum.EasingStyle.Linear,Enum.EasingDirection.Out), {Volume = 0})
			TweenFX:Play()
			local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.clothsfx12:Clone()
			RedFX2425.Parent = Character.HumanoidRootPart
			game.Debris:AddItem(RedFX2425,5)
			RedFX2425:Play()
			local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.clothsfx14:Clone()
			RedFX2425.Parent = Character.HumanoidRootPart
			game.Debris:AddItem(RedFX2425,5)
			RedFX2425:Play()
			local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.clothsfx16:Clone()
			RedFX2425.Parent = Character.HumanoidRootPart
			game.Debris:AddItem(RedFX2425,5)
			RedFX2425:Play()
			task.delay(5/60,function()
				local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.clothsfx15:Clone()
				RedFX2425.Parent = Character.HumanoidRootPart
				game.Debris:AddItem(RedFX2425,5)
				RedFX2425:Play()
			end)
		end
		--task.delay(48/60,function()
		--	sucky()
		--end)
		task.delay(57/60,function()
			sucky()
		end)
		--task.delay(66/60,function()
		--	sucky()
		--end)
		task.delay(68/60,function()
			sucky()
		end)
		task.delay(78/60,function()
			sucky()
		end)
		task.delay(100/60,function()
			if gebura == true then
				local TweenFX = game:GetService("TweenService"):Create(sound1, TweenInfo.new(.15, Enum.EasingStyle.Linear,Enum.EasingDirection.Out), {Volume = 1.2})
				TweenFX:Play()
			end
		end)
		task.delay(100/60,function()
			if thor == true then
				local TweenFX = game:GetService("TweenService"):Create(sound1, TweenInfo.new(.15, Enum.EasingStyle.Linear,Enum.EasingDirection.Out), {Volume = 1.2})
				TweenFX:Play()
			end
		end)
		task.delay(95/60,function()
			local modelclone = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX.GroundLast2:Clone()
			modelclone.Parent = workspace.Ignore.Effects
			game.Debris:AddItem(modelclone,5)
			modelclone.CFrame = (Character.HumanoidRootPart.CFrame * CFrame.new(0,0,6)) * game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX.GroundLast2.CFrame
			emitsum25(modelclone)
		end)
		task.delay(84/60,function()
			emit(Directory2.ground11,false,Character)
		end)
		task.delay(105/60,function()
			local modelclone = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX.GroundLast2:Clone()
			modelclone.Parent = workspace.Ignore.Effects
			game.Debris:AddItem(modelclone,5)
			modelclone.CFrame = (Character.HumanoidRootPart.CFrame * CFrame.new(0,0,6)) * game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX.GroundLast2.CFrame
			emitsum25(modelclone)
			emit(Directory2.ground11,false,Character)
		end)
		task.delay(116/60,function()
			vineta()
			--if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 35 then
			--	local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
			--		Camera.CFrame = Camera.CFrame * shakeCf
			--	end)
			--	camShake:ShakeOnce(10, 10, .1,.5)
			--	camShake:Start()
			--end
			local RootCF = Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-5)
			--if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - RootCF.Position).Magnitude <= 45 then
			--	local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
			--		Camera.CFrame = Camera.CFrame * shakeCf
			--	end)
			--	camShake:ShakeOnce(7, 7, .4,.8)
			--	--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
			--	camShake:Start()
			--end
			coroutine.resume(coroutine.create(function()
				 RootCF = Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-4)
				local AppearTime = .17
				local Tilt = 25
				local Distance = 7
				local CollectAfter = 4.5
				local CollectLength = 7
				local HeightOffset = -2
				local HowMuchDown = -5 --how below the ground it is when it appears
				local HowMuchDownCollect = -10 --how below the ground it goes 
				local HowMuchUp = 15
				local DownRayLength = -20
				local NumberOfRocks =5 
				-- Rock Flying ==
				local Height = 75

				local SizeX = 1.3
				local SizeY = 1.3
				local SizeZ = 1.3
				local CollideAfter = .5
				local Spread = 25

				Module.RockFlying(RootCF , Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)
				local SizeX = 1.5
				local SizeY = 1.5
				local SizeZ = 1.5
				Module.RockFlying(RootCF , Height, SizeX*2.3, SizeY/10, SizeZ*2.3, NumberOfRocks,CollideAfter,Spread)
				Module.RockFlying(RootCF, Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)


				--Round 2
				local AppearTime = .19

				local CollectLength =5.6
				local HowMuchDown = -7
				local AppearTime = .21
				local HowMuchUp = 15

				coroutine.resume(coroutine.create(function()
					for i = 1,10 do
						Basemd.SmashTile(RootCF * CFrame.new(math.random(-5,5),0,math.random(-5,5)))
						Basemd.SmashTrees(RootCF * CFrame.new(math.random(-5,5),0,math.random(-5,5)))
						--task.wait(.1)
					end
				end))
				--Round 2
				local AppearTime = .19

				local CollectLength =5.6
				local HowMuchDown = -7
				local AppearTime = .21
				local HowMuchUp = 35
				--Round 3


				local AppearTime = .17
				local Tilt = 27
				local Distance = 1
				local CollectAfter = 4.5
				local CollectLength = 7
				local HeightOffset = -1.2
				local HowMuchDown = -5 --how below the ground it is when it appears
				local HowMuchDownCollect = -10 --how below the ground it goes 
				local HowMuchUp = 15
				local DownRayLength = -20
				local NumberOfRocks =6 
				--Module.RockSpawn1(script.Parent, NumberOfRocks, SizeX, SizeY, SizeZ, Distance)
				--	Module.RockSpawn2(RootCF , NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset-1.8,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --inside and smal;er
				--Module.RockSpawn2(RootCF, NumberOfRocks , SizeX, SizeY, SizeZ, Distance+.7,CollectAfter,HeightOffset-2.1,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --outside and bigger

				-- Rock Flying ==
				local Height = 70

				local SizeX = 1.4
				local SizeY = 1.4
				local SizeZ = 1.4
				local CollideAfter = .5
				local Spread = 20
				local SizeX = 1.5
				local SizeY = 1.5
				local SizeZ = 1.5
				local SizeX = 2.5
				local SizeY = 2.5
				local SizeZ = 3.2
				local Tilt = 37

				-- Ground spawn --
				local Distance = 1.4

				local NumberOfRocks = 5
				Module.RockSpawn2(RootCF, NumberOfRocks, SizeX, SizeY, SizeZ, Distance,CollectAfter,HeightOffset,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true) --inside and smal;er
				RootCF = RootCF * CFrame.Angles(0,math.rad(90),0)

				-- Ground spawn 2 --
				Distance = 3.4

				NumberOfRocks = 4
				SizeX = 3
				SizeY = 3
				SizeZ = 3
				RootCF = RootCF * CFrame.new(0,2,0)
				Module.RockSpawn2(RootCF, NumberOfRocks, SizeX, SizeY, SizeZ, Distance,CollectAfter,HeightOffset,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true) --inside and smal;er

				local Params = RaycastParams.new()
				Params.FilterDescendantsInstances =  {workspace.Ignore.Effects}
				Params.FilterType = Enum.RaycastFilterType.Exclude

				local hrp = Character.HumanoidRootPart
				local VictimRootPart = Enemy.HumanoidRootPart
				emit(Directory.impact5DownslamREMI,false)

				local modelclone = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX.GroundLast2:Clone()
				modelclone.Parent = workspace.Ignore.Effects
				game.Debris:AddItem(modelclone,5)
				modelclone.CFrame = Character.HumanoidRootPart.CFrame * game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX.GroundLast2.CFrame

				--local modelclone2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX.ExplosionLast2:Clone()
				--modelclone2.Parent = workspace.Ignore.Effects
				--game.Debris:AddItem(modelclone2,5)
				--modelclone2.CFrame = Character.HumanoidRootPart.CFrame * game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX.ExplosionLast2.CFrame
				emit(Directory2.ground11,false,Character)
				--emit(Directory2.slash2555,false,Character)
				emit(Directory.impact3DownslamREMI,false,Character)
				emitsum25(modelclone)
				--emitsum25(modelclone2)
			end))
			coroutine.resume(coroutine.create(function()
				--local AppearTime = .17
				--local Tilt = 25
				--local Distance = 8
				--local CollectAfter = 4.5
				--local CollectLength = 7
				--local HeightOffset = -2
				--local HowMuchDown = -5 --how below the ground it is when it appears
				--local HowMuchDownCollect = -10 --how below the ground it goes 
				--local HowMuchUp = 15
				--local DownRayLength = -20
				--local NumberOfRocks =4 
				----Module.RockSpawn1(script.Parent, NumberOfRocks, SizeX, SizeY, SizeZ, Distance)
				----	Module.RockSpawn2(RootCF , NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset-1.8,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --inside and smal;er
				----Module.RockSpawn2(RootCF, NumberOfRocks , SizeX, SizeY, SizeZ, Distance+.7,CollectAfter,HeightOffset-2.1,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --outside and bigger

				---- Rock Flying ==
				--local Height = 75

				--local SizeX =.5
				--local SizeY = .5
				--local SizeZ = .5
				--local CollideAfter = .5
				--local Spread = 30

				--Module.RockFlying(RootCF , Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)
				--local SizeX = 1.3
				--local SizeY = 1.3
				--local SizeZ = 1.3
				--Module.RockFlying(RootCF , Height, SizeX*2.3, SizeY/10, SizeZ*2.3, NumberOfRocks,CollideAfter,Spread)
				--Module.RockFlying(RootCF, Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)

				--Basemd.SmashTile(RootCF)

				----Round 2
				--local AppearTime = .19

				--local CollectLength =5.6
				--local HowMuchDown = -7
				--local AppearTime = .21
				--local HowMuchUp = 14
				----Round 3


				--local SizeX = 4 
				--local SizeY = 4
				--local SizeZ = 4
				---- Ground spawn --
				--local Distance = Random.new():NextNumber(1.4,1.6)
				--if numberofrocksrubbleslam == 3 then
				--	numberofrocksrubbleslam = 4 
				--elseif numberofrocksrubbleslam == 4 then
				--	numberofrocksrubbleslam = 3 
				--end
				--Module.RockSpawn2(RootCF, numberofrocksrubbleslam, Random.new():NextNumber(4.1,4.6), Random.new():NextNumber(4.1,4.6), Random.new():NextNumber(4,4.7), Random.new():NextNumber(1,2.5),CollectAfter,HeightOffset,Random.new():NextNumber(19.4,20),CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true) --inside and smal;er
				--RootCF = RootCF * CFrame.Angles(0,math.rad(90),0)

				--local CollectLength =7
				--local Distance = 6
				----.RockSpawn2(RootCF, NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset+.15,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true)

				local p5=ResourceFolder.wind:Clone()
				Debris:AddItem(p5,.31)
				p5.Parent= workspace.Ignore.Effects
				p5.CFrame= RootCF * CFrame.new(0,-4,0)
				p5.Orientation =Vector3.new(0, 0, -90)			
				local TweenFX = game:GetService("TweenService"):Create(p5, TweenInfo.new(0.3, Enum.EasingStyle.Sine,Enum.EasingDirection.Out), {Transparency = 1,Size = Vector3.new(0.35, 15.92, 15.92),Position = p5.Position + Vector3.new(0,-1.5,0) , Orientation = Vector3.new(0, 0, -90) })
				TweenFX:Play()

			end))
			local floorInstance = RayCastOnMap(RootCF.Position,Vector3.new(0,-15,0),true)
			if floorInstance then
				local RedFX21 = ResourceFolder.Parent.smashfx:Clone()
				--RedFX21[math.random(1,3)]:Play()
				--RedFX21["bloodmedium"]:Play()
				--RedFX21["smash"]:Play()
				RedFX21.Position = floorInstance.Position + Vector3.new(0,0.1,0)
				RedFX21.Parent = workspace.Ignore.Effects
				game.Debris:AddItem(RedFX21,2)
				--RedFX21.sfx:Play()
				for i,v in pairs(RedFX21:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
		end)
	end,
	["GROUNDSLAMFIRSTSKILL"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end

		--RedFX.sfx1:Play()
		--RedFX.sfx2:Play()
		local RootCF = Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-5)
		if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - RootCF.Position).Magnitude <= 45 then
			local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
				Camera.CFrame = Camera.CFrame * shakeCf
			end)
			camShake:ShakeOnce(7, 7, .4,.8)
			--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
			camShake:Start()
		end
		coroutine.resume(coroutine.create(function()
			local AppearTime = .17
			local Tilt = 25
			local Distance = 8
			local CollectAfter = 4.5
			local CollectLength = 7
			local HeightOffset = -2
			local HowMuchDown = -5 --how below the ground it is when it appears
			local HowMuchDownCollect = -10 --how below the ground it goes 
			local HowMuchUp = 15
			local DownRayLength = -20
			local NumberOfRocks =4 
			--Module.RockSpawn1(script.Parent, NumberOfRocks, SizeX, SizeY, SizeZ, Distance)
			--	Module.RockSpawn2(RootCF , NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset-1.8,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --inside and smal;er
			--Module.RockSpawn2(RootCF, NumberOfRocks , SizeX, SizeY, SizeZ, Distance+.7,CollectAfter,HeightOffset-2.1,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --outside and bigger

			-- Rock Flying ==
			local Height = 75

			local SizeX =.5
			local SizeY = .5
			local SizeZ = .5
			local CollideAfter = .5
			local Spread = 30

			Module.RockFlying(RootCF , Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)
			local SizeX = 1.3
			local SizeY = 1.3
			local SizeZ = 1.3
			Module.RockFlying(RootCF , Height, SizeX*2.3, SizeY/10, SizeZ*2.3, NumberOfRocks,CollideAfter,Spread)
			Module.RockFlying(RootCF, Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)

			Basemd.SmashTile(RootCF)

			--Round 2
			local AppearTime = .19

			local CollectLength =5.6
			local HowMuchDown = -7
			local AppearTime = .21
			local HowMuchUp = 14
			--Round 3


			local SizeX = 4 
			local SizeY = 4
			local SizeZ = 4
			-- Ground spawn --
			local Distance = Random.new():NextNumber(1.4,1.6)
			if numberofrocksrubbleslam == 3 then
				numberofrocksrubbleslam = 4 
			elseif numberofrocksrubbleslam == 4 then
				numberofrocksrubbleslam = 3 
			end
			Module.RockSpawn2(RootCF, numberofrocksrubbleslam, Random.new():NextNumber(4.1,4.6), Random.new():NextNumber(4.1,4.6), Random.new():NextNumber(4,4.7), Random.new():NextNumber(1,2.5),CollectAfter,HeightOffset,Random.new():NextNumber(19.4,20),CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true) --inside and smal;er
			RootCF = RootCF * CFrame.Angles(0,math.rad(90),0)

			local CollectLength =7
			local Distance = 6
			--.RockSpawn2(RootCF, NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset+.15,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true)

			local p5=ResourceFolder.wind:Clone()
			Debris:AddItem(p5,.31)
			p5.Parent= workspace.Ignore.Effects
			p5.CFrame= RootCF * CFrame.new(0,-4,0)
			p5.Orientation =Vector3.new(0, 0, -90)			
			local TweenFX = game:GetService("TweenService"):Create(p5, TweenInfo.new(0.3, Enum.EasingStyle.Sine,Enum.EasingDirection.Out), {Transparency = 1,Size = Vector3.new(0.35, 15.92, 15.92),Position = p5.Position + Vector3.new(0,-1.5,0) , Orientation = Vector3.new(0, 0, -90) })
			TweenFX:Play()

		end))
		local floorInstance = RayCastOnMap(RootCF.Position,Vector3.new(0,-15,0),true)
		if floorInstance then
			local RedFX21 = ResourceFolder.Parent.smashfx:Clone()
			RedFX21[math.random(1,3)]:Play()
			RedFX21["bloodmedium"]:Play()
			RedFX21["smash"]:Play()
			RedFX21.Position = floorInstance.Position + Vector3.new(0,0.1,0)
			RedFX21.Parent = workspace.Ignore.Effects
			game.Debris:AddItem(RedFX21,2)
			--RedFX21.sfx:Play()
			for i,v in pairs(RedFX21:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
			--local RedFX2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.GroundHit:Clone()
			--RedFX2.Parent = workspace.Ignore.Effects
			--game.Debris:AddItem(RedFX2,2)
			--RedFX2.Position = floorInstance.Position + Vector3.new(0,0.6,0)
			--for i,v in pairs(RedFX2:GetDescendants()) do
			--	if v:IsA('ParticleEmitter') then
			--		v:Emit(v:GetAttribute('EmitCount') or 1)
			--	end
			--end

			--local RedFX = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.skill3grabslam:Clone()
			--RedFX[math.random(1,3)]:Play()
			--RedFX["bloodmedium"]:Play()
			--RedFX["smash"]:Play()
			--RedFX.Parent = workspace.Ignore.Effects
			--game.Debris:AddItem(RedFX,2)
			--RedFX.Position = floorInstance.Position + Vector3.new(0,0.6,0)
			--for i,v in pairs(RedFX:GetDescendants()) do
			--	if v:IsA('ParticleEmitter') then
			--		v:Emit(v:GetAttribute('EmitCount') or 1)
			--	end
			--end
		end
	end,
	["SKILL3SLASHSOUND"] = function(Character)
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			Character["Right Arm"]:FindFirstChild("remiliaspear")["swing1"]:Play()
			Character["Right Arm"]:FindFirstChild("remiliaspear")["swing12"]:Play()
			Character["Right Arm"]:FindFirstChild("remiliaspear")["swing2"]:Play()
		end
	end,
	["SKILL3SLASH"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			Character["Right Arm"]:FindFirstChild("remiliaspear")["swing1"]:Play()
			Character["Right Arm"]:FindFirstChild("remiliaspear")["swing12"]:Play()
			Character["Right Arm"]:FindFirstChild("remiliaspear")["swing2"]:Play()
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Skill3Slash["FIRSTSLASH"]:Clone()
			RedFX15.Parent = Character.HumanoidRootPart
			game.Debris:AddItem(RedFX15,1.5)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
	end,
	["STAB"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			local Directory = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
			local function emit(instance,weld,enable)
				local instanceclone = instance:Clone()
				instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
				if weld == true then
					local Weld = Instance.new("WeldConstraint")
					Weld.Part0 = Character.HumanoidRootPart
					Weld.Part1 = instanceclone
					Weld.Name = instanceclone.Name
					Weld.Parent = instanceclone	
				else
					instanceclone.Anchored = true
				end
				instanceclone.Parent = workspace.Ignore.Effects
				if instanceclone:FindFirstChildOfClass("Model") then
					for i,v in pairs(instanceclone:GetDescendants()) do
						if v:IsA('Model') and v:FindFirstChild("Start") then
							local modelclone = v
							modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
							modelclone.Parent = workspace.Ignore.Effects
							task.delay(modelclone:GetAttribute("EmitDelay"),function()
								local decalparams
								if modelclone:GetAttribute("Decal_TweenParams") then
									decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
								else
									local decalparams2 = "Cubic,Out"
									decalparams = string.split(decalparams2, ",")
								end
								local partparams
								if modelclone:GetAttribute("Part_TweenParams") then
									partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
								else
									local partparams2 = "Cubic,Out"
									partparams = string.split(partparams2, ",")
								end
								game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
								v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
								game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
							end)
							--for ie,ve in pairs(modelclone:GetChildren()) do
							--end
						end
					end
				end

				game.Debris:AddItem(instanceclone,5)
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
			emit(Directory.impact5REMI,false)
			local count2 = 0
			if count2 == 0 then
				if Character["Right Arm"]:FindFirstChild("remiliaspear")["swing1"].IsPlaying then
					Character["Right Arm"]:FindFirstChild("remiliaspear")["swing2"]:Play()
				else
					Character["Right Arm"]:FindFirstChild("remiliaspear")["swing1"]:Play()
				end
			end
			if count2 == 1 then
				Character["Right Arm"]:FindFirstChild("remiliaspear")["swing2"]:Play()
			end
			count2 += 1
			Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir3"]:Play()
		end
	end,
	["DASHM1TRAIL"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		if Character:FindFirstChild("gunganire").Value == false then
		local FX= game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.DashTrail:Clone()
		FX.Parent=Character
		FX.w.Part0= Character['Right Arm']
		game.Debris:AddItem(FX,2)
		task.delay(.7,function()
			for i ,v in pairs(FX:GetDescendants())do
				if v:IsA('Trail') then
					v.Enabled = false
				end
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
				if v:IsA("PointLight") then
					game:GetService("TweenService"):Create(v, TweenInfo.new(.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Range = 0}):Play()
				end
			end
		end)
end
	end,
	["SKILL1DOWNCUT"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local Directory = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		emit(Directory.impact5DownslamREMI,false)
	end,
	["SKILL3DOWNCUT"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local Directory = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		emit(Directory.impact5DownslamREMI,false)
	end,
	["FASTSLASHVELOCITY2"] = function(Character)
		if Character.HumanoidRootPart:FindFirstChild("loalzoaew") then
			Character.HumanoidRootPart:FindFirstChild("loalzoaew"):Destroy()
		end
		Character.HumanoidRootPart.Velocity = Vector3.new(0,0,0)
		local velocity = Instance.new('BodyVelocity')
		velocity.MaxForce = Vector3.new(15000,0,15000)
		velocity.Velocity = Character.HumanoidRootPart.CFrame.LookVector * 25
		velocity.Parent = Character.HumanoidRootPart
		game.Debris:AddItem(velocity,.25)
		velocity.Name = ("loalzoaew")
	end,
	["FASTSLASHVELOCITY"] = function(Character)
		if Character.HumanoidRootPart:FindFirstChild("loalzoaew") then
			Character.HumanoidRootPart:FindFirstChild("loalzoaew"):Destroy()
		end
		Character.HumanoidRootPart.Velocity = Vector3.new(0,0,0)
		local velocity = Instance.new('BodyVelocity')
		velocity.MaxForce = Vector3.new(15000,0,15000)
		velocity.Velocity = Character.HumanoidRootPart.CFrame.LookVector * 10
		velocity.Name = ("loalzoaew")
		velocity.Parent = Character.HumanoidRootPart
		game.Debris:AddItem(velocity,.1)
	end,
	["DOWNCUT"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local Directory = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		emit(Directory.impact5DownslamREMI,false)
	end,
	["FLARE"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				if Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir1"].IsPlaying then
					Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir2"]:Play()
				else
					Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir1"]:Play()
				end
				Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir3"]:Play()
			end
			if not Character:FindFirstChildOfClass("Highlight") then 
				local highlight = script.Parent.Highlight:Clone()
				highlight.Parent = Character
				game:GetService("TweenService"):Create(highlight, TweenInfo.new(5/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 0}):Play()
				task.delay(5/60,function()
					game:GetService("TweenService"):Create(highlight, TweenInfo.new(15/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 1}):Play()
					game.Debris:AddItem(highlight,1)
				end)
			end
			return end
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			if Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir1"].IsPlaying then
				Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir2"]:Play()
			else
				Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir1"]:Play()
			end
			Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir3"]:Play()
			Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
			Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
		end
		if not Character:FindFirstChildOfClass("Highlight") then 
			local highlight = script.Parent.Highlight:Clone()
			highlight.Parent = Character
			game:GetService("TweenService"):Create(highlight, TweenInfo.new(5/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 0}):Play()
			task.delay(5/60,function()
				game:GetService("TweenService"):Create(highlight, TweenInfo.new(15/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 1}):Play()
				game.Debris:AddItem(highlight,1)
			end)
		end
	end,
	["SHINE1PARTICLE"] = function(Character)
		for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Shine1:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
					v:Emit((v:GetAttribute('EmitCount') or 1)/6)
				else
					v:Emit((v:GetAttribute('EmitCount')) or 1)
				end
			end
		end
	end,
	["FLAREPARTICLE"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir3"]:Play()
			end
			return end
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
			Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
		end
	end,
	["FLARENOSOUND"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir3"]:Play()
			end
			if not Character:FindFirstChildOfClass("Highlight") then 
				local highlight = script.Parent.Highlight:Clone()
				highlight.Parent = Character
				game:GetService("TweenService"):Create(highlight, TweenInfo.new(5/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 0}):Play()
				task.delay(5/60,function()
					game:GetService("TweenService"):Create(highlight, TweenInfo.new(15/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 1}):Play()
					game.Debris:AddItem(highlight,1)
				end)
			end
			return end
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir3"]:Play()
			Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
			Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
		end
		if not Character:FindFirstChildOfClass("Highlight") then 
			local highlight = script.Parent.Highlight:Clone()
			highlight.Parent = Character
			game:GetService("TweenService"):Create(highlight, TweenInfo.new(5/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 0}):Play()
			task.delay(5/60,function()
				game:GetService("TweenService"):Create(highlight, TweenInfo.new(15/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 1}):Play()
				game.Debris:AddItem(highlight,1)
			end)
		end
	end,
	["GROUNDPULL"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		Character["Right Arm"]:FindFirstChild("remiliaspear")["swing2"]:Play()
		if not Character:FindFirstChild("heartbreakingfr") then
			Character["Right Arm"]:FindFirstChild("remiliaspear").Attachm122ent.spinbladebycrokuran2:Play()
			for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Attachm122ent:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
	end,
	["LASTM1VFX"] = function(Character)
		--if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then return end
		end
		local Directory = ResourceFolder.Parent.MiserableMultitude
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		emit(Directory.slash1lastm1,false)
		--local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.LastM1.Ground:Clone()
		--RedFX15.Parent = Character.HumanoidRootPart
		--game.Debris:AddItem(RedFX15,5)
		--for i,v in pairs(RedFX15:GetDescendants()) do
		--	if v:IsA('ParticleEmitter') then
		--		v:Emit(v:GetAttribute('EmitCount') or 1)
		--	end
		--end
	end,
	["LASTM1HIGHLIGHT"] = function(Character)
		--if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		if Character:FindFirstChildOfClass("Highlight") then return end
		local highlight = script.Parent.Highlight:Clone()
		highlight.Parent = Character
		game:GetService("TweenService"):Create(highlight, TweenInfo.new(5/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 0}):Play()
		task.delay(5/60,function()
			game:GetService("TweenService"):Create(highlight, TweenInfo.new(15/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 1}):Play()
			game.Debris:AddItem(highlight,1)
		end)
	end,
	["2TRAIL"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			for i ,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants())do
				if  v:IsA('Trail') then
					if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad") then
						Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad"):Destroy()
					end
					local v1 = v:Clone()
					v1.Enabled = true
					v1.Name = ("lolazoverdad")
					v1.Parent =Character["Right Arm"]:FindFirstChild("remiliaspear")
					task.delay(1.1,function()
						v1.Enabled = false
						game.Debris:AddItem(v1,.8)
					end)
				end
			end
		end
	end,
	["M1TRAIL"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			for i ,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants())do
				if  v:IsA('Trail') then
					if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad") then
						Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad"):Destroy()
					end
					local v1 = v:Clone()
					v1.Enabled = true
					v1.Name = ("lolazoverdad")
					v1.Parent =Character["Right Arm"]:FindFirstChild("remiliaspear")
					task.delay(.6,function()
						v1.Enabled = false
						game.Debris:AddItem(v1,.8)
					end)
				end
			end
		end
	end,
	["CrokuranSponsorSpin"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		if not Character:FindFirstChild("heartbreakingfr") then
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				Character["Right Arm"]:FindFirstChild("remiliaspear").Attachm122ent.spinbladebycrokuran2:Play()
				for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Attachm122ent:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
		end
	end,
	["CrokuranSponsorSpinNOSOUND"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		if not Character:FindFirstChild("heartbreakingfr") then
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Attachm122ent:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
		end
	end,
	['BloodHit'] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].RemiliaVampKVFX.BloodHit:Clone()
		RedFX15.Parent = Character.HumanoidRootPart
		game.Debris:AddItem(RedFX15,2)
		for i,v in pairs(RedFX15:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
					v:Emit((v:GetAttribute('EmitCount') or 1)/6)
				else
					v:Emit((v:GetAttribute('EmitCount')) or 1)
				end
			end
		end
	end,
	['BlackFlash'] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].RemiliaVampKVFX.BFHit:Clone()
		RedFX15.Parent = Character.Torso
		--if Character.Torso:FindFirstChild("BlackFlash1") then
		--	Character.Torso:FindFirstChild("BlackFlash1"):Destroy()
		--end
		local blackflash = RedFX15.BlackFlash:Clone()
		blackflash.Parent = Character.Torso
		--blackflash.PlaybackSpeed = Random.new():NextNumber(0.85,1.04)
		blackflash:Play()
		game.Debris:AddItem(blackflash,7)
		game.Debris:AddItem(RedFX15,7)
		for i,v in pairs(RedFX15:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
					v:Emit((v:GetAttribute('EmitCount') or 1)/6)
				else
					v:Emit((v:GetAttribute('EmitCount')) or 1)
				end
			end
		end
	end,
	['BlackFlash1'] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].RemiliaVampKVFX.BFHit:Clone()
		RedFX15.Parent = Character.Torso
		local blackflash = RedFX15.BlackFlash1:Clone()
		blackflash.Parent = Character.Torso
		blackflash:Play()
		game.Debris:AddItem(blackflash,7)
		game.Debris:AddItem(RedFX15,7)
		for i,v in pairs(RedFX15:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
					v:Emit((v:GetAttribute('EmitCount') or 1)/6)
				else
					v:Emit((v:GetAttribute('EmitCount')) or 1)
				end
			end
		end
	end,
	['Skill1GroundVFXStartVelocity'] = function(Character)
		local hrp = Character.HumanoidRootPart
		if not Character.Values:FindFirstChild("Stunned") then
			task.delay(20/60,function()
				local velocity = Instance.new('BodyVelocity')
				velocity.MaxForce = Vector3.new(0,200000,0)
				velocity.Velocity = Character.HumanoidRootPart.CFrame.UpVector * 20
				velocity.Parent = Character.HumanoidRootPart
				game.Debris:AddItem(velocity,.14)
				local conn1
				task.delay(.14,function()
					conn1:Disconnect()
				end)
				conn1 = Character:GetAttributeChangedSignal("Cancel"):Connect(function()
					conn1:Disconnect()
					velocity:Destroy()
				end)
			end)
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(20000,0,20000)
			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			game:GetService("TweenService"):Create(lv, TweenInfo.new(fullfiendmodedelay, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {VectorVelocity = Vector3.new(0,0,-70)}):Play()
			task.delay(fullfiendmodedelay,function()
				game:GetService("TweenService"):Create(lv, TweenInfo.new(dashtime2 - fullfiendmodedelay , Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {VectorVelocity = Vector3.new(0,0,0)}):Play()
				game.Debris:AddItem(lv,dashtime2  - fullfiendmodedelay )
			end)
			local conn1
			task.delay(dashtime2,function()
				conn1:Disconnect()
			end)
			conn1 = Character:GetAttributeChangedSignal("Cancel"):Connect(function()
				conn1:Disconnect()
				lv:Destroy()
			end)
		end
	end,
	["Swing"] = function(Character, Combo)
		local thor = false
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
				thor = true
			else
			end
		else
		end
		local Directory = ResourceFolder.Parent.MiserableMultitude
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
			if thor then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v.Color = ColorSequence.new{
							ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
						}
					end
				end
			end
		end
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
			Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
		end
		local function aurae()
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA('ParticleEmitter') and v:GetAttribute("aurae") then
							v:Emit(3)
						end
					end))
				end
			end
		end
		if Combo == 2 then
			task.delay(10/60,function()
				emit(Directory.slash3m1,false)
			end)
		end
		if (Combo == 3) or (Combo == 1) then
			task.delay(10/60,function()
				aurae()
				task.delay(3/60,function()
					aurae()
				end)
				task.delay(6/60,function()
					aurae()
				end)
			end)
		end
		if Combo == 4 then
			task.delay(19/60,function()
				emit(Directory.slash1lastm1,false)
			end)
		end
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
				local chosen =Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori"..math.random(1,2))
				local RedFX=ResourceFolder["movesound"]:Clone() 
				Debris:AddItem(RedFX,2)
				RedFX.Parent = Character.Torso
				RedFX:Play()
				local sound15=chosen:Clone() 
				Debris:AddItem(sound15,2)
				sound15.Parent = Character.Torso
				sound15:Play()
				local RedFX=ResourceFolder.Sfx.Swings['s'..Combo]:Clone() 
				Debris:AddItem(RedFX,2)
				RedFX.Parent = Character.Torso
				RedFX:Play()
				return
			else
			end
		else
		end
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("gunganir3") then
				Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("gunganir3"):Play()
			end
			for i ,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants())do
				if  v:IsA('Trail') then
					if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad") then
						Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad"):Destroy()
					end
					local v1 = v:Clone()
					v1.Enabled = true
					v1.Name = ("lolazoverdad")
					v1.Parent =Character["Right Arm"]:FindFirstChild("remiliaspear")
					task.delay(.7,function()
						v1.Enabled = false
						game.Debris:AddItem(v1,.8)
					end)
				end
			end
		end
		local RedFX=ResourceFolder["movesound"]:Clone() 
		Debris:AddItem(RedFX,2)
		RedFX.Parent = Character.Torso
		RedFX.PlaybackSpeed = Random.new():NextNumber(.9,1.1)
		RedFX.Volume = .3
		RedFX:Play()
		local RedFX25=ResourceFolder["spear152"]:Clone() 
		Debris:AddItem(RedFX25,2)
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			RedFX25.Parent = Character["Right Arm"]:FindFirstChild("remiliaspear")
		else
			RedFX25.Parent = Character["Right Arm"]
		end
		RedFX25.PlaybackSpeed = Random.new():NextNumber(1,1.25)
		RedFX25.Volume = .25
		RedFX25:Play()
		local RedFX161=ResourceFolder["spear35"]:Clone() 
		Debris:AddItem(RedFX161,2)
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			RedFX161.Parent = Character["Right Arm"]:FindFirstChild("remiliaspear")
		else
			RedFX161.Parent = Character["Right Arm"]
		end
		RedFX161.PlaybackSpeed = Random.new():NextNumber(.98,1.05)
		RedFX161.Volume = .18
		RedFX161:Play()
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("redmisthorion") then
				Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("redmisthorion"):Play()
			end
		end
		task.delay(6/60,function()
			if not Character.Values:FindFirstChild("Stunned") then
				local RedFX26=ResourceFolder.Sfx.Swings['s'..Combo]:Clone() 
				Debris:AddItem(RedFX26,2)
				RedFX26.Parent = Character.Torso
				RedFX25.Volume = .16
				RedFX25.PlaybackSpeed = Random.new():NextNumber(1,1.25)
				RedFX26:Play()
			end
		end)
	end,	
	["SwingMissed"] = function(Character, Combo)

	end,
	["SpinVFX"] = function(Character, Enemy)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end

		local RedFX=ResourceFolder.Parent.SpinVFX.Ground:Clone()
		RedFX.Parent=Enemy.Torso
		Debris:AddItem(RedFX,1.6)
		for i,v in pairs(RedFX:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
					v:Emit((v:GetAttribute('EmitCount') or 1)/6)
				else
					v:Emit((v:GetAttribute('EmitCount')) or 1)
				end
			end
		end
	end,
	
	["BloodHit2"] = function(Character, Enemy)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Enemy.Head.Position).Magnitude <= 30 then
			local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
				Camera.CFrame = Camera.CFrame * shakeCf
			end)
			camShake:ShakeOnce(1, 1, .3,.3)
			--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
			camShake:Start()
		end
		for i,v in pairs(ResourceFolder.Parent.BloodHit2:GetChildren()) do
			local clone = v:Clone()
			clone.Parent = Enemy.Head
			game.Debris:AddItem(clone,1)
			if clone:IsA('ParticleEmitter') then
				clone:Emit(v:GetAttribute('EmitCount') or 1)
			elseif clone:IsA("Attachment") then
				for i,v in pairs(clone:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
		end
	end,

	["BloodHitReal"] = function(Character, Enemy)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		for i,v in pairs(ResourceFolder.Parent.BloodHit:GetChildren()) do
			local clone = v:Clone()
			clone.Parent = Character.HumanoidRootPart
			game.Debris:AddItem(clone,1.5)
			if clone:IsA('ParticleEmitter') then
				clone:Emit(v:GetAttribute('EmitCount') or 1)
			elseif clone:IsA("Attachment") then
				for i,v in pairs(clone:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
		end
	end,

	["Skill3StartHit"] = function(Character, Enemy)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		for i,v in pairs(ResourceFolder.Parent.SKILL3STARTHIT:GetChildren()) do
			local clone = v:Clone()
			clone.Parent = Enemy.Torso
			game.Debris:AddItem(clone,1.5)
			if clone:IsA('ParticleEmitter') then
				clone:Emit(v:GetAttribute('EmitCount') or 1)
			elseif clone:IsA("Attachment") then
				for i,v in pairs(clone:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
		end
	end,

	["Skill3AirHit"] = function(Character, Enemy)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		for i,v in pairs(ResourceFolder.Parent.SKILL3AIRHIT:GetChildren()) do
			local clone = v:Clone()
			clone.Parent = Enemy.Torso
			game.Debris:AddItem(clone,1.5)
			if clone:IsA('ParticleEmitter') then
				clone:Emit(v:GetAttribute('EmitCount') or 1)
			elseif clone:IsA("Attachment") then
				for i,v in pairs(clone:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
		end
	end,

	["BloodSucky"] = function(Character, Enemy)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		for i,v in pairs(ResourceFolder.Parent.bloodsucky:GetChildren()) do
			local clone = v:Clone()
			clone.Parent = Enemy.Head
			if clone:IsA('ParticleEmitter') or clone:IsA('Trail') then
				clone.Enabled = true
			elseif clone:IsA("Attachment") then
				for i,v in pairs(clone:GetDescendants()) do
					if v:IsA('ParticleEmitter') or v:IsA('Trail') then
						v.Enabled = true
					end
				end
			end
			task.delay((90-20)/60,function()
				game.Debris:AddItem(clone,1.5)

				if clone:IsA('ParticleEmitter') or clone:IsA('Trail') then
					clone.Enabled = false
				elseif clone:IsA("Attachment") then
					for i,v in pairs(clone:GetDescendants()) do
						if v:IsA('ParticleEmitter') or v:IsA('Trail') then
							v.Enabled = false
						end
					end
				end
			end)
		end
		if Enemy.Head:FindFirstChild("trail") then
			Enemy.Head:FindFirstChild("trail").Trail.Attachment0 = Enemy.Head:FindFirstChild("trail")
			Enemy.Head:FindFirstChild("trail").Trail.Attachment1 = Enemy.Head:FindFirstChild("trail2")
		end
	end,
	["REMIMOVEUPPERCUT"] = function(Character)
		local RedF2X2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.remimoveuppercut:Clone()
		RedF2X2425.Parent = Character.HumanoidRootPart
		game.Debris:AddItem(RedF2X2425,4)
		RedF2X2425:Play()

		local modelclone2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].UppercutMoveVFX
		local cframe = Character.HumanoidRootPart.CFrame
		local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
		local Directory2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
		local Directory5 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local function emit(instance,weld,characterc)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = characterc.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = characterc.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = characterc.HumanoidRootPart	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(characterc.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = game.Workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame,Size = modelclone:FindFirstChild("End").Size}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,4)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		local function emit2(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
					
				end
			end
		end
		local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
		for _,l in limbs do
			if Character[l]:FindFirstChild("dash0") then
				for _,thing in Character[l]:GetChildren() do
					if thing:IsA("Trail") and string.find(thing.Name, "dash") then
						thing.Enabled = true
					end
				end
			else
				local dash_vfx = dashLimbs:Clone():GetChildren()
				for _,p in dash_vfx do
					p.Parent = Character[l]
					if p:IsA("Trail") then
						p.Enabled = true
					end
				end
			end
		end
		local function vineta()
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 50 then
				redvignette()
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(5, 5, .4,.6)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end
		task.delay(55/60,function()
			for _,l in limbs do
				if Character[l]:FindFirstChild("dash0") then
					for _,thing in Character[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = false
						end
					end
				end
			end
		end)
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			for i ,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants())do
				if  v:IsA('Trail') then
					if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad") then
						Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad"):Destroy()
					end
					local v1 = v:Clone()
					v1.Enabled = true
					v1.Name = ("lolazoverdad")
					v1.Parent =Character["Right Arm"]:FindFirstChild("remiliaspear")
					task.delay(40/60,function()
						v1.Enabled = false
						game.Debris:AddItem(v1,.8)
					end)
				end
			end
		end
		emit(Directory.ground11,false,Character)
		local thor = false
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
				thor = true
			else
			end
		else
		end
		if thor == false then
			task.delay(17/60,function()
				emit2(Directory5.impact5UpperCutREMI,false)
				emitsum(modelclone2["Slash3 60"],modelclone2,Character.HumanoidRootPart.CFrame)
				emitsum(modelclone2["GroundSlash1 60"],modelclone2,Character.HumanoidRootPart.CFrame)
				vineta()
			end)
		end
	end,
	["REMIMOVEUPPERCUTHIT"] = function(Character)
		local RedF2X2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.remimoveuppercut:Clone()
		RedF2X2425.Parent = Character.HumanoidRootPart
		game.Debris:AddItem(RedF2X2425,4)
		RedF2X2425:Play()
		local modelclone3 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].CounterVFX
		local modelclone2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].UppercutMoveVFX
		local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
		local Directory2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
		local function emit(instance,weld,characterc)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = characterc.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = characterc.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = characterc.HumanoidRootPart	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(characterc.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = game.Workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame,Size = modelclone:FindFirstChild("End").Size}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,4)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
		for _,l in limbs do
			if Character[l]:FindFirstChild("dash0") then
				for _,thing in Character[l]:GetChildren() do
					if thing:IsA("Trail") and string.find(thing.Name, "dash") then
						thing.Enabled = true
					end
				end
			else
				local dash_vfx = dashLimbs:Clone():GetChildren()
				for _,p in dash_vfx do
					p.Parent = Character[l]
					if p:IsA("Trail") then
						p.Enabled = true
					end
				end
			end
		end
		local function vineta()
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 50 then
				redvignette()
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(5, 5, .4,.6)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end
		local Directory5 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local function emit2(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		task.delay(90/60,function()
			for _,l in limbs do
				if Character[l]:FindFirstChild("dash0") then
					for _,thing in Character[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = false
						end
					end
				end
			end
		end)
		local thor = false
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("thorhammerhit1") then
				Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("thorhammerhit"..math.random(1,2)):Play()
				RedF2X2425.Volume = .4
				thor = true
			else
			end
		else
		end
		local function slash()
			if thor == false then
				emitsum(modelclone2["Slash2"],modelclone2,Character.HumanoidRootPart.CFrame)
				emitsum(modelclone2["GroundSlash2"],modelclone2,Character.HumanoidRootPart.CFrame)
				if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 30 then
					redvignette()
					local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
						Camera.CFrame = Camera.CFrame * shakeCf
					end)
					camShake:ShakeOnce(3, 3, .4,.5)
					--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
					camShake:Start()
					--local vignet = game.ReplicatedStorage.Assets.Vignette:Clone()
					--vignet.ImageLabel.ImageColor3 = Color3.fromRGB(255,10,10)
					--vignet.Parent = game.Players.LocalPlayer.PlayerGui
					--game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(8/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = .6}):Play()
					--task.delay(8/60,function()
					--	game.Debris:AddItem(vignet,15/60)
					--	game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(15/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = 1}):Play()
					--end)
				end
			else
				emitsum(modelclone3["Wind 2375"],modelclone3,Character.HumanoidRootPart.CFrame)
				if Character["Right Arm"]:FindFirstChild("remiliaspear") then
					Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
					Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
				end
				for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Attachm122ent:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
				if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 50 then
					local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
						Camera.CFrame = Camera.CFrame * shakeCf
					end)
					camShake:ShakeOnce(2, 2, .3,.4)
					--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
					camShake:Start()
					local vignet = game.ReplicatedStorage.Assets.Vignette:Clone()
					vignet.ImageLabel.ImageColor3 = Color3.fromRGB(129, 221, 255)
					vignet.Parent = game.Players.LocalPlayer.PlayerGui
					game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(5/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = .85}):Play()
					task.delay(5/60,function()
						game.Debris:AddItem(vignet,10/60)
						game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(10/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = 1}):Play()
					end)
				end
			end
		end
		local attacking = true 
		task.delay(22/60,function()
			coroutine.resume(coroutine.create(function()
				if Character["Right Arm"]:FindFirstChild("remiliaspear") then
					for i ,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants())do
						if  v:IsA('Trail') then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad") then
								Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad"):Destroy()
							end
							local v1 = v:Clone()
							v1.Enabled = true
							v1.Name = ("lolazoverdad")
							v1.Parent =Character["Right Arm"]:FindFirstChild("remiliaspear")
							task.delay(80/60,function()
								v1.Enabled = false
								game.Debris:AddItem(v1,.8)
							end)
						end
					end
				end
				while attacking == true do
					slash()
					wait(.2)
				end
			end))
			--emitsom(modelclone["GroundSlash2"])
			--vineta()
		end)
		--task.delay(27/60,function()
		--	--emitsom(modelclone["Slash3"])
		--	--emitsom(modelclone["GroundSlash2"])
		--	--vineta()
		--end)
		--task.delay(31/60,function()
		--	emitsom(modelclone["Slash2"])
		--	--emitsom(modelclone["GroundSlash2"])
		--	--vineta()
		--end)
		----task.delay(37/60,function()
		----	--emitsom(modelclone["Slash3"])
		----	--emitsom(modelclone["GroundSlash2"])
		----	--vineta()
		----end)
		--task.delay(39/60,function()
		--	emitsom(modelclone["Slash2"])
		--	--emitsom(modelclone["Slash3"])
		--	--emitsom(modelclone["GroundSlash2"])
		--	--vineta()
		--end)
		----task.delay(47/60,function()
		----	emitsom(modelclone["Slash2"])
		----	--emitsom(modelclone["GroundSlash2"])
		----	--vineta()
		----end)
		--task.delay(51/60,function()
		--	emitsom(modelclone["Slash2"])
		--	--emitsom(modelclone["Slash3"])
		--	--emitsom(modelclone["GroundSlash2"])
		--	--vineta()
		--end)
		----task.delay(57/60,function()
		----	emitsom(modelclone["Slash2"])
		----	--emitsom(modelclone["Slash3"])
		----	--emitsom(modelclone["GroundSlash2"])
		----	--vineta()
		----end)
		--task.delay(63/60,function()
		--	emitsom(modelclone["Slash2"])
		--	--emitsom(modelclone["GroundSlash2"])
		--	--vineta()
		--end)
		--task.delay(63/60,function()
		--	emitsom(modelclone["Slash2"])
		--	--emitsom(modelclone["GroundSlash2"])
		--	--vineta()
		--end)
		----task.delay(66/60,function()
		----	--emitsom(modelclone["Slash3"])
		----	--emitsom(modelclone["GroundSlash2"])
		----	--vineta()
		----end)
		--task.delay(68/60,function()
		--	emitsom(modelclone["Wind 237"])
		--	--emitsom(modelclone["GroundSlash2"])
		--	--vineta()
		--end)
		task.delay(74/60,function()
			if thor == false then
				emit(Directory2.appear2,true,Character)
				emit2(Directory5.impact5DownslamREMI,false)
				emitsum(modelclone2["Slash2"],modelclone2,Character.HumanoidRootPart.CFrame)
			end
			emitsum(modelclone2["Wind 237"],modelclone2,Character.HumanoidRootPart.CFrame)
			attacking = false
			--emitsom(modelclone["GroundSlash2"])
			--vineta()
		end)
	end,
	["HEARTBREAKSTARTUPSFX2END"] = function(Character)
		local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.heartbreakstartupsfx2end:Clone()
		sound1.Parent = Character.HumanoidRootPart
		sound1:Play()
		game.Debris:AddItem(sound1,2)
	end,
	["HEARTBREAKSTARTUPSFX2"] = function(Character)
		local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.heartbreakstartupsfx2:Clone()
		sound1.Parent = Character.HumanoidRootPart
		sound1:Play()
		game.Debris:AddItem(sound1,2)
	end,
	["HEARTBREAKSTARTUPSFX"] = function(Character)
		local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.heartbreakstartupsfx:Clone()
		sound1.Parent = Character.HumanoidRootPart
		sound1:Play()
		game.Debris:AddItem(sound1,2)
	end,
	["COUNTERSTARTUP"] = function(Character)
		local Directory3 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
			if weld == true then
				local Weld = Instance.new("WeldConstraint")
				Weld.Part0 = Character.HumanoidRootPart
				Weld.Part1 = instanceclone
				Weld.Name = instanceclone.Name
				Weld.Parent = instanceclone	
			else
				instanceclone.Anchored = true
			end
			instanceclone.Parent = workspace.Ignore.Effects
			if instanceclone:FindFirstChildOfClass("Model") then
				for i,v in pairs(instanceclone:GetDescendants()) do
					if v:IsA('Model') and v:FindFirstChild("Start") then
						local modelclone = v
						modelclone:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame * v.Start.CFrame)
						modelclone.Parent = workspace.Ignore.Effects
						task.delay(modelclone:GetAttribute("EmitDelay"),function()
							local decalparams
							if modelclone:GetAttribute("Decal_TweenParams") then
								decalparams = string.split(modelclone:GetAttribute("Decal_TweenParams"), ",")
							else
								local decalparams2 = "Cubic,Out"
								decalparams = string.split(decalparams2, ",")
							end
							local partparams
							if modelclone:GetAttribute("Part_TweenParams") then
								partparams = string.split(modelclone:GetAttribute("Part_TweenParams"), ",")
							else
								local partparams2 = "Cubic,Out"
								partparams = string.split(partparams2, ",")
							end
							game:GetService("TweenService"):Create(modelclone.Start, TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[partparams[1]], Enum.EasingDirection[partparams[2]],0,false), {CFrame = modelclone:FindFirstChild("End").CFrame}):Play()
							v.Start:FindFirstChildOfClass("Decal").Transparency = modelclone:GetAttribute("StartTransparency")
							game:GetService("TweenService"):Create(modelclone.Start:FindFirstChildOfClass("Decal"), TweenInfo.new(modelclone:GetAttribute("Duration"), Enum.EasingStyle[decalparams[1]], Enum.EasingDirection[decalparams[2]]), {Transparency = modelclone:GetAttribute("EndTransparency")}):Play()
						end)
						--for ie,ve in pairs(modelclone:GetChildren()) do
						--end
					end
				end
			end

			game.Debris:AddItem(instanceclone,5)
			for i,v in pairs(instanceclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		task.delay(2/60,function()
			if Character["Right Arm"]:FindFirstChild("remiliaspear") then
				for i,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear").Shine1:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttributke('EmitCount')) or 1)
						end
					end
				end
			end
		end)
		local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.counterstartupsfx:Clone()
		sound1.Parent = Character.HumanoidRootPart
		sound1:Play()
		game.Debris:AddItem(sound1,1)
		emit(Directory3.ground151bat,true)
	end,
	["HEARTBREAKTHROWSFX"] = function(Character)
		local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.heartbreakthrowsound:Clone()
		sound1.Parent = Character.HumanoidRootPart
		sound1:Play()
		game.Debris:AddItem(sound1,3)
		local RedFX=ResourceFolder["spear255"]:Clone() 
		Debris:AddItem(RedFX,3)
		RedFX.Parent = Character.Torso
		RedFX:Play()
		RedFX.PlaybackSpeed = Random.new():NextNumber(0.95,1.2)
	end,
	["Hit"] = function(Character, Enemy, Combo)
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("redmiststab") then
				Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("redmiststab"):Play()
			end
		end
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("thorhammerhit1") then
				local chosen =Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("thorhammerhit"..math.random(1,2))
				local sound15=chosen:Clone() 
				Debris:AddItem(sound15,2)
				sound15.Parent = Enemy.Torso
				sound15:Play()
				local RedFX=ResourceFolder.Hitfisttd.VFX:Clone()
				RedFX.Parent=Enemy.Torso
				Debris:AddItem(RedFX,1.7)
				for i,v in pairs(RedFX:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						if Character then
							if Character["Right Arm"]:FindFirstChild("remiliaspear") then
								if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
									v.Color = ColorSequence.new{
										ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
										ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
									}
								end
							end
						end
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							v:Emit((v:GetAttribute('EmitCount') or 1)/6)
						else
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
				return
			end
		end
		local RedFX=ResourceFolder.Hit:Clone()
		RedFX.Parent=workspace.Ignore.Effects
		RedFX.CFrame = CFrame.lookAt(Enemy.HumanoidRootPart.Position,Character.HumanoidRootPart.Position)
		RedFX.VFX['h'..Combo]:Play()
		Debris:AddItem(RedFX,1.7)
		--if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
		--	for i,v in pairs(RedFX:GetDescendants()) do
		--		if v:IsA('ParticleEmitter') then
		--			v:Destroy()
		--		end
		--	end
		--else
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		--end
	end,
	--["Hit"] = function(Character, Enemy, Combo)

	--	local RedFX=ResourceFolder.Hit.VFX:Clone()
	--	RedFX.Parent=Enemy[mathrandomlimb[math.random(1,6)]]
	--	RedFX['h'..Combo]:Play()
	--	Debris:AddItem(RedFX,1.6)
	--	if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
	--		for i,v in pairs(RedFX:GetDescendants()) do
	--			if v:IsA('ParticleEmitter') then
	--				v:Destroy()
	--			end
	--		end
	--	else
	--		for i,v in pairs(RedFX:GetDescendants()) do
	--			if v:IsA('ParticleEmitter') then
	--				v:Emit(v:GetAttribute('EmitCount') or 1)
	--			end
	--		end
	--	end
	--end,
	["HitNOSFX"] = function(Character, Enemy, Combo)

		local RedFX=ResourceFolder.Hit.VFX:Clone()
		RedFX.Parent=Enemy[mathrandomlimb[math.random(1,6)]]

		Debris:AddItem(RedFX,1.6)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Destroy()
				end
			end
	end,
	["HitNOVFX"] = function(Character, Enemy, Combo)

		local RedFX=ResourceFolder.Hit.VFX:Clone()
		RedFX.Parent=Enemy[mathrandomlimb[math.random(1,6)]]
		RedFX['h'..Combo]:Play()

		Debris:AddItem(RedFX,1.6)
		for i,v in pairs(RedFX:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				v:Destroy()
			end
		end

	end,
	["Hit53"] = function(Character, Enemy, Combo)

		local RedFX=ResourceFolder.Hit.VFX:Clone()
		RedFX.Parent=Enemy[mathrandomlimb[math.random(1,6)]]
		RedFX['h'..Combo]:Play()

		Debris:AddItem(RedFX,1.6)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Destroy()
				end
			end
		else
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					--v.LockedToPart = true
					if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
						v:Emit((v:GetAttribute('EmitCount') or 1)/6)
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
	end,
	["Hit22"] = function(Character, Enemy, Combo)
		local thor = false
		if Character["Right Arm"]:FindFirstChild("remiliaspear") then
			if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("hammerhori1") then
				thor = true
			else
			end
		else
		end
		if thor == true then
			local sound151 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat["bash"..math.random(1,3)]:Clone()	
			sound151.Parent=Enemy[mathrandomlimb[math.random(1,6)]]
			sound151:Play()
			sound151.Volume = .5
			game.Debris:AddItem(sound151,1)
else
		--local RedFX=ResourceFolder.HitSecond.VFX:Clone()
		--RedFX.Parent=Enemy[mathrandomlimb[math.random(1,6)]]
		local sound151 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat["stab"..math.random(1,3)]:Clone()	
		sound151.Parent=Enemy[mathrandomlimb[math.random(1,6)]]
		sound151:Play()
		sound151.Volume = .6
		game.Debris:AddItem(sound151,1)
		--Debris:AddItem(RedFX,1.6)
		--local mathrand = math.random(1,3)
		--if mathrand then
		--	if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
		--		for i,v in pairs(RedFX:GetDescendants()) do
		--			if v:IsA('ParticleEmitter') then
		--				v:Destroy()
		--			end
		--		end
		--	else
		--		for i,v in pairs(RedFX:GetDescendants()) do
		--			if v:IsA('ParticleEmitter') then
		--				v.LockedToPart = false
		--				v:Emit(v:GetAttribute("EmitCount") or 1)
		--			end
		--		end
		--	end
		--else
			--for i,v in pairs(RedFX:GetDescendants()) do
			--	if v:IsA('ParticleEmitter') then
			--		v:Destroy()
			--	end
			--end
end
		--end
	end,
	["Hit2"] = function(Character, Enemy, Combo)
		local RedFX=ResourceFolder.HitSecond.VFX:Clone()
		RedFX.Parent=Enemy.Torso
		local sound151 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat["stab"..math.random(1,3)]:Clone()	
		sound151.Parent=Enemy[mathrandomlimb[math.random(1,6)]]
		sound151:Play()
		game.Debris:AddItem(sound151,1)
		Debris:AddItem(RedFX,1.6)
		for i,v in pairs(RedFX:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				v:Destroy()
			end
		end
		--if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
		--	for i,v in pairs(RedFX:GetDescendants()) do
		--		if v:IsA('ParticleEmitter') then
		--			v:Destroy()
		--		end
		--	end
		--else
		--	for i,v in pairs(RedFX:GetDescendants()) do
		--		if v:IsA('ParticleEmitter') then
		--			v.LockedToPart = true
		--			v:Emit(1)
		--		end
		--	end
		--end
	end,
	["Block"] = function(Character, Enemy, Combo)

	end,

	["DownSlamWindUp"] = function(Character)
		local modelclone2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].UppercutMoveVFX
		task.delay(3/60,function()
			emitsum(modelclone2["Wind 237"],modelclone2,Character.HumanoidRootPart.CFrame)
			local RedFX=game.ReplicatedStorage.Assets.VFX.uppercutswing:Clone()
			game.Debris:AddItem(RedFX,4)
			RedFX.Parent = Character.HumanoidRootPart
			RedFX:Play()
			local RedFX=ResourceFolder["movesound"]:Clone() 
			Debris:AddItem(RedFX,2)
			RedFX.Parent = Character["Right Leg"]
			RedFX.PlaybackSpeed = Random.new():NextNumber(.9,1.1)
			RedFX.Volume = .35
			RedFX:Play()
		end)
		local RedFX5=ResourceFolder["movesound5"]:Clone() 
		Debris:AddItem(RedFX5,2)
		RedFX5.Parent = Character["Right Leg"]
		RedFX5.PlaybackSpeed = Random.new():NextNumber(.9,1.1)
		RedFX5.Volume = .24
		RedFX5:Play()
		local FX2= game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.DashTrail3:Clone()
		FX2.Parent=Character
		FX2.w.Part0= Character['Right Leg']
		local enabled = true
		for i,v in pairs(FX2:GetDescendants()) do
			coroutine.resume(coroutine.create(function()
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
					while enabled == true do
						local rate = v.Rate
						if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
							rate = v.Rate / 5
						end
						wait(1/rate)
						v:Emit(1)
					end
				end
			end))
		end
		task.delay(24/60,function()
			if FX2 ~= nil then
				enabled = false
				game.Debris:AddItem(FX2,2)
				for i ,v in pairs(FX2:GetDescendants())do
					if  v:IsA('Trail') then
						v.Enabled = false
					end
					if  v:IsA('ParticleEmitter') then
						v.Enabled = false
					end
					if v:IsA("PointLight") then
						game:GetService("TweenService"):Create(v, TweenInfo.new(.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Range = 0}):Play()
					end
				end
			end
		end)
	end,

	['DownSlam'] = function(Character,Enemy)

		--if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local RedFX=ResourceFolder.Hitfisttd.VFX:Clone()
		RedFX.Parent=Enemy.Torso
		RedFX.BlackFlash1:Play()
		Debris:AddItem(RedFX,1.7)
		for i,v in pairs(RedFX:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				if Character["Right Arm"]:FindFirstChild("remiliaspear") then
					if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("thorhammerhit1") then
						v.Color = ColorSequence.new{
							ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
						}
					end
				end
				if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
					v:Emit((v:GetAttribute('EmitCount') or 1)/6)
				else
					v:Emit((v:GetAttribute('EmitCount')) or 1)
				end
			end
		end
		local RedFX152=ResourceFolder.Hitblackfla.VFX:Clone()
		RedFX152.Parent=Enemy.Torso
		Debris:AddItem(RedFX152,1.7)
		for i,v in pairs(RedFX152:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				if Character["Right Arm"]:FindFirstChild("remiliaspear") then
					if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("thorhammerhit1") then
						v.Color = ColorSequence.new{
							ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
						}
					end
				end
				if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
					v:Emit((v:GetAttribute('EmitCount') or 1)/6)
				else
					v:Emit((v:GetAttribute('EmitCount')) or 1)
				end
			end
		end
		local RedFX4=game.ReplicatedStorage.Assets.VFX.Combat.kick22:Clone()
		game.Debris:AddItem(RedFX4,RedFX4.TimeLength)
		RedFX4.Parent = Enemy.Torso
		RedFX4.Volume = .15
		RedFX4:Play()
		local RedFX2=game.ReplicatedStorage.Assets.VFX.Combat.kickdoor:Clone()
		game.Debris:AddItem(RedFX2,RedFX2.TimeLength)
		RedFX2.Parent = Enemy.Torso
		RedFX2.Volume = .15
		RedFX2:Play()
		local RedFX3=game.ReplicatedStorage.Assets.VFX.Combat.hitupper:Clone()
		game.Debris:AddItem(RedFX3,RedFX3.TimeLength)
		RedFX3.Parent = Enemy.Torso
		RedFX3.Volume = .15
		RedFX3:Play()
		local RootCF = CFrame.new(Enemy.Torso.Position + Vector3.new(0,2,0))

		local AppearTime = .17
		local Tilt = 25
		local Distance = 7
		local CollectAfter = 4.5
		local CollectLength = 7
		local HeightOffset = -2
		local HowMuchDown = -5 --how below the ground it is when it appears
		local HowMuchDownCollect = -10 --how below the ground it goes 
		local HowMuchUp = 15
		local DownRayLength = -20
		local NumberOfRocks =5 
		--Module.RockSpawn1(script.Parent, NumberOfRocks, SizeX, SizeY, SizeZ, Distance)
		--	Module.RockSpawn2(RootCF , NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset-1.8,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --inside and smal;er
		--Module.RockSpawn2(RootCF, NumberOfRocks , SizeX, SizeY, SizeZ, Distance+.7,CollectAfter,HeightOffset-2.1,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --outside and bigger

		-- Rock Flying ==
		local Height = 65

		local SizeX = 1.3
		local SizeY = 1.3
		local SizeZ = 1.3
		local CollideAfter = .5
		local Spread = 30

		Module.RockFlying(RootCF , Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)
		local SizeX = 1.5
		local SizeY = 1.5
		local SizeZ = 1.5
		Module.RockFlying(RootCF , Height, SizeX*2.3, SizeY/10, SizeZ*2.3, NumberOfRocks,CollideAfter,Spread)
		Module.RockFlying(RootCF, Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)

		Basemd.SmashTile(RootCF)

		--Round 2
		local AppearTime = .19

		local CollectLength =5.6
		local HowMuchDown = -7
		local AppearTime = .21
		local HowMuchUp = 14
		--Round 3


		local SizeX = 5 
		local SizeY = 5
		local SizeZ = 5
		local Tilt = 34
		-- Ground spawn --
		local Distance = 1

		local NumberOfRocks = 5
		Module.RockSpawn2(RootCF, NumberOfRocks, SizeX, SizeY, SizeZ, Distance,CollectAfter,HeightOffset,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true) --inside and smal;er
		RootCF = RootCF * CFrame.Angles(0,math.rad(90),0)

		local CollectLength =9
		local Distance = 6
		--.RockSpawn2(RootCF, NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset+.15,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true)

		local p5=ResourceFolder.wind:Clone()
		Debris:AddItem(p5,.31)
		p5.Parent= workspace.Ignore.Effects
		p5.CFrame= RootCF * CFrame.new(0,-1.2,0)
		p5.Orientation =Vector3.new(0, 0, -90)			
		local TweenFX = game:GetService("TweenService"):Create(p5, TweenInfo.new(0.3, Enum.EasingStyle.Sine,Enum.EasingDirection.Out), {Transparency = 1,Size = Vector3.new(0.35, 15.92, 15.92),Position = p5.Position + Vector3.new(0,-1.5,0) , Orientation = Vector3.new(0, 0, -90) })
		TweenFX:Play()

		local Params = RaycastParams.new()
		Params.FilterDescendantsInstances =  {workspace.Ignore.Effects}
		Params.FilterType = Enum.RaycastFilterType.Exclude

		local hrp = Character.HumanoidRootPart
		local VictimRootPart = Enemy.HumanoidRootPart
		coroutine.resume(coroutine.create(function()
			--wait(.12)
			local effect = ResourceFolder.GroundHit:Clone()
			effect.Parent = workspace.Ignore.Effects
			game.Debris:AddItem(effect,5)
			local floorInstance = RayCastOnMap(VictimRootPart.Position,Vector3.new(0,-25,0),true)
			if floorInstance then
				local mathrandom = math.random(1,2) 
				local Sound = effect["ROCKIMPACT"..mathrandom]:Clone()
				Sound.Parent = VictimRootPart
				Sound:Play()
				--VictimRootPart.Anchored = true
				----// Look lock \\--

				--local lookDirection = CFrame.lookAt(
				--	VictimRootPart.Position,
				--	Vector3.new(hrp.Position.X, VictimRootPart.Position.Y, hrp.Position.Z)
				--)
				--VictimRootPart.CFrame = lookDirection * CFrame.new(0,-4,0)
				--VictimRootPart.Velocity = Vector3.new(0,0,0)
				--VictimRootPart.CFrame *= CFrame.Angles(math.rad(90), 0, 0)
				--task.delay(0.1,function()
				--	VictimRootPart.Anchored = false
				--end)
				effect.Position = floorInstance.Position + Vector3.new(0,0.75,0)
				for i,v in pairs(effect.GroundBounce:GetDescendants()) do
					if v:IsA("ParticleEmitter") then
						if Character["Right Arm"]:FindFirstChild("remiliaspear") then
							if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("thorhammerhit1") then
								v.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
								}
							end
						end
						v:Emit(v:GetAttribute("EmitCount") or v.Rate)
					end
				end
			end
		end))

	end,
	['hitheadreallyhard'] = function(Character,Enemy,Part)
		--local position = Part:GetClosestPointOnSurface(Enemy.Parent.AttachmentNail.WorldCFrame.Position)
		if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Part.Position).Magnitude <= 30 then
			local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
				Camera.CFrame = Camera.CFrame * shakeCf
			end)
			camShake:ShakeOnce(5, 5, .4,.4)
			--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
			camShake:Start()
		end
		local position = Part:GetClosestPointOnSurface(Enemy.Position)
		local effect = ResourceFolder.WallHit:Clone()
		effect.Parent = workspace.Ignore.Effects
		effect.Position = position
		--effect.CFrame = CFrame.lookAt(effect.Position,Enemy.Parent.AttachmentNail.WorldCFrame.Position)
		effect.CFrame = CFrame.lookAt(effect.Position,Enemy.Position)
		--local Sound = effect["ROCKIMPACT"..math.random(1,2)]
		--Sound:Play()
		local sfx=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.ultfrontdashsfx:Clone()
		sfx.Parent = effect
		sfx:Play()
		for i,v in pairs(effect.GroundBounce:GetDescendants()) do
			if v:IsA("ParticleEmitter") then
				if Character["Right Arm"]:FindFirstChild("remiliaspear") then
					if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("thorhammerhit1") then
						v.Color = ColorSequence.new{
							ColorSequenceKeypoint.new(0, Color3.fromRGB(144, 207, 255)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(144, 207, 255))
						}
					end
				end
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		game.Debris:AddItem(effect,3)
	end,
	['heartbreakland'] = function(Character,Enemy,Part)
		--local position = Part:GetClosestPointOnSurface(Enemy.Parent.AttachmentNail.WorldCFrame.Position)
		if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Part.Position).Magnitude <= 48 then
			local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
				Camera.CFrame = Camera.CFrame * shakeCf
			end)
			camShake:ShakeOnce(5, 5, .4,.4)
			--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
			camShake:Start()
		end
		local position = Part:GetClosestPointOnSurface(Enemy.edge.WorldCFrame.Position)
		local effect = ResourceFolder.WallHit:Clone()
		effect.Parent = workspace.Ignore.Effects
		effect.Position = position
		--effect.CFrame = CFrame.lookAt(effect.Position,Enemy.Parent.AttachmentNail.WorldCFrame.Position)
		effect.CFrame = CFrame.lookAt(effect.Position,Enemy.edge.WorldCFrame.Position)
		local Sound = effect["ROCKIMPACT"..math.random(1,2)]
		Sound:Play()
		for i,v in pairs(effect.GroundBounce:GetDescendants()) do
			if v:IsA("ParticleEmitter") then
				v:Emit(v:GetAttribute("EmitCount"))
			end
		end
		game.Debris:AddItem(effect,2.5)
	end,
	['outline'] = function(Character,Enemy)
		for i,v in pairs(Enemy:GetDescendants()) do
			if v.Name == ("Highlight") then
				v.Enabled = true
			end
		end
	end
}
