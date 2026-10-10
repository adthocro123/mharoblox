local Skill3 = {}
Skill3.Settings = {
	Cooldown = 25,
	Damage = 4,
	AttackLength = (210/60),
	AttackLength2 = (228/60),

	HitboxSettings = {
		--DelayTime = .23,
		Debris = .15,

		Offset = CFrame.new(0,-1,-2),
		Size = Vector3.new(10,8,14)
	},
	magnitudeForClose = 20,
}
Skill3.Settings2 = {
	Cooldown = 25,
	Damage = 6,
	AttackLength = 1.4,

	HitboxSettings = {
		Debris = .15,

		Offset = CFrame.new(0,-1,-5),
		Size = Vector3.new(8,14,15)
	},
}

function Skill3:CreateHitbox(callback)
	self:bindClassToAttack(self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = self.Character.HumanoidRootPart,
		Offset = self.Settings2.HitboxSettings.Offset,
		Size = self.Settings2.HitboxSettings.Size,
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = false,
		IgnoresBlock = true,
		Visualize = false,
		DelayTime = self.Settings2.HitboxSettings.DelayTime,
		Debris = self.Settings2.HitboxSettings.Debris,
	}, callback))
end

function Skill3:TagEnemy(Enemy)
	if self.Character.Values:FindFirstChild("Stunned") then return end
	if self.Cancelled then return end
	if self.Hit then return end
	if Enemy:GetAttribute("Blocking") then		
		self.Knit.GetService("DamageService"):Damage({

			Character = self.Character,
			Enemy = Enemy,

			--KnockbackData = {
			--	KnockbackType = "Velocity",
			--	MaxForce = Vector3.new(100000,0,100000),
			--	Velocity = self.Character.HumanoidRootPart.CFrame.LookVector*(85), 
			--	Time = .25,
			--} ,

			--RagdollData = {
			--	Time = 2,
			--},
			StateData = {
				Stunned = .6,
				AutoRotate = .6,
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
				Time = .6,
			},

			BlockData = {			
				HitterOrigin = self.Character.HumanoidRootPart.CFrame,
			},

			Damage = self.Settings.Damage,
			ReactionAnim = (game.ReplicatedStorage.Assets.Animations.ReactionsFlyingREAL["Reaction"..math.random(1,4)]),
			EnemyFacesCharacter = true,
		},function(State)		
			if State == "Hit" then
				self.Hit = true
				--	self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
				--	self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
				--	self.Knit.GetService("StateService"):RemoveStates(self.Character, {"Dashing"})
				--	if isClose then
				--		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 25, self.Character:GetAttribute("Combat"), "Dash", "DashM1Close", self.Character, Enemy)
				--	else
				--		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 25, self.Character:GetAttribute("Combat"), "Dash", "DashM1Far", self.Character, Enemy)
				--	end
				--	--self.Character.Humanoid:MoveTo(self.Character.HumanoidRootPart.Position:Lerp(Enemy.HumanoidRootPart.Position, 0.5))
			elseif State == "Block" then
				--task.delay(.1,function()
				--	self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
				--end)
				--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 25, self.Character:GetAttribute("Combat"), "Dash", "DashM1Miss", self.Character)
				--self.Knit.GetService("MovementService"):AddMovements(self.Character, {WalkSpeed = 0, JumpPower = 0}, .6)
			end
		end)
		return end
	Enemy:SetAttribute("Cancel", os.clock())

	if self.Knit.GetService("CounterService"):counter(self.Character, Enemy) then
		self.Cancelled = true
		self:Destroy()
	end
	if self.Character:GetAttribute("Ragdoll") then
		self.Knit.GetService("RagdollService"):unragdoll(self.Character, true,true)
	end
	if Enemy:GetAttribute("Ragdoll") then
	self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
