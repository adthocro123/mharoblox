local Special = {}
Special.Settings = {
	Cooldown = 15,
	--Damage = .6,--same damage as saitama consecutive punches (really op)
	Damage = 7,
	AttackLength = 79/60,

	HitboxSettings = {
		DelayTime = 0,
		Debris = .2,

		Offset = CFrame.new(0,0,-2.5),
		Size = Vector3.new(10,15,17)
	},
	HitboxSettings2 = {
		DelayTime = 0,
		Debris = .1,

		Offset = CFrame.new(0,0,0),
		Size = Vector3.new(30, 30, 30)
	},
}
local ResourceFolder = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"]
function Special:CreateHitbox(callback)
	self:bindClassToAttack(self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = self.Character.HumanoidRootPart,
		Offset = self.Settings.HitboxSettings.Offset,
		Size = self.Settings.HitboxSettings.Size,
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = false,
		IgnoresBlock = true,
		Visualize = false,
		DelayTime = self.Settings.HitboxSettings.DelayTime,
		Debris = self.Settings.HitboxSettings.Debris,
	}, callback))
end
local GetLocalCharPosition = require(game.ServerStorage.Touhou.Bridge).GetLocalCharPosition

function Special:TagEnemy(Enemy,Projectile)
	if Enemy:GetAttribute("Ragdoll") then
		self.Knit.GetService("DamageService"):Damage({

			Character = self.Character,
			Enemy = Enemy,

			KnockbackData = {
				KnockbackType = "ShortKnockback",
				--MaxForce = Vector3.new(100000,0,100000),
				VelocityOrigin = Projectile, 
				Velocity = 4, 
				VelocityUp = 2, 
				--Time = .25,
			} ,

			--RagdollData = isClose and {
			--	Time = 1,
			--},
			StateData = {
				Stunned = 1,
				--AutoRotate = 1,
			},
			--KnockbackData = isClose and {
			--	KnockbackType = "VelocityTweenDown",
			--	MaxForce = Vector3.new(50000000,0,50000000),
			--	Velocity = self.Character.HumanoidRootPart.CFrame.LookVector*(isClose and 35 or 7),
			--	Time = .2,
			--	TweenLength = .7
			--},

			--StateData = {
			--	Stunned = 1,
			--	AutoRotate = 1,
			--},

			MovementData = {
				WalkSpeed = 0,
				JumpPower = 0,
				Time = 1,
			},

			BlockData = {			
				HitterOrigin = Projectile.CFrame,
			},

			Damage = 5,
			--ReactionAnim = isClose and game.ReplicatedStorage.Assets.Animations.Reactions.DashM1Reaction or isflying and game.ReplicatedStorage.Assets.Animations.ReactionsFlying["Reaction"..math.random(1,4)] or (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),
			EnemyFacesCharacter = true,
		},function(State)		
			if State == "Hit" then
				self.Hit = true
			elseif State == "Block" then
			end
		end)
	else
		self.Knit.GetService("DamageService"):Damage({

			Character = self.Character,
			Enemy = Enemy,
			KnockbackData = {
				KnockbackType = "Velocity",
				MaxForce = Vector3.new(20000,20000,20000),
				Velocity = ((Enemy.HumanoidRootPart.CFrame.Position - Projectile.CFrame.Position).Unit *(70)) + Vector3.new(0,5,0), 
				Time = .2,
			},
			RagdollData =  {
				Time = 1.7,
			},
			StateData = {
				Stunned = 1.7,
				AutoRotate = 1.7,
			},
			--KnockbackData = isClose and {
			--	KnockbackType = "VelocityTweenDown",
			--	MaxForce = Vector3.new(50000000,0,50000000),
			--	Velocity = self.Character.HumanoidRootPart.CFrame.LookVector*(isClose and 35 or 7),
			--	Time = .2,
			--	TweenLength = .7
			--},

			--StateData = {
			--	Stunned = 1,
			--	AutoRotate = 1,
			--},

			MovementData = {
				WalkSpeed = 0,
				JumpPower = 0,
				Time = 1.7,
			},

			BlockData = {			
				HitterOrigin = self.Character.HumanoidRootPart.CFrame,
			},

			Damage = 8,
			ReactionAnim = (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),
			--EnemyFacesCharacter = true,
		},function(State)		
			if State == "Hit" then
				self.Hit = true
			elseif State == "Block" then
				task.delay(.1,function()
					if not self.Character:FindFirstChild("m1ing") then
						--self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
					end
				end)
				self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Miss", self.Character)
				local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
				task.delay(.7,function()
					if Cant ~= nil then
						Cant:Destroy()
					end
				end)
				local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 0), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
				--local time1 = .1
				--if Arg1 == "Front" or Arg1 == 'Back' then
				--	time1 == 1 
				--end
				task.delay(.6,function()
					if Jump ~= nil then
						Jump:Destroy()
					end
					if Speed ~= nil then
						Speed:Destroy()
					end
				end)
			end
		end)
	end
