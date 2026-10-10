local Skill1 = {}
Skill1.Settings = {
	Cooldown = 20,
	Damage = 4,
	AttackLength = (71/60),
	AttackLength2 = (70/60),

	HitboxSettings = {
		DelayTime = 0,
		Debris = .1,

		Offset = CFrame.new(0,0,-1.4),
		Size = Vector3.new(14,15,16)
	},
}
Skill1.Settings2 = {
	Cooldown = 20,
	Damage = 5,
	AttackLength = 1.4,

	HitboxSettings = {
		DelayTime = 0,
		Debris = .2,

		Offset = CFrame.new(0,0,-3),
		Size = Vector3.new(10,15,15)
	},
	HitboxSettings2 = {
		DelayTime = 0,
		Debris = .14,

		Offset = CFrame.new(0,0,-2),
		Size = Vector3.new(14,14,14)
	},
}
Skill1.Settings3 = {
	Cooldown = 25,
	Damage = 6,
	AttackLength = 1.4,

	HitboxSettings = {
		DelayTime = 0,
		Debris = .2,

		Offset = CFrame.new(0,4.5,-4),
		Size = Vector3.new(10,17,20)
	},
}
local ApplyHandlr = require(game.ServerStorage.Touhou.SimJump)
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

function Skill1:CreateHitbox(callback)
	self:bindClassToAttack(self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = self.Character.HumanoidRootPart,
		Offset = self.Settings.HitboxSettings.Offset,
		Size = self.Settings.HitboxSettings.Size,
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = false,
		IgnoresBlock = false,
		Visualize = false,
		DelayTime = self.Settings.HitboxSettings.DelayTime,
		Debris = self.Settings.HitboxSettings.Debris,
	}, callback))
end

function Skill1:CreateHitbox2(callback)
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
function Skill1:CreateHitbox23(callback)
	self:bindClassToAttack(self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = self.Character.HumanoidRootPart,
		Offset = self.Settings2.HitboxSettings2.Offset,
		Size = self.Settings2.HitboxSettings2.Size,
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = false,
		IgnoresBlock = true,
		Visualize = false,
		DelayTime = self.Settings2.HitboxSettings2.DelayTime,
		Debris = self.Settings2.HitboxSettings2.Debris,
	}, callback))
end

function Skill1:TagEnemy2(Enemy)
	if self.Character.Values:FindFirstChild("Stunned") then return end
	if self.Cancelled then return end
	local damage = 7
	local KnockbackData1
	if not Enemy:GetAttribute("Ragdoll") then
		KnockbackData1 = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(0,25000,0),
			Velocity = Vector3.new(math.random(2,4),-100,math.random(2,4)),
			Time = .1,
		}
	else
		damage = 4
		KnockbackData1 = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(0,20000,0),
			Velocity = Vector3.new(0,50,0),
			Time = .15,
		}
	end
	self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Victim2,1,nil,0)
	wait()
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,
		

		KnockbackData = KnockbackData1,

		StateData = {
			Stunned = 2.3,
			AutoRotate = 2.3,
		},

		MovementData = {
			WalkSpeed = 0,
			JumpPower = 0,
			Time = 2.3,
		},

		RagdollData = {
			Time = 2.3,
		},
		Damage = damage,
		--EnemyFacesCharacter = true,
	},function(State)
		if State == "Hit" then
			self.HitSomeone = true
			local RedF2X2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.althit:Clone()
			RedF2X2425.Parent = Enemy.Torso
			game.Debris:AddItem(RedF2X2425,2)
			RedF2X2425:Play()
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 45, script.Parent.Name, "M1", "HitNOSFX", self.Character, Enemy, math.random(1,4))
		end
	end)
end


