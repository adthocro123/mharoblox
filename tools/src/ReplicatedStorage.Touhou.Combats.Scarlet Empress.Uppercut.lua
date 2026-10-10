local Debris = game:GetService("Debris")
local ResourceFolder = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat
return {
	["Swing"] = function(Character, Combo)
		task.delay(1/60,function()
			local RedFX=game.ReplicatedStorage.Assets.VFX.uppercutswing:Clone()
			game.Debris:AddItem(RedFX,4)
			RedFX.Parent = Character.HumanoidRootPart
			RedFX:Play()
			local RedFX=ResourceFolder["movesound"]:Clone() 
			Debris:AddItem(RedFX,2)
			RedFX.Parent = Character["Left Arm"]
			RedFX.PlaybackSpeed = Random.new():NextNumber(.9,1.1)
			RedFX.Volume = .35
			RedFX:Play()
		end)
		local RedFX5=ResourceFolder["movesound5"]:Clone() 
		Debris:AddItem(RedFX5,2)
		RedFX5.Parent = Character["Left Arm"]
		RedFX5.PlaybackSpeed = Random.new():NextNumber(.9,1.1)
		RedFX5.Volume = .24
		RedFX5:Play()
		local FX2= game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.DashTrail3:Clone()
		FX2.Parent=Character
		FX2.w.Part0= Character['Left Arm']
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
	
	["Hit"] = function(Character, Enemy)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end
		local RedFX=ResourceFolder.UpperCut:Clone()	
		RedFX.sfx:Play()
		RedFX.sfx2:Play()
		RedFX.sfx3:Play()
		RedFX.CFrame = Enemy.Head.CFrame
		RedFX.Orientation = Vector3.new(0,0,0)
		Debris:AddItem(RedFX,1.6)
		RedFX.Parent= workspace.Ignore.Effects
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
				v:Emit(v:GetAttribute("EmitCount") or 1)
			end
		end
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
	end,
	
	["Block"] = function(Character, Enemy)
		
	end,
}