end
function Special:TagEnemy2(Enemy,Anim)
	coroutine.resume(coroutine.create(function()
		if not self.Character:FindFirstChild("canhitSpecial") then return end
		if self.Cancelled then return end
		if Enemy.Values:FindFirstChild("IFrames") then return end

		if not Enemy:FindFirstChild("hitwithtecatocamokou") then
			self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
			local buffvalue = Instance.new("BoolValue",Enemy)
			buffvalue.Value = true
			buffvalue.Name = ("hitwithtecatocamokou")
			game.Debris:AddItem(buffvalue,2.8)
			local StunVal = self.Knit.GetService("StateService"):CreateStun(Enemy)
			local victimanim = self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Special.Victim)
			victimanim.TimePosition = (Anim.TimePosition - (26/60))
			StunVal:SetAttribute("MokouBaseSpecialFireTalonStunUnability",true)
			local grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,0,-0.1)*CFrame.Angles(0,math.rad(180),0))
			--self.Knit.GetService("RagdollService"):unragdoll(self.Character, true,true)
			task.delay(2.8,function()
				for _, v in pairs(self.Character.HumanoidRootPart:GetDescendants()) do
					coroutine.resume(coroutine.create(function()
						if v.Name == ("GrabWeld") then
							v:Destroy()
						end
					end))
				end
			end)
			repeat wait()

			until not self.Character.HumanoidRootPart:FindFirstChild("GrabWeld")
			--networkOwner = Enemy

			--if game.Players:GetPlayerFromCharacter(Enemy) then			
			--	networkOwner = game.Players:GetPlayerFromCharacter(Enemy)			
			--end
			--Enemy.HumanoidRootPart:SetNetworkOwner(networkOwner)

			if grab ~= nil then
				grab:Destroy()
			end
			local pos = GetLocalCharPosition:InvokeClient(game.Players:GetPlayerFromCharacter(self.Character))
			--if (self.Character.HumanoidRootPart.Position-Vector3.new(pos)).magnitude >= 20 then
			--local pos = self.Character.HumanoidRootPart.CFrame
			--end
			Enemy.HumanoidRootPart.CFrame = (pos * (CFrame.new(0,0,-5)*CFrame.Angles(0,math.rad(180),0)))
			--task.delay(.15,function()
			self.Knit.GetService("DamageService"):Damage({

				Character = self.Character,
				Enemy = Enemy,

				KnockbackData = {
					KnockbackType = "ShortKnockback",
					--MaxForce = Vector3.new(100000,0,100000),
					VelocityOrigin = self.Character.HumanoidRootPart, 
					Velocity = 5, 
					VelocityUp = 4, 
					--Time = .25,
				} ,

				--RagdollData = isClose and {
				--	Time = 1,
				--},
				StateData = {
					Stunned = 1,
					--AutoRotate = 1,
				},
				--KnockbackData = isClose and {
				--	KnockbackType = "VelocityTweenDown",
				--	MaxForce = Vector3.new(50000000,0,50000000),
				--	Velocity = self.Character.HumanoidRootPart.CFrame.LookVector*(isClose and 35 or 7),
				--	Time = .2,
				--	TweenLength = .7
				--},

				--StateData = {
				--	Stunned = 1,
				--	AutoRotate = 1,
				--},

				MovementData = {
					WalkSpeed = 0,
					JumpPower = 0,
					Time = 1,
				},

				BlockData = {			
					HitterOrigin = self.Character.HumanoidRootPart.CFrame,
				},

				Damage = self.Settings.Damage,
				--ReactionAnim = isClose and game.ReplicatedStorage.Assets.Animations.Reactions.DashM1Reaction or isflying and game.ReplicatedStorage.Assets.Animations.ReactionsFlying["Reaction"..math.random(1,4)] or (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),
				EnemyFacesCharacter = true,
			},function(State)		
				if State == "Hit" then
					self.Hit = true
					self.Victim = Enemy
					self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Immortal Blaze", "M1", "HittaliciousMaximus", self.Character, Enemy, math.random(1,4))

				elseif State == "Block" then
				end
			end)
			if Enemy:FindFirstChild("Values") then
				for i,v in pairs(Enemy:FindFirstChild("Values"):GetDescendants()) do
					if v.Name == ("MokouBaseSpecialFireTalonStunUnability") or v:GetAttribute("MokouBaseSpecialFireTalonStunUnability") then
						v:Destroy()
					end
				end
			end


		end
	end))