function Skill1:TagEnemy(Enemy)
	if self.Cancelled then return end
	if self.Knit.GetService("CounterService"):counter(self.Character, Enemy) then
		self.Cancelled = true
		self:Destroy()
		return
	end
	--CombatProfile.Combo = 4
	self.Knit.GetService("DamageService"):Damage({

	Character = self.Character,
	Enemy = Enemy,
		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(0,20000,0),
			Velocity = Vector3.new(0,47,0),
			Time = .34,
		},
	--KnockbackData = {
	--	KnockbackType = "Velocity",
	--	MaxForce = Vector3.new(500000,500000,500000),
	--	Velocity = (self.Character.HumanoidRootPart.CFrame.LookVector * 15) + Vector3.new(0,14,0), 
	--	Time = .1,
	--},

	StateData = {
		Stunned = 1,
		AutoRotate = 1,
	},

	MovementData = {
		WalkSpeed = 0,
		JumpPower = 0,
		Time = 1,
	},

	RagdollData = {
		Time = .5,
	},
	ReactionAnim = (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),
	Damage = self.Settings.Damage,
	},function(State)
		self.HitSomeone = true

		if State == "Hit" then
			local RedFX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.kick11:Clone()
			game.Debris:AddItem(RedFX,4)
			RedFX.Parent = Enemy.HumanoidRootPart
			RedFX:Play()
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, script.Parent.Name, "Smash2", "Hit", self.Character, Enemy)
		end
	end)
end
function Skill1:TagEnemy1(Enemy)
	if self.Cancelled then return end
	if self.Knit.GetService("CounterService"):counter(self.Character, Enemy) then
		self.Cancelled = true
		self:Destroy()
		return
	end
	local isflying = false if Enemy:GetAttribute("Character") == ("Scarlet Empress") then isflying = true end self.Knit.GetService("DamageService"):Damage({

	Character = self.Character,
	Enemy = Enemy,

	KnockbackData = {
		KnockbackType = "Velocity",
		MaxForce = Vector3.new(500000,500000,500000),
		Velocity = (self.Character.HumanoidRootPart.CFrame.LookVector * 55) + Vector3.new(0,5,0), 
		Time = .2,
	},

	StateData = {
		Stunned = 1,
		AutoRotate = 1,
	},

	MovementData = {
		WalkSpeed = 0,
		JumpPower = 0,
		Time = 1,
	},

	RagdollData = {
		Time = 3,
	},
	ReactionAnim = isflying and game.ReplicatedStorage.Assets.Animations.ReactionsFlying["Reaction"..math.random(1,4)] or (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),
	Damage = self.Settings.Damage,
	},function(State)
		self.HitSomeone = true

		if State == "Hit" then
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, script.Parent.Name, "Smash2", "Hit", self.Character, Enemy)
		end
	end)
end
function Skill1:TagEnemyThrow(Enemy)
	if self.Cancelled then return end
	local stuntime = 3
	self.Knit.GetService("DamageService"):Damage({

		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(10000,10000,10000),
			Velocity = (self.Character.HumanoidRootPart.CFrame.LookVector*(14)) + Vector3.new(0,-80,0),
			Time = .04,
		},

		Character = self.Character,
		Enemy = Enemy,

		StateData = {
			Stunned = stuntime,
			AutoRotate = stuntime,
		},

		MovementData = {
			WalkSpeed = 0,
			JumpPower = 0,
			Time = stuntime,
		},

		RagdollData = {
			Time = stuntime,
		},

		Damage = 1,
	},function(State)
		self.HitSomeone = true
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 70, "Immortal Blaze", "M1", "SmashWhenGround", Enemy,1)
	end)
end

