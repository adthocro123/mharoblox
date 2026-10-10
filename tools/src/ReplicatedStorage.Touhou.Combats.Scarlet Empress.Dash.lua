local md = require(game.ReplicatedStorage.Modules.Util.baseassets)
local Debris = game:GetService("Debris")
local ResourceFolder = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat
local Camera = workspace.CurrentCamera
local CameraShaker=require(game.ReplicatedStorage.Modules.Util.shaker)
local FXFolder = workspace.Ignore.Effects
local TS = game:GetService("TweenService")
local dashLimbs = game.ReplicatedStorage.Assets.VFX:WaitForChild("dash_limbs")
local dashSmoke = game.ReplicatedStorage.Assets.VFX:WaitForChild("dash_smoke")
return {
	["DashM1Miss"] = function(Character)
		--local Folder = game.ReplicatedStorage.Assets.VFX.Combat
		--local  RedFX= Folder.DashMiss:Clone()
		--RedFX.Parent=FXFolder
		--RedFX.CFrame= Character.HumanoidRootPart.CFrame  * CFrame.new(0,-2.4,0)
		--Debris:AddItem(RedFX,5)
		--RedFX.sfx:Play()

		--for i,v in pairs(RedFX:GetDescendants()) do
		--	if v:IsA('ParticleEmitter') then
		--		v:Emit(v:GetAttribute('EmitCount'))
		--	end
		--end
	end,
	

	["DashM1Close"] = function(Character, Enemy)
		local EnemyRoot = Enemy.HumanoidRootPart
		local Folder = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat
		local tim = .5
		local  RedFX= Folder.Hit:Clone()
		RedFX.Parent=FXFolder
		RedFX.CFrame= Enemy.HumanoidRootPart.CFrame 
		Debris:AddItem(RedFX,5)
		RedFX.VFX.h1:Play()

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
					v:Emit((v:GetAttribute("EmitCount") or v.Rate) * 1.4)
				end
			end
		end
		
		local p5=ResourceFolder.Parent["Scarlet Empress"].Combat.wind:Clone()
		Debris:AddItem(p5,.31)
		p5.Parent= workspace.Ignore.Effects
		p5.CFrame= Character.HumanoidRootPart.CFrame * CFrame.new(0,-1.2,0) * CFrame.Angles(0,math.rad(90),0)

		local TweenFX = game:GetService("TweenService"):Create(p5, TweenInfo.new(0.3, Enum.EasingStyle.Sine,Enum.EasingDirection.Out), {Transparency = 1,Size = Vector3.new(0.15, 15.92, 15.92) })
		TweenFX:Play()
		task.wait(.1)
		md.rockspawn(EnemyRoot,.53,.63,tim,.15,Vector3.new(-2.25,0,0),true)

		md.rockspawn(EnemyRoot,.53,.63,tim,.15,Vector3.new(2.25,0,0),true)
		
	

	end,

	["DashM1Far"] = function(Character, Enemy)
		local Folder = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat
		local  RedFX= Folder.Hit:Clone()
		RedFX.Parent=FXFolder
		RedFX.CFrame= Enemy.HumanoidRootPart.CFrame 
		Debris:AddItem(RedFX,5)
		RedFX.VFX.h1:Play()

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
					v:Emit((v:GetAttribute("EmitCount") or v.Rate) * 1.4)
				end
			end
		end

	end,

	["DashM1Swing"] = function(Character)
		coroutine.resume(coroutine.create(function()
			wait(.07)
			local RedFX=ResourceFolder.Sfx.Swings['s3']:Clone() 
			Debris:AddItem(RedFX,2)
			RedFX.Parent = Character.HumanoidRootPart
			RedFX:Play()
			--local attacking = true
			--task.delay(3,function()
			--	attacking = false
			--end)
			--local Folder = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat
			--local RedFX= Folder["claw1"]:Clone()
			--RedFX.Parent=game.Workspace.Ignore.Effects
			--RedFX.CFrame= Character.HumanoidRootPart.CFrame  * CFrame.new(0,1,-2.4)
			--game.Debris:AddItem(RedFX,5)
			--coroutine.resume(coroutine.create(function()
			--	while attacking == true do
			--		wait()
			--		RedFX.CFrame= Character.HumanoidRootPart.CFrame  * CFrame.new(0,1,-2.4)
			--	end
			--end))
			--for i,v in pairs(RedFX:GetDescendants()) do
			--	if v:IsA('ParticleEmitter') then
			--		v:Emit(v:GetAttribute('EmitCount'))
			--	end
			--end

		end))
	end,
	
	["Start"] = function(Character,Side)
		local root = Character.HumanoidRootPart
		local tim = .2
		local FX
		-- Put fx here
		--dashtypes are Front, Back, Right Left
		if Side == 'Back' then
tim = 1
			md.rockspawn(root,.37,.37,tim,.046,Vector3.new(-1.3,0,-1.3),true)

			md.rockspawn(root,.37,.37,tim,.046,Vector3.new(1.3,0,1.3))

			md.rockspawn(root,.37,.37,tim,.07,Vector3.new(-1.9,0,-1.9),false)

			md.rockspawn(root,.32,.32,tim,.07,Vector3.new(1.9,0,1.9))

			md.rockspawn(root,.5,.5,tim,.15,Vector3.new(-2.25,0,0),true)

			md.rockspawn(root,.5,.5,tim,.15,Vector3.new(2.25,0,0),true)
		elseif Side == 'Front' then
			local Directory = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
			local function emit(instance,weld,enable)
				local instanceclone = instance:Clone()
				instanceclone.CFrame = Character.HumanoidRootPart.CFrame * instance.CFrame
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
							v:Emit((v:GetAttribute('EmitCount')) or 1)
						end
					end
				end
			end
			emit(Directory.impact4FrontDashWindREMI,false)
			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].WindFX.Attachment:Clone()
			RedFX15.Parent =Character.HumanoidRootPart
			game.Debris:AddItem(RedFX15,5)
			for i,v in pairs(RedFX15:GetDescendants()) do
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
			if Character:FindFirstChild("gunganire").Value == true then
				if Character["Right Arm"]:FindFirstChild("remiliaspear") then
					for i ,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants())do
						if  v:IsA('Trail') then
							local v1 = v:Clone()
							v1.Enabled = true
							v1.Parent =Character["Right Arm"]:FindFirstChild("remiliaspear")
							task.delay(.6,function()
								v1.Enabled = false
								game.Debris:AddItem(v1,.5)
							end)
						end
					end
				end
			end
			FX= ResourceFolder.DashTrail:Clone()
			for i ,v in pairs(FX:GetDescendants())do
				if  v:IsA('Trail') then
					v.Enabled = false
				end
				if  v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
			end
			FX.Parent=Character
			FX.w.Part0= Character['Right Arm']
			FX.sfx:Play()
			FX.sfx2:Play()
			FX.sfx3:Play()
			Debris:AddItem(FX,4)


			md.makering(root.CFrame,Vector3.new(0, 6, 6),Vector3.new(0,90,0))
			tim = .6

			md.rockspawn(root,.37,.37,tim,.046,Vector3.new(-1.3,0,-1.3),true)

			md.rockspawn(root,.37,.37,tim,.046,Vector3.new(1.3,0,1.3))

			md.rockspawn(root,.37,.37,tim,.07,Vector3.new(-1.9,0,-1.9),false)

			md.rockspawn(root,.32,.32,tim,.07,Vector3.new(1.9,0,1.9))

		elseif Side == 'Left' then
			md.rockspawn(root,.37,.37,tim,.046,Vector3.new(-1.3,0,-1.3),true)

			md.rockspawn(root,.37,.37,tim,.046,Vector3.new(1.3,0,1.3))

			md.rockspawn(root,.37,.37,tim,.07,Vector3.new(-1.9,0,-1.9),false)

			md.rockspawn(root,.32,.32,tim,.07,Vector3.new(1.9,0,1.9))
		elseif Side == 'Right' then

			md.rockspawn(root,.37,.37,tim,.046,Vector3.new(-1.3,0,-1.3),true)

			md.rockspawn(root,.37,.37,tim,.046,Vector3.new(1.3,0,1.3))

			md.rockspawn(root,.37,.37,tim,.07,Vector3.new(-1.9,0,-1.9),false)

			md.rockspawn(root,.32,.32,tim,.07,Vector3.new(1.9,0,1.9))
			--	Part,MinimumSize,MaxSize,Time,TimeToWait,PosInCFrame,HasParticle)
		end
		local enabled_trails
		--if Side ~= ("Front") then
		if (Side == 'Front') or (Side == 'Back') then
			coroutine.resume(coroutine.create(function()
				local limbs = {"Left Arm", "Right Arm", "Right Leg", "Left Leg"}
				enabled_trails = {}
				for _,l in limbs do
					if Character[l]:FindFirstChild("dash0") then
						for _,thing in Character[l]:GetChildren() do
							if thing:IsA("Trail") and string.find(thing.Name, "dash") then
								thing.Enabled = true
								table.insert(enabled_trails, thing)
							end
						end
					else
						local dash_vfx = dashLimbs:Clone():GetChildren()
						for _,p in dash_vfx do
							p.Parent = Character[l]
							if p:IsA("Trail") then
								p.Enabled = true
								table.insert(enabled_trails, p)
							end
						end
					end
				end
			end))
		end
			if Character.Humanoid:GetState() == Enum.HumanoidStateType.Running then
				if not Character.HumanoidRootPart:FindFirstChild("dust") then
					local smoke = dashSmoke.dust:Clone()
					smoke.Parent = Character.HumanoidRootPart
				end
				for _,part in Character.HumanoidRootPart.dust:GetChildren() do
					part.Enabled = true
				end
			end
		--end
		task.wait(tim)
		if (Side == 'Front') or (Side == 'Back') then
			if enabled_trails then
			for _,e in enabled_trails do
				e.Enabled = false
			end
		end
end
		task.spawn(function()
			for _,part in Character.HumanoidRootPart.dust:GetChildren() do
				part.Enabled = false
			end
		end)
		task.delay(.7,function()
			if Side == ("Front") then
				if Character["Right Arm"]:FindFirstChild("remiliaspear") then
					if not Character:FindFirstChild("m1ing") then
						for i ,v in pairs(Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants())do
							if  v:IsA('Trail') then
								v.Enabled = false
							end
						end
					end
				end
			end
			if FX ~= nil then
				for i ,v in pairs(FX:GetDescendants())do
					if  v:IsA('Trail') then
						v.Enabled = false
					end
					if  v:IsA('ParticleEmitter') then
						v.Enabled = false
					end
				end
			end
end)
	end
}