end

function Special:CreateHitbox2(callback)
	self:bindClassToAttack(self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = self.Character.HumanoidRootPart,
		Offset = self.Settings.HitboxSettings2.Offset,
		Size = self.Settings.HitboxSettings2.Size,
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = false,
		IgnoresBlock = true,
		Visualize = false,
		DelayTime = self.Settings.HitboxSettings2.DelayTime,
		Debris = self.Settings.HitboxSettings2.Debris,
	}, callback))
end

--function Special:Hold(InAir)
--end
function Special:Explosion(ProjectilePart,attacking)
	coroutine.resume(coroutine.create(function()
		if attacking == true then
			--ProjectilePart.Anchored = true
			ProjectilePart.fuse:Destroy()
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, 'Immortal Blaze', "M1", "BambooExplode", ProjectilePart)
			ProjectilePart.Transparency = 1
			ProjectilePart.Orientation = Vector3.new(0,0,0)
			self.Knit.GetService("HitboxService"):createHitbox({
				Caster = self.Character,
				Origin = ProjectilePart,
				Offset = CFrame.new(0,0,0),
				Size = Vector3.new(20,20,20),
				HitboxType = "Box",
				HitType = "OneHit",
				IgnoresRagdoll = true,
				IgnoresIFrames = false,
				IgnoresBlock = true,
				DelayTime = 0,
				Debris = .1,
				ReactionAnim = game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,3)],
			}, function(Enemy)
				self:TagEnemy(Enemy,ProjectilePart)
			end)
			game.Debris:AddItem(ProjectilePart,2)
			for i,v in pairs(ProjectilePart:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
				if v:IsA('BasePart') then
					v.Transparency = 1
				end
				if v:IsA('Decal') then
					v.Transparency = 1
				end
				if v:IsA('Trail') then
					v.Enabled = false
				end
				if v:IsA('PointLight') then
					game:GetService("TweenService"):Create(v,TweenInfo.new(.4,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Range = 0}):Play()
				end
			end
			ProjectilePart.Anchored = true
		end
	end))
end

function Special:Release(InAir)
	local FX = nil
	task.delay(16/60,function()
		if self.Cancelled then return end
		local RedFX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.ThrowBambooGrenade1:Clone() 
		game.Debris:AddItem(RedFX,2)
		RedFX.Parent = self.Character.HumanoidRootPart
		RedFX:Play()
		local RedFX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.ThrowBambooGrenade2:Clone() 
		game.Debris:AddItem(RedFX,2)
		RedFX.Parent = self.Character.HumanoidRootPart
		RedFX:Play()
	end)
	task.delay(43/60,function()
		if self.Cancelled then return end
		local RedFX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Hit.VFX['h'..math.random(1,4)]:Clone() 
		game.Debris:AddItem(RedFX,2)
		RedFX.TimePosition = 0
		RedFX.PlaybackSpeed = 1.2
		RedFX.Parent = self.Character.HumanoidRootPart
		RedFX:Play()
	end)
	task.delay(39/60,function()
		if self.Cancelled then return end
		local RedFX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Sfx.Swings['s'..math.random(1,4)]:Clone() 
		game.Debris:AddItem(RedFX,2)
		RedFX.TimePosition = 0
		RedFX.PlaybackSpeed = 1.1
		RedFX.Parent = self.Character.HumanoidRootPart
		RedFX:Play()
	end)
	task.delay(30/60,function()
		if self.Cancelled then return end
		FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
		FX.Parent=self.Character
		FX.w.Part0= self.Character['Left Leg']
		for i ,v in pairs(FX:GetDescendants())do
			if v:IsA('Trail') then
				v.Enabled = true
			end
		end
	end)
	local BambooBomb = game.ServerStorage.BambooBomb:Clone()
	BambooBomb.Parent = self.Character["HumanoidRootPart"]
	BambooBomb.BambooBomb.Part0 = self.Character["HumanoidRootPart"]
