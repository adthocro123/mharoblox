local Debris = game:GetService("Debris")
local ResourceFolder = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat
return {
	["Swing"] = function(Character, Combo)

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
				v:Emit(v:GetAttribute("EmitCount") or 1)
			end
		end
	end,
	
	["Block"] = function(Character, Enemy)
		
	end,
}