end
	self.Hit = Enemy
	self.Character.Humanoid.AutoRotate = true
	self:AddFor(self.Settings.AttackLength, function()
		self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill3", self.Settings.Cooldown)
	end)
	local grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,0,-0.1)*CFrame.Angles(0,math.rad(180),0))
	task.delay(1,function()
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill3.Release)
	end)
	local secondaddon = .5
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	task.delay(self.Settings.AttackLength + secondaddon,function()
		if Cant ~= nil then
			Cant:Destroy()
		end
	end)
	local EnemyIFrames = self.Knit.GetService("StateService"):CreateIFrames(Enemy)
	local EnemyAutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(Enemy)
	game.Debris:AddItem(EnemyIFrames,self.Settings.AttackLength2)
	game.Debris:AddItem(EnemyAutoRotate,self.Settings.AttackLength2)
	
	local IFrames = self.Knit.GetService("StateService"):CreateIFrames(self.Character)
	local AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
	game.Debris:AddItem(IFrames, self.Settings.AttackLength + secondaddon)
	game.Debris:AddItem(AutoRotate, self.Settings.AttackLength + secondaddon)

	local StunVal = self.Knit.GetService("StateService"):CreateStun(Enemy)
	game.Debris:AddItem(StunVal,self.Settings.AttackLength2)
	--self.Knit.GetService("MovementService"):AddMovements(self.Character, {WalkSpeed = 0, JumpPower = 0}, self.Settings.AttackLength2)
	--self.Knit.GetService("MovementService"):AddMovements(Enemy, {WalkSpeed = 0, JumpPower = 0}, self.Settings.AttackLength2)
	local Speed1, Jump2 = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 0), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	game.Debris:AddItem(Speed1, self.Settings.AttackLength + secondaddon)
	game.Debris:AddItem(Jump2, self.Settings.AttackLength + secondaddon)

	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(Enemy, 0), self.Knit.GetService("MovementService"):CreateJump(Enemy, 0)
	game.Debris:AddItem(Speed, self.Settings.AttackLength2)
	game.Debris:AddItem(Jump, self.Settings.AttackLength2)
	self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill3.Victim,1,nil,0)
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill3.Success,1,nil,0)

	--if self.Character["Right Arm"]:FindFirstChild("remiliaspear") then
	--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, script.Parent.Name, "M1", "Hit", self.Character, Enemy, 1)
	--	self.Character["Right Arm"]:FindFirstChild("remiliaspear")["Impale"]:Play()
	--end
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 25, script.Parent.Name, "M1", "HitNOSFX", self.Character, Enemy, math.random(1,4))
	local Red12FX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Wind162:Clone()
	game.Debris:AddItem(Red12FX,7)
	Red12FX.Parent = Enemy.HumanoidRootPart
	Red12FX:Play()
	local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
	FX.Parent=self.Character
	FX.w.Part0= self.Character['Right Leg']
	game.Debris:AddItem(FX,5)
	local FX2= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
	FX2.Parent=self.Character
	FX2.w.Part0= self.Character['Left Leg']
	game.Debris:AddItem(FX2,5)

	local function mokourightvfx()
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 15, "Immortal Blaze", "M1", "mokourightvfx", self.Character, self.Character)	
	end

	local function mokouleftvfx()
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 15, "Immortal Blaze", "M1", "mokouleftvfx", self.Character, self.Character)	

	end
	local function groundcrack()
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 15, "Immortal Blaze", "M1", "groundcrack", self.Character, self.Character)	
	end
	local function bigexplode()
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 15, "Immortal Blaze", "M1", "bigexplode", self.Character, self.Character)	
	end
	mokourightvfx()
	task.delay(173/60,function()
		mokourightvfx()
	end)
	task.delay(27/60,function()
		mokouleftvfx()
	end)
	task.delay(207/60,function()
		mokouleftvfx()
	end)
	task.delay(45/60,function()
		groundcrack()
		self.Knit.GetService("HitboxService"):createHitbox({
			Caster = self.Character,
			Origin = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-4),
			Offset = CFrame.new(0,0,-2.4),
			Size = Vector3.new(17,16,16),
			HitboxType = "Box",
			HitType = "OneHit",
			IgnoresRagdoll = true,
			IgnoresBlock = true,
			DelayTime = 0,
			Debris = .1,
		}, function(Enemy5)
			if Enemy5 == Enemy then return end
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 25, script.Parent.Name, "M1", "HitNOSFX", self.Character, Enemy5, math.random(1,4))
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy5, 2)
			self:TagEnemyThrow2(Enemy5)
		end)
	end)
	task.delay(173/60,function()
		self.Knit.GetService("HitboxService"):createHitbox({
			Caster = self.Character,
			Origin = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-4),
			Offset = CFrame.new(0,0,-2.4),
			Size = Vector3.new(17,16,16),
			HitboxType = "Box",
			HitType = "OneHit",
			IgnoresRagdoll = true,
			IgnoresBlock = true,
			DelayTime = 0,
			Debris = .1,
		}, function(Enemy5)
			if Enemy5 == Enemy then return end
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 35, script.Parent.Name, "M1", "HitNOSFX", self.Character, Enemy5, math.random(1,4))
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy5, 2)
			self:TagEnemyThrow2(Enemy5)
		end)
		groundcrack()
	end)
	task.delay(206/60,function()
		self.Knit.GetService("HitboxService"):createHitbox({
			Caster = self.Character,
			Origin = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-4.5),
			Offset = CFrame.new(0,0,-2.6),
			Size = Vector3.new(17,16,18),
			HitboxType = "Box",
			HitType = "OneHit",
			IgnoresRagdoll = true,
			IgnoresBlock = true,
			DelayTime = 0,
			Debris = .1,
		}, function(Enemy5)
			if Enemy5 == Enemy then return end
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 25, script.Parent.Name, "M1", "HitNOSFX", self.Character, Enemy5, math.random(1,4))
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy5, 2)
			self:TagEnemyThrow3(Enemy5)
		end)
		bigexplode()
	end)
	task.delay(86/60,function()
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 40, "Immortal Blaze", "M1", "mokoubarragevfx", self.Character, self.Character)	
	end)
	self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 1)

	task.delay(26/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 1.5)
		end
	end)

	task.delay(43/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 1.5)
		end
	end)
	