BambooBomb.fuse:Play()
	for i ,v in pairs(BambooBomb:GetDescendants())do
		if v:IsA("PointLight") then
			game:GetService("TweenService"):Create(v, TweenInfo.new(.2, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), {Range = .5}):Play()
		end
		if v:IsA("Trail") then
			v.Enabled = true
		end
	end
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit1"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit2"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit3"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit4"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Uppercut"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Downslam"])
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Special.Release)
	task.delay(41/60,function()
		if self.Cancelled then return end
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Immortal Blaze", "M1", "specialvelocity", self.Character, self.Character)	
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 120, "Immortal Blaze", "M1", "LASTM1HIGHLIGHT", self.Character, self.Character)	
	end)
	task.delay(44/60,function()
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 150, "Immortal Blaze", "M1", "SpecialWind", self.Character, self.Character)	
		BambooBomb.BambooBomb:Destroy()
		BambooBomb.CollisionPart.CollisionGroup = ("Visuals2")
		BambooBomb.CollisionPart.CanCollide = true
		BambooBomb.Parent = workspace.Ignore.Effects
		local boopyve = Instance.new("BodyVelocity")
		boopyve.MaxForce = Vector3.new(20000, 20000, 20000)
		boopyve.P = 10
		local pos = GetLocalCharPosition:InvokeClient(game.Players:GetPlayerFromCharacter(self.Character))
		--BambooBomb.CFrame = (pos * CFrame.new(-1.672, -3.19, 0.544)) * CFrame.fromOrientation(112.255, 20.329, 4.708)
		boopyve.Velocity = pos.LookVector * 75 + Vector3.new(0,10,0)
		boopyve.Parent = BambooBomb
		game.Debris:AddItem(boopyve, 0.1)
		coroutine.resume(coroutine.create(function()
			local attacking = true
			local connection2
			task.delay(1.4,function()
				if attacking == true then
					connection2:Disconnect()
					self:Explosion(BambooBomb,attacking)
					attacking = false
				end		
			end)

			connection2 = BambooBomb.HitboxPart.Touched:Connect(function(part)
				if require(game.ServerStorage.Touhou.Bridge).isEntity(part) then
					if (part.Parent:FindFirstChildOfClass("Humanoid")) then
						if not part:IsDescendantOf(self.Character) then
							if part.Parent ~= self.Character then
								self:Explosion(BambooBomb,attacking)
								attacking = false
							end
						end
					end
				end
			end)
		end))
		BambooBomb:SetNetworkOwner(nil)

		--task.delay(2,function()
		--	game.Debris:AddItem(object, 0.65)
		--	local TweenFX = game:GetService("TweenService"):Create(object, TweenInfo.new(0.65, Enum.EasingStyle.Linear,Enum.EasingDirection.InOut), {Transparency = 1})
		--	TweenFX:Play()
		--end)
		--mokouleftvfx()
	end)

	self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
	--self:changeBackCombat()
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 1), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	task.delay(self.Settings.AttackLength,function()
		if Cant ~= nil then
			Cant:Destroy()
		end
		if FX ~= nil then
			game.Debris:AddItem(FX,2)
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
		end
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end	
	end)

	--self.Knit.GetService("StateService"):AddStates(self.Character, {"IFrames"}, self.Settings.AttackLength)
	self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Special", self.Settings.Cooldown)
	self.Cancelled = false
	local attacking = true
	local RedFX251
	local RedFX2514
	self:listenForCancel(function()
		if BambooBomb.Parent == self.Character.HumanoidRootPart then
			BambooBomb:Destroy()
		end
		if FX ~= nil then
			game.Debris:AddItem(FX,2)
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
		end
		self.Cancelled = true
		attacking = false
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end	
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Special.Release)
		if Cant ~= nil then
			Cant:Destroy()
		end
		--self.Knit.GetService("StateService"):RemoveStates(self.Character, {"IFrames"})
		self:Destroy()
	end)
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 70, "Scarlet Empress", "M1", "CLOTHAWAKENING2", self.Character, self.Character)	
end

return Special
