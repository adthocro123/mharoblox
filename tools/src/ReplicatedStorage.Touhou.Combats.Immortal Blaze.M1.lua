local Debris = game:GetService("Debris")
local ResourceFolder = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat
local md = require(game.ReplicatedStorage.Modules.Util.baseassets)

local function RayCastOnMap(origin,direction,returnAll)
	local raycastSettings = RaycastParams.new()
	raycastSettings.FilterType = Enum.RaycastFilterType.Blacklist
	raycastSettings.FilterDescendantsInstances = {workspace.Ignore}
	local ray = workspace:Raycast(origin, direction, raycastSettings)
	if ray and ray.Instance then
		if ray.Instance.CanCollide == false then
			ray = nil
		end
	end
	if returnAll then return ray end
	if ray then
		return ray.Position
	else
		return origin
	end
end
local dashLimbs = game.ReplicatedStorage.Assets.VFX:WaitForChild("dash_limbs")
local dashSmoke = game.ReplicatedStorage.Assets.VFX:WaitForChild("dash_smoke")
local Basemd = require(game.ReplicatedStorage.Modules.Util.baseassets)
local Camera = workspace.CurrentCamera
local CameraShaker=require(game.ReplicatedStorage.Modules.Util.shaker)
local fullfiendmodedelay = 28/60
local dashtime2 = 170/60
local mathrandomlimb = {
	[1] = "Torso",
	[2] = "Head",
	[3] = "Right Arm",
	[4] = "Left Arm",
	[5] = "Right Leg",
	[6] = "Left Leg",
}
local Module = require(game.ReplicatedStorage.Modules.Util.RockScript)
local function orangevignette()
	local vignet = game.ReplicatedStorage.Assets.Vignette:Clone()
	vignet.ImageLabel.ImageColor3 = Color3.fromRGB(255, 60, 0)
	vignet.Parent = game.Players.LocalPlayer.PlayerGui
	game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(8/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = .65}):Play()
	task.delay(7/60,function()
		game.Debris:AddItem(vignet,14/60)
		game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(14/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = 1}):Play()
	end)