--muda kicks
	task.delay(86/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .2)
		end
	end)
	task.delay(97/60,function()
		if self.Cancelled ~= true then
			local math1 = math.random(1,40)
			if math1 == 40 then
				local RedFX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.mudamuda:Clone()
				game.Debris:AddItem(RedFX,4)
				RedFX.Parent = self.Character.HumanoidRootPart
				RedFX:Play()
			end
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .2)
		end
	end)
	task.delay(103/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .2)
		end
	end)
	task.delay(109/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .2)
		end
	end)
	task.delay(115/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .25)
		end
	end)
	task.delay(121/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .25)
		end
	end)
	task.delay(127/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .2)
		end
	end)
---muda kicks end
	task.delay(129/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .2)
		end
	end)
	task.delay(136/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .7)
		end
	end)
	task.delay(174/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .7)
		end
	end)
	task.delay(208/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 1.1)
		end
	end)
	task.delay(self.Settings.AttackLength,function()
		if self.Cancelled then return end
		grab:Destroy()
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
		if FX2 ~= nil then
			game.Debris:AddItem(FX2,2)
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
		end
		if Jump ~= nil then
			Jump:Destroy()
		end
		if EnemyIFrames ~= nil then
			EnemyIFrames:Destroy()
		end
		if EnemyAutoRotate ~= nil then
			EnemyAutoRotate:Destroy()
		end
		if IFrames ~= nil then
			IFrames:Destroy()
		end
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end
		if Cant ~= nil then
			Cant:Destroy()
		end
		self:TagEnemyThrow(Enemy)
		if StunVal ~= nil then
			StunVal:Destroy()
		end
		--self.Knit.GetService("AnimationService"):stopAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill3.Victim)
		--self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, self.Settings.Damage)
		--self.Knit.GetService("RagdollService"):ragdoll(Enemy, 3)
	end)	

	self:listenForCancel(function()
		if StunVal ~= nil then
			StunVal:Destroy()
		end
		if Cant ~= nil then
			Cant:Destroy()
		end
		if IFrames ~= nil then
			IFrames:Destroy()
		end
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
		end
		
		Red12FX:Destroy()
		self.Cancelled = true
		grab:Destroy()
		if EnemyIFrames ~= nil then
			EnemyIFrames:Destroy()
		end
		if EnemyAutoRotate ~= nil then
			EnemyAutoRotate:Destroy()
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
		if FX2 ~= nil then
			game.Debris:AddItem(FX2,2)
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
		end
		--self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill3.Success)
		--self.Knit.GetService("AnimationService"):stopAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill3.Victim)
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Jump2 ~= nil then
			Jump2:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end
		if Speed1 ~= nil then
			Speed1:Destroy()
		end
	end)