function Skill1:TagEnemy3(Enemy)
	if self.Character.Values:FindFirstChild("Stunned") then return end
	if self.Cancelled then return end
	if self.Hit then return end
	Enemy:SetAttribute("Cancel", os.clock())
	if Enemy:GetAttribute("Ragdoll") then
		self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	end
	self.Hit = Enemy
	--self.Character.Humanoid.AutoRotate = true
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 100, self.Character:GetAttribute("Character"), "M1", "SKILL1GRABVFX", self.Character,Enemy)
	local grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,-.5,-3)*CFrame.Angles(0,math.rad(180),0))
	task.delay(.2,function()
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.StartupGrab)
	end)
	self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "Skill4Drill", "DrillVELOCIDAD", self.Character, self.Character)	

	self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .4)

	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 60, "Stuff", "downslamupthing", "ENABLEAIRLIMBS", Enemy, Enemy)	
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 60, "Stuff", "downslamupthing", "ENABLEAIRLIMBS", self.Character, self.Character)	
	local IFrames = self.Knit.GetService("StateService"):CreateULTIFrames(self.Character)
	local IFramesEnemy = self.Knit.GetService("StateService"):CreateULTIFrames(Enemy)
	local AutoRotateEnemy = self.Knit.GetService("StateService"):CreateAutoRotate(Enemy)
	local AutoRotate = nil
	local Cant2 = self.Knit.GetService("StateService"):CreateCant(Enemy)
	local StunVal = self.Knit.GetService("StateService"):CreateStun(Enemy)
	game.Debris:AddItem(Cant2,self.Settings.AttackLength2+.4)
	game.Debris:AddItem(StunVal,self.Settings.AttackLength2+.4)
	local Speed1, Jump2 = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 1), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	game.Debris:AddItem(Speed1, self.Settings.AttackLength + 7/60)
	game.Debris:AddItem(Jump2, self.Settings.AttackLength + 7/60)

	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(Enemy, 0), self.Knit.GetService("MovementService"):CreateJump(Enemy, 0)
	game.Debris:AddItem(Speed, self.Settings.AttackLength2)
	game.Debris:AddItem(Jump, self.Settings.AttackLength2)
	task.delay(9/60,function()
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .8)
	end)
	task.delay(45/60,function()
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .8)
	end)
	task.delay(77/60,function()
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .4)
	end)
	task.delay(73/60,function()
		AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
	end)
	self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Victim)
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Success,1,nil,0)
	task.delay(self.Settings.AttackLength - .1,function()
		local buffvalue = Instance.new("BoolValue",Enemy)
		buffvalue.Value = true
		buffvalue.Name = ("CANTBEDETECTEDBYCLOSETORSODETECTION")
		game.Debris:AddItem(buffvalue,.5)
	end)
	task.delay(self.Settings.AttackLength,function()
		if self.Cancelled then return end
		coroutine.resume(coroutine.create(function()
			if IFramesEnemy.Parent ~= nil then
				IFramesEnemy:Destroy()
			end
			if AutoRotateEnemy.Parent ~= nil then
				AutoRotateEnemy:Destroy()
			end
			task.delay(10/60,function()
				self.Knit.GetService("CombatService"):FireAllClients(self.Character, 60, "Stuff", "downslamupthing", "DISABLEAIRLIMBS", Enemy, Enemy)	
			end)
			task.delay(28/60,function()
				local holding5 = Instance.new("BoolValue",self.Character)
				holding5.Value = true
				holding5.Name = ("canusetwice")
				game.Debris:AddItem(holding5,20/60)
				task.delay(20/60,function()
					if not self.Character:FindFirstChild("usedtwice") then
						self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill1", self.Settings.Cooldown)
					end
				end)
				self.Knit.GetService("CombatService"):FireAllClients(self.Character, 60, "Stuff", "downslamupthing", "DISABLEAIRLIMBS", self.Character, self.Character)	
				if IFrames.Parent ~= nil then
					IFrames:Destroy()
				end
				if AutoRotate ~= nil then
					AutoRotate:Destroy()
				end
				if Jump2.Parent ~= nil then
					Jump2:Destroy()
				end
				if Speed1.Parent ~= nil then
					Speed1:Destroy()
				end
				if Cant.Parent ~= nil then
					Cant:Destroy()
				end
			end)
			if StunVal.Parent ~= nil then
				StunVal:Destroy()
			end
			if Jump.Parent ~= nil then
				Jump:Destroy()
			end
			if Speed.Parent ~= nil then
				Speed:Destroy()
			end
		end))
		if grab ~= nil then
			grab:Destroy()
		end
		if Enemy.Parent ~= nil then
			self:TagEnemyThrow(Enemy)
		end
	end)	
end

function Skill1:TagEnemy45(Enemy)
	if self.Cancelled then return end
	if self.Knit.GetService("CounterService"):counter(self.Character, Enemy) then
		self.Cancelled = true
		self:Destroy()
		return
	end
	if Enemy:GetAttribute("Ragdoll") then
		self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	end
	local stuntime = 1
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,

		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(20000,0,20000),
			Velocity = ((Enemy.HumanoidRootPart.CFrame.Position - self.Character.HumanoidRootPart.CFrame.Position).Unit *(40)), 
			Time = .25,
		},

		StateData = {
			Stunned = stuntime,
			AutoRotate = stuntime
		},

		MovementData = {
			WalkSpeed = 0,
			JumpPower = 0,
			Time = stuntime,
		},
		--BlockData = {			
		--	HitterOrigin = self.Character.HumanoidRootPart.CFrame,
		--},
		ReactionAnim = (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),

		EnemyFacesCharacter = true,

		Damage = self.Settings.Damage,
	},function(State)
		if State == "Hit" then
			self.HitSomeone = true
			local RedF2X2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.althit:Clone()
			RedF2X2425.Parent = Enemy.Torso
			game.Debris:AddItem(RedF2X2425,2)
			RedF2X2425:Play()
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 45, script.Parent.Name, "M1", "HitNOSFX", self.Character, Enemy, math.random(1,4))
		end
	end)
