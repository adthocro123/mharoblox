local Debris = game:GetService("Debris")
local ResourceFolder = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Smash
local Camera = workspace.CurrentCamera
local CameraShaker=require(game.ReplicatedStorage.Modules.Util.shaker)
local TS = game:GetService("TweenService")
local FXFolder = workspace.Ignore.Effects
local md = require(game.ReplicatedStorage.Modules.Util.baseassets)

return {
	['Run'] = function(character)
		local oldCancel = character:GetAttribute("Cancel")

		local hp = character.HumanoidRootPart
		local timeInRun = .57
		local speed = 77

		local velocity = Instance.new('BodyVelocity')
		local functionToDisconnect = nil
		local bool = false

		task.delay(timeInRun,function()
			if functionToDisconnect then functionToDisconnect:Disconnect() velocity:Destroy() end
		end)

		for _,v in pairs(hp:GetChildren())  do
			if v:IsA('BodyVelocity') then v:Destroy() end
		end

		velocity.MaxForce = Vector3.new(50000,0,50000)
		velocity.Velocity = hp.CFrame.LookVector * speed
		velocity.Parent = hp

		game.TweenService:Create(velocity,TweenInfo.new(.3,Enum.EasingStyle.Cubic,Enum.EasingDirection.InOut,0,false,timeInRun-.5),{MaxForce = Vector3.new(0,0,0)}):Play()

		functionToDisconnect = game["Run Service"].Heartbeat:Connect(function()
			if character:GetAttribute('Cancel') ~= oldCancel or character.Humanoid.Health <= 0 then
				velocity:Destroy()
				functionToDisconnect:Disconnect()
			end
			if velocity and not bool and hp then
				velocity.Velocity = hp.CFrame.LookVector * speed
			end	
		end)
		
		local rockTime = .2
		
		md.rockspawnfast(hp,.5,.9,rockTime,.02,Vector3.new(-2.25,0,0),true)

		md.rockspawnfast(hp,.5,.9,rockTime,.02,Vector3.new(2.25,0,0),true)
		--
		md.rockspawnfast(hp,.4,.7,rockTime,.01,Vector3.new(-1.65,0,0),false)

		md.rockspawnfast(hp,.4,.7,rockTime,.001,Vector3.new(1.65,0,0),false)
	end,
	
	['Victim'] = function(Enemy)
		local ParticleTable = {}
		local ResourceFolder = ResourceFolder.Parent.Combat
		for i,v in pairs(ResourceFolder.particles:GetChildren()) do
			if v:IsA("ParticleEmitter") then

				local v = v:Clone()
				v.Parent = Enemy['Torso']

				table.insert(ParticleTable,v)

				game.Debris:AddItem(v,3)		

			end						
		end

		for i,v in pairs(ResourceFolder.particles:GetChildren()) do
			if v:IsA("ParticleEmitter") then

				local v = v:Clone()
				v.Parent = Enemy['Head']

				table.insert(ParticleTable,v)

				game.Debris:AddItem(v,3)		

			end						
		end
		task.delay(.66,function()
			for i,v in pairs(ParticleTable) do
				v.Enabled = false
			end
		end)
		
	end,
	["Startup"] = function(Character)


		local RedFX=ResourceFolder.Smash:Clone()
		RedFX.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-2)
		Debris:AddItem(RedFX,2.6)
		RedFX.Parent = FXFolder
		RedFX.Dash.sfx:Play()
		for i,v in pairs(RedFX.Dash:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				v:Emit(v:GetAttribute('EmitCount'))
			end
		end
		
		
		local RedFX=ResourceFolder.SmashBig:Clone()
		RedFX.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-6)
		Debris:AddItem(RedFX,2.6)
		RedFX.Parent = FXFolder
		for i,v in pairs(RedFX.Dash:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				v:Emit(v:GetAttribute('EmitCount'))
			end
		end
		
	end,
	
	["Smash"] = function(Character, Offset)
		local LocalCharacter = game.Players.LocalPlayer.Character
		local RootCF = Character.HumanoidRootPart.CFrame * CFrame.new(0,-1,-3.4)
		local Module = require(game.ReplicatedStorage.Modules.Util.RockScript)
		local Basemd = require(game.ReplicatedStorage.Modules.Util.baseassets)

		coroutine.resume(coroutine.create(function()
			for i = 1,10 do
				Basemd.SmashTile(RootCF * CFrame.new(math.random(-10,10),0,math.random(-10,10)))
				Basemd.SmashTrees(RootCF * CFrame.new(math.random(-10,10),0,math.random(-10,10)))
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
		local Distance = 3

		local NumberOfRocks = 8
		RootCF = RootCF * CFrame.Angles(0,math.rad(40),0)
		Module.RockSpawn2(RootCF, NumberOfRocks, SizeX, SizeY, SizeZ, Distance,CollectAfter,HeightOffset,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect) --inside and smal;er
		local NumberOfRocks = 6
		RootCF = RootCF * CFrame.Angles(0,math.rad(60),0)
		local CollectLength =9
		local Distance = 1
		local Tilt = 34
		Module.RockSpawn2(RootCF, NumberOfRocks, SizeX/1.3, SizeY, SizeZ, Distance,CollectAfter,HeightOffset+.15,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect)

		local AppearTime = .17
		local Tilt = 25
		local Distance = 5
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

		local RedFX=ResourceFolder.Smash:Clone()
		RedFX.CFrame = Character.HumanoidRootPart.CFrame * CFrame.new(0,-2.9,-3)
		Debris:AddItem(RedFX,14)
		RedFX.Parent = FXFolder
		RedFX.sfx:Play()
		RedFX.sfx2:Play()
		for i,v in pairs(RedFX:GetDescendants()) do
			if v:IsA('ParticleEmitter') then
				v:Emit(v:GetAttribute('EmitCount'))
			end
		end
		
		if (LocalCharacter:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 35 then
			local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
				Camera.CFrame = Camera.CFrame * shakeCf
			end)
			camShake:ShakeOnce(7, 7, .4,.4)
			--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
			camShake:Start()
		end
		

		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = {workspace.Map}


	end,
	
	["Hit"] = function(Character, Enemy)
		
	end,
}