end
function Skill3:TagEnemyThrow2(Enemy)
	if self.Cancelled then return end

	local isflying = false if Enemy:GetAttribute("Character") == ("Scarlet Empress") then isflying = true end self.Knit.GetService("DamageService"):Damage({

	KnockbackData = {
		KnockbackType = "Velocity",
		MaxForce = Vector3.new(20000,20000,20000),
		Velocity = Vector3.new(2,30,2),
		Time = .25,
	},

	Character = self.Character,
	Enemy = Enemy,

	StateData = {
		Stunned = 2.7,
		AutoRotate = 2.7,
	},

	MovementData = {
		WalkSpeed = 0,
		JumpPower = 0,
		Time = 2.7,
	},

	RagdollData = {
		Time = 2.7,
	},

	ReactionAnim = (game.ReplicatedStorage.Assets.Animations.ReactionsFlyingREAL["Reaction"..math.random(1,4)]),

	Damage = .3,
	},function(State)
		self.HitSomeone = true

	end)
end
function Skill3:TagEnemyThrow3(Enemy)
	if self.Character.Values:FindFirstChild("Stunned") then return end
	if self.Cancelled then return end
	local damage = 3
	--Enemy.HumanoidRootPart.CFrame = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-1.5)
	self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,
		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(20000,20000,20000),
			Velocity = ((Enemy.HumanoidRootPart.CFrame.Position - self.Character.HumanoidRootPart.CFrame.Position).Unit *(75)) + Vector3.new(0,10,0), 
			Time = .2,
		},
		RagdollData =  {
			Time = 2,
		},
		StateData = {
			Stunned = 2,
			AutoRotate = 2,
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
			Time = 2,
		},

		BlockData = {			
			HitterOrigin = self.Character.HumanoidRootPart.CFrame,
		},

		Damage = .3,
		ReactionAnim = (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),
		--EnemyFacesCharacter = true,
	},function(State)
		self.HitSomeone = true

	end)
end
function Skill3:TagEnemyThrow(Enemy)
	if self.Character.Values:FindFirstChild("Stunned") then return end
	if self.Cancelled then return end
	local damage = 3
	--Enemy.HumanoidRootPart.CFrame = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-1.5)

	self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	local ragdolltime = 2.4
	if damage >= Enemy.Humanoid.Health then
		ragdolltime = 20
		self.Knit.GetService("DamageService"):Damage({

			Character = self.Character,
			Enemy = Enemy,

			KnockbackData = {
				KnockbackType = "Velocity",
				MaxForce = Vector3.new(100000,100000,100000),
				Velocity = (self.Character.HumanoidRootPart.CFrame.LookVector*(150)) + Vector3.new(0,80,0), 
				Time = .5,
			},
			--KnockbackData = {
			--	KnockbackType = "Velocity",
			--	MaxForce = Vector3.new(20000,0,20000),
			--	Velocity = self.Character.HumanoidRootPart.CFrame.LookVector*(70), 
			--	Time = .2,
			--},
			RagdollData =  {
				Time = ragdolltime,
			},
			StateData = {
				Stunned = ragdolltime,
				AutoRotate = ragdolltime,
			},

			MovementData = {
				WalkSpeed = 0,
				JumpPower = 0,
				Time = ragdolltime,
			},

			--RagdollData = {
			--	Time = 3,
			--},

			Damage = damage * 500,
		},function(State)
			self.HitSomeone = true

		end)
	else
		self.Knit.GetService("DamageService"):Damage({

			Character = self.Character,
			Enemy = Enemy,

			--KnockbackData = {
			--	KnockbackType = "ShortKnockback",
			--	--MaxForce = Vector3.new(100000,0,100000),
			--	VelocityOrigin = self.Character.HumanoidRootPart, 
			--	Velocity = 5, 
			--	VelocityUp = 7.5, 
			--	--Time = .25,
			--} ,
			KnockbackData = {
				KnockbackType = "Velocity",
				MaxForce = Vector3.new(20000,20000,20000),
				Velocity = (self.Character.HumanoidRootPart.CFrame.LookVector*(85)) + Vector3.new(0,20,0), 
				Time = .3,
			},
			RagdollData =  {
				Time = ragdolltime,
			},
			StateData = {
				Stunned = ragdolltime,
				AutoRotate = ragdolltime,
			},

			MovementData = {
				WalkSpeed = 0,
				JumpPower = 0,
				Time = ragdolltime,
			},
			--StateData = {
			--	Stunned = 3,
			--	AutoRotate = 3,
			--},

			--MovementData = {
			--	WalkSpeed = 0,
			--	JumpPower = 0,
			--	Time = 3,
			--},

			--RagdollData = {
			--	Time = 3,
			--},

			Damage = damage,
		},function(State)
			self.HitSomeone = true

		end)
	end