end
local function emitsum(instance,modelclone,cframe)
	coroutine.resume(coroutine.create(function()
		local modelclone = instance:Clone()
		modelclone.Parent = workspace.Ignore.Effects
		game.Debris:AddItem(modelclone,8)
		modelclone.CFrame = cframe * instance.CFrame
		--modelclone.Anchored = false
		--local Weld = Instance.new("WeldConstraint")
		--Weld.Part0 = modelclone.HumanoidRootPart
		--Weld.Part1 = modelclone
		--Weld.Name = modelclone.Name
		--Weld.Parent = modelclone.HumanoidRootPart	
		--if modelclone.Name == ("GroundSlash2") then
		--	local floorInstance = RayCastOnMap(modelclone.Position,Vector3.new(0,-8,0),true)
		--	if floorInstance then
		--		modelclone.Position = floorInstance.Position + Vector3.new(0,0.5,0)
		--		for i,v in pairs(modelclone:GetDescendants()) do
		--			if v:IsA('ParticleEmitter') then
		--				v:Emit(v:GetAttribute('EmitCount') or 1)
		--			end
		--		end
		--	end
		--else
			for i,v in pairs(modelclone:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			--end
		end
	end))
end
return {
	['DeepwokenJump'] = function(Character)
		local hrp = Character.HumanoidRootPart
		if not Character.Values:FindFirstChild("Stunned") then
			local velocity = Instance.new('BodyVelocity')
			velocity.MaxForce = Vector3.new(0,12000,0)
			velocity.Velocity = Character.HumanoidRootPart.CFrame.UpVector * 40
			velocity.Parent = Character.HumanoidRootPart
			local time115 = .8
			game.Debris:AddItem(velocity,time115)
			local conn1
			task.delay(time115,function()
				conn1:Disconnect()
			end)
			conn1 = Character:GetAttributeChangedSignal("Cancel"):Connect(function()
				conn1:Disconnect()
				velocity:Destroy()
			end)
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(20000,0,20000)
			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			local starterframethingy = 7
			local extraframes1 = 8
			local time2 = (((170/60) - (111/60)) - ((38/60) - (starterframethingy/60)) - (extraframes1/60))
			local line = -70
			lv.VectorVelocity = Vector3.new(0,0,line)
			game:GetService("TweenService"):Create(lv, TweenInfo.new((time2) + 5 , Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {VectorVelocity = Vector3.new(0,0,0)}):Play()
			game.Debris:AddItem(lv,(time2))
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
	["SKILL4GRABBEDMOVEMENT"] = function(Character)
		local hrp = Character:FindFirstChild("HumanoidRootPart")
			local startingPos = Character.HumanoidRootPart.Position
		local a1 = hrp.CFrame.LookVector
			Character.HumanoidRootPart.Velocity = Vector3.new(0,0,0)
			Character.HumanoidRootPart.Anchored = true
			local MaxRange = 2458
			local starterframethingy = 7
			local pos = hrp.CFrame
			local GoalPosition2 = RayCastOnMap(pos.p, Vector3.new(0,25,0))
			if GoalPosition2 == pos.p then
				GoalPosition2 = pos.p + Vector3.new(0,25,0)
			else
				GoalPosition2 = GoalPosition2 - Vector3.new(0,1.5,0)
		end
		local GoalPosition = CFrame.new(GoalPosition2,a1)
		game:GetService("TweenService"):Create(hrp,TweenInfo.new(62/60,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{CFrame = GoalPosition}):Play()
			wait(65/60)
			local pos = hrp.CFrame
			local TargetPos2 = (pos * CFrame.new(0,-5,-14)).p
			local DetectedFloor = RayCastOnMap(TargetPos2,Vector3.new(0,-MaxRange*1.8,0))
			if TargetPos2 ~= DetectedFloor then
				TargetPos2 = DetectedFloor + Vector3.new(0,3,0)
			end
		local TargetPos = CFrame.new(TargetPos2,a1)
		game:GetService("TweenService"):Create(hrp,TweenInfo.new((123/60) - (65/60),Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{CFrame = TargetPos}):Play()

			wait(123/60)
			Character.HumanoidRootPart.Anchored = false
	end,
	["skill3velocity"] = function(Character)
		local waitee = 3
		local velocity = Instance.new('BodyVelocity')
		velocity.MaxForce = Vector3.new(15000,0,15000)
		velocity.Velocity = Character.HumanoidRootPart.CFrame.LookVector * 110
		velocity.Name = ("loalzoaew")
		velocity.Parent = Character.HumanoidRootPart
		local Val = Instance.new("NumberValue")
		Val.Name = "AutoRotate"
		Val.Parent = Character.Values
		game.Debris:AddItem(Val,.5)
		local grabweldconn
		grabweldconn = Character.HumanoidRootPart.ChildAdded:Connect(function(child)
			if child.Name == ("GrabWeld") then
				grabweldconn:Disconnect()
				if Val ~= nil then
					Val:Destroy()
				end
			end
		end)
		task.delay(waitee/60,function()
			velocity:Destroy()
			Character.HumanoidRootPart.Velocity = Vector3.new(0,0,0)
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.MokouRightVFX:Clone()
			RedFX15.Parent = Character['Right Leg']
			game.Debris:AddItem(RedFX15,6)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
			grabweldconn:Disconnect()
			task.delay(.4,function()
				if Val ~= nil then
					Val:Destroy()
				end
			end)
		end)
	end,
	["specialvelocity"] = function(Character)
		local waitee = 3
		local velocity = Instance.new('BodyVelocity')
		velocity.MaxForce = Vector3.new(15000,0,15000)
		velocity.Velocity = Character.HumanoidRootPart.CFrame.LookVector * 110
		velocity.Name = ("loalzoaew")
		velocity.Parent = Character.HumanoidRootPart
		local Val = Instance.new("NumberValue")
		Val.Name = "AutoRotate"
		Val.Parent = Character.Values
		game.Debris:AddItem(Val,.5)
		local grabweldconn
		grabweldconn = Character.HumanoidRootPart.ChildAdded:Connect(function(child)
			if child.Name == ("GrabWeld") then
				grabweldconn:Disconnect()
				if Val ~= nil then
					Val:Destroy()
				end
			end
		end)
		task.delay(waitee/60,function()
			velocity:Destroy()
			Character.HumanoidRootPart.Velocity = Vector3.new(0,0,0)
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.MokouRightVFX:Clone()
			RedFX15.Parent = Character['Left Leg']
			game.Debris:AddItem(RedFX15,6)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
			grabweldconn:Disconnect()
			task.delay(.4,function()
				Val:Destroy()
			end)
		end)
	end,
	["explodeeff3"] = function(Character)
		local Directory5 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
		local Directory = ResourceFolder.diablejambelol
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		if Character:FindFirstChild("BeamMOK") then
			Character:FindFirstChild("BeamMOK"):Destroy()
		end
		for i ,v in pairs(Character:GetDescendants()) do
			if v.Name:match("BeamMOK") then
				--if v:IsA("BoolValue") then
				--	v:Destroy()
				--else
				game.Debris:AddItem(v,2.5)
				--end
				for ie ,ve in pairs(v:GetDescendants()) do
					if ve:IsA('ParticleEmitter') then
						ve.Enabled = false
					end
					if ve:IsA('PointLight') then
						game.TweenService:Create(ve,TweenInfo.new(.2,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,0,false,0),{Brightness = 0,Range = 0}):Play()
					end
					if ve:IsA('Beam') then
						game:GetService("TweenService"):Create(ve,TweenInfo.new(.7,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0,Width1 = 0}):Play()
					end
				end
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
				if v:IsA('PointLight') then
					game.TweenService:Create(v,TweenInfo.new(.2,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,0,false,0),{Brightness = 0,Range = 0}):Play()
				end
				if v:IsA('Beam') then
					game:GetService("TweenService"):Create(v,TweenInfo.new(.7,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0,Width1 = 0}):Play()
				end
			end
		end
		local LocalCharacter = game.Players.LocalPlayer.Character
		local offset2 = -2.8
		local RootCF = Character.HumanoidRootPart.CFrame * CFrame.new(0,-3.8,-1)

		local Module = require(game.ReplicatedStorage.Modules.Util.RockScript)
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
		RootCF = Character.HumanoidRootPart.CFrame * CFrame.new(0,.5,offset2)

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
		local AppearTime = .19

		local CollectLength =5.6
		local HowMuchDown = -7
		local AppearTime = .21
		local HowMuchUp = 35


		local AppearTime = .17
		local Tilt = 27
		local Distance = 1
		local CollectAfter = 4.5
		local CollectLength = 7
		local HeightOffset = -1.2
		local HowMuchDown = -5 
		local HowMuchDownCollect = -10 
		local HowMuchUp = 15
		local DownRayLength = -20
		local NumberOfRocks =6 

		local Height = 70

		local SizeX = 1.4
		local SizeY = 1.4
		local SizeZ = 1.4
		local CollideAfter = .5
		local Spread = 20
		local SizeX = 1.5
		local SizeY = 1.5
		local SizeZ = 1.5
		RootCF = Character.HumanoidRootPart.CFrame * CFrame.new(0,-3.8,offset2)
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
		Distance = 8

		NumberOfRocks = 7
		SizeX = 6
		SizeY = 6
		SizeZ = 6
		RootCF = RootCF * CFrame.new(0,-5,0)
		Module.RockSpawn2(RootCF, NumberOfRocks, SizeX, SizeY, SizeZ, Distance,CollectAfter,HeightOffset,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true) --inside and smal;er

		emit(Directory.impact225,false,Character)
		emit(Directory.impact3DownslamBig,false,Character)
		emit(Directory.impact3DownslamBig,false,Character)
		if (LocalCharacter:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 35 then
			local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
				Camera.CFrame = Camera.CFrame * shakeCf
			end)
			camShake:ShakeOnce(7, 7, .4,.4)
			--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
			camShake:Start()
		end

		local Params = RaycastParams.new()
		Params.FilterDescendantsInstances =  {workspace.Ignore.Effects}
		Params.FilterType = Enum.RaycastFilterType.Exclude

		local hrp = Character.HumanoidRootPart

		emit(Directory.impact3Downslam,false,Character)
		coroutine.resume(coroutine.create(function()
			local floorInstance = RayCastOnMap((Character.HumanoidRootPart.CFrame*CFrame.new(0,0,-1)).p,Vector3.new(0,-80,0),true)
			if floorInstance then
				local effect = ResourceFolder.GroundHit2:Clone()
				effect.Parent = workspace.Ignore.Effects
				game.Debris:AddItem(effect,5)
				effect.Position = floorInstance.Position + Vector3.new(0,0.8,0)
				for i,v in pairs(effect:GetDescendants()) do
					if v:IsA("ParticleEmitter") then
						v:Emit(v:GetAttribute("EmitCount") or v.Rate)
					end
				end
				local effect2 = ResourceFolder.Slam:Clone()
				effect2.Parent = workspace.Ignore.Effects
				game.Debris:AddItem(effect2,5)
				effect2.Position = floorInstance.Position + Vector3.new(0,0.8,0)
				for i,v in pairs(effect2:GetDescendants()) do
					if v:IsA("ParticleEmitter") then
						v:Emit(v:GetAttribute("EmitCount") or v.Rate)
					end
				end
			end
		end))

	end,
	["startupvfx3"] = function(Character)
		--task.delay(6/60,function()
		local RedF2X24235=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.firekickmiss:Clone()
		RedF2X24235.Parent = Character.Torso
		game.Debris:AddItem(RedF2X24235,4.5)
		RedF2X24235:Play()
		local Directory = ResourceFolder.diablejambelol
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		emit(Directory.ground11,false,Character)
		local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.emit:Clone()
		xsc52.Parent = Character['HumanoidRootPart']
		game.Debris:AddItem(xsc52,5)
		for i,v in pairs(xsc52:GetDescendants()) do
			coroutine.resume(coroutine.create(function()
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute("EmitCount") or 1)
				end
			end))
		end
		task.delay(60/60,function()
			if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then if RedF2X24235 then RedF2X24235:Destroy() end end
			local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.step:Clone()
			xsc52.Parent = Character['Right Leg']
			game.Debris:AddItem(xsc52,5)
			for i,v in pairs(xsc52:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						v:Emit(v:GetAttribute("EmitCount") or 1)
					end
				end))
			end
		end)
		task.delay(77/60,function()
			if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then if RedF2X24235 then RedF2X24235:Destroy() end end
			local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.step:Clone()
			xsc52.Parent = Character['Right Leg']
			game.Debris:AddItem(xsc52,5)
			for i,v in pairs(xsc52:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						v:Emit(v:GetAttribute("EmitCount") or 1)
					end
				end))
			end
		end)
		task.delay(77/60,function()
			if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then if RedF2X24235 then RedF2X24235:Destroy() end end
			local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.step:Clone()
			xsc52.Parent = Character['Left Leg']
			game.Debris:AddItem(xsc52,5)
			for i,v in pairs(xsc52:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						v:Emit(v:GetAttribute("EmitCount") or 1)
					end
				end))
			end
		end)
		task.delay(97/60,function()
			if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then if RedF2X24235 then RedF2X24235:Destroy() end end
			local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.step:Clone()
			xsc52.Parent = Character['Right Leg']
			game.Debris:AddItem(xsc52,5)
			for i,v in pairs(xsc52:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						v:Emit(v:GetAttribute("EmitCount") or 1)
					end
				end))
			end
		end)
		task.delay(97/60,function()
			if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then if RedF2X24235 then RedF2X24235:Destroy() end end
			local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.step:Clone()
			xsc52.Parent = Character['Right Leg']
			game.Debris:AddItem(xsc52,5)
			for i,v in pairs(xsc52:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						v:Emit(v:GetAttribute("EmitCount") or 1)
					end
				end))
			end
		end)
		task.delay(127/60,function()
			if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then if RedF2X24235 then RedF2X24235:Destroy() end end
			emit(Directory.ground11,false,Character)
		end)
		task.delay(101/60,function()
			if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then if RedF2X24235 then RedF2X24235:Destroy() end end
			emit(Directory.ground11,false,Character)
			local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.emit:Clone()
			xsc52.Parent = Character['HumanoidRootPart']
			game.Debris:AddItem(xsc52,5)
			for i,v in pairs(xsc52:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						v:Emit(v:GetAttribute("EmitCount") or 1)
					end
				end))
			end
		end)
		task.delay(122/60,function()
			if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then if RedF2X24235 then RedF2X24235:Destroy() end end
			emit(Directory.impact5,false,Character)
		end)
		--end)
	end,
	["HEARTBREAKLOOPVFX2"] = function(EXPLCFRAME,Character,CharacterCFrame)
		local Projectile = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].feather:clone()
		Projectile.Parent = workspace.Ignore.Effects
		Projectile.Anchored = true
		Projectile.CFrame = CharacterCFrame * CFrame.new(0,0,-1) * CFrame.Angles(0,0,0)
		--if not Projectile:FindFirstChild("FINISHERKNIFE") then
		local time15 = (((CharacterCFrame).Position - EXPLCFRAME.Position).magnitude) / 150
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
						wait(1/rate)
						v:Emit(1)
					end
				end
			end))
		end
		local Directory5 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
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
					else
						v:Emit((v:GetAttribute('EmitCount')) or 1)
					end
				end
			end
		end
		local function emit2(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = CharacterCFrame * instance.CFrame
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
			emit2(Directory5.Feather,false)
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 20 then
				orangevignette()
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(3, 3, .3,.4)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		--local RedFX24215=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.gungnirsound2:Clone()
		--RedFX24215.Parent = Character.HumanoidRootPart
		--game.Debris:AddItem(RedFX24215,3)
		--RedFX24215:Play()
		game:GetService("TweenService"):Create(Projectile.Sound,TweenInfo.new(.1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = .8}):Play()
		--coroutine.resume(coroutine.create(function()
		--	emit(Directory5.impact5REMI,false)
		--	emit(Directory5.impact5REMIVAMPIREton,false)
		--	local RedFX=ResourceFolder.Emit:Clone()
		--	RedFX.CFrame = Projectile.CFrame * CFrame.new(1.2,0,4)
		--	Debris:AddItem(RedFX,2.6)
		--	RedFX.Parent = workspace.Ignore.Effects
		--	RedFX.sfx:Play()
		--	RedFX.sfx2:Play()
		--	RedFX.sfx3:Play()
		--	RedFX.CanQuery = false
		--	RedFX.CanCollide = false

		--	local p5=ResourceFolder.Parent.Parent["Scarlet Empress"].Combat.wind2:Clone()
		--	Debris:AddItem(p5,.31)
		--	p5.Parent= workspace.Ignore.Effects
		--	p5.CFrame=  Projectile.CFrame * CFrame.new(1.2,.4,-4) * CFrame.Angles(0,math.rad(90),0)

		--	local TweenFX = game:GetService("TweenService"):Create(p5, TweenInfo.new(0.3, Enum.EasingStyle.Sine,Enum.EasingDirection.Out), {Transparency = 1,Size = Vector3.new(0.15, 15.92, 15.92) })
		--	TweenFX:Play()
		--	if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 1 then
		--		local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
		--			Camera.CFrame = Camera.CFrame * shakeCf
		--		end)
		--		camShake:ShakeOnce(6, 6, .4,.4)
		--		--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
		--		camShake:Start()
		--	end
		--end))
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
		--Projectile.HeartbreakExplosionSFX:Play()
		--emit(Directory.expl2heart,false)
		game.Debris:AddItem(Projectile,5)
		game:GetService("TweenService"):Create(Projectile.Sound,TweenInfo.new(.3,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 0}):Play()
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
	["hiteff3pers"] = function(Character,Enemy)
		if Character:FindFirstChild("wawoonga") then
			local Directory = ResourceFolder.diablejambelol
			local canceled = false
			local conn1
			task.delay(160/60,function()
				game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(10/60, Enum.EasingStyle.Linear, Enum.EasingDirection.In,0,false), {FieldOfView = 105}):Play()
			end)
			conn1 = Character:FindFirstChild("wawoonga").Destroying:Connect(function()
				game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(15/60, Enum.EasingStyle.Back, Enum.EasingDirection.In,0,false), {FieldOfView = 70}):Play()
				if conn1 then 
					conn1:Disconnect()
				end
				canceled = true
			end)
		end
	end,
	["hiteff3"] = function(Character,Enemy)
		if Character:FindFirstChild("wawoonga") then
			local RedF2X24235=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.firekickhit:Clone()
			RedF2X24235.Parent = Character.Torso
			game.Debris:AddItem(RedF2X24235,6)
			RedF2X24235:Play()
			local Directory = ResourceFolder.diablejambelol
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
			end
			emit(Directory.impact5,false)
			local FX2
			local RedFX15 
			local canceled = false
			local enablooru = true
			local enablooru5 = true
			local xsc1552 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.TP:Clone()
			xsc1552.Parent = Character['HumanoidRootPart']
			game.Debris:AddItem(xsc1552,5)
			for i,v in pairs(xsc1552:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						v:Emit(v:GetAttribute("EmitCount") or 1)
					end
				end))
			end
			local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.impact:Clone()
			xsc52.Parent = Enemy['HumanoidRootPart']
			game.Debris:AddItem(xsc52,5)
			for i,v in pairs(xsc52:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						v:Emit(v:GetAttribute("EmitCount") or 1)
					end
				end))
				end
			task.delay(64/60,function()
				if canceled == true then return end
				local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.TP:Clone()
				xsc52.Parent = Character['HumanoidRootPart']
				game.Debris:AddItem(xsc52,5)
				for i,v in pairs(xsc52:GetDescendants()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA('ParticleEmitter') then
							v:Emit(v:GetAttribute("EmitCount") or 1)
						end
					end))
				end
				local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.uptilt:Clone()
				xsc52.Parent = Enemy['HumanoidRootPart']
				game.Debris:AddItem(xsc52,5)
				for i,v in pairs(xsc52:GetDescendants()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA('ParticleEmitter') then
							v:Emit(v:GetAttribute("EmitCount") or 1)
						end
					end))
				end
			end)
			task.delay(62/60,function()
				if canceled == true then return end
				local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.TP:Clone()
				game.Debris:AddItem(xsc52,5)
				xsc52.Parent = Character['HumanoidRootPart']
				for i,v in pairs(xsc52:GetDescendants()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA('ParticleEmitter') then
							v:Emit(v:GetAttribute("EmitCount") or 1)
						end
					end))
				end
			end)
			task.delay(160/60,function()
				if canceled == true then return end
				local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.pop:Clone()
				game.Debris:AddItem(xsc52,5)
				xsc52.Parent = Character['Torso']
				for i,v in pairs(xsc52:GetDescendants()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA('ParticleEmitter') then
							v:Emit(v:GetAttribute("EmitCount") or 1)
						end
					end))
				end

				local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.TP:Clone()
				game.Debris:AddItem(xsc52,5)
				xsc52.Parent = Character['Torso']
				for i,v in pairs(xsc52:GetChildren()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA('ParticleEmitter') then
							v.Enabled = false
							while enablooru5 == true do
								wait(1/v.Rate)
								v:Emit(1)
							end
						end
					end))
				end
			end)
			task.delay(170/60,function()
				if canceled == true then return end
				local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.pop:Clone()
				game.Debris:AddItem(xsc52,5)
				xsc52.Parent = Character['HumanoidRootPart']
				for i,v in pairs(xsc52:GetDescendants()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA('ParticleEmitter') then
							v:Emit(v:GetAttribute("EmitCount") or 1)
						end
					end))
				end
			end)
			task.delay(159/60,function()
				enablooru5 = false
				for i,v in pairs(Character:GetDescendants()) do
					if v:IsA("BasePart") then
						if v.Transparency == 0 then
							v.Transparency = 1
							task.delay(.05,function()
								game:GetService("TweenService"):Create(v,TweenInfo.new(.3,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 0}):Play()
							end)
						end
					end
				end
			end)
			task.delay(104/60,function()
				if canceled == true then return end
				local xs142141c52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.Hitspark2:Clone()
				game.Debris:AddItem(xs142141c52,5)
				xs142141c52.Parent = Character['Torso']
				local xs1421412c52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.Hitspark3:Clone()
				game.Debris:AddItem(xs1421412c52,5)
				xs1421412c52.Parent = Character['Torso']
				local xs142142512c52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.Flash:Clone()
				game.Debris:AddItem(xs142142512c52,5)
				xs142142512c52.Parent = Character['Torso']
				coroutine.resume(coroutine.create(function()
					while enablooru5 == true do
						wait(1/xs142142512c52.Rate)
						xs142142512c52:Emit(1)
					end
				end))
				coroutine.resume(coroutine.create(function()
					while enablooru5 == true do
						wait(1/xs1421412c52.Rate)
						xs1421412c52:Emit(1)
					end
				end))
				coroutine.resume(coroutine.create(function()
					while enablooru5 == true do
						wait(1/xs142141c52.Rate)
						xs142141c52:Emit(1)
					end
				end))

				local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.TP:Clone()
				game.Debris:AddItem(xsc52,5)
				xsc52.Parent = Character['Torso']
				for i,v in pairs(xsc52:GetChildren()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA('ParticleEmitter') then
							v.Enabled = false
							while enablooru5 == true do
								wait(1/v.Rate)
								v:Emit(1)
							end
						end
					end))
				end
			end)
			local goingdownsound
			task.delay(170/60,function()
				if canceled == true then return end
			    goingdownsound=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.firekickloop:Clone()
				goingdownsound.Parent = Enemy.Head
				goingdownsound:Play()
				game:GetService("TweenService"):Create(goingdownsound,TweenInfo.new(.4,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 1.2}):Play()
				FX2= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.goingdown:Clone()
				FX2.Parent=Character
				FX2.Weld.Part0= Character['Left Leg']
				FX2.Name = ("BeamMOK")
				for i,v in pairs(FX2:GetChildren()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA('ParticleEmitter') then
							v.Enabled = false
							while enablooru == true do
								wait(1/v.Rate)
								v:Emit(1)
							end
						end
					end))
				end
				--game.Debris:AddItem(FX2,5)
				--task.delay(45/60,function()
				--	for i ,v in pairs(FX2:GetDescendants())do
				--		if  v:IsA('Trail') then
				--			v.Enabled = false
				--		end
				--		if  v:IsA('ParticleEmitter') then
				--			v.Enabled = false
				--		end
				--		if v:IsA("PointLight") then
				--			game:GetService("TweenService"):Create(v, TweenInfo.new(.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Range = 0}):Play()
				--		end
				--	end
				--end)
				RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.LeftFootAttachmentbeamo:Clone()
				RedFX15.Parent = Character['Left Leg']
				RedFX15.Name = "BeamMOK"
				for i,v in pairs(RedFX15:GetChildren()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA('ParticleEmitter') then
							v.Enabled = false
							while enablooru == true do
								wait(1/v.Rate)
								v:Emit(1)
							end
						end
					end))
				end
				local function dothesamebeamthing(ve)
					local origwidth0 = ve.Width0
					local origwidth1 = ve.Width1
					ve.Width0 = 0
					ve.Width1 = 0
					game:GetService("TweenService"):Create(ve,TweenInfo.new(.7,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Width0 = origwidth0,Width1 = origwidth1}):Play()

				end
				for ie ,ve in pairs(Character:GetDescendants()) do
					if ve:IsA("Beam") and ve:GetAttribute("Attachment") then
						dothesamebeamthing(ve)
					end
				end
				for ie ,ve in pairs(Character:GetDescendants()) do
					if ve.Name:match("BeamMOK") and ve:IsA("Beam") then
						dothesamebeamthing(ve)
					end
				end
				for ie ,ve in pairs(FX2:GetDescendants()) do
					if ve:IsA('ParticleEmitter') then
						ve.Enabled = false
					end
					--if ve:IsA('PointLight') then
					--	game.TweenService:Create(ve,TweenInfo.new(.2,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,0,false,0),{Brightness = 0,Range = 0}):Play()
					--end
					if ve:IsA('Beam') then
						dothesamebeamthing(ve)
					end
				end
				for ie ,ve in pairs(RedFX15:GetDescendants()) do
					if ve:IsA('ParticleEmitter') then
						ve.Enabled = false
					end
					--if ve:IsA('PointLight') then
					--	game.TweenService:Create(ve,TweenInfo.new(.2,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,0,false,0),{Brightness = 0,Range = 0}):Play()
					--end
					if ve:IsA('Beam') then
						dothesamebeamthing(ve)
					end
				end
				
				for i ,v in pairs(game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.BeamStuff3:GetChildren()) do
					local clonv = v:Clone()
					clonv.Parent = Character["Left Leg"] 
				end
				for i ,v in pairs(game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.leftarmbeamstuff:GetChildren()) do
					local clonv = v:Clone()
					clonv.Parent = Character["Left Arm"] 
				end
				for i ,v in pairs(game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.rightarmbeamstuff:GetChildren()) do
					local clonv = v:Clone()
					clonv.Parent = Character["Right Arm"] 
				end
				for i ,v in pairs(Character["Left Leg"]:GetChildren()) do
					if v:IsA("Beam") and v:GetAttribute("Attachment") then
						local desiredparent = nil
						for ie,ve in pairs(Character:GetDescendants()) do
							if (ve:IsA("Attachment")) and (ve.Name == v:GetAttribute("Attachment")) then
								desiredparent = ve
								break
							end
						end
						if desiredparent ~= nil then
							v.Attachment1 = desiredparent
							if Character["Left Leg"]:FindFirstChild("BeamMOKattach") then
								v.Attachment0 = Character["Left Leg"]:FindFirstChild("BeamMOKattach")
							end
						end
					end
				end
			end)
			local conn1
			conn1 = Character:FindFirstChild("wawoonga").Destroying:Connect(function()
				if conn1 then 
					conn1:Disconnect()
				end
				canceled = true
				enablooru = false
				local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.Final:Clone()
				game.Debris:AddItem(xsc52,8)
				xsc52.Parent = Character['HumanoidRootPart']
				for i,v in pairs(xsc52:GetDescendants()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA('ParticleEmitter') then
							v:Emit(v:GetAttribute("EmitCount") or 1)
						end
					end))
				end
				local souindxpl=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.firekickexpl:Clone()
				souindxpl.Parent = Character.Torso
				souindxpl:Play()
				game.Debris:AddItem(souindxpl,4)
				game.Debris:AddItem(goingdownsound,1)
				game:GetService("TweenService"):Create(goingdownsound,TweenInfo.new(.4,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 0}):Play()
				coroutine.resume(coroutine.create(function()
					local LocalCharacter = game.Players.LocalPlayer.Character
					local offset2 = -2.8
					local RootCF = Character.HumanoidRootPart.CFrame * CFrame.new(0,-3.8,-1)

					local Module = require(game.ReplicatedStorage.Modules.Util.RockScript)
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
					RootCF = Character.HumanoidRootPart.CFrame * CFrame.new(0,.5,offset2)

					-- Rock Flying ==
					local Height = 80

					local SizeX = 1.5
					local SizeY = 1.5
					local SizeZ = 1.5
					local CollideAfter = .5
					local Spread = 45

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
					local AppearTime = .19

					local CollectLength =5.6
					local HowMuchDown = -7
					local AppearTime = .21
					local HowMuchUp = 35


					local AppearTime = .17
					local Tilt = 27
					local Distance = 1
					local CollectAfter = 4.5
					local CollectLength = 7
					local HeightOffset = -1.2
					local HowMuchDown = -5 
					local HowMuchDownCollect = -10 
					local HowMuchUp = 15
					local DownRayLength = -20
					local NumberOfRocks =6 

					local Height = 70

					local SizeX = 1.4
					local SizeY = 1.4
					local SizeZ = 1.4
					local CollideAfter = .5
					local Spread = 20
					local SizeX = 1.5
					local SizeY = 1.5
					local SizeZ = 1.5
					RootCF = Character.HumanoidRootPart.CFrame * CFrame.new(0,-3.8,offset2)
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
					Distance = 15

					NumberOfRocks = 16
					SizeX = 7
					SizeY = 7
					SizeZ = 7
					RootCF = RootCF * CFrame.new(0,-4.5,0)
					Module.RockSpawn2(RootCF, NumberOfRocks, SizeX, SizeY, SizeZ, Distance,CollectAfter,HeightOffset,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true) --inside and smal;er

					emit(Directory.impact225,false,Character)
					emit(Directory.impact3DownslamBig,false,Character)
					emit(Directory.impact3DownslamBig,false,Character)
					if (LocalCharacter:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 35 then
						local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
							Camera.CFrame = Camera.CFrame * shakeCf
						end)
						camShake:ShakeOnce(7, 7, .4,.4)
						--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
						camShake:Start()
					end

					local Params = RaycastParams.new()
					Params.FilterDescendantsInstances =  {workspace.Ignore.Effects}
					Params.FilterType = Enum.RaycastFilterType.Exclude

					local hrp = Character.HumanoidRootPart

					emit(Directory.impact3Downslam,false,Character)
					coroutine.resume(coroutine.create(function()
						local floorInstance = RayCastOnMap((Character.HumanoidRootPart.CFrame*CFrame.new(0,0,-1)).p,Vector3.new(0,-80,0),true)
						if floorInstance then
							local effect = ResourceFolder.GroundHit2:Clone()
							effect.Parent = workspace.Ignore.Effects
							game.Debris:AddItem(effect,5)
							effect.Position = floorInstance.Position + Vector3.new(0,0.8,0)
							for i,v in pairs(effect:GetDescendants()) do
								if v:IsA("ParticleEmitter") then
									v:Emit(v:GetAttribute("EmitCount") or v.Rate)
								end
							end
							local effect2 = ResourceFolder.Slam:Clone()
							effect2.Parent = workspace.Ignore.Effects
							game.Debris:AddItem(effect2,5)
							effect2.Position = floorInstance.Position + Vector3.new(0,0.8,0)
							for i,v in pairs(effect2:GetDescendants()) do
								if v:IsA("ParticleEmitter") then
									v:Emit(v:GetAttribute("EmitCount") or v.Rate)
								end
							end
						end
					end))

				end))
				game.Debris:AddItem(FX2,3)
				game.Debris:AddItem(RedFX15,3)
				FX2.Weld.Part0= Character['HumanoidRootPart']
				for ie ,ve in pairs(Character:GetDescendants()) do
					if ve:IsA("Beam") and ve:GetAttribute("Attachment") then
						game.Debris:AddItem(ve,1)
						game:GetService("TweenService"):Create(ve,TweenInfo.new(.7,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0,Width1 = 0}):Play()
					end
				end
				for ie ,ve in pairs(Character:GetDescendants()) do
					if ve.Name:match("BeamMOK") and ve:IsA("Beam") then
						game.Debris:AddItem(ve,1)
						game:GetService("TweenService"):Create(ve,TweenInfo.new(.7,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0,Width1 = 0}):Play()
					end
				end
				for ie ,ve in pairs(FX2:GetDescendants()) do
					if ve:IsA('ParticleEmitter') then
						ve.Enabled = false
					end
					if ve:IsA('PointLight') then
						game.TweenService:Create(ve,TweenInfo.new(.2,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,0,false,0),{Brightness = 0,Range = 0}):Play()
					end
					if ve:IsA('Beam') then
						game:GetService("TweenService"):Create(ve,TweenInfo.new(.7,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0,Width1 = 0}):Play()
					end
				end
				for ie ,ve in pairs(RedFX15:GetDescendants()) do
					if ve:IsA('ParticleEmitter') then
						ve.Enabled = false
					end
					if ve:IsA('PointLight') then
						game.TweenService:Create(ve,TweenInfo.new(.2,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,0,false,0),{Brightness = 0,Range = 0}):Play()
					end
					if ve:IsA('Beam') then
						game:GetService("TweenService"):Create(ve,TweenInfo.new(.7,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0,Width1 = 0}):Play()
					end
				end
				RedFX15:Destroy()
				FX2:Destroy()
			end)
		end
	end,
	["attachmnt1"] = function(Character)
		local FX2= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
		FX2.Parent=Character
		FX2.w.Part0= Character['Right Leg']
		game.Debris:AddItem(FX2,5)
		task.delay(45/60,function()
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
		end)
		task.delay(29/60,function()
			if not Character.Values:FindFirstChild("Stunned") then
				local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.WaistCenterAttachmentMOK:Clone()
				RedFX15.Parent = Character['Torso']
				game.Debris:AddItem(RedFX15,6)
				for i,v in pairs(RedFX15:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v:Emit(v:GetAttribute('EmitCount') or 1)
					end
				end
			end
		end)
		task.delay(23/60,function()
			if not Character.Values:FindFirstChild("Stunned") then
				local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.RightFootAttachmentMOK:Clone()
				RedFX15.Parent = Character['Right Leg']
				game.Debris:AddItem(RedFX15,6)
				for i,v in pairs(RedFX15:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v:Emit(v:GetAttribute('EmitCount') or 1)
					end
				end
			end
		end)
	end,
	["DASHM1VFX"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local highlight = script.Parent.Highlight:Clone()
		highlight.Parent = Character
		game:GetService("TweenService"):Create(highlight, TweenInfo.new(5/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 0}):Play()
		task.delay(4/60,function()
			game:GetService("TweenService"):Create(highlight, TweenInfo.new(15/60, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 1}):Play()
			game.Debris:AddItem(highlight,1)
		end)
		task.delay(4/60,function()
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.MokouRightVFX:Clone()
			RedFX15.Parent = Character['Right Leg']
			game.Debris:AddItem(RedFX15,6)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
			--local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX["BigExplode"]:Clone()
			--RedFX15.Parent = Character['HumanoidRootPart']
			--game.Debris:AddItem(RedFX15,6)
			--for i,v in pairs(RedFX15:GetDescendants()) do
			--	if v:IsA('ParticleEmitter') then
			--		v:Emit(v:GetAttribute('EmitCount') or 1)
			--	end
			--end
		end)
		local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.RightFootAttachmentMOK:Clone()
		RedFX15.Parent = Character['Right Leg']
		game.Debris:AddItem(RedFX15,6)
		for i,v in pairs(RedFX15:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				v:Emit(v:GetAttribute('EmitCount') or 1)
			end
		end
	end,
	["BITBYADOGWITHARABIDTOOTH"] = function(Character)

		local raycastParams  = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
		raycastParams.FilterDescendantsInstances = {Character,workspace.Ignore.Effects,workspace.Ignore.Rocks}
		local raycastResult = workspace:Raycast(Character.HumanoidRootPart.CFrame.p, Character.HumanoidRootPart.CFrame.LookVector*67.511, raycastParams)

		local TPD = -67.511

		if raycastResult then

			local magnitude  = (Character.HumanoidRootPart.CFrame.p - raycastResult.Position).Magnitude

			TPD =  -magnitude
		end

		Character.HumanoidRootPart.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0,0,TPD)
	end,
	["WALLCOMBOVFX"] = function(Character,theenemy,rootpart51,rootpart56,v45)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		--local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.clothsfx14:Clone()
		--RedFX2425.Parent = Character.HumanoidRootPart
		--game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
		--RedFX2425:Play()
		local count = 0
		local count2 = 0
		local RedFX=ResourceFolder.Hit.VFX:Clone()
		RedFX.Parent=theenemy.Head
		local function effectdownslam()
			if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
			local effectDowsnalm = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.WallHit:Clone()
			local position = v45:GetClosestPointOnSurface(Character.HumanoidRootPart.Position)
			effectDowsnalm.Parent = workspace.Ignore.Effects
			effectDowsnalm.Position = position
			effectDowsnalm.CFrame = CFrame.lookAt(effectDowsnalm.Position,Character.HumanoidRootPart.Position)
			for i,v in pairs(effectDowsnalm.GroundBounce:GetDescendants()) do
				if v:IsA("ParticleEmitter") then
					v:Emit(v:GetAttribute("EmitCount"))
				end
			end
			game.Debris:AddItem(effectDowsnalm,2.5)
		end
		Debris:AddItem(RedFX,1.6)
		for i,v in pairs(RedFX:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				v:Emit(v:GetAttribute('EmitCount') or 0)
			end
		end
		--task.delay(100/60,function()
		--	local RedFX2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.runespeed:Clone()
		--	RedFX2425.Parent = Character.HumanoidRootPart
		--	game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
		--	RedFX2425:Play()
		--end)
		--task.delay(136/60,function()
		--	local RedFX2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.abysscswing:Clone()
		--	RedFX2425.Parent = Character.HumanoidRootPart
		--	game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
		--	RedFX2425:Play()
		--end)
		local RedFX2425=ResourceFolder.wallcombosfx:Clone()
		RedFX2425.Parent = Character.Torso
		game.Debris:AddItem(RedFX2425,5)
		RedFX2425:Play()
		task.delay(137/60,function()
			--local RedFX2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].jump2:Clone()
			--RedFX2425.Parent = Character.HumanoidRootPart
			--game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
			--RedFX2425:Play()
			--local RedFX2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.SpiritBuff:Clone()
			--RedFX2425.Parent = Character.HumanoidRootPart
			--game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
			--RedFX2425:Play()
			local RedFX=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].SpinVFX.Ground:Clone()
			RedFX.Parent=Character.Torso
			Debris:AddItem(RedFX,1.6)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
			task.delay(.2,function()
				local RedFX=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].SpinVFX.Ground:Clone()
				RedFX.Parent=Character.Torso
				Debris:AddItem(RedFX,1.6)
				for i,v in pairs(RedFX:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v:Emit(v:GetAttribute('EmitCount') or 1)
					end
				end
			end)
			task.delay(.4,function()
				local RedFX=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].SpinVFX.Ground:Clone()
				RedFX.Parent=Character.Torso
				Debris:AddItem(RedFX,1.6)
				for i,v in pairs(RedFX:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v:Emit(v:GetAttribute('EmitCount') or 1)
					end
				end
			end)
			task.delay(.6,function()
				local RedFX=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].SpinVFX.Ground:Clone()
				RedFX.Parent=Character.Torso
				Debris:AddItem(RedFX,1.6)
				for i,v in pairs(RedFX:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v:Emit(v:GetAttribute('EmitCount') or 1)
					end
				end
			end)
		end)
		task.delay(32/60,function()
			local RedFX=ResourceFolder.Hit.VFX:Clone()
			RedFX.Parent=theenemy.Head

			Debris:AddItem(RedFX,1.6)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 0)
				end
			end

			local RedFX=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].SpinVFX.Ground:Clone()
			RedFX.Parent=theenemy.Torso
			Debris:AddItem(RedFX,1.6)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end)
		task.delay(44/60,function()
			local RedFX=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].SpinVFX.Ground:Clone()
			RedFX.Parent=theenemy.Torso
			Debris:AddItem(RedFX,1.6)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end)
		task.delay(61/60,function()
			local RedFX=ResourceFolder.Hit.VFX:Clone()
			RedFX.Parent=theenemy.Torso
			Debris:AddItem(RedFX,1.6)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 0)
				end
			end
		end)
		task.delay(71/60,function()
			local RedFX=ResourceFolder.Hit.VFX:Clone()
			RedFX.Parent=theenemy["Left Leg"]

			Debris:AddItem(RedFX,1.6)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 0)
				end
			end
		end)
		task.delay(81/60,function()

			local RedFX=ResourceFolder.Hit.VFX:Clone()
			RedFX.Parent=theenemy.Head

			Debris:AddItem(RedFX,1.6)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 0)
				end
			end
		end)
		task.delay(99/60,function()
			effectdownslam()
			local RedFX=ResourceFolder.Hit.VFX:Clone()
			RedFX.Parent=theenemy.Head

			Debris:AddItem(RedFX,1.6)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 0)
				end
			end
		end)
		task.delay(198/60,function()
			local RedFX=ResourceFolder.Hit.VFX:Clone()
			RedFX.Parent=theenemy.Head

			Debris:AddItem(RedFX,1.6)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 0)
				end
			end
		end)
		task.delay(160/60,function()
			local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.jumpsfx:Clone()
			RedFX2425.Parent = Character.Torso
			game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
			RedFX2425:Play()
		end)
		effectdownslam()
		task.delay(74/60,function()
			local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.clothsfx12:Clone()
			RedFX2425.Parent = Character.Torso
			game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
			RedFX2425:Play()
		end)
		local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
		FX.Parent=Character
		FX.w.Part0= Character['Left Leg']
		game.Debris:AddItem(FX,15)
		local FX2= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
		FX2.Parent=Character
		FX2.w.Part0= Character['Right Leg']
		game.Debris:AddItem(FX2,15)
		task.delay((240/60)-(25/60),function()
			game.Debris:AddItem(FX,1)
			for i ,v in pairs(FX:GetDescendants())do
				if  v:IsA('Trail') then
					v.Enabled = false
				end
				if  v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
			end
			game.Debris:AddItem(FX2,1)
			for i ,v in pairs(FX2:GetDescendants())do
				if  v:IsA('Trail') then
					v.Enabled = false
				end
				if  v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
			end
		end)
		--task.delay(1/60,function()
		--	vortex()
		--end)
		--task.delay(11/60,function()
		--	vortex()
		--end)
		----task.delay(20/60,function()
		----	flare()
		----end)
		--task.delay(11/60,function()
		--	swingsoundspear()
		--end)
		--task.delay(25/60,function()
		--	slash()
		--end)
		--task.delay(115/60,function()
		--	swingsoundspear()
		--end)
		--task.delay(143/60,function()
		--	slash2()
		--end)
		--task.delay(52/60,function()
		--	flare()
		--end)
	end,
	['Skill4GroundVFXStartVelocity'] = function(Character)
		local hrp = Character.HumanoidRootPart
		if not Character.Values:FindFirstChild("Stunned") then
			task.delay(27/60,function()
				local velocity = Instance.new('BodyVelocity')
				velocity.MaxForce = Vector3.new(0,20000,0)
				velocity.Velocity = Character.HumanoidRootPart.CFrame.UpVector * 25
				velocity.Parent = Character.HumanoidRootPart
				game.Debris:AddItem(velocity,.17)
				local conn1
				task.delay(.17,function()
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
			local line = -55
			game:GetService("TweenService"):Create(lv, TweenInfo.new(fullfiendmodedelay + .5, Enum.EasingStyle.Exponential, Enum.EasingDirection.In), {VectorVelocity = Vector3.new(0,0,line)}):Play()
			task.delay(fullfiendmodedelay,function()
				lv.VectorVelocity = Vector3.new(0,0,line)
				game:GetService("TweenService"):Create(lv, TweenInfo.new((dashtime2 - fullfiendmodedelay) + 2 , Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {VectorVelocity = Vector3.new(0,0,0)}):Play()
				game.Debris:AddItem(lv,(dashtime2  - fullfiendmodedelay))
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
	["SLASHFASTVFX"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local FX
		local FX2
		local enabled2 = true
		local Directory = ResourceFolder.diablejambelol
		task.delay((20/60),function()
			if Character.Values:FindFirstChild("Stunned") then return end
			local a = Directory.ring:Clone()
			a.Parent = workspace.Ignore.Effects
			a.Position = Character.Torso.BodyFrontAttachment.WorldCFrame.Position
			for i,v in pairs(a:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v.Enabled = true
				end
			end
			coroutine.resume(coroutine.create(function()
				while enabled2 == true do
					wait(.15)
					a.Position = Character.Torso.BodyFrontAttachment.WorldCFrame.Position
					for i,v in pairs(a:GetDescendants()) do
						if v:IsA('ParticleEmitter') then
							v:Emit(1)
						end
					end
				end
				for i,v in pairs(a:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v.Enabled = false
					end
				end
				game.Debris:AddItem(a,3)
			end))
			FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
			FX.Parent=Character
			FX.w.Part0= Character['Left Leg']
			game.Debris:AddItem(FX,15)
			FX2= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
			FX2.Parent=Character
			FX2.w.Part0= Character['Right Leg']
			game.Debris:AddItem(FX2,15)
			task.delay((103-20)/60,function()
				game.Debris:AddItem(FX,1)
				enabled2 = false
				for i ,v in pairs(FX:GetDescendants())do
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
			end)
		end)
		coroutine.resume(coroutine.create(function()
			local Time = 0

			repeat
				local dt = .0325

				--Hit = SimpleHitbox(hrp.CFrame)
				--HitRay = Rayc(hrp)
				wait(dt)
				Time += dt
			until
			Time >= (103/60) or not Character.Values:FindFirstChild("Cant") or Character.HumanoidRootPart:FindFirstChild("GrabWeld")  or Character.Values:FindFirstChild("Stunned")
			enabled2 = false
			if Character.Values:FindFirstChild("Stunned") then
				if FX ~= nil then
					FX:Destroy()
				end
				if FX2 ~= nil then
					FX2:Destroy()
				end
			end
		end))
	end;
	["DIABLEJAMBLELOL"] = function(Character,theenemy)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local Directory = ResourceFolder.diablejambelol
		local sound1=ResourceFolder.diablesfx:Clone()
		sound1.Parent = Character.Torso
		sound1:Play()
		local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
		FX.Parent=Character
		FX.w.Part0= Character['Right Leg']

		game.Debris:AddItem(FX,4)
		task.delay(3,function()
		end)  

		local FX2= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
		FX2.Parent=Character
		FX2.w.Part0= Character['Left Leg']

		game.Debris:AddItem(FX2,4)
		task.delay(3,function()
			for i ,v in pairs(FX2:GetDescendants())do
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		task.delay(0/60,function()
			emit(Directory.impact1,false)
		end)
		task.delay(5/60,function()
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 50 then
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(5, 5, .4,.6)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
			emit(Directory.impact2,false)
		end)
		task.delay(37/60,function()
			emit(Directory.impact3,false)
		end)
		task.delay(71/60,function()
			emit(Directory.ground1,false)
		end)
		task.delay(106/60,function()
			emit(Directory.impact4,false)
		end)
		task.delay(221/60,function()
			emit(Directory.impact5,false)
		end)
		task.delay(146/60,function()
			for i, v in pairs(FX:GetDescendants()) do
				if v:IsA("PointLight") or v:IsA("Trail") or v:IsA("ParticleEmitter") then
					v.Enabled = false
				end
			end
			for i, v in pairs(FX2:GetDescendants()) do
				if v:IsA("PointLight") or v:IsA("Trail") or v:IsA("ParticleEmitter") then
					v.Enabled = false
				end
			end
		end)
		task.delay(323/60,function()
			for i, v in pairs(FX:GetDescendants()) do
				if v:IsA("PointLight") or v:IsA("Trail") or v:IsA("ParticleEmitter") then
					v.Enabled = true
				end
			end
			for i, v in pairs(FX2:GetDescendants()) do
				if v:IsA("PointLight") or v:IsA("Trail") or v:IsA("ParticleEmitter") then
					v.Enabled = true
				end
			end
			emit(Directory.impact6,false)
		end)
		local enabled1 = true
		task.delay(151/60,function()
			local a = Directory.ring:Clone()
			a.Parent = workspace.Ignore.Effects
			a.Position = Character.Torso.WaistCenterAttachment.WorldCFrame.Position
			for i,v in pairs(a:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v.Enabled = true
				end
			end
			coroutine.resume(coroutine.create(function()
				while enabled1 == true do
					wait(.15)
					a.Position = Character.Torso.WaistCenterAttachment.WorldCFrame.Position
					for i,v in pairs(a:GetDescendants()) do
						if v:IsA('ParticleEmitter') then
							v:Emit(1)
						end
					end
				end
				for i,v in pairs(a:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v.Enabled = false
					end
				end
				game.Debris:AddItem(a,3)
			end))
		end)
		task.delay(220/60,function()
			enabled1 = false
		end)
		local enabled2 = true
		task.delay(243/60,function()
			local a = Directory.ring2:Clone()
			a.Parent = workspace.Ignore.Effects
			a.Position = Character.Torso.BodyFrontAttachment.WorldCFrame.Position
			for i,v in pairs(a:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v.Enabled = true
				end
			end
			coroutine.resume(coroutine.create(function()
				while enabled2 == true do
					wait(.15)
					a.Position = Character.Torso.BodyFrontAttachment.WorldCFrame.Position
					for i,v in pairs(a:GetDescendants()) do
						if v:IsA('ParticleEmitter') then
							v:Emit(1)
						end
					end
				end
				for i,v in pairs(a:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v.Enabled = false
					end
				end
				game.Debris:AddItem(a,3)
			end))
		end)
		task.delay(285/60,function()
			enabled2 = false
		end)
	end,
	['FASTSLASHVELOCITY'] = function(Character)
		local hrp = Character.HumanoidRootPart
		--local RedFX15
		coroutine.resume(coroutine.create(function()
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(0,0,24000)

			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			lv.VectorVelocity = Vector3.new(0,0,0)
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(.7, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,-8)})

			Tween:Play()

			local Hit = false

			local HitRay = false

			local Time = 0

			repeat
				local dt = .0325

				--Hit = SimpleHitbox(hrp.CFrame)
				--HitRay = Rayc(hrp)
				wait(dt)
				Time += dt
			until
			Time >= (107/60) or not Character.Values:FindFirstChild("Cant") or Character.HumanoidRootPart:FindFirstChild("GrabWeld")  or Character.Values:FindFirstChild("Stunned")
			if Character.Values:FindFirstChild("Stunned") then
				--if RedFX15 ~= nil then
				--	RedFX15:Destroy()
				--end
			end
			Tween:Pause()
			Tween:Destroy()
			local Tween2 = game:GetService("TweenService"):Create(lv,TweenInfo.new(.1, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,0)})
			Tween2:Play()
			game.Debris:AddItem(lv,.15)
		end))
	end,
	["SLASHFASTVFXULT"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		if Character.Values:FindFirstChild("Stunned") then return end
		local RedFX15
		RedFX15 =game.ReplicatedStorage.Assets.Tornado:Clone()
		local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
			Camera.CFrame = Camera.CFrame * shakeCf
		end)
		local vignet = game.ReplicatedStorage.Assets.Vignette:Clone()
		vignet.ImageLabel.ImageColor3 = Color3.fromRGB(255, 99, 8)
		vignet.Parent = game.Players.LocalPlayer.PlayerGui
		game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(8/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = .5}):Play()

		camShake:ShakeSustain(CameraShaker.Presets.BatSwarm)
		camShake:Start()
		for i,v in pairs(Character:GetDescendants()) do
			if v:IsA('BasePart') or v:IsA('Decal') or v:IsA('Texture') then
				coroutine.resume(coroutine.create(function()
					local originaltransparency = v.Transparency
					game:GetService("TweenService"):Create(v,TweenInfo.new(.15,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
					task.delay((160-60)/60, function()
						game:GetService("TweenService"):Create(v,TweenInfo.new(.4,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Transparency = originaltransparency}):Play()
					end)
				end))
			end
		end
		for i,v in pairs(RedFX15:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				v.Enabled = false
			end
			if v:IsA('PointLight') then
				v.Enabled = true
				local range = v.Range
				v.Range = 0
				game:GetService("TweenService"):Create(v,TweenInfo.new(.15,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Range = range}):Play()
			end
			if v:IsA('Beam') then
				v.Enabled = false
				local width1 = v.Width1
				local width0 = v.Width0
				v.Width1 = 0
				v.Width0 = 0
				game:GetService("TweenService"):Create(v,TweenInfo.new(.6,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = width0,Width1 = width1}):Play()
			end
		end
		RedFX15.Parent = Character
		RedFX15.Middle.Motor6D.Part0 = Character.HumanoidRootPart
		game.Debris:AddItem(RedFX15,10)
		task.delay(115/60,function()
			if RedFX15 ~= nil then
				for i,v in pairs(RedFX15:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v.Enabled = false
					end
					if v:IsA('PointLight') then
						v.Enabled = true
						game:GetService("TweenService"):Create(v,TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Range = 0}):Play()
					end
					if v:IsA('Beam') then
						v.Enabled = false
						game:GetService("TweenService"):Create(v,TweenInfo.new(1,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0,Width1 = 0}):Play()
					end
				end
			end
		end)
		--end)
local attacking = true
task.delay(115/60,function()
			attacking = false
			camShake:Stop()
			game.Debris:AddItem(vignet,15/60)
			game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(15/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = 1}):Play()
			end)
		coroutine.resume(coroutine.create(function()
			local Time = 0

			repeat
				local dt = .06
				--local mathrandom = math.random(1,2)
				--if mathrandom == 1 then
					for i,v in pairs(RedFX15:GetDescendants()) do
						if v:IsA('ParticleEmitter') then
							v:Emit(1)
						end
					end
				--end
				wait(dt)
				Time += dt
			until
			attacking == false or not Character.Values:FindFirstChild("Cant") or Character.HumanoidRootPart:FindFirstChild("GrabWeld")  or Character.Values:FindFirstChild("Stunned")
			if Character.Values:FindFirstChild("Stunned") then
				if RedFX15 ~= nil then
					RedFX15:Destroy()
				end
			end
		end))
	end;
	['FASTSLASHVELOCITYULT'] = function(Character)
		local hrp = Character.HumanoidRootPart
		--local RedFX15
		coroutine.resume(coroutine.create(function()
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(0,0,15000)

			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			lv.VectorVelocity = Vector3.new(0,0,0)
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(.2, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,-60)})

			Tween:Play()

			local Hit = false

			local HitRay = false

			local Time = 0

			repeat
				local dt = .0325

				--Hit = SimpleHitbox(hrp.CFrame)
				--HitRay = Rayc(hrp)
				wait(dt)
				Time += dt
			until
			Time >= (110/60) or not Character.Values:FindFirstChild("Cant") or Character.HumanoidRootPart:FindFirstChild("GrabWeld")  or Character.Values:FindFirstChild("Stunned")
			if Character.Values:FindFirstChild("Stunned") then
			--if RedFX15 ~= nil then
			--	RedFX15:Destroy()
			--end
end
			Tween:Pause()
			Tween:Destroy()
			local Tween2 = game:GetService("TweenService"):Create(lv,TweenInfo.new(.1, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,0)})
			Tween2:Play()
			game.Debris:AddItem(lv,.15)
		end))
	end,
	["UPPERCUTVFX"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end

		local Directory = ResourceFolder.diablejambelol
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		emit(Directory.impact5UpperCut,false)
	end,
	--["lolazosegundo"] = function(Character,Enemy)
	--	Character.HumanoidRootPart.Anchored = true
	--	local timefor4s = .1
	--	for i = 0.1, 0.7, 0.1 do
	--		if i < 0.7 then
	--			local originallookvector1 = Character.HumanoidRootPart.CFrame.LookVector
	--			local pos = (Character.HumanoidRootPart.CFrame:Lerp((Enemy.HumanoidRootPart.CFrame*CFrame.new(0,0,-4)), timefor4s)).Position
	--			game:GetService("TweenService"):Create(Character.HumanoidRootPart, TweenInfo.new(.01), { CFrame = CFrame.new(pos, pos + originallookvector1)}):Play();
	--			--end
	--			--if i ~= 0.7 then
	--			timefor4s += .1
	--			wait(.01)
	--		end
	--	end
	--	Character.HumanoidRootPart.Anchored = false
	--end,
	["VELOCITYULT31FC"] = function(Character)
		local pos = Character.HumanoidRootPart.CFrame
		local GoalPosition = RayCastOnMap(pos.p, Vector3.new(0,120,0))
		if GoalPosition == pos.p then
			GoalPosition = pos.p + Vector3.new(0,120,0)
		else
			GoalPosition = GoalPosition - Vector3.new(0,2,0)
		end
		local BP = Instance.new("BodyPosition")
		BP.D = 500
		BP.P = 800
		BP.MaxForce = Vector3.new(0,20000,0)
		BP.Position = GoalPosition
		BP.Parent = Character.HumanoidRootPart
		local lv = Instance.new("LinearVelocity")
		lv.Name = "Dashing"
		lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		lv.MaxAxesForce = Vector3.new(20000,0,20000)
		lv.Attachment0 = Character.HumanoidRootPart:FindFirstChild("RootAttachment")
		lv.Parent = Character.HumanoidRootPart
		lv.VectorVelocity = Vector3.new(0,0,-60)
		game.Debris:AddItem(lv,65/60)
		game.Debris:AddItem(BP,65/60)
	end,
	["SPEEDBLITZVFXLOLZHIT"] = function(Character,enemy)
		--local RedF2X2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.remimoveuppercut:Clone()
		--RedF2X2425.Parent = Character.HumanoidRootPart
		--game.Debris:AddItem(RedF2X2425,4)
		--RedF2X2425:Play()
		local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
		local Directory2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
		local Directory5 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local function emit(instance,weld,characterc)
			if not Character.Values:FindFirstChild("Cant") then return end
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		local function emit2(instance,weld,enable)
			if not Character.Values:FindFirstChild("Cant") then return end
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
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
		task.delay(190/60,function()
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
		for _,l in limbs do
			if enemy[l]:FindFirstChild("dash0") then
				for _,thing in enemy[l]:GetChildren() do
					if thing:IsA("Trail") and string.find(thing.Name, "dash") then
						thing.Enabled = true
					end
				end
			else
				local dash_vfx = dashLimbs:Clone():GetChildren()
				for _,p in dash_vfx do
					p.Parent = enemy[l]
					if p:IsA("Trail") then
						p.Enabled = true
					end
				end
			end
		end
		task.delay(190/60,function()
			for _,l in limbs do
				if enemy[l]:FindFirstChild("dash0") then
					for _,thing in enemy[l]:GetChildren() do
						if thing:IsA("Trail") and string.find(thing.Name, "dash") then
							thing.Enabled = false
						end
					end
				end
			end
		end)
		local attacking = true 
		local function vineta()
			if not Character.Values:FindFirstChild("Cant") then return end
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 30 then
				--local RedF2X24235=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.althit:Clone()
				--RedF2X24235.Parent = Character.Torso
				--game.Debris:AddItem(RedF2X24235,3)
				--RedF2X24235.Volume = .4
				--RedF2X24235.Pitch = (math.random(9, 11) / 10)
				--RedF2X24235:Play()
				--local RedF2X2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.althit2:Clone()
				--RedF2X2425.Parent = Character.Torso
				--game.Debris:AddItem(RedF2X2425,3)
				--RedF2X2425.Volume = .8
				--RedF2X2425.Pitch = (math.random(9, 11) / 10)
				--RedF2X2425:Play()
				orangevignette()
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(3, 3, .3,.4)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end
		local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.emit:Clone()
		xsc52.Parent = Character['HumanoidRootPart']
		game.Debris:AddItem(xsc52,5)
		for i,v in pairs(xsc52:GetDescendants()) do
			coroutine.resume(coroutine.create(function()
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute("EmitCount") or 1)
				end
			end))
		end
		emit(Directory5.ground11,false,Character)
		local tim = .25
		local root = Character.HumanoidRootPart
		task.delay(136/60,function()
			if not Character.Values:FindFirstChild("Cant") then return end
			emit(Directory.ground11,false,Character)
			local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.emit:Clone()
			xsc52.Parent = Character['HumanoidRootPart']
			game.Debris:AddItem(xsc52,5)
			for i,v in pairs(xsc52:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						v:Emit(v:GetAttribute("EmitCount") or 1)
					end
				end))
			end
			md.rockspawn(root,.37,.37,tim,.046,Vector3.new(-1.3,0,-1.3),true)

			md.rockspawn(root,.37,.37,tim,.046,Vector3.new(1.3,0,1.3))

			md.rockspawn(root,.37,.37,tim,.07,Vector3.new(-1.9,0,-1.9),false)

			md.rockspawn(root,.32,.32,tim,.07,Vector3.new(1.9,0,1.9))
		end)

		--local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.clothsfx12:Clone()
		--RedFX2425.Parent = Character.HumanoidRootPart
		--game.Debris:AddItem(RedFX2425,5)
		--RedFX2425:Play()
		--local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.clothsfx14:Clone()
		--RedFX2425.Parent = Character.HumanoidRootPart
		--game.Debris:AddItem(RedFX2425,5)
		--RedFX2425:Play()
		--local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.clothsfx16:Clone()
		--RedFX2425.Parent = Character.HumanoidRootPart
		--game.Debris:AddItem(RedFX2425,5)
		--RedFX2425:Play()
		--task.delay(5/60,function()
		--	local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.clothsfx15:Clone()
		--	RedFX2425.Parent = Character.HumanoidRootPart
		--	game.Debris:AddItem(RedFX2425,5)
		--	RedFX2425:Play()
		--end)
		--task.delay(146/60,function()
		--	emit(Directory.flashstep,false,Character)
		--	--coroutine.resume(coroutine.create(function()
		--	--	local Data = {}
		--	--	Data[1] = Character
		--	--	local originalhealth = Character.Humanoid.HealthDisplayDistance
		--	--	local originalname = Character.Humanoid.NameDisplayDistance
		--	--	Character.Humanoid.HealthDisplayDistance = 0
		--	--	Character.Humanoid.NameDisplayDistance = 0
		--	--	Character.Archivable = true
		--	--	local Can = true
		--	--	task.delay(40/60,function()
		--	--		Can = false
		--	--		Character.Archivable = false
		--	--		Character.Humanoid.HealthDisplayDistance = originalhealth
		--	--		Character.Humanoid.NameDisplayDistance = originalname
		--	--	end)
		--	--	while Can do
		--	--		local chrclone = Character:Clone()
		--	--		chrclone.HumanoidRootPart.CFrame = Character.HumanoidRootPart.CFrame
		--	--		for i,v in pairs(chrclone:GetDescendants()) do
		--	--			if v:IsA('Sound') or v:IsA('PointLight') then
		--	--				v:Destroy()
		--	--			end
		--	--			if v:IsA('BasePart') or v:IsA('Decal') or v:IsA('Texture') then
		--	--				if not (v.Transparency >= 1) then
		--	--					v.Transparency = .95
		--	--				end
		--	--			end
		--	--			if v:IsA('BasePart') then
		--	--				v.CanCollide = false
		--	--				v.CollisionGroup = "Visuals"
		--	--				v.RootPriority = -127
		--	--				v.Anchored = true
		--	--			end
		--	--		end
		--	--		chrclone.Humanoid.HealthDisplayDistance = 0
		--	--		chrclone.Humanoid.NameDisplayDistance = 0
		--	--		chrclone.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		--	--		chrclone.Parent = workspace.Ignore.Effects


		--	--		for i,v in pairs(chrclone:GetDescendants()) do
		--	--			if v:IsA('BasePart') and v.Transparency == 0 then
		--	--				local P1 = game:GetService("TweenService"):Create(v,TweenInfo.new(.6,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,0,false),{Transparency = 1})
		--	--				P1:Play()
		--	--			elseif v:IsA('Decal') or v:IsA('Texture') then
		--	--				local P1 = game:GetService("TweenService"):Create(v,TweenInfo.new(.6,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,0,false),{Transparency = 1})
		--	--				P1:Play()
		--	--			elseif v:IsA('PointLight') then
		--	--				game.TweenService:Create(v,TweenInfo.new(.3,Enum.EasingStyle.Cubic,Enum.EasingDirection.InOut,0,false,.95),{Brightness = 0,Range = 0}):Play()
		--	--			end
		--	--		end
		--	--		Debris:AddItem(chrclone,.6)
		--	--		task.wait(.04)
		--	--	end
		--	--end))
		--end)
		local RedF2X24235=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.fireguy:Clone()
		RedF2X24235.Parent = enemy.Torso
		game.Debris:AddItem(RedF2X24235,4.5)
		RedF2X24235:Play()
		local RedF2X24235=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.fireguyscrape:Clone()
		RedF2X24235.Parent = Character.Torso
		game.Debris:AddItem(RedF2X24235,4.5)
		RedF2X24235:Play()
		task.delay(100/60,function()
			if not Character.Values:FindFirstChild("Cant") then return end
			vineta()
			coroutine.resume(coroutine.create(function()
				local effect = ResourceFolder.GroundHit2:Clone()
				effect.Parent = workspace.Ignore.Effects
				game.Debris:AddItem(effect,5)
				local floorInstance = RayCastOnMap((Character.HumanoidRootPart.CFrame*CFrame.new(0,0,-1)).p,Vector3.new(0,-80,0),true)
				if floorInstance then
					local p5=ResourceFolder.wind:Clone()
					Debris:AddItem(p5,.31)
					p5.Parent= workspace.Ignore.Effects
					p5.CFrame= Character.HumanoidRootPart.CFrame * CFrame.new(0,-4,0)
					p5.Orientation =Vector3.new(0, 0, -90)			
					local TweenFX = game:GetService("TweenService"):Create(p5, TweenInfo.new(0.3, Enum.EasingStyle.Sine,Enum.EasingDirection.Out), {Transparency = 1,Size = Vector3.new(0.35, 15.92, 15.92),Position = p5.Position + Vector3.new(0,-1.5,0) , Orientation = Vector3.new(0, 0, -90) })
					TweenFX:Play()
					local LocalCharacter = game.Players.LocalPlayer.Character
					local offset2 = -2.8
					local RootCF = Character.HumanoidRootPart.CFrame * CFrame.new(0,-3.8,0)

					local Module = require(game.ReplicatedStorage.Modules.Util.RockScript)
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
					RootCF = Character.HumanoidRootPart.CFrame * CFrame.new(0,.5,offset2)

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
					RootCF = Character.HumanoidRootPart.CFrame * CFrame.new(0,-3.8,offset2)
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


					if (LocalCharacter:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 35 then
						local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
							Camera.CFrame = Camera.CFrame * shakeCf
						end)
						camShake:ShakeOnce(7, 7, .4,.4)
						--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
						camShake:Start()
					end

					local Params = RaycastParams.new()
					Params.FilterDescendantsInstances =  {workspace.Ignore.Effects}
					Params.FilterType = Enum.RaycastFilterType.Exclude

					local hrp = Character.HumanoidRootPart

					local Directory = ResourceFolder.diablejambelol
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
								v:Emit(v:GetAttribute('EmitCount') or 1)
							end
						end
					end
					emit(Directory5.impact225,false,Character)
					--emit(Directory.impact3DownslamBig,false)
					emit(Directory5.impact3DownslamBig,false,Character)
					effect.Position = floorInstance.Position + Vector3.new(0,0.5,0)
					--effect["ROCKIMPACT1"]:Play()
					--effect["ROCKIMPACT11"]:Play()
					--effect["ROCKIMPACT2"]:Play()
					--effect["ROCKIMPACT22"]:Play()
					for i,v in pairs(effect:GetDescendants()) do
						if v:IsA("ParticleEmitter") then
							v:Emit(v:GetAttribute("EmitCount") or v.Rate)
						end
					end
				end
			end))
		end)
		coroutine.resume(coroutine.create(function()
			while attacking == true do
				if attacking == true then
					vineta()
					emit(Directory5.impact4FrontDashWind2,false,Character)
				end
				wait(.32)
			end
		end))
		emit(Directory5.impact4FrontDashWind2,false,Character)
		coroutine.resume(coroutine.create(function()
			local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
			FX.Parent=Character
			FX.w.Part0= Character['Right Arm']
			game.Debris:AddItem(FX,240/60)
			task.delay(102/60,function()
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
		end))
		coroutine.resume(coroutine.create(function()
			local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
			FX.Parent=Character
			FX.w.Part0= Character['Left Arm']
			game.Debris:AddItem(FX,200/60)
			task.delay(102/60,function()
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
		end))
		coroutine.resume(coroutine.create(function()
			local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
			FX.Parent=Character
			FX.w.Part0= Character['Right Leg']
			game.Debris:AddItem(FX,200/60)
			task.delay(102/60,function()
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
		end))
		coroutine.resume(coroutine.create(function()
			local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
			FX.Parent=Character
			FX.w.Part0= Character['Left Leg']
			game.Debris:AddItem(FX,200/60)
			task.delay(102/60,function()
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
		end))
		task.delay(45/60,function()
			attacking = false
		end)
	end,
	["AWAKENVFX"] = function(Character)
		local Directory = ResourceFolder.diablejambelol
		local Directory2 = ResourceFolder.Parent.Parent["Scarlet Empress"].MiserableMultitude
		local Directory3 = ResourceFolder.Parent.Parent["Scarlet Empress"].AWAKENVFX
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		local sfx1 = ResourceFolder.mokousfx:Clone()
		sfx1.Parent = Character.HumanoidRootPart
		sfx1:Play()
		game.Debris:AddItem(sfx1,16)
		local function vineta()
			if (game.Players.LocalPlayer.Character:WaitForChild('Torso').Position - Character.Torso.Position).Magnitude <= 50 then
				orangevignette()
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(5, 5, .4,.6)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
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
		task.delay(840/60,function()
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
		local enabled2 = true
		task.delay(203/60,function()
			local a = Directory3.amokou2:Clone()
			a.Parent = workspace.Ignore.Effects
			a.CFrame = CFrame.new(Character.Torso.Position)
			for i,v in pairs(a:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						while enabled2 == true do
							wait(1/v.Rate)
							v:Emit(1)
						end
					end
				end))
			end
			for i,v in pairs(a:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
			end
			game.Debris:AddItem(a,6)
			coroutine.resume(coroutine.create(function()
				while enabled2 == true do
					a.CFrame = CFrame.new(Character.Torso.Position)
					wait(.1)
				end
			end))
		end)
		task.delay(548/60,function()
			enabled2 = false
		end)
		local enabled = true
		task.delay(260/60,function()
			local a = Directory3.amokou:Clone()
			a.Parent = workspace.Ignore.Effects
			a.CFrame = CFrame.new(Character.Torso.Position)
			for i,v in pairs(a:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						while enabled == true do
							wait(1/(v.Rate/1.1))
							v:Emit(1)
						end
					end
				end))
			end
			for i,v in pairs(a:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
			end
			game.Debris:AddItem(a,215/60)
			coroutine.resume(coroutine.create(function()
				while enabled == true do
					a.CFrame = CFrame.new(Character.Torso.Position)
					wait()
				end
			end))
		end)
		task.delay(296/60,function()
			enabled = false
			vineta()
			emit(Directory.impact3Downslam25,false)
		end)
		task.delay(15/60,function()
			emit(Directory2.ground11,false)
			local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.emit:Clone()
			xsc52.Parent = Character['HumanoidRootPart']
			game.Debris:AddItem(xsc52,5)
			for i,v in pairs(xsc52:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						v:Emit(v:GetAttribute("EmitCount") or 1)
					end
				end))
			end
		end)
		task.delay(326/60,function()
			emit(Directory.impact3Downslam255,false)
			vineta()
		end)
		task.delay(544/60,function()
			emit(Directory2.ground151,false)
		end)
	end,
	["DESSERTVFXHIT"] = function(Character,Enemy)
		local modelclone2 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].DESSERTVFX
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		local sound1=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.dessertsfx:Clone()
		sound1.Parent = Enemy.Head
		sound1:Play()
		game.Debris:AddItem(sound1,8.5)
		local sound2=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.dessertsfx2:Clone()
		sound2.Parent = Character.Torso
		sound2:Play()
		game.Debris:AddItem(sound2,8.5)
		local tim = .55
		local root = Character.HumanoidRootPart
		task.delay(398/60,function()
			if not Character.Values:FindFirstChild("Cant") then return end
			if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then return end
			emit(Directory.ground11,false,Character)
			local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.emit:Clone()
			xsc52.Parent = Character['HumanoidRootPart']
			game.Debris:AddItem(xsc52,5)
			for i,v in pairs(xsc52:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						v:Emit(v:GetAttribute("EmitCount") or 1)
					end
				end))
			end
			md.rockspawn(root,.37,.37,tim,.046,Vector3.new(-1.3,0,-1.3),true)

			md.rockspawn(root,.37,.37,tim,.07,Vector3.new(-1.9,0,-1.9),false)

			md.rockspawn(root,.32,.32,tim,.07,Vector3.new(1.9,0,1.9))
		end)
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
		task.delay(447/60,function()
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
		task.delay(270/60,function()
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
			if (game.Players.LocalPlayer.Character:WaitForChild('Torso').Position - Character.Torso.Position).Magnitude <= 50 then
				orangevignette()
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(5, 5, .4,.6)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end
		task.delay(352/60,function()
			if game.Players.LocalPlayer.Character == Character then
				wait(.1)
			end
			if game.Players.LocalPlayer.Character == Enemy then
				wait(.1)
			end
			emitsum(modelclone2["fortnitehit"],modelclone2,Character.HumanoidRootPart.CFrame)
			emit(modelclone2["fortnitehithigheremit"],false,Character)
			emit(Directory3["ground1"],false,Character)
		end)
		task.delay(227/60,function()
			emit(Directory3["impact3"],false,Character)
			emitsum(modelclone2["smokepart2"],modelclone2,Character.HumanoidRootPart.CFrame)
		end)
		task.delay(217/60,function()
			emitsum(modelclone2["smallhit"],modelclone2,Character.HumanoidRootPart.CFrame)
			emit(modelclone2["smallhithigheremit"],false,Character)
		end)
		task.delay(169/60,function()
			emitsum(modelclone2["smokepart"],modelclone2,Character.HumanoidRootPart.CFrame)
			vineta()
		end)
		task.delay(262/60,function()
			emitsum(modelclone2["enablekick"],modelclone2,Character.HumanoidRootPart.CFrame)
			emit(Directory3["impact2"],false,Character)
			vineta()
		end)
		task.delay(265/60,function()
			--if (game.Players.LocalPlayer.Character:WaitForChild('Torso').Position - Character.Torso.Position).Magnitude <= 50 then
			--	local vignet = game.ReplicatedStorage.Assets.Vignette:Clone()
			--	vignet.ImageLabel.ImageColor3 = Color3.fromRGB(255, 21, 0)
			--	vignet.Parent = game.Players.LocalPlayer.PlayerGui
			--	game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(8/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = .65}):Play()
			--	task.delay((352-265)/60,function()
			--		game.Debris:AddItem(vignet,14/60)
			--		game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(14/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = 1}):Play()
			--	end)
			--end
			local enabled1 = true
			local modelclone25 = modelclone2["enablekick"]:Clone()
			modelclone25.Parent = workspace.Ignore.Effects
			game.Debris:AddItem(modelclone25,2)
			task.delay((352-265)/60,function()
				enabled1 = false
				modelclone25:Destroy()
			end)
			modelclone25.CFrame = Character.HumanoidRootPart.CFrame * modelclone2["enablekick"].CFrame
			for i,v in pairs(modelclone25:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
			for i,v in pairs(modelclone25:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						while enabled1 == true do
							wait(1/(v.Rate--/2
								))
							modelclone25.CFrame = Character.HumanoidRootPart.CFrame * modelclone2["enablekick"].CFrame
							v:Emit(1)
						end
					end
				end))
			end
		end)
		task.delay(396/60,function()
			local enabled1 = true
			task.delay(.5,function()
				enabled1 = false
			end)
			local modelclone25 = modelclone2["RightLeg"].Attachment:Clone()
			modelclone25.Parent = Character["Right Leg"]
			game.Debris:AddItem(modelclone25,2)
			for i,v in pairs(modelclone25:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						while enabled1 == true do
							wait(1/v.Rate)
							v:Emit(1)
						end
					end
				end))
			end
		end)
		task.delay(128/60,function()
			emitsum(modelclone2["thirdhit"],modelclone2,Character.HumanoidRootPart.CFrame)
			emit(modelclone2["thirdhithigheremit"],false,Character)
			vineta()
		end)
		task.delay(60/60,function()
			emitsum(modelclone2["smokehit"],modelclone2,Character.HumanoidRootPart.CFrame)
			vineta()
		end)
		task.delay(57/60,function()
			emitsum(modelclone2["secondhit"],modelclone2,Character.HumanoidRootPart.CFrame)
			emit(modelclone2["secondhithigheremit"],false,Character)
			vineta()
		end)
		task.delay(4/60,function()
			emitsum(modelclone2["firsthit"],modelclone2,Character.HumanoidRootPart.CFrame)
			emit(Directory3["impact1"],false,Character)
			emit(modelclone2["firsthithigheremit"],false,Character)
			emit(Directory3["impact5"],false,Character)
			vineta()
		end)
	--	task.delay(35/60,function()
	--		--emit(Directory.slash4,false,Character)
	--		emitsum(modelclone2["Slash2 35"],modelclone2,Character.HumanoidRootPart.CFrame)
	--		vineta()
	--	end)
	--	task.delay(60/60,function()
	--		emitsum(modelclone2["Slash3 60"],modelclone2,Character.HumanoidRootPart.CFrame)
	--		emitsum(modelclone2["GroundSlash1 60"],modelclone2,Character.HumanoidRootPart.CFrame)
	--		vineta()
	--	end)
	--	task.delay(84/60,function()
	--		emitsum(modelclone2["Wind2 84"],modelclone2,Character.HumanoidRootPart.CFrame)
	--		emitsum(modelclone2["Spawn 84"],modelclone2,Character.HumanoidRootPart.CFrame)
	--		emitsum(modelclone2["SpawnHit 84"],modelclone2,Character.HumanoidRootPart.CFrame)
	--		vineta()
	--	end)
	--	if Character["Right Arm"]:FindFirstChild("remiliaspear") then
	--		for i ,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants())do
	--			if  v:IsA('Trail') then
	--				if Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad") then
	--					Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("lolazoverdad"):Destroy()
	--				end
	--				local v1 = v:Clone()
	--				v1.Enabled = true
	--				v1.Name = ("lolazoverdad")
	--				v1.Parent =Character["Right Arm"]:FindFirstChild("remiliaspear")
	--				task.delay(350/60,function()
	--					v1.Enabled = false
	--					game.Debris:AddItem(v1,.8)
	--				end)
	--			end
	--		end
	--	end
	--	local enabled1 = true
	--	task.delay(160/60,function()
	--		enabled1 = false
	--	end)
	--	task.delay(110/60,function()
	--		--emitsum(modelclone2["Wind3 110"],modelclone2,Character.HumanoidRootPart.CFrame)
	--		local modelclone25 = modelclone2["Wind3 110"]:Clone()
	--		modelclone25.Parent = workspace.Ignore.Effects
	--		game.Debris:AddItem(modelclone25,8)
	--		modelclone25.CFrame = Character.HumanoidRootPart.CFrame * modelclone2["Wind3 110"].CFrame
	--		for i,v in pairs(modelclone25:GetDescendants()) do
	--			if v:IsA('ParticleEmitter') then
	--				v:Emit(v:GetAttribute('EmitCount') or 1)
	--			end
	--		end
	--		for i,v in pairs(modelclone25:GetDescendants()) do
	--			coroutine.resume(coroutine.create(function()
	--				if v:IsA('ParticleEmitter') then
	--					while enabled1 == true do
	--						wait(1/v.Rate)
	--						v:Emit(5)
	--					end
	--				end
	--			end))
	--		end
	--	end)
	--	task.delay(168/60,function()
	--		emitsum(modelclone2["Slash4 168"],modelclone2,Character.HumanoidRootPart.CFrame)
	--		emitsum(modelclone2["GroundSlash2 168"],modelclone2,Character.HumanoidRootPart.CFrame)
	--		vineta()
	--	end)
	--	task.delay(185/60,function()
	--		emitsum(modelclone2["Slash5 185"],modelclone2,Character.HumanoidRootPart.CFrame)
	--		vineta()
	--	end)
	--	task.delay(210/60,function()
	--		emitsum(modelclone2["Slash6 210"],modelclone2,Character.HumanoidRootPart.CFrame)
	--		vineta()
	--	end)
	--	task.delay(212/60,function()
	--		emitsum(modelclone2["GroundSlash3 212"],modelclone2,Character.HumanoidRootPart.CFrame)
	--	end)
	--	task.delay(237/60,function()
	--		emitsum(modelclone2["Wind 237"],modelclone2,Character.HumanoidRootPart.CFrame)
	--	end)
	--	task.delay(234/60,function()
	--		emitsum(modelclone2["GroundSlash4 246"],modelclone2,Character.HumanoidRootPart.CFrame)
	--		emitsum(modelclone2["Slash7 246"],modelclone2,Character.HumanoidRootPart.CFrame)
	--		vineta()
	--	end)
	--	task.delay(277/60,function()
	--		emitsum(modelclone2["Wind4 277"],modelclone2,Character.HumanoidRootPart.CFrame)
	--	end)
	--	task.delay(315/60,function()
	--		emit(Directory.ground11,false,Character)
	--	end)
	--	task.delay(281/60,function()
	--		emit(Directory.ground22,false,Character)
	--		emitsum(modelclone2["GroundLast 281"],modelclone2,Character.HumanoidRootPart.CFrame)
	--		emitsum(modelclone2["ExplosionLast 281"],modelclone2,Character.HumanoidRootPart.CFrame)
	--		if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 50 then
	--			local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
	--				Camera.CFrame = Camera.CFrame * shakeCf
	--			end)
	--			camShake:ShakeOnce(7, 7, .6,.7)
	--			camShake:Start()
	--		end
	--	end)
	end,
	["SPEEDBLITZVFXLOLZ"] = function(Character)
		--local RedF2X2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.remimoveuppercut:Clone()
		--RedF2X2425.Parent = Character.HumanoidRootPart
		--game.Debris:AddItem(RedF2X2425,4)
		--RedF2X2425:Play()
if Character.Values:FindFirstChild("Stunned") then return end
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
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
		task.delay(104/60,function()
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
		emit(Directory.ground11,false,Character)
		local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.emit:Clone()
		xsc52.Parent = Character['HumanoidRootPart']
		game.Debris:AddItem(xsc52,5)
		for i,v in pairs(xsc52:GetDescendants()) do
			coroutine.resume(coroutine.create(function()
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute("EmitCount") or 1)
				end
			end))
		end
		local attacking = true 
		local function vineta()
			if Character.Values:FindFirstChild("Stunned") then return end
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 50 then
				--local RedF2X24235=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.althit:Clone()
				--RedF2X24235.Parent = Character.Torso
				--game.Debris:AddItem(RedF2X24235,3)
				--RedF2X24235.Volume = .4
				--RedF2X24235.Pitch = (math.random(9, 11) / 10)
				--RedF2X24235:Play()
				--local RedF2X2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.althit2:Clone()
				--RedF2X2425.Parent = Character.Torso
				--game.Debris:AddItem(RedF2X2425,3)
				--RedF2X2425.Volume = .8
				--RedF2X2425.Pitch = (math.random(9, 11) / 10)
				--RedF2X2425:Play()
				orangevignette()
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(3, 3, .3,.4)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end
		local RedF2X24235=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.fireguystartup:Clone()
		RedF2X24235.Parent = Character.Torso
		game.Debris:AddItem(RedF2X24235,4.5)
		RedF2X24235:Play()
		--local RedF2X24252=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.clothsfx15:Clone()
		--RedF2X24252.Parent = Character.Torso
		--game.Debris:AddItem(RedF2X24252,2)
		--RedF2X24252:Play()
		task.delay(52/60,function()
			if Character.Values:FindFirstChild("Stunned") then return end
			coroutine.resume(coroutine.create(function()
				while attacking == true do
					if Character.Values:FindFirstChild("Stunned") then 
						attacking = false
					end
					vineta()
					emit(Directory5.impact4FrontDashWind2,false,Character)
					wait(.3)
				end
			end))
			emit(Directory5.impact4FrontDashWind2,false,Character)
			coroutine.resume(coroutine.create(function()
				--local RedF2X2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.windsfx1:Clone()
				--RedF2X2425.Parent = Character.Torso
				--game.Debris:AddItem(RedF2X2425,2)
				--RedF2X2425:Play()
				--local RedFX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Wind15:Clone()
				--game.Debris:AddItem(RedFX,4)
				--RedFX.Parent = Character.Torso
				--RedFX:Play()
				local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
				FX.Parent=Character
				FX.w.Part0= Character['Right Arm']
				--FX.sfx:Play()
				game.Debris:AddItem(FX,150/60)
				task.delay(80/60,function()
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
			end))
			coroutine.resume(coroutine.create(function()
				local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
				FX.Parent=Character
				FX.w.Part0= Character['Right Leg']
				game.Debris:AddItem(FX,150/60)
				task.delay(80/60,function()
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
			end))
			coroutine.resume(coroutine.create(function()
				local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
				FX.Parent=Character
				FX.w.Part0= Character['Left Leg']
				game.Debris:AddItem(FX,150/60)
				task.delay(80/60,function()
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
			end))
		end)
		--task.delay(55/60,function()
		--	local RedF2X24252=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.abysscswing:Clone()
		--	RedF2X24252.Parent = Character.Torso
		--	game.Debris:AddItem(RedF2X24252,4)
		--	RedF2X24252:Play()
		--end)
		task.delay(106/60,function()
			attacking = false
			--local RedF2X24252=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Wind16:Clone()
			--RedF2X24252.Parent = Character.Torso
			--game.Debris:AddItem(RedF2X24252,2)
			--RedF2X24252:Play()
			--local RedF2X24252=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.windsfx1:Clone()
			--RedF2X24252.Parent = Character.Torso
			--game.Debris:AddItem(RedF2X24252,2)
			--RedF2X24252:Play()
			if Character.Values:FindFirstChild("Stunned") then return end
			emit(Directory5.impact5,false,Character)
		end)
	end,
	["DESSERTVFXLOLZ"] = function(Character)
		--local RedF2X2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.remimoveuppercut:Clone()
		--RedF2X2425.Parent = Character.HumanoidRootPart
		--game.Debris:AddItem(RedF2X2425,4)
		--RedF2X2425:Play()
		if Character:FindFirstChild("COUNTERED") then return end
		if Character.Values:FindFirstChild("Stunned") then return end
		local RedF2X24235=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.fireconter:Clone()
		RedF2X24235.Parent = Character.Torso
		RedF2X24235:Play()
		game.Debris:AddItem(RedF2X24235,2)
		local Directory = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].MiserableMultitude
		local Directory2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].AWAKENVFX
		local Directory5 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local function emit(instance,weld,characterc)
			if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then return end
			if Character:FindFirstChild("COUNTERED") then return end
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		local function emit2(instance,weld,enable)
			if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then return end
			if Character:FindFirstChild("COUNTERED") then return end
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
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
		task.delay(104/60,function()
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
		if Character:FindFirstChild("COUNTERED") then return end
		emit(Directory5.impact3Downslam25,false,Character)
		--emit(Directory.ground11,false,Character)
		local attacking = true 
		local function vineta()
			if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then return end
			if Character.Values:FindFirstChild("Stunned") then return end
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 50 then
				--local RedF2X24235=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.althit:Clone()
				--RedF2X24235.Parent = Character.Torso
				--game.Debris:AddItem(RedF2X24235,3)
				--RedF2X24235.Volume = .4
				--RedF2X24235.Pitch = (math.random(9, 11) / 10)
				--RedF2X24235:Play()
				--local RedF2X2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.althit2:Clone()
				--RedF2X2425.Parent = Character.Torso
				--game.Debris:AddItem(RedF2X2425,3)
				--RedF2X2425.Volume = .8
				--RedF2X2425.Pitch = (math.random(9, 11) / 10)
				--RedF2X2425:Play()
				orangevignette()
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(3, 3, .3,.4)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end
		--local tim = .25
		--local root = Character.HumanoidRootPart
		--task.delay(398/60,function()
		--	if not Character.Values:FindFirstChild("Cant") then return end
		--	if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then return end
		--	emit(Directory.ground11,false,Character)

		--	md.rockspawn(root,.37,.37,tim,.046,Vector3.new(-1.3,0,-1.3),true)

		--	md.rockspawn(root,.37,.37,tim,.046,Vector3.new(1.3,0,1.3))

		--	md.rockspawn(root,.37,.37,tim,.07,Vector3.new(-1.9,0,-1.9),false)

		--	md.rockspawn(root,.32,.32,tim,.07,Vector3.new(1.9,0,1.9))
		--end)
		--local RedF2X24252=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.clothsfx15:Clone()
		--RedF2X24252.Parent = Character.Torso
		--game.Debris:AddItem(RedF2X24252,2)
		--RedF2X24252:Play()
		task.delay(102/60,function()
			if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then return end
			if Character:FindFirstChild("COUNTERED") then return end
			if Character.Values:FindFirstChild("Stunned") then return end
			local RedF2X24235=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.firecounterslide:Clone()
			RedF2X24235.Parent = Character.Torso
			game.Debris:AddItem(RedF2X24235,4.5)
			RedF2X24235:Play()
			coroutine.resume(coroutine.create(function()
				while attacking == true do
					if Character.Values:FindFirstChild("Stunned") then 
						attacking = false
					end
					vineta()
					emit(Directory5.impact4FrontDashWind2,false,Character)
					wait(.3)
				end
			end))
			emit(Directory5.impact4FrontDashWind2,false,Character)
			--coroutine.resume(coroutine.create(function()
			--	--local RedF2X2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.windsfx1:Clone()
			--	--RedF2X2425.Parent = Character.Torso
			--	--game.Debris:AddItem(RedF2X2425,2)
			--	--RedF2X2425:Play()
			--	--local RedFX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Wind15:Clone()
			--	--game.Debris:AddItem(RedFX,4)
			--	--RedFX.Parent = Character.Torso
			--	--RedFX:Play()
			--	local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
			--	FX.Parent=Character
			--	FX.w.Part0= Character['Right Arm']
			--	--FX.sfx:Play()
			--	game.Debris:AddItem(FX,150/60)
			--	task.delay(80/60,function()
			--		for i ,v in pairs(FX:GetDescendants())do
			--			if v:IsA('Trail') then
			--				v.Enabled = false
			--			end
			--			if v:IsA('ParticleEmitter') then
			--				v.Enabled = false
			--			end
			--			if v:IsA("PointLight") then
			--				game:GetService("TweenService"):Create(v, TweenInfo.new(.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Range = 0}):Play()
			--			end
			--		end
			--	end)
			--end))
			coroutine.resume(coroutine.create(function()
				local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
				FX.Parent=Character
				FX.w.Part0= Character['Right Arn']
				game.Debris:AddItem(FX,150/60)
				task.delay((186-109)/60,function()
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
			end))
			--coroutine.resume(coroutine.create(function()
			--	local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
			--	FX.Parent=Character
			--	FX.w.Part0= Character['Left Leg']
			--	game.Debris:AddItem(FX,150/60)
			--	task.delay(80/60,function()
			--		for i ,v in pairs(FX:GetDescendants())do
			--			if v:IsA('Trail') then
			--				v.Enabled = false
			--			end
			--			if v:IsA('ParticleEmitter') then
			--				v.Enabled = false
			--			end
			--			if v:IsA("PointLight") then
			--				game:GetService("TweenService"):Create(v, TweenInfo.new(.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Range = 0}):Play()
			--			end
			--		end
			--	end)
			--end))
		end)
		--task.delay(55/60,function()
		--	local RedF2X24252=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.abysscswing:Clone()
		--	RedF2X24252.Parent = Character.Torso
		--	game.Debris:AddItem(RedF2X24252,4)
		--	RedF2X24252:Play()
		--end)
		task.delay(149/60,function()
			attacking = false
			--local RedF2X24252=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Wind16:Clone()
			--RedF2X24252.Parent = Character.Torso
			--game.Debris:AddItem(RedF2X24252,2)
			--RedF2X24252:Play()
			--local RedF2X24252=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.windsfx1:Clone()
			--RedF2X24252.Parent = Character.Torso
			--game.Debris:AddItem(RedF2X24252,2)
			--RedF2X24252:Play()
			if Character:FindFirstChild("COUNTERED") then return end
			if Character.Values:FindFirstChild("Stunned") then return end
			emit(Directory5.impact5,false,Character)
		end)
	end,
	["dropkkick"] = function(Character)
		local Directory = ResourceFolder.diablejambelol
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		emit(Directory.impact535,false)
		emit(Directory.impact5,false)
	end,
	["BURNING1"] = function(Character)
		if Character:FindFirstChild("Burning") then
			local highlightname = ("BurningHighlight")
			local highlight = script.Parent[highlightname]:Clone()
			highlight.Parent = Character
			game:GetService("TweenService"):Create(highlight, TweenInfo.new(.6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 1.3,OutlineTransparency = .9}):Play()
			local RedFX251 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MilleniumSmoke.Attachment:Clone()
			RedFX251.Parent = Character.Torso
			local RedFX251515 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MilleniumSmoke.Attachment1:Clone()
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
			--coroutine.resume(coroutine.create(function()
			--	wait(.6)
			--	if enabled == false then return end
			--	while enabled == true do
			--		if enabled == false then break end
			--		game:GetService("TweenService"):Create(highlight, TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 2}):Play()
			--		wait(2)	
			--		if enabled == false then break end
			--		game:GetService("TweenService"):Create(highlight, TweenInfo.new(2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {FillTransparency = 1.4}):Play()
			--		if enabled == false then break end
			--		wait(2)	
			--		if enabled == false then break end
			--	end
			--end))
			local namae = ("AURALOOPSFXMOKOU")
			local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat[namae]:Clone()
			sound1.Parent = Character.Torso
			sound1:Play()
			game:GetService("TweenService"):Create(sound1,TweenInfo.new(.5,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 1}):Play()
			local conn1
			conn1 = Character:FindFirstChild("Burning").Destroying:Connect(function()
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
	["FEATHERVFXTA"] = function(Character)
		local Directory = ResourceFolder.diablejambelol
		local RedFX2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.fireburn:Clone()
		RedFX2425.Parent = Character.HumanoidRootPart
		game.Debris:AddItem(RedFX2425,5)
		RedFX2425:Play()
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
		FX.Parent=Character
		FX.w.Part0= Character['Right Arm']
		game.Debris:AddItem(FX,3)
		local enabled = true
		for i,v in pairs(FX:GetDescendants()) do
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
		task.delay(.3,function()
			enabled = false
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
		task.delay(10/60,function()
			emit(Directory.mokouburst,false)
			if (game.Players.LocalPlayer.Character:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 20 then
				orangevignette()
				local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
					Camera.CFrame = Camera.CFrame * shakeCf
				end)
				camShake:ShakeOnce(3, 3, .3,.4)
				--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
				camShake:Start()
			end
		end)
		--local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.LastM1.Ground:Clone()
		--RedFX15.Parent = Character.HumanoidRootPart
		--game.Debris:AddItem(RedFX15,5)
		--for i,v in pairs(RedFX15:GetDescendants()) do
		--	if v:IsA('ParticleEmitter') then
		--		v:Emit(v:GetAttribute('EmitCount') or 1)
		--	end
		--end
	end,
	["FEATHERVFX"] = function(Character)
		local RedFX2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.firethrow:Clone()
		RedFX2425.Parent = Character.HumanoidRootPart
		game.Debris:AddItem(RedFX2425,5)
		RedFX2425:Play()
		local Directory = ResourceFolder.diablejambelol
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
		FX.Parent=Character
		FX.w.Part0= Character['Right Arm']
		game.Debris:AddItem(FX,3)
		local enabled = true
		for i,v in pairs(FX:GetDescendants()) do
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
		task.delay(.4,function()
			enabled = false
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
		--local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.LastM1.Ground:Clone()
		--RedFX15.Parent = Character.HumanoidRootPart
		--game.Debris:AddItem(RedFX15,5)
		--for i,v in pairs(RedFX15:GetDescendants()) do
		--	if v:IsA('ParticleEmitter') then
		--		v:Emit(v:GetAttribute('EmitCount') or 1)
		--	end
		--end
	end,
	["LASTM1VFX"] = function(Character)
		local Directory = ResourceFolder.diablejambelol
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		emit(Directory.impact5,false)
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
	["M1TRAILRIGHT"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
		FX.Parent=Character
		FX.w.Part0= Character['Right Leg']
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
	end,
	["M1TRAILLEFT"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
		FX.Parent=Character
		FX.w.Part0= Character['Left Leg']
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
	end,
	["BambooExplode"] = function(ProjectilePart)
		local LocalCharacter = game.Players.LocalPlayer.Character
		--ProjectilePart.CFrame = ProjectilePart.CFrame
		coroutine.resume(coroutine.create(function()
			for i = 1,10 do
				Basemd.SmashTile(ProjectilePart.CFrame * CFrame.new(math.random(-10,10),0,math.random(-10,10)))
				Basemd.SmashTrees(ProjectilePart.CFrame * CFrame.new(math.random(-10,10),0,math.random(-10,10)))
				--task.wait(.1)
			end
		end))
		ProjectilePart.sfx:Play()
		ProjectilePart.sfx2:Play()
		ProjectilePart.sfx3:Play()
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
			for i,v in pairs(ProjectilePart.EXPLODE:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Destroy()
				end
			end
		else
			for i,v in pairs(ProjectilePart.EXPLODE:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == false then
		if (LocalCharacter:WaitForChild('HumanoidRootPart').Position - ProjectilePart.Position).Magnitude <= 35 then
			local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
				Camera.CFrame = Camera.CFrame * shakeCf
			end)
			camShake:ShakeOnce(6, 6, .4,.4)
			--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
			camShake:Start()
		end
end
		--ProjectilePart.Anchored = true

	end,

	['SpecialWind'] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].SpecVFX.Attachment:Clone()
		RedFX15.Parent = Character.HumanoidRootPart
		game.Debris:AddItem(RedFX15,2)
		for i,v in pairs(RedFX15:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				v:Emit(v:GetAttribute('EmitCount') or 1)
			end
		end
	end,
	["cutscenesecondmovefirstult"] = function(Character, Combo)
		--enable
		task.delay(144/60,function()
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouCutsceneSecondMoveFirstUltVFX["Spinn"]:Clone()
			RedFX15.Parent = Character["Torso"]
			game.Debris:AddItem(RedFX15,10)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v.Enabled = true
				end
			end
			task.delay((211/60)-(144/60),function()
				for i,v in pairs(RedFX15:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v.Enabled = false
					end
				end
			end)
		end)

		task.delay(233/60,function()
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouCutsceneSecondMoveFirstUltVFX["Spinn2"]:Clone()
			RedFX15.Parent = Character["Torso"]
			game.Debris:AddItem(RedFX15,10)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v.Enabled = true
				end
			end
			task.delay((305/60)-(233/60),function()
				for i,v in pairs(RedFX15:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v.Enabled = false
					end
				end
			end)
		end)
		--emit
		local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouCutsceneSecondMoveFirstUltVFX["1"]:Clone()
		RedFX15.Parent = Character["HumanoidRootPart"]
		game.Debris:AddItem(RedFX15,10)
		for i,v in pairs(RedFX15:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				v:Emit(v:GetAttribute('EmitCount') or 1)
			end
		end
		task.delay(45/60,function()
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouCutsceneSecondMoveFirstUltVFX["2"]:Clone()
			RedFX15.Parent = Character["HumanoidRootPart"]
			game.Debris:AddItem(RedFX15,10)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end)
		task.delay(100/60,function()
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouCutsceneSecondMoveFirstUltVFX["2.5"]:Clone()
			RedFX15.Parent = Character["HumanoidRootPart"]
			game.Debris:AddItem(RedFX15,10)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end)
		task.delay(107/60,function()
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouCutsceneSecondMoveFirstUltVFX["3"]:Clone()
			RedFX15.Parent = Character["HumanoidRootPart"]
			game.Debris:AddItem(RedFX15,10)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end)
		task.delay(216/60,function()
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouCutsceneSecondMoveFirstUltVFX["4"]:Clone()
			RedFX15.Parent = Character["HumanoidRootPart"]
			game.Debris:AddItem(RedFX15,10)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end)
		task.delay(327/60,function()
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouCutsceneSecondMoveFirstUltVFX["5"]:Clone()
			RedFX15.Parent = Character["HumanoidRootPart"]
			game.Debris:AddItem(RedFX15,10)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end)
		task.delay(47/60,function()
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouCutsceneSecondMoveFirstUltVFX["gc1"]:Clone()
			RedFX15.Parent = Character["HumanoidRootPart"]
			game.Debris:AddItem(RedFX15,10)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end)
		task.delay(225/60,function()
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouCutsceneSecondMoveFirstUltVFX["gc2"]:Clone()
			RedFX15.Parent = Character["HumanoidRootPart"]
			game.Debris:AddItem(RedFX15,10)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end)
	end,
	["SKILL1GRABVFX"] = function(Character,Enemy)
		local Directory = ResourceFolder.diablejambelol
		local RedFX2425=ResourceFolder.airbeatdownsfx:Clone()
		RedFX2425.Parent = Character.Torso
		game.Debris:AddItem(RedFX2425,5)
		RedFX2425:Play()
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		local function hookvfx(limb)
			--local RedFX152 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX["MokouBarrageVFX"]:Clone()
			--RedFX152.Parent = Character[limb]
			--game.Debris:AddItem(RedFX152,1.5)
			--for i,v in pairs(RedFX152:GetDescendants()) do
			--	if v:IsA('ParticleEmitter') then
			--		if v.Enabled == true then
			--			v.Enabled = false
			--		end
			--		v:Emit(v:GetAttribute("EmitCount") or 2)
			--	end
			--end
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.MokouRightVFX:Clone()
			RedFX15.Parent = Character[limb]
			game.Debris:AddItem(RedFX15,1.5)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 2)
				end
			end
		end
		local function hit()
			local RedFX=ResourceFolder.Hit.VFX:Clone()
			RedFX.Parent=Enemy[mathrandomlimb[math.random(1,6)]]

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
						v:Emit(v:GetAttribute('EmitCount') or 1)
					end
				end
			end
		end
		task.delay(9/60,function()
			hookvfx("Left Leg")
		end)
		task.delay(45/60,function()
			hookvfx("Right Leg")
		end)
		task.delay(77/60,function()
			hookvfx("Right Leg")
			emit(Directory.impact5Downslam,false)
		end)
		task.delay(9/60,function()
			hit()
		end)
		task.delay(33/60,function()
			hit()
		end)
		task.delay(70/60,function()
			hit()
		end)
		task.delay(72/60,function()
			hit()
		end)
		local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
		FX.Parent=Character
		FX.w.Part0= Character['Left Leg']
		game.Debris:AddItem(FX,15)
		local FX2= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
		FX2.Parent=Character
		FX2.w.Part0= Character['Right Leg']
		game.Debris:AddItem(FX2,15)
		task.delay((95/60),function()
			game.Debris:AddItem(FX,1)
			for i ,v in pairs(FX:GetDescendants())do
				if  v:IsA('Trail') then
					v.Enabled = false
				end
				if  v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
			end
			game.Debris:AddItem(FX2,1)
			for i ,v in pairs(FX2:GetDescendants())do
				if  v:IsA('Trail') then
					v.Enabled = false
				end
				if  v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
			end
		end)
	end,
	["mokourightvfx"] = function(Character, Combo)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		--local RedFX152 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX["MokouBarrageVFX"]:Clone()
		--RedFX152.Parent = Character['Right Leg']
		--game.Debris:AddItem(RedFX152,1.5)
		--for i,v in pairs(RedFX152:GetDescendants()) do
		--	if v:IsA('ParticleEmitter') then
		--		if v.Enabled == true then
		--			v.Enabled = false
		--		end
		--		v:Emit(v:GetAttribute("EmitCount") or 2)
		--	end
		--end
		local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.MokouRightVFX:Clone()
		RedFX15.Parent = Character['Right Leg']
		game.Debris:AddItem(RedFX15,1.5)
		for i,v in pairs(RedFX15:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				v:Emit(v:GetAttribute('EmitCount') or 1)
			end
		end
	end,
	["mokouleftvfx"] = function(Character, Combo)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		--local RedFX152 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX["MokouBarrageVFX"]:Clone()
		--RedFX152.Parent = Character['Left Leg']
		--game.Debris:AddItem(RedFX152,1.5)
		--for i,v in pairs(RedFX152:GetDescendants()) do
		--	if v:IsA('ParticleEmitter') then
		--		if v.Enabled == true then
		--			v.Enabled = false
		--		end
		--		v:Emit(v:GetAttribute("EmitCount") or 2)
		--	end
		--end
		local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.MokouRightVFX:Clone()
		RedFX15.Parent = Character['Left Leg']
		game.Debris:AddItem(RedFX15,1.5)
		for i,v in pairs(RedFX15:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				v:Emit(v:GetAttribute('EmitCount') or 1)
			end
		end
	end,
	["groundcrack2"] = function(Character, Combo)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local Directory = ResourceFolder.diablejambelol
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		emit(Directory.impact3Downslam,false)
		local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX["GroundCrack2"]:Clone()
		RedFX15.Parent = Character['HumanoidRootPart']
		game.Debris:AddItem(RedFX15,6)
		for i,v in pairs(RedFX15:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				v:Emit(v:GetAttribute('EmitCount') or 1)
			end
		end
	end,
	["groundcrack"] = function(Character, Combo)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local Directory = ResourceFolder.diablejambelol
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		emit(Directory.impact3Downslam,false)
		local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX["GroundCrack"]:Clone()
		RedFX15.Parent = Character['HumanoidRootPart']
		game.Debris:AddItem(RedFX15,6)
		for i,v in pairs(RedFX15:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				v:Emit(v:GetAttribute('EmitCount') or 1)
			end
		end
	end,
	["bigexplode"] = function(Character, Combo)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local Directory = ResourceFolder.diablejambelol
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		emit(Directory.impact5,false)
		--local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX["BigExplode"]:Clone()
		--RedFX15.Parent = Character['HumanoidRootPart']
		--game.Debris:AddItem(RedFX15,6)
		--for i,v in pairs(RedFX15:GetDescendants()) do
		--	if v:IsA('ParticleEmitter') then
		--		v:Emit(v:GetAttribute('EmitCount') or 1)
		--	end
		--end
	end,
	["DOWNCUT"] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end

		local Directory = ResourceFolder.diablejambelol
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		emit(Directory.impact5Downslam,false)
	end,
	["mokoubarragevfx2"] = function(Character, Combo)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX["MokouBarrageVFX"]:Clone()
		RedFX15.Parent = Character['Right Leg']
		game.Debris:AddItem(RedFX15,6)
		local RedFX152 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX["MokouBarrageVFX"]:Clone()
		RedFX152.Parent = Character['Left Leg']
		game.Debris:AddItem(RedFX152,6)
		local enabled = true
		coroutine.resume(coroutine.create(function()
			for i,v in pairs(RedFX152:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') and (v.Enabled == true) then
						while enabled == true do
							wait(1/v.Rate)
							v:Emit(1)
						end
					end
				end))
			end
		end))
		coroutine.resume(coroutine.create(function()
			for i,v in pairs(RedFX15:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') and (v.Enabled == true) then
						while enabled == true do
							wait(1/v.Rate)
							v:Emit(1)
						end
					end
				end))
			end
		end))
		for i,v in pairs(RedFX152:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				if v.Enabled == true then
					v.Enabled = false
				end
			end
		end
		for i,v in pairs(RedFX15:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				if v.Enabled == true then
					v.Enabled = false
				end
			end
		end
		task.delay((153/60)-(95/60),function()
enabled = false
		end)
	end,
	["mokoubarragevfx"] = function(Character, Combo)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX["MokouBarrageVFX"]:Clone()
		RedFX15.Parent = Character['Right Leg']
		game.Debris:AddItem(RedFX15,6)
		local enabled = true
		coroutine.resume(coroutine.create(function()
			for i,v in pairs(RedFX15:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') and (v.Enabled == true) then
						while enabled == true do
							wait(1/v.Rate)
							v:Emit(1)
						end
					end
				end))
			end
		end))
		for i,v in pairs(RedFX15:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				if v.Enabled == true then
					v.Enabled = false
				end
			end
		end
		task.delay((129/60)-(86/60),function()
enabled = false
		end)
	end,
	["Swing"] = function(Character, Combo)
		local ResourceFolder2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat
		local RedFX=ResourceFolder.Sfx.Swings['s'..Combo]:Clone() 
		Debris:AddItem(RedFX,2)
		RedFX.Parent = Character.HumanoidRootPart
		RedFX:Play()
		local Re15d1FX=ResourceFolder2["movesound"]:Clone() 
		Debris:AddItem(Re15d1FX,3)
		Re15d1FX.PlaybackSpeed = Random.new():NextNumber(1,1.25)
		Re15d1FX.Volume = .8
		Re15d1FX.Parent = Character.Torso
		Re15d1FX:Play()

		local Re15d15FX=ResourceFolder2["movesound5"]:Clone() 
		Debris:AddItem(Re15d15FX,3)
		Re15d15FX.Volume = .35
		Re15d15FX.Parent = Character.Torso
		Re15d15FX:Play()

		local Re15d151FX=ResourceFolder2["movesound51"]:Clone() 
		Debris:AddItem(Re15d151FX,3)
		Re15d151FX.PlaybackSpeed = Random.new():NextNumber(1,1.25)
		Re15d151FX.Volume = .2
		Re15d151FX.Parent = Character.Torso
		Re15d151FX:Play()
		if Combo == 1 then
			--local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
			--FX.Parent=Character
			--FX.w.Part0= Character['Right Leg']
			--game.Debris:AddItem(FX,3)
			--local enabled = true
			--for i,v in pairs(FX:GetDescendants()) do
			--	coroutine.resume(coroutine.create(function()
			--		if v:IsA('ParticleEmitter') and v.Enabled == true then
			--			v.Enabled = false
			--			local rate = v.Rate
			--			if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
			--				rate = v.Rate / 5
			--			end
			--			wait(1/rate)
			--			v:Emit(1)
			--		end
			--	end))
			--end
			local enablooru5 = true
			task.delay(9/60,function()
				enablooru5 = false
			end)
			--task.delay(4/60,function()
				local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.TP2:Clone()
				game.Debris:AddItem(xsc52,5)
				xsc52.Parent = Character['Right Leg']
				for i,v in pairs(xsc52:GetChildren()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA('ParticleEmitter') then
							v.Enabled = false
							while enablooru5 == true do
								wait(1/v.Rate)
								v:Emit(1)
							end
						end
					end))
				end
			--end)
			--task.delay(.4,function()
			--	enabled = false
			--	for i ,v in pairs(FX:GetDescendants())do
			--		if v:IsA('Trail') then
			--			v.Enabled = false
			--		end
			--		if v:IsA('ParticleEmitter') then
			--			v.Enabled = false
			--		end
			--		if v:IsA("PointLight") then
			--			game:GetService("TweenService"):Create(v, TweenInfo.new(.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Range = 0}):Play()
			--		end
			--	end
			--end)
		end
		if Combo == 2 then
			local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
			FX.Parent=Character
			FX.w.Part0= Character['Right Arm']
			game.Debris:AddItem(FX,3)
			local enabled = true
			for i,v in pairs(FX:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						if v.Enabled == true then
							v.Enabled = false
							while enabled == true do
								local rate = (v.Rate*1.2)
								if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
									rate = v.Rate / 5
								end
								wait(1/rate)
								v:Emit(1)
							end
						end
					end
				end))
			end
			task.delay(2/60,function()
				local RedFX25=ResourceFolder["ROCKIMPACT155"]:Clone() 
				Debris:AddItem(RedFX25,2)
				RedFX25.Parent = Character["Right Leg"]
				RedFX25.Volume = .6
				RedFX25:Play()
			end)
			task.delay(5/60,function()
				local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.step:Clone()
				xsc52.Parent = Character['Right Leg']
				game.Debris:AddItem(xsc52,5)
				for i,v in pairs(xsc52:GetDescendants()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA('ParticleEmitter') then
							v:Emit(v:GetAttribute("EmitCount") or 1)
						end
					end))
				end
			end)
			local enablooru5 = true
			task.delay(14/60,function()
				enablooru5 = false
			end)
			--task.delay(3/60,function()
			local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.TP2:Clone()
			game.Debris:AddItem(xsc52,5)
			xsc52.Parent = Character['Right Arm']
			for i,v in pairs(xsc52:GetChildren()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						v.Enabled = false
						while enablooru5 == true do
							wait(1/v.Rate)
							v:Emit(1)
						end
					end
				end))
			end
			--end)
			task.delay(.3,function()
				enabled = false
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
		if Combo == 3 then
			local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
			FX.Parent=Character
			FX.w.Part0= Character['Left Arm']
			game.Debris:AddItem(FX,3)
			local enabled = true
			for i,v in pairs(FX:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						if v.Enabled == true then
							v.Enabled = false
							while enabled == true do
								local rate = (v.Rate*1.2)
								if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
									rate = v.Rate / 5
								end
								wait(1/rate)
								v:Emit(1)
							end
						end
					end
				end))
			end
			task.delay(7/60,function()
					for i,v in pairs(FX.Flare:GetDescendants()) do
						coroutine.resume(coroutine.create(function()
							if v:IsA('ParticleEmitter') then
								v:Emit(v:GetAttribute("EmitRate") or 1)
							end
						end))
					end
				local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.MokouRightVFX:Clone()
				RedFX15.Parent = Character['Left Arm']
				game.Debris:AddItem(RedFX15,6)
				for i,v in pairs(RedFX15:GetDescendants()) do
					if v:IsA('ParticleEmitter') then
						v:Emit(v:GetAttribute('EmitCount') or 1)
					end
				end
			end)
			local enablooru5 = true
			task.delay(13/60,function()
				enablooru5 = false
			end)
			--task.delay(3/60,function()
			local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.TP2:Clone()
			game.Debris:AddItem(xsc52,5)
			xsc52.Parent = Character['Right Arm']
			for i,v in pairs(xsc52:GetChildren()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						v.Enabled = false
						while enablooru5 == true do
							wait(1/v.Rate)
							v:Emit(1)
						end
					end
				end))
			end
			--end)
			task.delay(.25,function()
				enabled = false
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
		if Combo == 4 then
			local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
			FX.Parent=Character
			FX.w.Part0= Character['Left Leg']
			game.Debris:AddItem(FX,3)
			local enabled = true
			for i,v in pairs(FX:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						if v.Enabled == true then
							v.Enabled = false
							while enabled == true do
								local rate = (v.Rate*1.2)
								if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
									rate = v.Rate / 5
								end
								wait(1/rate)
								v:Emit(1)
							end
						end
					end
				end))
			end
			task.delay(6/60,function()
				local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.step:Clone()
				xsc52.Parent = Character['Right Leg']
				game.Debris:AddItem(xsc52,5)
				for i,v in pairs(xsc52:GetDescendants()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA('ParticleEmitter') then
							v:Emit(v:GetAttribute("EmitCount") or 1)
						end
					end))
				end
			end)
			task.delay(15/60,function()
				for i,v in pairs(FX.Flare:GetDescendants()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA('ParticleEmitter') then
							v:Emit(v:GetAttribute("EmitRate") or 1)
						end
					end))
				end
			end)
			local enablooru5 = true
			task.delay(14/60,function()
				enablooru5 = false
			end)
			--task.delay(3/60,function()
			local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.TP2:Clone()
			game.Debris:AddItem(xsc52,5)
			xsc52.Parent = Character['Left Leg']
			for i,v in pairs(xsc52:GetChildren()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						v.Enabled = false
						while enablooru5 == true do
							wait(1/v.Rate)
							v:Emit(1)
						end
					end
				end))
			end
			--end)
			task.delay(.3,function()
				enabled = false
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
		if Combo == 5 then

		end
	end,	
	["SwingMissed"] = function(Character, Combo)

	end,
	["HitNOSFX"] = function(Character, Enemy, Combo)

		local RedFX=ResourceFolder.Hit.VFX:Clone()
		RedFX.Parent=Enemy[mathrandomlimb[math.random(1,6)]]

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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end

	end,
	["HitSFX"] = function(Character, Enemy, Combo)

		local RedFX=ResourceFolder.Hit.VFX:Clone()
		RedFX.Parent=Enemy[mathrandomlimb[math.random(1,6)]]
		RedFX['h'..Combo]:Play()

		Debris:AddItem(RedFX,2)
			for i,v in pairs(RedFX:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Destroy()
				end
			end

	end,
	["HitBlue"] = function(Character, Enemy, Combo)

		local RedFX=ResourceFolder.HitBlue.VFX:Clone()
		RedFX.Parent=Enemy[mathrandomlimb[math.random(1,6)]]
		if Combo ~= nil then
			RedFX['h'..Combo]:Play()
		end
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end

	end,
	["Hit"] = function(Character, Enemy, Combo)

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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end

	end,
	["HittaliciousMaximus"] = function(Character, Enemy, Combo)

		local RedFX=ResourceFolder.HitaliciousClawsximus.VFX:Clone()
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end

	end,
	["Hit2"] = function(Character, Enemy, Combo)
		local RedFX=ResourceFolder.HitSecond.VFX:Clone()
		RedFX.Parent=Enemy[mathrandomlimb[math.random(1,6)]]
		--RedFX['h1']:Destroy()
		--RedFX['h2']:Destroy()

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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
	end,
	["Block"] = function(Character, Enemy, Combo)

	end,

	["DownSlamWindUp"] = function(Character)
		local modelclone2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].UppercutMoveVFX
		local ResourceFolder2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat
		--local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.TP:Clone()
		--xsc52.Parent = Character['Right Leg']
		--game.Debris:AddItem(xsc52,5)
		--for i,v in pairs(xsc52:GetDescendants()) do
		--	coroutine.resume(coroutine.create(function()
		--		if v:IsA('ParticleEmitter') then
		--			v:Emit(v:GetAttribute("EmitCount") or 1)
		--		end
		--	end))
		--end
		task.delay(3/60,function()
			local RedFX=game.ReplicatedStorage.Assets.VFX.uppercutswing:Clone()
			game.Debris:AddItem(RedFX,4)
			RedFX.Parent = Character.HumanoidRootPart
			RedFX:Play()
			local RedFX=ResourceFolder2["movesound"]:Clone() 
			Debris:AddItem(RedFX,2)
			RedFX.Parent = Character["Right Leg"]
			RedFX.PlaybackSpeed = Random.new():NextNumber(.9,1.1)
			RedFX.Volume = .35
			RedFX:Play()
		end)
		local RedFX5=ResourceFolder2["movesound5"]:Clone() 
		Debris:AddItem(RedFX5,2)
		RedFX5.Parent = Character["Right Leg"]
		RedFX5.PlaybackSpeed = Random.new():NextNumber(.9,1.1)
		RedFX5.Volume = .24
		RedFX5:Play()
		local FX2= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
		FX2.Parent=Character
		FX2.w.Part0= Character['Right Leg']
		local enabled = true
		for i,v in pairs(FX2:GetDescendants()) do
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
		local enablooru5 = true
		task.delay(17/60,function()
			enablooru5 = false
		end)
		local xsc52 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.TP2:Clone()
		game.Debris:AddItem(xsc52,5)
		xsc52.Parent = Character['Right Leg']
		for i,v in pairs(xsc52:GetChildren()) do
			coroutine.resume(coroutine.create(function()
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
					while enablooru5 == true do
						wait(1/v.Rate)
						v:Emit(1)
					end
				end
			end))
		end
		task.delay(28/60,function()
			enabled = false
			if FX2 ~= nil then
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

		local Directory = ResourceFolder.diablejambelol
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		task.delay(14/60,function()
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouBarrageVFX.MokouRightVFX:Clone()
			RedFX15.Parent = Character['Right Leg']
			game.Debris:AddItem(RedFX15,6)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
			for i,v in pairs(FX2.Flare:GetDescendants()) do
				coroutine.resume(coroutine.create(function()
					if v:IsA('ParticleEmitter') then
						v:Emit(v:GetAttribute("EmitRate") or 1)
					end
				end))
			end
			emit(Directory.impact5Downslam,false)
		end)
	end,
	["SmashWhenGround"] = function(Enemy,Length)
		task.wait(.4)
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

					local Basemd = require(game.ReplicatedStorage.Modules.Util.baseassets)

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

					local SizeX = 1.6
					local SizeY = 1.6
					local SizeZ = 1.6
					local CollideAfter = .5
					local Spread = 20

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


					local SizeX = 3.4
					local SizeY = 4
					local SizeZ = 4.2
					local Tilt = 25
					-- Ground spawn --
					local Distance = 1.5

					local NumberOfRocks = 5
					Module.RockSpawn2(RootCF, NumberOfRocks, SizeX, SizeY, SizeZ, Distance,CollectAfter,HeightOffset,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true) --inside and smal;er
					RootCF = RootCF * CFrame.Angles(0,math.rad(90),0)

					Module.RockSpawn2(RootCF, NumberOfRocks, SizeX/1.2, SizeY/1.2, SizeZ/1.2, Distance+4,CollectAfter,HeightOffset,Tilt+40,CollectLength+.3,AppearTime,HowMuchDown,HowMuchDownCollect,true)

					local SizeX = 3.4
					local SizeY = 4
					local SizeZ = 4.5
					local Tilt = 28
					-- Ground spawn --
					local Distance = 4

					local NumberOfRocks = 3
					Module.RockSpawn2(RootCF, NumberOfRocks, SizeX, SizeY, SizeZ, Distance,CollectAfter,HeightOffset,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true) --inside and smal;er
					RootCF = RootCF * CFrame.Angles(0,math.rad(90),0)

					Module.RockSpawn2(RootCF, NumberOfRocks, SizeX/1.2, SizeY/1.2, SizeZ/1.2, Distance+4,CollectAfter,HeightOffset,Tilt+40,CollectLength+.3,AppearTime,HowMuchDown,HowMuchDownCollect,true)

					local CollectLength =9
					local Distance = 6
					local Params = RaycastParams.new()
					Params.FilterDescendantsInstances =  {workspace.Ignore.Effects}
					Params.FilterType = Enum.RaycastFilterType.Exclude

					local VictimRootPart = Enemy.HumanoidRootPart
					coroutine.resume(coroutine.create(function()
						local effect = ResourceFolder.GroundHit2:Clone()
						effect.Parent = workspace.Ignore.Effects
						game.Debris:AddItem(effect,5)
						effect["ROCKIMPACT22"]:Play()
						local Sound = effect["ROCKIMPACT2"]:Clone()
						Sound.Parent = VictimRootPart
						Sound:Play()
						local floorInstance = RayCastOnMap((Enemy.HumanoidRootPart.CFrame*CFrame.new(0,0,0)).p,Vector3.new(0,-80,0),true)
						if floorInstance then
							effect.Position = floorInstance.Position + Vector3.new(0,0.5,0)
							for i,v in pairs(effect.GroundBounce:GetChildren()) do
								if v:IsA("ParticleEmitter") then
									v:Emit(v:GetAttribute("EmitCount") or v.Rate)
								end
							end
						end
					end))
					break
				end
			end

			task.wait()
		end

	end,
	['DownSlam'] = function(Character,Enemy)

		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local RootCF = CFrame.new(Enemy.HumanoidRootPart.Position + Vector3.new(0,2,0))
		local Module = require(game.ReplicatedStorage.Modules.Util.RockScript)
		local Basemd = require(game.ReplicatedStorage.Modules.Util.baseassets)

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

		--local p5=ResourceFolder.wind:Clone()
		--Debris:AddItem(p5,.31)
		--p5.Parent= workspace.Ignore.Effects
		--p5.CFrame= RootCF * CFrame.new(0,-1.2,0)
		--p5.Orientation =Vector3.new(0, 0, -90)			
		--local TweenFX = game:GetService("TweenService"):Create(p5, TweenInfo.new(0.3, Enum.EasingStyle.Sine,Enum.EasingDirection.Out), {Transparency = 1,Size = Vector3.new(0.35, 15.92, 15.92),Position = p5.Position + Vector3.new(0,-1.5,0) , Orientation = Vector3.new(0, 0, -90) })
		--TweenFX:Play()

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
						v:Emit(v:GetAttribute("EmitCount") or v.Rate)
					end
				end
			end
		end))

	end,
	["Impact25"] = function(Character)
		local Directory = ResourceFolder.diablejambelol
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = Character.HumanoidRootPart.CFrame-- * instance.CFrame
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		emit(Directory.impact3Downslam,false)
	end,
	['DownSlam2'] = function(Character,Enemy)
		local LocalCharacter = game.Players.LocalPlayer.Character
		local offset2 = -2.8
		local RootCF = Character.HumanoidRootPart.CFrame * CFrame.new(0,-3.8,-1)

		local Module = require(game.ReplicatedStorage.Modules.Util.RockScript)
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
		RootCF = Character.HumanoidRootPart.CFrame * CFrame.new(0,.5,offset2)

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
		RootCF = Character.HumanoidRootPart.CFrame * CFrame.new(0,-3.8,offset2)
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


		if (LocalCharacter:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 35 then
			local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
				Camera.CFrame = Camera.CFrame * shakeCf
			end)
			camShake:ShakeOnce(7, 7, .4,.4)
			--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
			camShake:Start()
		end

		local Params = RaycastParams.new()
		Params.FilterDescendantsInstances =  {workspace.Ignore.Effects}
		Params.FilterType = Enum.RaycastFilterType.Exclude

		local hrp = Character.HumanoidRootPart
		local VictimRootPart = Enemy.HumanoidRootPart

		local Directory = ResourceFolder.diablejambelol
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		emit(Directory.impact3Downslam,false)
		coroutine.resume(coroutine.create(function()
			local effect = ResourceFolder.GroundHit2:Clone()
			effect.Parent = workspace.Ignore.Effects
			game.Debris:AddItem(effect,5)
			effect["ROCKIMPACT11"]:Play()
			local Sound = effect["ROCKIMPACT1"]:Clone()
			Sound.Parent = VictimRootPart
			Sound:Play()
			local floorInstance = RayCastOnMap((Character.HumanoidRootPart.CFrame*CFrame.new(0,0,-1)).p,Vector3.new(0,-80,0),true)
			if floorInstance then
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
				effect.Position = floorInstance.Position + Vector3.new(0,0.5,0)
				for i,v in pairs(effect:GetDescendants()) do
					if v:IsA("ParticleEmitter") then
						v:Emit(v:GetAttribute("EmitCount") or v.Rate)
					end
				end
			end
		end))

	end,
	['heartbreakland'] = function(Character,Enemy)


		--local RootCF = CFrame.new(Enemy.Position)
		--RootCF = RootCF * CFrame.Angles(0,0,math.rad(90))
		--local Module = require(game.ReplicatedStorage.Modules.Util.RockScript)
		--local Basemd = require(game.ReplicatedStorage.Modules.Util.baseassets)

		--local AppearTime = .17
		--local Tilt = 25
		--local Distance = 7
		--local CollectAfter = 4.5
		--local CollectLength = 7
		--local HeightOffset = -2
		--local HowMuchDown = -5 --how below the ground it is when it appears
		--local HowMuchDownCollect = -10 --how below the ground it goes 
		--local HowMuchUp = 15
		--local DownRayLength = -20
		--local NumberOfRocks =5 
		----Module.RockSpawn1(script.Parent, NumberOfRocks, SizeX, SizeY, SizeZ, Distance)
		----	Module.RockSpawn2(RootCF , NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset-1.8,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --inside and smal;er
		----Module.RockSpawn2(RootCF, NumberOfRocks , SizeX, SizeY, SizeZ, Distance+.7,CollectAfter,HeightOffset-2.1,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --outside and bigger

		---- Rock Flying ==
		--local Height = 100

		--local SizeX = .5
		--local SizeY = .5
		--local SizeZ = .5
		--local CollideAfter = .5
		--local Spread = 30

		--Module.RockFlying(RootCF , Height, SizeX, SizeY, SizeZ, NumberOfRocks-3,CollideAfter,Spread)
		--local SizeX = 1
		--local SizeY = 1
		--local SizeZ = 1
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
		--local Tilt = 34
		---- Ground spawn --
		--local Distance = 2

		--local NumberOfRocks = 5
		--Module.RockSpawn2(RootCF, NumberOfRocks, SizeX, SizeY, SizeZ, Distance,CollectAfter,HeightOffset,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true) --inside and smal;er

		--local CollectLength =9
		--local Distance = 6
		----.RockSpawn2(RootCF, NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset+.15,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,true)

	end,
	['outline'] = function(Character,Enemy)
		for i,v in pairs(Enemy:GetDescendants()) do
			if v.Name == ("Highlight") then
				v.Enabled = true
			end
		end
	end
}
