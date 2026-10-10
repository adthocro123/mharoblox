local dashLimbs = game.ReplicatedStorage.Assets.VFX:WaitForChild("dash_limbs")
local dashSmoke = game.ReplicatedStorage.Assets.VFX:WaitForChild("dash_smoke")
local Basemd = require(game.ReplicatedStorage.Modules.Util.baseassets)
local PositionData = {}
local Packages = game.ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
return {
	["PARRYHIGHLIGHT"] = function(Character)
		--if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		if Character:FindFirstChildOfClass("Highlight") then return end
		local highlight = script.Parent.ParryHighlight:Clone()
		highlight.Parent = Character
		game:GetService("TweenService"):Create(highlight, TweenInfo.new(4/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 0, OutlineTransparency = 0}):Play()
		task.delay(4/60,function()
			game:GetService("TweenService"):Create(highlight, TweenInfo.new(12/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 1, OutlineTransparency = 1}):Play()
			game.Debris:AddItem(highlight,1)
		end)
	end,
	["SMASHTREES"] = function(Character) 
		coroutine.resume(coroutine.create(function()
			for i = 1,5 do
				Basemd.SmashTrees(Character.HumanoidRootPart.CFrame * CFrame.new(math.random(-5,5),0,math.random(-5,5)))
			end
		end))
	end,
	["DestroyBodyMovers"] = function(specificType)
		local Character = game.Players.LocalPlayer.Character

		for _, Bodymover in pairs(Character.HumanoidRootPart:GetDescendants()) do
			if Bodymover.Name == ("GrabWeld") then return end
			if specificType then
				if Bodymover:IsA(specificType) then
					Bodymover:Destroy()
				end
			else
				if Bodymover.Name == ("GrabWeld") then return end
				if Bodymover:IsA("BodyMover") then
					Bodymover:Destroy()
				end
				--if Bodymover:IsA("LinearVelocity") then
				--	Bodymover:Destroy()
				--end
			end
		end
	end,
	["HITBOX"] = function(Data,Origin,Size,Offset,Debris)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Visible Hitboxes").Value == false then return end
		local Visual
		Visual = Instance.new("Part")
		Visual.Anchored = true
		Visual.Size = Size
		Visual.Material = Enum.Material.ForceField
		Visual.CastShadow = false
		Visual.CanCollide = false
		Visual.Color = Color3.fromRGB(240, 0, 0)
		Visual.Transparency = 0
		Visual.Parent = workspace.Ignore.Effects
		Visual.CFrame = typeof(Origin) == "CFrame" and Origin or Origin.CFrame*Offset
		local connection = true
		coroutine.resume(coroutine.create(function()
			while connection == true do
				if Visual then
					game:GetService("TweenService"):Create(Visual, TweenInfo.new(.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {CFrame = typeof(Origin) == "CFrame" and Origin or Origin.CFrame*Offset}):Play()
				end
				wait(.2)
			end
		end))
		task.delay(Debris,function()
			connection = false
			Visual:Destroy()
		end)
	end,
	["HEALVIGNETTE"] = function(Character)
		pcall(function() game.Players.LocalPlayer.PlayerGui.ShopGui.Heal:Play() end)
		local vignet = game.ReplicatedStorage.Assets.Vignette:Clone()
		vignet.ImageLabel.ImageColor3 = Color3.fromRGB(85, 255, 127)
		vignet.Parent = game.Players.LocalPlayer.PlayerGui
		game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(8/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = .6}):Play()
		task.delay(8/60,function()
			game.Debris:AddItem(vignet,15/60)
			game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(15/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = 1}):Play()
		end)
	end,
	["SPAWNVFX"] = function(Character)
		task.delay(.2,function()
			if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Spawn Flicker").Value == false then return end
			repeat task.wait() until Knit.Loaded
			local spawnsound=game.ReplicatedStorage.Assets.VFX["1up"]:Clone()
			game.Debris:AddItem(spawnsound,1.6)
			spawnsound.Parent = Character.HumanoidRootPart
			spawnsound:Play()
			local originalTransparency = {}
			local flashTimes = {0.05, 0.07, 0.1, 0.15}
			for _, descendant in ipairs(Character:GetChildren()) do
				if descendant:IsA("BasePart") or descendant:IsA("Decal") then
					originalTransparency[descendant] = descendant.Transparency
					--elseif descendant:IsA("Accessory") and descendant:FindFirstChild("Handle") then
					--	originalTransparency[descendant.Handle] = descendant.Handle.Transparency
				end
			end
			for _, descendant in ipairs(Character.AccessoryFolder:GetChildren()) do
				if descendant:IsA("BasePart") or descendant:IsA("Decal") then
					originalTransparency[descendant] = descendant.Transparency
					--elseif descendant:IsA("Accessory") and descendant:FindFirstChild("Handle") then
					--	originalTransparency[descendant.Handle] = descendant.Handle.Transparency
				end
			end
			task.spawn(function()
				for _, duration in ipairs(flashTimes) do
					for descendant, _ in pairs(originalTransparency) do
						if descendant then
							descendant.Transparency = 1
						end
					end
					task.wait(duration)
					for descendant, original in pairs(originalTransparency) do
						if descendant then
							descendant.Transparency = original
						end
					end

					task.wait(duration)
				end
			end)
		end)
	end,
	["DEATHVFX"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Death P Buttons").Value == false then return end
		local originalTransparency = {}
			local flashTimes = {0.05, 0.05, 0.07, 0.07, 0.1, 0.1, 0.15, 0.2, 0.3}
		local Model = game.ReplicatedStorage.Assets.pblock:Clone()
		Model.Parent = workspace.Ignore.Effects
		game.Debris:AddItem(Model,7)
		Model:SetPrimaryPartCFrame(Character.HumanoidRootPart.CFrame)
		for i,v in pairs(Model:GetChildren()) do
			if v:IsA("BasePart") then
				v.CollisionGroup = ("Visuals2")
				v.CanCollide = true
				local boopyve = Instance.new("BodyVelocity")
				boopyve.MaxForce = Vector3.new(45000, 45000, 45000)
				boopyve.P = 9
				local throwdirection2 = math.random(1,3)
				if throwdirection2 == 1 then
					boopyve.Velocity = v.CFrame.RightVector * -math.random(15,25) + Vector3.new(math.random(-12,12), math.random(10,10), math.random(-12,12))
				elseif throwdirection2 == 2 then
					boopyve.Velocity = v.CFrame.RightVector * math.random(15,25) + Vector3.new(math.random(-12,12), math.random(10,10), math.random(-12,12))
				elseif throwdirection2 == 3 then
					boopyve.Velocity = v.CFrame.LookVector * -math.random(15,25) + Vector3.new(math.random(-12,12), math.random(10,10), math.random(-12,12))
				end	
				boopyve.Parent = v
				game.Debris:AddItem(boopyve, .25)
				task.delay(5,function()
					task.spawn(function()
						for _, duration in ipairs(flashTimes) do
							v.BillboardGui.ImageLabel.ImageTransparency = 1
							task.wait(duration)
							v.BillboardGui.ImageLabel.ImageTransparency = 0
							task.wait(duration)
						end
						v:Destroy()
					end)
					--game:GetService("TweenService"):Create(v.BillboardGui.ImageLabel, TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {ImageTransparency = 1}):Play()
				end)
			end
		end
	end,
	["VOICELINE"] = function(Character,FolderName,Specific)
		if Character:FindFirstChild("voicelineable") then
			if FolderName then
				if game.ReplicatedStorage.Voicelines:FindFirstChild(Character:GetAttribute("Character")) then
					local bigfolder = game.ReplicatedStorage.Voicelines:FindFirstChild(Character:GetAttribute("Character"))
					if bigfolder:FindFirstChild(FolderName) then
						local voicelineoriginal
						if Specific then
							voicelineoriginal = bigfolder:FindFirstChild(FolderName):FindFirstChild(Specific)
						else
							local folder = bigfolder:FindFirstChild(FolderName):GetChildren()
							voicelineoriginal = folder[(math.random(1,#folder))]
						end
						for i,v in pairs(Character:GetDescendants()) do
							if v.Name == ("VoicelineSound") or v:GetAttribute("VoicelineSound") then
								v:Destroy()
							end
						end
						local voiceline = voicelineoriginal:Clone()
						voiceline:SetAttribute("VoicelineSound",true)
						voiceline.Parent = Character.Head
						voiceline:Play()
						game.Debris:AddItem(voiceline,7)
					end
				end
			end
		end
	end,
	["HITHIGHLIGHT"] = function(Character,Enemy,Color)
		--if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Hit Indicator").Value == false then return end
		if Enemy:FindFirstChildOfClass("Highlight") then return end
		local highlight = script.Highlight:Clone()
		highlight.Parent = Enemy
		highlight.FillColor = Color
		highlight.OutlineColor = Color
		game:GetService("TweenService"):Create(highlight, TweenInfo.new(7/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 0}):Play()
		task.delay(7/60,function()
			game:GetService("TweenService"):Create(highlight, TweenInfo.new(10/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 1}):Play()
			game.Debris:AddItem(highlight,1)
		end)
	end,
	["EMITSUM"] = function(object)
		object:Emit(object:GetAttribute("EmitCount") or 1)
	end,
	["TRANSTWEEN1"] = function(object)
		local TweenFX = game:GetService("TweenService"):Create(object, TweenInfo.new(0.65, Enum.EasingStyle.Linear,Enum.EasingDirection.InOut), {Transparency = 1})
		TweenFX:Play()
	end,
	["SQUISH"] = function(object)
		local RandomX = Random.new():NextNumber(0.2,1.7)
		if RandomX <= 1.1 and RandomX > 1 then
			RandomX += Random.new():NextNumber(0.15,0.45)
		elseif RandomX >= 0.9 and RandomX < 1 then
			RandomX -= Random.new():NextNumber(0.1,0.4)
		end

		local RandomY = 1
		if RandomX < 1 then
			RandomY = 1 + (1 - RandomX)
		elseif RandomX > 1 then
			RandomY = 1 - (RandomX - 1)
		end
		local Size = object.Size
		local Goal = Size * Vector3.new(RandomX,RandomX,RandomY)
		for i=1,40 do
			game:GetService("RunService").Heartbeat:Wait()
			object.Size = object.Size:Lerp(Goal, 0.3)
			Goal = Goal:Lerp(Size, .1)
		end
	end,
	["REPLICATEPOS1"] = function(char, part, cf, value, root, Duration, tValue)
		local TimeValue = Instance.new("NumberValue")
		TimeValue.Value = tValue

		if value then
			if PositionData[char] then
				PositionData[char]:Disconnect()
			end

			PositionData[char] = game:GetService("RunService").RenderStepped:Connect(function()
				if part and root then
					if TimeValue.Value == 0 then
						part.CFrame = root.CFrame * cf
					else
						game:GetService("TweenService"):Create(part,TweenInfo.new(TimeValue.Value,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{CFrame = root.CFrame * cf}):Play()
					end
				elseif not part or part.Parent == nil then
					PositionData[char]:Disconnect()
					PositionData[char] = nil
				end
			end)
		else
			if PositionData[char] then
				PositionData[char]:Disconnect()
				PositionData[char] = nil
			end
		end

		game:GetService("TweenService"):Create(TimeValue,TweenInfo.new(Duration,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{Value = 0}):Play()
	end,
	["DISRUPTIVE"] = function(Character)
		for ie ,ve in pairs(Character:GetDescendants()) do
			if ve:IsA('ParticleEmitter') and ve:GetAttribute("DISRUPTIVE") then
				ve.Enabled = false
			end
			if ve:IsA('PointLight') and ve:GetAttribute("DISRUPTIVE") then
				game.TweenService:Create(ve,TweenInfo.new(.1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,0,false,0),{Brightness = 0,Range = 0}):Play()
			end
			if ve:IsA('Beam') and ve:GetAttribute("DISRUPTIVE") then
				ve.Enabled = false
				--game:GetService("TweenService"):Create(ve,TweenInfo.new(.1,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0,Width1 = 0}):Play()
			end
		end
	end,
	["GRABWELD"] = function(Character,Enemy,C0)
		local v75
		local v72 = C0
		Enemy.HumanoidRootPart.CFrame = Character.HumanoidRootPart.CFrame * v72
		local buffvalue = Instance.new("BoolValue",Enemy)
		buffvalue.Value = true
		buffvalue.Name = ("BeingGrabbed5")
		local destroyingconn
		destroyingconn = buffvalue.Destroying:Connect(function()
			if destroyingconn ~= nil then
				destroyingconn:Disconnect()
			end
			if v75 ~= nil then
				v75:Disconnect()
			end
		end)
		v75 = game:GetService("RunService").PreRender:Connect(function()
			Enemy.HumanoidRootPart.CFrame = Character.HumanoidRootPart.CFrame * v72
		end);
	end,
	["CLEARGRABWELDS"] = function(Character)
		for i,v in pairs(Character:GetDescendants()) do
			if v.Name == ("BeingGrabbed5") then
				v:Destroy()
			end
		end
	end,
	["ENABLEAIRLIMBS"] = function(Character)
		coroutine.resume(coroutine.create(function()
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
		end))
		--if Character.Humanoid:GetState() == Enum.HumanoidStateType.Running then
		--	if not Character.HumanoidRootPart:FindFirstChild("dust") then
		--		local smoke = dashSmoke.dust:Clone()
		--		smoke.Parent = Character.HumanoidRootPart
		--	end
		--	for _,part in Character.HumanoidRootPart.dust:GetChildren() do
		--		part.Enabled = true
		--	end
		--end
	end,
	["DISABLEAIRLIMBS"] = function(Character)
		coroutine.resume(coroutine.create(function()
			local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
			for _,l in limbs do
				if Character[l]:FindFirstChild("dash0") then
					for _,thing in Character[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = false
						end
					end
				end
			end
		end))
		--if Character.Humanoid:GetState() == Enum.HumanoidStateType.Running then
		--	if Character.HumanoidRootPart:FindFirstChild("dust") then
		--		for _,part in Character.HumanoidRootPart.dust:GetChildren() do
		--			part.Enabled = false
		--		end
		--	end
		--end
	end,
	["removeinclient"] = function(Character, Thing)
		Thing:Destroy()
	end,	
	["disableinclient"] = function(Character, Thing)
		Thing.Enabled = false
	end,	
	["enableinclient"] = function(Character, Thing)
		Thing.Enabled = true
	end,
	["downslamvelocity"] = function(Character, Combo)
		local velocity = Instance.new('BodyVelocity')
		velocity.MaxForce = Vector3.new(0,20000,0)
		velocity.Velocity = Character.HumanoidRootPart.CFrame.UpVector * 25
		velocity.Parent = Character.HumanoidRootPart
		game.Debris:AddItem(velocity,.1)
	end,	
}