end

local Blacklist2 = OverlapParams.new()

Blacklist2.FilterDescendantsInstances = {script.Parent,workspace.Terrain,workspace.Ignore}

Blacklist2.FilterType = Enum.RaycastFilterType.Exclude

local Blacklist = RaycastParams.new()

Blacklist.FilterDescendantsInstances = {script.Parent,workspace.Terrain,workspace.Ignore}

Blacklist.FilterType = Enum.RaycastFilterType.Exclude


local SimpleHitbox = function(CFram)
	local Parts = workspace:GetPartBoundsInBox(CFram,Vector3.new(5,5,5),Blacklist2)

	local FakePart = Instance.new("Part",workspace.Terrain)

	FakePart.Transparency = 1

	FakePart.Anchored = true

	FakePart.CanCollide = false

	FakePart.CFrame = CFram

	FakePart.Size = Vector3.new(5,5,5)

	game.Debris:AddItem(FakePart,.15)

	for num,Part in pairs(Parts) do
		if Part.Parent:FindFirstChildOfClass("Humanoid") then
			return true

		end
	end
	return false
end

local Rayc = function(Hrp)
	local ray = workspace:Raycast(Hrp.Position,Hrp.CFrame.LookVector*4,Blacklist)

	if ray then
		return true
	end
	return false
