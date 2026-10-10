local Debris = game:GetService("Debris")
local ResourceFolder = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"]["Heart Break"]
local Camera = workspace.CurrentCamera
local CameraShaker=require(game.ReplicatedStorage.Modules.Util.shaker)
local TS = game:GetService("TweenService")
local FXFolder = workspace.Ignore.Effects
local Basemd = require(game.ReplicatedStorage.Modules.Util.baseassets)

return {

	["Cast"] = function(Character,projectilecframe)
		local LocalCharacter = game.Players.LocalPlayer.Character
		local Directory = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.diablejambelol
		local function emit(instance,weld,enable)
			local instanceclone = instance:Clone()
			instanceclone.CFrame = projectilecframe * instance.CFrame
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
						modelclone:SetPrimaryPartCFrame(projectilecframe * v.Start.CFrame)
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
					v:Emit(v:GetAttribute('EmitCount') or 1)
				end
			end
		end
		emit(Directory.impact5REMI,false)
		emit(Directory.impact5REMIVAMPIREton,false)
		local RedFX=ResourceFolder.Emit:Clone()
		RedFX.CFrame = projectilecframe * CFrame.new(1.2,0,4)
		Debris:AddItem(RedFX,2.6)
		RedFX.Parent = FXFolder
		RedFX.sfx:Play()
		RedFX.sfx2:Play()
		RedFX.sfx3:Play()
		RedFX.CanQuery = false
		RedFX.CanCollide = false

		local p5=ResourceFolder.Parent.Parent["Scarlet Empress"].Combat.wind2:Clone()
		Debris:AddItem(p5,.31)
		p5.Parent= workspace.Ignore.Effects
		p5.CFrame=  projectilecframe * CFrame.new(1.2,.4,-4) * CFrame.Angles(0,math.rad(90),0)

		local TweenFX = game:GetService("TweenService"):Create(p5, TweenInfo.new(0.3, Enum.EasingStyle.Sine,Enum.EasingDirection.Out), {Transparency = 1,Size = Vector3.new(0.15, 15.92, 15.92) })
		TweenFX:Play()
		if (LocalCharacter:WaitForChild('HumanoidRootPart').Position - Character.HumanoidRootPart.Position).Magnitude <= 1 then
			local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value, function(shakeCf)
				Camera.CFrame = Camera.CFrame * shakeCf
			end)
			camShake:ShakeOnce(6, 6, .4,.4)
			--magnitude, roughness , fadeInTime, fadeOutTime, posInfluence, rotInfluence
			camShake:Start()
		end

	end,
	
}