end
function Skill1:Release(InAir)
	if not InAir then
		if self.Character:FindFirstChild("canusetwice") then return end
		if self.Character:FindFirstChild("canusetwice") then
			self.Character:FindFirstChild("canusetwice"):Destroy()
		end
		if self.Character:FindFirstChild("usedtwice") then
			self.Character:FindFirstChild("usedtwice"):Destroy()
		end
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit1"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit2"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit3"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit4"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Uppercut"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Downslam"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.CloseVariant)
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.Release2)
		self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.StartupGrab)
		local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 1), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
		local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
		self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
		self.Knit.GetService("AttackService"):destroyBodyGyroHold(self.Character,"FullMouse")
		local RedF2X2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.windsfx1:Clone()
		RedF2X2425.Parent = self.Character.Torso
		game.Debris:AddItem(RedF2X2425,2)
		RedF2X2425:Play()
		local RedFX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Wind15:Clone()
		game.Debris:AddItem(RedFX,4)
		RedFX.Parent = self.Character.Torso
		RedFX:Play()
		local count = 0
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Visuals2'
			end
		end
		self:listenForCancel(function()	
			if Cant ~= nil then
				Cant:Destroy()
			end
			if Jump ~= nil then
				Jump:Destroy()
			end
			if Speed ~= nil then
				Speed:Destroy()
			end
			self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.StartupNew)
			self.Cancelled = true
			for _,v in pairs(self.Character:GetChildren()) do
				if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
					v.CollisionGroup = 'Characters'
				end
			end
			self:Destroy()
		end)
		local hrp = self.Character:FindFirstChild("HumanoidRootPart")
		local startingPos = self.Character.HumanoidRootPart.Position
		task.delay(15/60,function()
			if self.Cancelled then return end
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 30, self.Character:GetAttribute("Combat"), "Dash", "Start", self.Character, "Back")
			self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "Skill3Drill", "Dash2fifties55", self.Character, self.Character)	
		end)
		task.delay(20/60,function()
			if self.Cancelled then return end
			self:CreateHitbox2(function(Enemy)
				self:TagEnemy45(Enemy,startingPos)
			end)
		end)
		local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
		FX.Parent=self.Character
		FX.w.Part0= self.Character['Left Leg']
		wait(52/60)
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Characters'
			end
		end
		game.Debris:AddItem(FX,1.2)
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
		task.delay(self.Settings3.HitboxSettings.Debris,function()
			if not self.Hit then
				self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill1", self.Settings.Cooldown)
			end
		end)
		if self.Cancelled then
			if Cant ~= nil then
				Cant:Destroy()
			end
			if Jump ~= nil then
				Jump:Destroy()
			end
			if Speed ~= nil then
				Speed:Destroy()
			end
			self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.StartupGrab)
			self.Cancelled = true
			self:Destroy()
			return
		end
		local IFrames = self.Knit.GetService("StateService"):CreateIFrames(self.Character)
		task.delay(.3,function()
			if IFrames ~= nil then
				IFrames:Destroy()
			end
		end)
		if self.Cancelled then
			self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.StartupGrab)
			if Cant ~= nil then
				Cant:Destroy()
			end
			if Jump ~= nil then
				Jump:Destroy()
			end
			if Speed ~= nil then
				Speed:Destroy()
			end
			self.Cancelled = true
			self:Destroy()
			return
		end
		coroutine.resume(coroutine.create(function()
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 50, script.Parent.Name, "M1", "DownSlam2", self.Character, self.Character)
			self:CreateHitbox23(function(Enemy)
				self:TagEnemy3(Enemy,startingPos)
				for _,v in pairs(self.Character:GetChildren()) do
					if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
						v.CollisionGroup = 'Characters'
					end
				end
			end)
		end))
		wait((90/60) - (53/60))
		if Cant ~= nil then
			Cant:Destroy()
		end
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end

		self:Destroy()
	elseif (InAir) or (InAir and self.Character:FindFirstChild("canusetwice")) then
		local seconduse = false
		if self.Character:FindFirstChild("canusetwice") then
			self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill1", self.Settings.Cooldown)
			self.Character:FindFirstChild("canusetwice"):Destroy()
			local holding5 = Instance.new("BoolValue",self.Character)
			holding5.Value = true
			holding5.Name = ("usedtwice")
			game.Debris:AddItem(holding5,100/60)
			seconduse = true
		end
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit1"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit2"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit3"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit4"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Uppercut"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Downslam"])
		self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
		self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill1", self.Settings2.Cooldown)
		--self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Victim)
		self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Startup)
		local Speed1, Jump2 = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, .2), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
		local Speed, Jump
		local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
		FX.Parent=self.Character
		FX.w.Part0= self.Character['Left Leg']
		game.Debris:AddItem(FX,25)
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Visuals2'
			end
		end
		if InAir then
			self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Stuff", "downslamupthing", "downslamvelocity", self.Character, self.Character)	
		end
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Stuff", "downslamupthing", "ENABLEAIRLIMBS", self.Character, self.Character)	
		local IFrames = self.Knit.GetService("StateService"):CreateIFrames(self.Character)
		local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
		self:listenForCancel(function()
			self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Stuff", "downslamupthing", "DISABLEAIRLIMBS", self.Character, self.Character)	
			for _,v in pairs(self.Character:GetChildren()) do
				if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
					v.CollisionGroup = 'Characters'
				end
			end
			if IFrames ~= nil then
				IFrames:Destroy()
			end
			if Jump2 ~= nil then
				Jump2:Destroy()
			end
			if Speed1 ~= nil then
				Speed1:Destroy()
			end

			if Jump ~= nil then
				Jump:Destroy()
			end
			if Speed ~= nil then
				Speed:Destroy()
			end
			if Cant ~= nil then
				Cant:Destroy()
			end
			--for i ,v in pairs(FX2:GetDescendants())do
			--	if v:IsA('Trail') then
			--		v.Enabled = false
			--	end
			--	if v:IsA('ParticleEmitter') then
			--		v.Enabled = false
			--	end
			--	if v:IsA("PointLight") then
			--		game:GetService("TweenService"):Create(v, TweenInfo.new(.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Range = 0}):Play()
			--	end
			--end
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
			--self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Startup)
			if Cant ~= nil then
				Cant:Destroy()
			end
			self.Cancelled = true
			self:Destroy()
		end)
		task.delay(17/60,function()
			if self.Cancelled ~= true then
				local RedFX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Wind15:Clone()
				game.Debris:AddItem(RedFX,4)
				RedFX.Parent = self.Character.Torso
				RedFX:Play()
			end
		end)
		wait(19/60)
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 50, script.Parent.Name, "M1", "Impact25", self.Character, self.Character)
		local RedFX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Wind152:Clone()
		game.Debris:AddItem(RedFX,4)
		RedFX.Parent = self.Character.Torso
		RedFX:Play()
		--if self.Cancelled then
		--	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Startup)
		--	self.Cancelled = true
		--	self:Destroy()
		--	return
		--end
		--	local RedFX2=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Updash1:Clone()
		--	RedFX2.CFrame = self.Character.HumanoidRootPart.CFrame
		--game.Debris:AddItem(RedFX2,2.6)
		--RedFX2.Parent = workspace.Ignore.Effects
		--for i,v in pairs(RedFX2:GetDescendants()) do
		--	if v:IsA('ParticleEmitter') then
		--		v:Emit(v:GetAttribute('EmitCount'))
		--	end
		--end
		local NewJump

		local Pos = self.Character.HumanoidRootPart.Position


		local stophitting = false
		--if game.Players:GetPlayerFromCharacter(self.Character) then
		--	NewJump = game.ReplicatedStorage.Modules.SimJumpPlayerHandler:InvokeClient(game.Players:GetPlayerFromCharacter(self.Character),self.Character.HumanoidRootPart,Vector3.new(0,1.5,0),self.Character.HumanoidRootPart.CFrame.LookVector,5,6.7,1.3,nil,{workspace.Ignore},true)
		--else 
		if seconduse == false then
			NewJump = ApplyHandlr.functioned(self.Character.HumanoidRootPart,Vector3.new(0,1.7,0),self.Character.HumanoidRootPart.CFrame.LookVector,6,7,1.4,nil,{workspace.Ignore},true,.6)
		else
			NewJump = ApplyHandlr.functioned(self.Character.HumanoidRootPart,Vector3.new(0,1.6,0),self.Character.HumanoidRootPart.CFrame.LookVector,5.5,2,1.5,nil,{workspace.Ignore},true,.6)
		end
		--end
		--wait(70/60)
		local start = os.clock()

		repeat
			wait()
		until (NewJump.Complet and (os.clock() - start >= .6))	or (os.clock() - start >= 5)			 
		if self.Cancelled then
			if IFrames ~= nil then
				IFrames:Destroy()
			end
			if Jump ~= nil then
				Jump:Destroy()
			end
			if Speed ~= nil then
				Speed:Destroy()
			end
			if Jump2 ~= nil then
				Jump2:Destroy()
			end
			if Speed1 ~= nil then
				Speed1:Destroy()
			end
			self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Startup)
			if Cant ~= nil then
				Cant:Destroy()
			end
			self.Cancelled = true
			self:Destroy()
			return
		end
		self.Knit.GetService("AnimationService"):adjustSpeed(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Startup,1)
		--self.Knit.GetService("AnimationService"):setTimePos(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Startup1,(36/60))
		--self.Knit.GetService("AnimationService"):adjustSpeed(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Startup1,1)
		wait(2/60)
		local AutoRotate
		if not self.Cancelled then
			AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)

			self:CreateHitbox2(function(Enemy)
				if self.Character.Values:FindFirstChild("Stunned") then return end
				if self.Cancelled then return end
				self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Victim2,1,nil,0)
				self:TagEnemy2(Enemy)
			end)
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 50, script.Parent.Name, "M1", "DownSlam2", self.Character, self.Character)
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 50, "Immortal Blaze", "M1", "groundcrack2", self.Character, self.Character)	
			task.delay(.1,function()
				self.Knit.GetService("CombatService"):FireAllClients(self.Character, 35, "Immortal Blaze", "M1", "mokouleftvfx", self.Character, self.Character)	
			end)
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 35, "Immortal Blaze", "M1", "LASTM1HIGHLIGHT", self.Character, self.Character)	
			local RedFX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Wind152:Clone()
			game.Debris:AddItem(RedFX,4)
			RedFX.Parent = self.Character.Torso
			RedFX:Play()
			--local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouFirstUltAnimVFX.Explode:Clone()
			--RedFX15.Parent = self.Character['HumanoidRootPart']
			--game.Debris:AddItem(RedFX15,6)
			--for i,v in pairs(RedFX15:GetDescendants()) do
			--	if v:IsA('ParticleEmitter') then
			--		v:Emit(v:GetAttribute('EmitCount') or 1)
			--	end
			--end
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, 'Immortal Blaze', "Smash2", "Smash2", self.Character, Skill1.Settings.HitboxSettings.Offset)
		end

		--local RedFX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.kick33swing:Clone()
		--game.Debris:AddItem(RedFX,4)
		--RedFX.Parent = self.Character.HumanoidRootPart
		--RedFX:Play()
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
		--for i ,v in pairs(FX2:GetDescendants())do
		--	if v:IsA('Trail') then
		--		v.Enabled = false
		--	end
		--	if v:IsA('ParticleEmitter') then
		--		v.Enabled = false
		--	end
		--	if v:IsA("PointLight") then
		--		game:GetService("TweenService"):Create(v, TweenInfo.new(.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Range = 0}):Play()
		--	end
		--end
		if Jump2 ~= nil then
			Jump2:Destroy()
		end
		if Speed1 ~= nil then
			Speed1:Destroy()
		end
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Characters'
			end
		end
		if IFrames ~= nil then
			IFrames:Destroy()
		end
		Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 0), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
		wait((95-54)/60)
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Stuff", "downslamupthing", "DISABLEAIRLIMBS", self.Character, self.Character)	
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
		end
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end
		if Cant ~= nil then
			Cant:Destroy()
		end
	end
end

return Skill1