end
function Skill3:Release()

	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit1"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit2"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit3"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit4"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Uppercut"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Downslam"])
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill3.Release)
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
	self.Knit.GetService("AttackService"):destroyBodyGyroHold(self.Character,"FullMouse")
	--self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill3", self.Settings.Cooldown)
	--local RedF151X=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.BloodDash:Clone()
	--game.Debris:AddItem(RedF151X,4)
	--RedF151X.Parent = self.Character.HumanoidRootPart
	--RedF151X:Play()
	local count = 0
	--local function flare()
	--	if self.Cancelled ~= true then
	--		if self.Character["Right Arm"]:FindFirstChild("remiliaspear") then
	--			if count == 0 then
	--				if self.Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir1"].IsPlaying then
	--					self.Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir2"]:Play()
	--				else
	--					self.Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir1"]:Play()
	--				end
	--			end
	--			count += 1
	--			self.Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir3"]:Play()
	--			self.Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(self.Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
	--			self.Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(self.Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
	--		end
	--	end
	--end
	--local function slash()
	--	if self.Cancelled ~= true then
	--		if self.Character["Right Arm"]:FindFirstChild("remiliaspear") then
	--			self.Character["Right Arm"]:FindFirstChild("remiliaspear")["swing1"]:Play()
	--			self.Character["Right Arm"]:FindFirstChild("remiliaspear")["swing12"]:Play()
	--			self.Character["Right Arm"]:FindFirstChild("remiliaspear")["swing2"]:Play()

	--			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Skill3Slash.Attach221ment:Clone()
	--			RedFX15.Parent = self.Character.HumanoidRootPart
	--			game.Debris:AddItem(RedFX15,1.5) 
	--			for i,v in pairs(RedFX15:GetDescendants()) do
	--				if v:IsA('ParticleEmitter') then
	--					v:Emit(v:GetAttribute('EmitCount') or 1)
	--				end
	--			end

	--			local RedFX156 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Skill3Slash["emit 011"]:Clone()
	--			RedFX156.Parent = self.Character.HumanoidRootPart
	--			game.Debris:AddItem(RedFX156,1.5)
	--			for i,v in pairs(RedFX156:GetDescendants()) do
	--				if v:IsA('ParticleEmitter') then
	--					v:Emit(v:GetAttribute('EmitCount') or 1)
	--				end
	--			end

	--		end
	--	end
	--end
	--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 70, "Scarlet Empress", "M1", "CLOTHAWAKENING2", self.Character, self.Character)	
	--self.Character["Right Arm"]:FindFirstChild("remiliaspear")["spearswing2"]:Play()


	--task.delay(11/60,function()
	--	flare()
	--end)
	--task.delay(38/60,function()
	--	flare()
	--end)
	--task.delay(60/60,function()
	--	slash()
	--end)
	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 1), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
	FX.Parent=self.Character
	FX.w.Part0= self.Character['Right Leg']

	game.Debris:AddItem(FX,2)
	task.delay(1,function()
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
	self:listenForCancel(function()	
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end
		--RedFX2425:Destroy()
		--self.Character["Right Arm"]:FindFirstChild("remiliaspear")["spearswing2"]:Stop()
		if Cant ~= nil then
			Cant:Destroy()
		end
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill3.Release)
		self.Cancelled = true
		self:Destroy()
	end)
	task.delay(20/60,function()
		local Red12FX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Wind16:Clone()
		game.Debris:AddItem(Red12FX,4)
		Red12FX.Parent = self.Character.HumanoidRootPart
		Red12FX:Play()
	end)
	local hrp = self.Character:FindFirstChild("HumanoidRootPart")
	local startingPos = self.Character.HumanoidRootPart.Position
	task.delay(41/60,function()
		task.delay(self.Settings2.HitboxSettings.Debris,function()
			if not self.Hit then
				self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill3", self.Settings.Cooldown)
			end
		end)
	end)
	task.delay(30/60,function()
		if self.Cancelled then return end
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Immortal Blaze", "M1", "skill3velocity", self.Character, self.Character)	
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 25, "Immortal Blaze", "M1", "LASTM1HIGHLIGHT", self.Character, self.Character)	
	end)
	wait(33/60)

	if self.Cancelled == true then return end
	--local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].WindFX.Attachment:Clone()
	--RedFX15.Parent = self.Character.HumanoidRootPart
	--game.Debris:AddItem(RedFX15,6)
	--for i,v in pairs(RedFX15:GetDescendants()) do
	--	if v:IsA('ParticleEmitter') then
	--		v:Emit(v:GetAttribute('EmitCount') or 1)
	--	end
	--end
	if self.Cancelled then
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end
		--self.Character["Right Arm"]:FindFirstChild("remiliaspear")["spearswing2"]:Stop()
		--RedF151X:Destroy()
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill3.Release)
		if Cant ~= nil then
			Cant:Destroy()
		end
		self.Cancelled = true
		self:Destroy()
		return
	end
	coroutine.resume(coroutine.create(function()
		self:CreateHitbox(function(Enemy)
			self:TagEnemy(Enemy,startingPos)
		end)
	end))
	wait((62/60) - (33/60))
	--wait((40/60) - ((48/60) - (22/60))) 
	--local RedFX = ResourceFolder.Parent.MilleniumExplosion.Attachment:Clone()
	--RedFX.Parent = self.Character.Torso
	--game.Debris:AddItem(RedFX,bufftime)
	--for i,v in pairs(RedFX:GetDescendants()) do
	--	if v:IsA('ParticleEmitter') then
	--		v:Emit(v:GetAttribute('EmitCount') or 1)
	--	end
	--end
	--RedFX.shockwave:Play()
	--RedFX.shockwave2:Play()
	--RedFX.shockwave3:Play()
	--local buffvalue = Instance.new("BoolValue",self.Character)
	--buffvalue.Value = true
	--buffvalue.Name = ("MilleniumVampire")
	--game.Debris:AddItem(buffvalue,bufftime)
	--local RedFX251 = ResourceFolder.Parent.MilleniumSmoke.Attachment:Clone()
	--RedFX251.Parent = self.Character.Torso
	--game.Debris:AddItem(RedFX251,bufftime + 2)
	--for i,v in pairs(RedFX251:GetChildren()) do
	--	if v:IsA("ParticleEmitter") then
	--		task.delay(bufftime,function()
	--			v.Enabled = false
	--		end)
	--	end
	--end
	--for i,v in pairs(ResourceFolder:GetChildren()) do
	--	if v:IsA("ParticleEmitter") then
	--		local cloneado = v:Clone()
	--		cloneado.Parent = self.Character.Torso
	--		task.delay(bufftime,function()
	--			cloneado.Enabled = false
	--			game.Debris:AddItem(cloneado,2)
	--		end)
	--	end
	--end
	--task.wait(.9)
	if Cant ~= nil then
		Cant:Destroy()
	end
	if Jump ~= nil then
		Jump:Destroy()
	end
	if Speed ~= nil then
		Speed:Destroy()
	end
end

return Skill3
