local Skill2 = {}
Skill2.Settings = {
	Cooldown = 28,
	Damage = 9,
	Damage2 = 15,
	HitboxSettings51 = {
		DelayTime = 0,
		Debris = .15,

		Offset = CFrame.new(0,0,-2.5),
		Size = Vector3.new(15,15,20)
	},
	HitboxSettings = {
		DelayTime = 0,
		Debris = .1,

		Offset = CFrame.new(0,0,0),
		Size = Vector3.new(11,11,11)
	},
} 
Skill2.Settings2 = {
	Cooldown = 28,
	Damage = 12,
	AttackLength = 1.4,

	HitboxSettings = {
		DelayTime = 0,
		Debris = .1,
		Offset = CFrame.new(0,0,-11), --spearplacementis-15 --originaloffsetwas4 --returnsto-11
		Size = Vector3.new(14,14,18)
		--Offset = CFrame.new(0,1.5,-3.5),
		--Size = Vector3.new(7,12,12)
	},
}
Skill2.Settings3 = {
	Cooldown = 25,
	Damage = 3,
	AttackLength = 282/60,

	HitboxSettings = {
		DelayTime = 0,
		Debris = .15,

		Offset = CFrame.new(0,0,-2),
		Size = Vector3.new(9,14,13)
	},
}

function Skill2:CreateHitboxClose()
	self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = self.Character.HumanoidRootPart,
		Offset = self.Settings2.HitboxSettings.Offset,
		Size = self.Settings2.HitboxSettings.Size,
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = false,
		IgnoresBlock = false,
		Visualize = false,
		DelayTime = self.Settings2.HitboxSettings.DelayTime,
		Debris = self.Settings2.HitboxSettings.Debris,
	}, function(Enemy)
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
					--		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Close", self.Character, Enemy)
					--	else
					--		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Far", self.Character, Enemy)
					--	end
					--	--self.Character.Humanoid:MoveTo(self.Character.HumanoidRootPart.Position:Lerp(Enemy.HumanoidRootPart.Position, 0.5))
				elseif State == "Block" then
					--task.delay(.1,function()
					--	self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
					--end)
					--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Miss", self.Character)
					--self.Knit.GetService("MovementService"):AddMovements(self.Character, {WalkSpeed = 0, JumpPower = 0}, .6)
				end
			end)
			return end
		self:TagEnemyClose(Enemy)
	end)
end
function Skill2:CreateHitboxFinisher()
	self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = self.Character.HumanoidRootPart,
		Offset = self.Settings2.HitboxSettings.Offset,
		Size = self.Settings2.HitboxSettings.Size,
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = false,
		IgnoresBlock = false,
		Visualize = false,
		DelayTime = 0,
		Debris = 3/60,
	}, function(Enemy)
		self:TagEnemyFinisher(Enemy)
	end)
end

function Skill2:CreateHitboxClose2(root)
	self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = root,
		Offset = self.Settings2.HitboxSettings.Offset,
		Size = self.Settings2.HitboxSettings.Size,
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = false,
		IgnoresBlock = false,
		Visualize = false,
		DelayTime = self.Settings2.HitboxSettings.DelayTime,
		Debris = self.Settings2.HitboxSettings.Debris,
	}, function(Enemy)
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
					self.HitSomeone = true
					--	self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
					--	self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
					--	self.Knit.GetService("StateService"):RemoveStates(self.Character, {"Dashing"})
					--	if isClose then
					--		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Close", self.Character, Enemy)
					--	else
					--		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Far", self.Character, Enemy)
					--	end
					--	--self.Character.Humanoid:MoveTo(self.Character.HumanoidRootPart.Position:Lerp(Enemy.HumanoidRootPart.Position, 0.5))
				elseif State == "Block" then
					--task.delay(.1,function()
					--	self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
					--end)
					--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Miss", self.Character)
					--self.Knit.GetService("MovementService"):AddMovements(self.Character, {WalkSpeed = 0, JumpPower = 0}, .6)
				end
			end)
			return end

		self:TagEnemyClose2(Enemy,root)
	end)
end

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
local GetLocalCharPosition = require(game.ServerStorage.Touhou.Bridge).GetLocalCharPosition
local massmultiplier = .9999
local AttackPower = 1
local AttackDamage = 100
local AtackRechargeTime = 3
local AttackRecharge = 1/AtackRechargeTime
local AttackSpeed = 280
function Skill2:TagEnemyClose2(Enemy, startingPos)
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
				Stunned = .48,
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
				self.HitSomeone = true
				--	self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
				--	self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
				--	self.Knit.GetService("StateService"):RemoveStates(self.Character, {"Dashing"})
				--	if isClose then
				--		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Close", self.Character, Enemy)
				--	else
				--		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Far", self.Character, Enemy)
				--	end
				--	--self.Character.Humanoid:MoveTo(self.Character.HumanoidRootPart.Position:Lerp(Enemy.HumanoidRootPart.Position, 0.5))
			elseif State == "Block" then
				--task.delay(.1,function()
				--	self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
				--end)
				--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Miss", self.Character)
				--self.Knit.GetService("MovementService"):AddMovements(self.Character, {WalkSpeed = 0, JumpPower = 0}, .6)
			end
		end)
		return end
	--task.delay(.1,function()

	--end)
	local stuntime = 1.5
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,

		KnockbackData  
			=
			{
				KnockbackType = "Velocity",
				MaxForce = Vector3.new(10000,10000,10000),
				Velocity = ((Enemy.HumanoidRootPart.CFrame.Position - self.Character.HumanoidRootPart.CFrame.Position).Unit *(50)) + Vector3.new(0,10,0),
				Time = .2,
			} ,
		StateData = {
			Stunned = stuntime,
			--AutoRotate = 1,
		},

		MovementData = {
			WalkSpeed = 0,
			JumpPower = 0,
			Time = stuntime,
		},

		RagdollData = {
			Time = stuntime,
		},

		BlockData = {			
			HitterOrigin = self.Character.HumanoidRootPart.CFrame,
		},

		Damage = self.Settings.Damage,
		ReactionAnim = (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),
	},function(State)		
		if State == "Hit" then
			self.HitSomeone = true
			--task.delay(.3,function()
			--if self.Character["Right Arm"]:FindFirstChild("remiliaspear") then
			--	self.Character["Right Arm"]:FindFirstChild("remiliaspear")["Impale"]:Play()
			--end
			--if self.Character["Right Arm"]:FindFirstChild("LowRes_Gungir2_Body") then
			--	self.Character["Right Arm"]:FindFirstChild("LowRes_Gungir2_Body")["Impale"]:Play()
			--end
			--end)
			--task.delay(.2,function()
			--if not self.Character:FindFirstChild("m1ing") then
			--self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
			--self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
			--end
			--end)
			--local CombatProfile = self.Knit.GetService("CharacterService"):GetProfile(self.Character).Combats[self.Character:GetAttribute("Combat")]
			--if CombatProfile.Combo <= 3 then
			--	local Clock = os.clock()
			--	CombatProfile.Combo = 1
			--	CombatProfile.LastM1 = Clock
			--end
			--if self.Character:GetAttribute("M1Cooldown") then
			--	self.Character:SetAttribute("M1Cooldown", nil)
			--end
			local sound151 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat["stab"..math.random(1,3)]:Clone()	
			sound151.Parent = Enemy.Torso
			sound151:Play()
			game.Debris:AddItem(sound151,1)
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Gungnir", "M1", "HitPunch2", self.Character, Enemy, 3)
			if self.Character["Right Arm"]:FindFirstChild("remiliaspear") then
				self.Character["Right Arm"]:FindFirstChild("remiliaspear").slash2:Play()
			end
			--if self.Character["Right Arm"]:FindFirstChild("remiliaspear") then
			--	self.Character["Right Arm"]:FindFirstChild("remiliaspear").slash:Play()
			--end
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 15, script.Parent.Name, "M1", "Hit", self.Character, Enemy, math.random(1,3))
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Gungnir", "M1", "Hit", self.Character, Enemy, math.random(1,4))
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Gungnir", "M1", "HitPunch", self.Character, Enemy, math.random(1,4))
			--self.Character.Humanoid:MoveTo(self.Character.HumanoidRootPart.Position:Lerp(Enemy.HumanoidRootPart.Position, 0.5))
		elseif State == "Block" then
		end
	end)
end
function Skill2:TagEnemyClose(Enemy)
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
				Stunned = .48,
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
				self.HitSomeone = true
				--	self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
				--	self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
				--	self.Knit.GetService("StateService"):RemoveStates(self.Character, {"Dashing"})
				--	if isClose then
				--		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Close", self.Character, Enemy)
				--	else
				--		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Far", self.Character, Enemy)
				--	end
				--	--self.Character.Humanoid:MoveTo(self.Character.HumanoidRootPart.Position:Lerp(Enemy.HumanoidRootPart.Position, 0.5))
			elseif State == "Block" then
				--task.delay(.1,function()
				--	self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
				--end)
				--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Miss", self.Character)
				--self.Knit.GetService("MovementService"):AddMovements(self.Character, {WalkSpeed = 0, JumpPower = 0}, .6)
			end
		end)
		return end

	--task.delay(.1,function()

	--end)
	local damgae = .01
	if Enemy.Humanoid.Health <= 8 then
		damgae = 0
	end
	local stuntime = .54
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,

		KnockbackData  
			=
			{
				KnockbackType = "Velocity",
				MaxForce = Vector3.new(10000,0,10000),
				Velocity = self.Character.HumanoidRootPart.CFrame.LookVector*(3), 
				Time = .1,
			} ,
		StateData = {
			Stunned = stuntime,
			--AutoRotate = 1,
		},

		MovementData = {
			WalkSpeed = 0,
			JumpPower = 0,
			Time = stuntime,
		},

		BlockData = {			
			HitterOrigin = self.Character.HumanoidRootPart.CFrame,
		},

		Damage = damgae,
		ReactionAnim = (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),
	},function(State)		
		if State == "Hit" then
			self.HitSomeone = true
			if Enemy:GetAttribute("Ragdoll") then
				self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
			end
			--local sound151 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat["stab"..math.random(1,3)]:Clone()	
			--sound151.Parent = Enemy.Torso
			--sound151.Volume = .6
			--sound151:Play()
			--game.Debris:AddItem(sound151,1)
			local buffvalue = Instance.new("BoolValue",self.Character)
			buffvalue.Value = true
			buffvalue.Name = ("HEARTBREAKCLOSEVARIANTHIT")
			buffvalue:SetAttribute("HeartBreakMovementUnability",true)
			game.Debris:AddItem(buffvalue,.1)
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 65, script.Parent.Name, "M1", "Hit22", self.Character, Enemy, math.random(1,4))
     	elseif State == "Block" then
		end
	end)
end
function Skill2:CreateHitboxStart(callback)
	self:bindClassToAttack(self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = self.Character.HumanoidRootPart,
		Offset = self.Settings.HitboxSettings51.Offset,
		Size = self.Settings.HitboxSettings51.Size,
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = false,
		IgnoresBlock = true,
		Visualize = false,
		DelayTime = self.Settings.HitboxSettings51.DelayTime,
		Debris = self.Settings.HitboxSettings51.Debris,
	}, callback))
end
function Skill2:TagEnemyFinisher(Enemy)
	if self.Character:FindFirstChild("MilleniumVampire") or (Enemy.Humanoid.Health <= 14) then
		if self.Character.Values:FindFirstChild("Stunned") then return end
		--if self.Cancelled then return end
		if self.Hit then return end
		if not self.Character:FindFirstChild("remiliaspearspinlolz") then return end
		local buffval1 = Instance.new("BoolValue",self.Character)
		buffval1.Name = ("SKILL2FINISHERATT")
		buffval1.Value = true
		Enemy:SetAttribute("Cancel", os.clock())
		--if self.Knit.GetService("CounterService"):counter(self.Character, Enemy) then
		--	self.Cancelled = true
		--	self:Destroy()
		--end
		--self.Knit.GetService("RagdollService"):unragdoll(self.Character, true,true)
		if Enemy:GetAttribute("Ragdoll") then
			self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
		end
	self.Hit = Enemy
	--self.Character.Humanoid.AutoRotate = true
	self:AddFor(self.Settings.AttackLength, function()
		self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill1", self.Settings.Cooldown)
	end)
		local grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,0,-4.528)*CFrame.Angles(0,math.rad(180),0))
		--task.delay(.25,function()
	--	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.ReleaseNew)
	--	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.Release2New)
	--end)
	for _,v in pairs(self.Character:GetChildren()) do
		if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
			v.CollisionGroup = 'Characters'
		end
	end
	if self.Character:FindFirstChild("Values") then
		for i,v in pairs(self.Character:FindFirstChild("Values"):GetDescendants()) do
			if v.Name == ("HeartBreakMovementUnability") or v:GetAttribute("HeartBreakMovementUnability") then
				v:Destroy()
			end
		end
	end
	--self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .5)
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 300, "Scarlet Empress", "M1", "SKILL2FINISHERVFX", self.Character, Enemy)	
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	local IFrames = self.Knit.GetService("StateService"):CreateULTIFrames(self.Character)
	task.delay(550/60,function()
		if IFrames ~= nil then
			IFrames:Destroy()
		end
	end)
	local IFramesEnemy = Instance.new("StringValue",Enemy.Values)
	IFramesEnemy.Name = "StunnedBy"
	IFramesEnemy.Value = self.Character.Name
	local AutoRotateEnemy = self.Knit.GetService("StateService"):CreateAutoRotate(Enemy)
	--task.delay(self.Settings.AttackLength2,function()
	--	if IFramesEnemy ~= nil then
	--		IFramesEnemy:Destroy()
	--	end
	--	if AutoRotateEnemy ~= nil then
	--		AutoRotateEnemy:Destroy()
	--	end
	--end)
		local Cant2 = self.Knit.GetService("StateService"):CreateCant(Enemy)
	local StunVal = self.Knit.GetService("StateService"):CreateStun(Enemy)
	local Speed1, Jump2 = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, .005), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(Enemy, 0), self.Knit.GetService("MovementService"):CreateJump(Enemy, 0)

		local finishhim = false			
		if (Enemy.Humanoid.Health <= 14) then
			finishhim = true
		end
		if finishhim == true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 150)
			local enemyunbuffval = Instance.new("BoolValue",Enemy)
			enemyunbuffval.Name = ("NORAGDOLLAFTERDEATH")
			enemyunbuffval.Value = true
		end
		if self.Character:FindFirstChild("MilleniumVampire") then
			self.Character:FindFirstChild("MilleniumVampire"):Destroy()
		end
		--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 120, "Scarlet Empress", "M1", "KISSFIRSTSKILLFINISHER", self.Character, Enemy)	
		local AutoRotate21512
		task.delay(42/60,function()
			AutoRotate21512 = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
		end)
		if Enemy then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .01)
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 1)
			task.delay(18/60,function()
				if Enemy then
					self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 1)
				end		
			end)
			task.delay(44/60,function()
				if Enemy then
					self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
				end				end)
			task.delay(112/60,function()
				if Enemy then
					self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3)
				end	
			end)
		end
		self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.Victim,1,nil,0)
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.HoldClose)
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.ReleaseClose)
		self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.Success,1,nil,0)
		task.delay(391/60,function()
			if Enemy and Enemy:FindFirstChild("Torso") then
			self.Knit.GetService("HitboxService"):createHitbox({
				Caster = self.Character,
				Origin = Enemy.Torso.CFrame,
				Offset = CFrame.new(0,0,0),
				Size = Vector3.new(31,35,31),
				HitboxType = "Box",
				HitType = "OneHit",
				IgnoresRagdoll = true,
				IgnoresBlock = true,
				DelayTime = 0,
				Debris = .2,
			}, function(Enemy5)
				if Enemy5 ~= Enemy then 
					local stuntime = 2

					self.Knit.GetService("DamageService"):Damage({


						Character = self.Character,
						Enemy = Enemy,

						StateData = {
							Stunned = stuntime,
							AutoRotate = stuntime,
						},

						KnockbackData  =
							{
								KnockbackType = "Velocity",
								MaxForce = Vector3.new(10000,10000,10000),
								Velocity = (Enemy.HumanoidRootPart.CFrame.Position - (Enemy.Torso.CFrame.Position and Enemy.Torso.CFrame.Position or self.Character.HumanoidRootPart.CFrame.Position)).Unit *(65) + Vector3.new(0,16,0),
								Time = .15,
							} ,

						MovementData = {
							WalkSpeed = 0,
							JumpPower = 0,
							Time = stuntime,
						},

						RagdollData = {
							Time = stuntime,
						},

						Damage = 20,
					},function(State)

					end)
				end
			end)
			end
			if buffval1 ~= nil then
				buffval1:Destroy()
			end
			if Enemy ~= nil then
				if (Enemy.Humanoid.Health <= 14) then
					finishhim = true
				end
				if finishhim == true then
					Enemy.Humanoid.Health = -15
					local enemyunbuffval = Instance.new("BoolValue",Enemy)
					enemyunbuffval.Name = ("NORAGDOLLAFTERDEATH")
					enemyunbuffval.Value = true
					self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 20)
				end
			end
			if Enemy ~= nil then
				self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 1)
			end	
			coroutine.resume(coroutine.create(function()
				if grab ~= nil then
					grab:Destroy()
				end
			end))
			if Enemy ~= nil then
				if Enemy:GetAttribute("Character") == ("Ice Fairy") then
					local mathq = math.random(1,2)
					if mathq == 1 then
						self.Knit.GetService("CombatService"):FireAllClients(self.Character,250, "Stuff", "downslamupthing", "VOICELINE", self.Character,"SentenceSecondTake","Fairies are really useless.")
					elseif mathq == 2 then
						self.Knit.GetService("CombatService"):FireAllClients(self.Character,250, "Stuff", "downslamupthing", "VOICELINE", self.Character,"SentenceFirstTake","Fairies are really useless.")
					end
				elseif Enemy:GetAttribute("Character") == ("Scarlet Empress") then
					local mathq = math.random(1,2)
					if mathq == 1 then
						self.Knit.GetService("CombatService"):FireAllClients(self.Character,250, "Stuff", "downslamupthing", "VOICELINE", self.Character,"SentenceSecondTake","Vampires don't show up in mirrors, so this is just an afterimage.")
					elseif mathq == 2 then
						self.Knit.GetService("CombatService"):FireAllClients(self.Character,250, "Stuff", "downslamupthing", "VOICELINE", self.Character,"SentenceFirstTake","Vampires don't show up in mirrors, so this is just an afterimage.")
					end
				elseif Enemy:GetAttribute("Character") == ("Phantom Gardener") then
					local mathq = math.random(1,2)
					if mathq == 1 then
						self.Knit.GetService("CombatService"):FireAllClients(self.Character,250, "Stuff", "downslamupthing", "VOICELINE", self.Character,"SentenceSecondTake","I heard a rumor that ghost-based air conditioning is a trend...")
					elseif mathq == 2 then
						self.Knit.GetService("CombatService"):FireAllClients(self.Character,250, "Stuff", "downslamupthing", "VOICELINE", self.Character,"SentenceFirstTake","I heard a rumor that ghost-based air conditioning is a trend...")
					end
				else
					local mathq = math.random(1,2)
					if mathq == 1 then
						self.Knit.GetService("CombatService"):FireAllClients(self.Character,250, "Stuff", "downslamupthing", "VOICELINE", self.Character,"SentenceSecondTake")
					elseif mathq == 2 then
						self.Knit.GetService("CombatService"):FireAllClients(self.Character,250, "Stuff", "downslamupthing", "VOICELINE", self.Character,"SentenceFirstTake")
					end
				end
				if finishhim then
					self.Knit.GetService("AnimationService"):stopAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.Victim,0)
					Enemy.HumanoidRootPart.CFrame = Enemy.HumanoidRootPart.CFrame * CFrame.new(0,11.793,8.834)
				end
				wait()
			end
			if Enemy ~= nil then
				self:TagEnemyThrow(Enemy)
			end
			if Enemy ~= nil then
				if finishhim == true then
					if (self.Character["Right Arm"]:FindFirstChild("remiliaspear")) then
						if (self.Character["Right Arm"]:FindFirstChild("remiliaspear")):FindFirstChild("SKINDATA") then
							if (self.Character["Right Arm"]:FindFirstChild("remiliaspear")):FindFirstChild("SKINDATA").Value == "Longinus" then
								local RedFX=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].asukascream:Clone()
								game.Debris:AddItem(RedFX,5)
								RedFX.Parent = Enemy.HumanoidRootPart
								RedFX:Play()
							end
						end
					end
					self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 500)
					if Enemy:FindFirstChild("Torso") then
						local torso = Enemy:FindFirstChild("Torso")
						torso["Left Hip"]:Destroy()
						torso["Right Hip"]:Destroy()
						torso["Neck"]:Destroy()
						torso["Left Shoulder"]:Destroy()
						torso["Right Shoulder"]:Destroy()
						task.delay(.1,function()
							torso.CollisionGroup = ("Visuals2")
							torso.CanCollide = true
							--local currentProperties = torso.CurrentPhysicalProperties
							--local newProperties = PhysicalProperties.new(.1, currentProperties.Friction, currentProperties.Elasticity)
							--torso.CustomPhysicalProperties = newProperties
							--torso.RootPriority = -127
							local boopyve = Instance.new("BodyVelocity")
							boopyve.Parent = torso
							boopyve.MaxForce = Vector3.new(45000, 45000, 45000)
							boopyve.P = 9
							local throwdirection2 = math.random(1,3)
							if throwdirection2 == 1 then
								boopyve.Velocity = torso.CFrame.RightVector * -math.random(15,25) + Vector3.new(math.random(-12,12), math.random(-12,12), math.random(-12,12))
							elseif throwdirection2 == 2 then
								boopyve.Velocity = torso.CFrame.RightVector * math.random(15,25) + Vector3.new(math.random(-12,12), math.random(-12,12), math.random(-12,12))
							elseif throwdirection2 == 3 then
								boopyve.Velocity = torso.CFrame.LookVector * -math.random(15,25) + Vector3.new(math.random(-12,12), math.random(-12,12), math.random(-12,12))
							end	
							game.Debris:AddItem(boopyve, .25)
						end)
						for i,v in pairs(Enemy:GetChildren()) do
							if v:IsA("BasePart") then
								v.CollisionGroup = ("Visuals2")
								v.CanCollide = true
								--local currentProperties = torso.CurrentPhysicalProperties
								--local newProperties = PhysicalProperties.new(.1, currentProperties.Friction, currentProperties.Elasticity)
								--torso.CustomPhysicalProperties = newProperties
								--torso.RootPriority = -127
								local boopyve = Instance.new("BodyVelocity")
								boopyve.MaxForce = Vector3.new(45000, 45000, 45000)
								boopyve.P = 9
								local throwdirection2 = math.random(1,3)
								if throwdirection2 == 1 then
									boopyve.Velocity = torso.CFrame.RightVector * -math.random(15,25) + Vector3.new(math.random(-12,12), math.random(-12,12), math.random(-12,12))
								elseif throwdirection2 == 2 then
									boopyve.Velocity = torso.CFrame.RightVector * math.random(15,25) + Vector3.new(math.random(-12,12), math.random(-12,12), math.random(-12,12))
								elseif throwdirection2 == 3 then
									boopyve.Velocity = torso.CFrame.LookVector * -math.random(15,25) + Vector3.new(math.random(-12,12), math.random(-12,12), math.random(-12,12))
								end	
								boopyve.Parent = v
								game.Debris:AddItem(boopyve, .25)
							end
						end
					end
					end
				end
			if Jump ~= nil then
				Jump:Destroy()
			end
			if Speed ~= nil then
				Speed:Destroy()
			end
			if StunVal ~= nil then
				StunVal:Destroy()
			end
			if Cant2 ~= nil then
				Cant2:Destroy()
			end
			if IFramesEnemy ~= nil then
				IFramesEnemy:Destroy()
			end
			if AutoRotateEnemy ~= nil then
				AutoRotateEnemy:Destroy()
			end
			if finishhim == true then
				Enemy.Humanoid.Health = 0
end
		end)
		--task.delay(515/60,function()
		--	if buffval1 ~= nil then
		--		buffval1:Destroy()
		--	end
		--end)
		task.delay(545/60,function()
if IFramesEnemy ~= nil then
				IFramesEnemy:Destroy()
			end
			if StunVal ~= nil then
				StunVal:Destroy()
			end
			if Cant2 ~= nil then
				Cant2:Destroy()
			end
			if AutoRotate21512 ~= nil then
				AutoRotate21512:Destroy()
			end
			if AutoRotateEnemy ~= nil then
				AutoRotateEnemy:Destroy()
			end
			if IFrames ~= nil then
				IFrames:Destroy()
			end
			if StunVal ~= nil then
				StunVal:Destroy()
			end
			if Cant2 ~= nil then
				Cant2:Destroy()
			end
			if Jump ~= nil then
				Jump:Destroy()
			end
			if Speed ~= nil then
				Speed:Destroy()
			end
			if grab ~= nil then
				grab:Destroy()
			end
			task.delay(.2,function()
				if Jump2 ~= nil then
					Jump2:Destroy()
				end
			end)
			if Speed1 ~= nil then
				Speed1:Destroy()
			end
			if Cant ~= nil then
				Cant:Destroy()
			end
		end)
end
end
function Skill2:TagEnemyThrow(Enemy)
	--if self.Cancelled then return end
	local stuntime = 2.5
	self.Knit.GetService("DamageService"):Damage({

		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(15000,15000,15000),
			Velocity = Vector3.new(0,47,0),
			Time = .25,
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

		Damage = 20,
	},function(State)
		self.HitSomeone = true

	end)
end
function Skill2:TagEnemyStart(Enemy)
	if self.Cancelled then return end
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
				self.HitSomeone = true
				--	self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
				--	self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
				--	self.Knit.GetService("StateService"):RemoveStates(self.Character, {"Dashing"})
				--	if isClose then
				--		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Close", self.Character, Enemy)
				--	else
				--		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Far", self.Character, Enemy)
				--	end
				--	--self.Character.Humanoid:MoveTo(self.Character.HumanoidRootPart.Position:Lerp(Enemy.HumanoidRootPart.Position, 0.5))
			elseif State == "Block" then
				--task.delay(.1,function()
				--	self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
				--end)
				--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Miss", self.Character)
				--self.Knit.GetService("MovementService"):AddMovements(self.Character, {WalkSpeed = 0, JumpPower = 0}, .6)
			end
		end)
		return end
	if Enemy:GetAttribute("Ragdoll") then
		self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	end
	local stuntime = .7
	local damgae = 3
	if Enemy.Humanoid.Health <= 8 then
		damgae = 0
	end
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,

		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(15000,0,15000),
			Velocity = self.Character.HumanoidRootPart.CFrame.LookVector*(70), 
			Time = .2,
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

		Damage = damgae,
	},function(State)
		if State == "Hit" then
			self.HitSomeone = true
		end
	end)
end
function Skill2:Hold(InAir,torso)
	--if self.Character.Values:FindFirstChild("RagdollSuperArmor") then return end
	if self.Character:FindFirstChild("Values") then
		for i,v in pairs(self.Character:FindFirstChild("Values"):GetDescendants()) do
			if v.Name == ("HeartBreakMovementUnability") or v:GetAttribute("HeartBreakMovementUnability") then
				v:Destroy()
			end
		end
	end
	local Val5 = Instance.new("NumberValue")
	Val5.Name = "STOPLUNGE"
	Val5.Parent = self.Character.Values
	Val5:SetAttribute("HeartBreakMovementUnability",true)
	game.Debris:AddItem(Val5,10/60)
	--local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	--game.Debris:AddItem(Cant,10/60)
	self.Character:SetAttribute("CancelDash", os.clock())
	self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit1"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit2"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit3"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit4"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Uppercut"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Downslam"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.Release2)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.Release)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.CloseVariant)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.Startup)
	local Val2 = Instance.new("NumberValue")
	Val2.Name = "CantHeartBreak"
	Val2.Parent = self.Character.Values
	Val2:SetAttribute("HeartBreakMovementUnability",true)
	if not InAir then
		local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 4), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
		Jump:SetAttribute("HeartBreakMovementUnability",true)
		Speed:SetAttribute("HeartBreakMovementUnability",true)
		local connection1
		local attacking = true
		local cancelled = false
		local cancelled25 = false
		local buffvalue = Instance.new("BoolValue",self.Character)
		buffvalue.Value = true
		buffvalue.Name = ("HEARTBREAKCLOSEVARIANTHOLD")
		buffvalue:SetAttribute("HeartBreakMovementUnability",true)
		game.Debris:AddItem(buffvalue,400/60)
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "M1", "FOVCHANGE2", self.Character, self.Character)	
		task.delay(2.5/60,function()
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 65, "Scarlet Empress", "M1", "CrokuranSponsorSpinNOSOUND", self.Character, self.Character)	
		end)
		self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.HoldClose)
		local function cancel(typeo2f)
			if cancelled25 == false then
				cancelled25 = true
				if connection1 ~= nil then
					connection1:Disconnect()
				end
				if buffvalue.Parent ~= nil then
					buffvalue:Destroy()
				end
				if Val2.Parent ~= nil then
					Val2:Destroy()
				end
				if Jump.Parent ~= nil then
					Jump:Destroy()
				end
				if Speed.Parent ~= nil then
					Speed:Destroy()
				end
				--attacking = false
				local waitoo = 3/60
				if typeo2f == "forced" then
					local waitoo = 0
				end
				if typeo2f ~= "forced" then
					self:CreateHitboxFinisher()
				end
				coroutine.resume(coroutine.create(function()
					task.delay(3/60,function()
						local finished = false
						if self.Character:FindFirstChild("SKILL2FINISHERATT") then
							finished = true
						end
						if typeo2f ~= "forced" then
							repeat wait() until not self.Character:FindFirstChild("SKILL2FINISHERATT") 
						end
						self.Knit.GetService("AnimationService"):stopAnimation(self.Character,game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.HoldClose)
						cancelled = true
						attacking = false
						if self.Character:FindFirstChild("remiliaspearspinlolz") then
							self.Character:FindFirstChild("remiliaspearspinlolz"):Destroy()
						end
						if self.Character:FindFirstChild("MilleniumVampire") then
							self.Character:FindFirstChild("MilleniumVampire"):Destroy()
						end
						if typeo2f ~= "forced" then
							if finished == false then
								self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.ReleaseClose)
							end
						end
						self:Destroy()
					end)
				end))
--				if remiliaspearspin then
--					local waittime = .12
--					game:GetService("TweenService"):Create(remiliaspearspin.HumanoidRootPart,TweenInfo.new(waittime,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{CFrame = self.Character.HumanoidRootPart.CFrame}):Play()
--					game:GetService("TweenService"):Create(remiliaspearspin.remiliaspear.spinloop,TweenInfo.new(.5,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = 0}):Play()
--					self.Knit.GetService("CombatService"):FireAllClients(self.Character, 120, self.Character:GetAttribute("Character"), "M1", "HEARTBREAKSTARTUPSFX2END", self.Character)
--					task.delay(waittime,function()
--						--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 65, "Scarlet Empress", "M1", "GROUNDPULL", self.Character, self.Character)	
--						self.Knit.GetService("CombatService"):FireAllClients(self.Character, 65, "Scarlet Empress", "M1", "SHINE1PARTICLE", self.Character, self.Character)	
--						coroutine.resume(coroutine.create(function()
--							if remiliaspearspin then
--								for i,v in pairs(remiliaspearspin:GetDescendants()) do
--									if v:IsA("BasePart") then
--										v.Transparency = 1
--									end
--								end
--							end
--						end))
--						if (self.Character["Right Arm"]:FindFirstChild("remiliaspear")) then
--							for i,v in pairs(self.Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
--								if v:IsA("BasePart") and v.Transparency == 5 then
--									v.Transparency = 0
--								end
--							end
--						end
--					end)
--					game.Debris:AddItem(remiliaspearspin,1)
--						for i,v in pairs(remiliaspearspin:GetDescendants()) do
--							if v:IsA('ParticleEmitter') then
--								v:Destroy()
--							end
--							--if v:IsA('BasePart') then
--							--	game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
--							--end
--							if v:IsA('Decal') then
--								v.Transparency = 1
--							end
--							if v:IsA('Trail') then
--								v.Enabled = false
--								v.Lifetime = .3
--							end
--							if v:IsA('Beam') then
--								game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0}):Play()
--								game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width1 = 0}):Play()
--							end
--							if v:IsA('PointLight') then
--								game:GetService("TweenService"):Create(v,TweenInfo.new(.4,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Range = 0}):Play()
--							end
--						end
--end
				self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill2", self.Settings.Cooldown)
				self.Knit.GetService("AttackService"):destroyBodyGyroHold(self.Character,"FullCam")
				self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
				if self.Character:FindFirstChild("Values") then
					for i,v in pairs(self.Character:FindFirstChild("Values"):GetDescendants()) do
						if v.Name == ("HeartBreakMovementUnability") or v:GetAttribute("HeartBreakMovementUnability") then
							v:Destroy()
						end
					end
				end
				self.Cancelled = true
				self:Destroy()
			end
		end
		task.delay(155/60, function()
			if cancelled == false or cancelled25 == false then
				attacking = false
				cancel("normal")
				attacking = false
				self:Destroy()
				return
			end
		end)
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 120, self.Character:GetAttribute("Character"), "M1", "HEARTBREAKSTARTUPSFX2", self.Character)
		task.delay(32/60, function()
			if cancelled == false or cancelled25 == false then
				coroutine.resume(coroutine.create(function()
					if self.Character:FindFirstChild("remiliaspearspinlolz") then
						self.Character:FindFirstChild("remiliaspearspinlolz"):Destroy()
					end
					local buffvalue = Instance.new("BoolValue",self.Character)
					buffvalue.Value = true
					buffvalue.Name = ("remiliaspearspinlolz")
					--buffvalue:SetAttribute("HeartBreakMovementUnability",true)
					self.Knit.GetService("CombatService"):FireAllClients(self.Character, 120, self.Character:GetAttribute("Character"), "M1", "REMILIASPEARSPIN", self.Character)
					self:CreateHitboxStart(function(Enemy)
						self:TagEnemyStart(Enemy)
					end)
					--remiliaspearspin = game.ServerStorage.ModelStorage.SpinningRemiliaSpear:Clone()
					--remiliaspearspin.Parent = workspace.Ignore.Effects
					--remiliaspearspin.HumanoidRootPart.CFrame = self.Character.HumanoidRootPart.CFrame
					--local shide = remiliaspearspin
					--local animation = shide.MainAnimation
					--local humanoid = shide.AnimationController
					--local mainAnim = humanoid:LoadAnimation(animation)
					--mainAnim:Play()
					--mainAnim:AdjustSpeed(1)
					--coroutine.resume(coroutine.create(function()
					--	for i,v in pairs(remiliaspearspin.remiliaspear["windred"]:GetDescendants()) do
					--		coroutine.resume(coroutine.create(function()
					--			if v:IsA('ParticleEmitter') then
					--				while attacking do
					--					wait(1/v.Rate)
					--					v:Emit(2)
					--				end
					--			end
					--		end))
					--	end
					--end))
					--if (self.Character["Right Arm"]:FindFirstChild("remiliaspear")) then
					--	for i,v in pairs(self.Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
					--		if v:IsA("BasePart") and v.Transparency == 0 then
					--			v.Transparency = 5
					--		end
					--	end
					--end
					--game:GetService("TweenService"):Create(remiliaspearspin.remiliaspear.spinloop,TweenInfo.new(.4,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Volume = .5}):Play()
					while attacking do
						if self.Hit then return end
						if cancelled == false then
							--game:GetService("TweenService"):Create(remiliaspearspin.HumanoidRootPart,TweenInfo.new(.06,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{CFrame = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-15)}):Play()

							--self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.ReleaseClose)
							--self.Character.gunganire.Value = false
							--local timer = 200/60
							--local attacking = true
							--coroutine.resume(coroutine.create(function()
							--	while attacking do
									self:CreateHitboxClose()
									--task.wait(.06)
							--	end
							--end))
							--coroutine.resume(coroutine.create(function()
							--	task.delay(timer,function()
							--		attacking = false
							--		game.Debris:AddItem(remiliaspearspin,1)
							--		for i,v in pairs(remiliaspearspin:GetDescendants()) do
							--			if v:IsA('ParticleEmitter') then
							--				v.Enabled = false
							--			end
							--			if v:IsA('BasePart') then
							--				game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
							--			end
							--			if v:IsA('Decal') then
							--				v.Transparency = 1
							--			end
							--			if v:IsA('Trail') then
							--				v.Enabled = false
							--				v.Lifetime = .3
							--			end
							--			if v:IsA('Beam') then
							--				game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0}):Play()
							--				game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width1 = 0}):Play()
							--			end
							--			if v:IsA('PointLight') then
							--				game:GetService("TweenService"):Create(v,TweenInfo.new(.4,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Range = 0}):Play()
							--			end
							--		end
							--		self:CreateHitboxClose2(remiliaspearspin.HumanoidRootPart)
							--		repeat wait() until not self.Character.Values:FindFirstChild("Cant")
							--		if (self.Character["Right Arm"]:FindFirstChild("remiliaspear")) then
							--			for i,v in pairs(self.Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
							--				if v:IsA("BasePart") and v.Transparency == 5 then
							--					v.Transparency = 0
							--				end
							--			end
							--			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 30, "Scarlet Empress", "M1", "GUNGNIREXPLODESPAWN", self.Character["Right Arm"]:FindFirstChild("remiliaspear"))	
							--		end
							--		self.Character.gunganire.Value = true
							--	end)
							--end))
							--self:CreateHitboxClose(self.Character.HumanoidRootPart)
						end
						task.wait(.06)
					end
				end))
			elseif cancelled == true then
				attacking = false
			end
		end)
		connection1 = self.Character.Values.ChildAdded:Connect(function(child)
			if child.Name == ("Cant") then
				if child:GetAttribute("skill2cant") then
					cancel("normal")
				else
					cancel("forced")
				end
			end
		end)
		self:listenForCancel(function()
			if Val2 ~= nil then
				Val2:Destroy()
			end
			cancel("forced")
		end)
	else
		local Val23 = Instance.new("NumberValue")
		Val23.Name = "INAIRREMILIAWINGS"
		Val23.Parent = self.Character
		Val23:SetAttribute("HeartBreakMovementUnability",true)
		local sound1=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.wingloopsfx:Clone()
		sound1.Parent = self.Character.HumanoidRootPart
		sound1:Play()
		game.Debris:AddItem(sound1,300/60)
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 120, "Scarlet Empress", "M1", "STARTHEARTBREAKRANGED", self.Character)	
		self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.Hold)
	self.Knit.GetService("AttackService"):createBodyGyroHold(self.Character,"FullCam")
	if self.Character.Values:FindFirstChild("Cant") then return end
	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 6), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	Jump:SetAttribute("HeartBreakMovementUnability",true)
	Speed:SetAttribute("HeartBreakMovementUnability",true)
	local startCFrame = self.Character.HumanoidRootPart.CFrame

	self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "M1", "HEARTBREAKVELOCITY", self.Character, self.Character)	

	self:listenForCancel(function()
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end
			if Val2 ~= nil then
				Val2:Destroy()
			end
			if Val23 ~= nil then
				Val23:Destroy()
			end
		self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill2", self.Settings.Cooldown)
		self.Knit.GetService("AttackService"):destroyBodyGyroHold(self.Character,"FullCam")
		self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character,game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.Hold)
		self.Cancelled = true
		self:Destroy()
	end)
end
end


function Skill2:TagEnemy(Enemy,Projectile)
	local stunnedtime = 1.8
	local maindamage = 20
	if Enemy.Humanoid.Health <= maindamage then
		if (self.Character["Right Arm"]:FindFirstChild("remiliaspear")) then
			if (self.Character["Right Arm"]:FindFirstChild("remiliaspear")):FindFirstChild("SKINDATA") then
				if (self.Character["Right Arm"]:FindFirstChild("remiliaspear")):FindFirstChild("SKINDATA").Value == "Longinus" then
					local RedFX=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].asukascream:Clone()
					game.Debris:AddItem(RedFX,5)
					RedFX.Parent = Enemy.HumanoidRootPart
					RedFX:Play()
				end
			end
		end
	end
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,
		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(10000,10000,10000),
			Velocity = ((Enemy.HumanoidRootPart.CFrame.Position - (Projectile.CFrame.Position + Vector3.new(0,-16,0))).Unit *(60)) + Vector3.new(0,16,0), 
			Time = .2,
		},
		RagdollData =  {
			Time = stunnedtime,
		},
		StateData = {
			Stunned = stunnedtime,
			AutoRotate = stunnedtime,
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
			Time = stunnedtime,
		},

		BlockData = {			
			HitterOrigin = Projectile.CFrame,
		},
		NoDMGBuffs = true,
		Damage = maindamage,
	},function(State)		
		if State == "Hit" then
			self.Hit = true
			local buffvalue = Instance.new("BoolValue",Enemy)
			buffvalue.Value = true
			buffvalue.Name = ("HITWITHRANGEDHEARTBREAK")
			game.Debris:AddItem(buffvalue,1.5)
		elseif State == "Block" then
		end
	end)
end

function Skill2:Explosion(ProjectilePart,attacking,destroy,instantdestroy,hitpart,finisher,cfran)
coroutine.resume(coroutine.create(function()
--if self.Finisher ~= true then
--	coroutine.resume(coroutine.create(function()
--		if attacking == true then
--				if destroy == true then
					--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 450, "Scarlet Empress", "M1", "AIMEDEXPL2", ProjectilePart)
					--game:GetService("TweenService"):Create(ProjectilePart.gungnirloop,TweenInfo.new(.35,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Volume = 0}):Play()
					--if not finisher then
						--coroutine.resume(coroutine.create(function()
						--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, script.Parent.Name, "M1", "heartbreakland", self.Character, ProjectilePart.heartbreak,hitpart)
						--end))
	local MaxRange = 200
	--local GoalPosition = (ProjectilePart * CFrame.new(0,0,-MaxRange)).Position
	local goalpos2 = self.Character.HumanoidRootPart.CFrame.LookVector * MaxRange
	local goalpos3 = (ProjectilePart * CFrame.new(0,0,-MaxRange)).Position
	--local Direction = (GoalPosition - self.Character.HumanoidRootPart.Position).Unit
	--local Distance = (GoalPosition - self.Character.HumanoidRootPart.Position).Magnitude
	--local TargetPos = self.Character.HumanoidRootPart.Position + Direction * MaxRange 

	--if Distance > MaxRange then
	--	TargetPos =  self.Character.HumanoidRootPart.Position + Direction * MaxRange 
	--else
	--	TargetPos = GoalPosition
	--end
	--local DetectedFloor = RayCastOnMap(TargetPos,Vector3.new(0,-TargetPos*2,0),{workspace.Ignore})
	--if DetectedFloor then
	--	if TargetPos ~= DetectedFloor then
	--		TargetPos = DetectedFloor + Vector3.new(0,2,0)
	--	end
	--else
	--	TargetPos = GoalPosition
	--end
		local ray = Ray.new(self.Character.HumanoidRootPart.Position, goalpos2)
		local part, hitPosition = workspace:FindPartOnRay(ray, workspace.Ignore.Effects)
		local chosen = nil
		if part then 
			chosen = CFrame.new(hitPosition)
		else
			chosen = CFrame.new(goalpos3)
		end
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "M1", "KNOCKBACKRELATIVETO",self.Character,chosen)	
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 370, "Scarlet Empress", "M1", "HEARTBREAKLOOPVFX2", chosen,self.Character,self.Character.HumanoidRootPart.CFrame)	
		local time15 = ((self.Character.HumanoidRootPart.Position - chosen.Position).magnitude) / 170
		wait(time15)
	local rootpart51 = Instance.new("Part")
	rootpart51.Parent = workspace.Ignore.Effects
	rootpart51.Anchored = true
	rootpart51.Size = self.Character.HumanoidRootPart.Size
		rootpart51.CFrame = chosen
		rootpart51.CanCollide = false
	rootpart51.Transparency = 1
	rootpart51.Name = ("DECOYETR")
	game.Debris:AddItem(rootpart51,1)
						--ProjectilePart.Anchored = true
						--ProjectilePart.CFrame = cfran
					--if hitpart.Size >= Vector3.new(150,150,150) then
					--	ProjectilePart.Position = hitpart:GetClosestPointOnSurface((ProjectilePart.CFrame * CFrame.new(0,0,-40)).Position)
					--else
						--ProjectilePart.Position = hitpart:GetClosestPointOnSurface((ProjectilePart.CFrame * CFrame.new(0,0,-50)).Position)
					--end
					--local holding5 = Instance.new("BoolValue")
					--holding5.Value = true
					--holding5.Name = ("FINISHERKNIFE")
					--holding5.Parent = ProjectilePart
					--end
					--if finisher then
					--	self.Finisher = true
					--	ProjectilePart.Velocity = Vector3.new(0,0,0)
					--end

					self.Knit.GetService("HitboxService"):createHitbox({
						Caster = self.Character,
						Origin = rootpart51,
						Offset = CFrame.new(0,0,0),
						Size = Vector3.new(50,50,50),
						HitboxType = "Box",
						HitType = "OneHit",
						IgnoresRagdoll = true,
						IgnoresIFrames = true,
						IgnoresBlock = false,
						DelayTime = 0,
						Debris = .15,
						ReactionAnim = game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,3)],
					}, function(Enemy)
						self:TagEnemy(Enemy,rootpart51)
					end)
					--for i,v in pairs(ProjectilePart:GetDescendants()) do
					--	if v:IsA('Trail') then
					--		v.Enabled = false
					--	end
					--	if v:IsA('ParticleEmitter') then
					--		v.Enabled = false
					--	end
					--end
				--local timer = 5 
				--if instantdestroy == true then
				--	timer = 0 
				--else
				--	local RedFX=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.HitHeartBreak:Clone()	
				--	RedFX.Parent = workspace.Ignore.Effects
				--	RedFX.CFrame = ProjectilePart.CFrame
				--	RedFX.VFX["h"..math.random(1,5)]:Play()
				--	game.Debris:AddItem(RedFX,4)
				--end
				--ProjectilePart.heartbreak.Flare12emit.Enabled = false
				--ProjectilePart.heartbreak.Flare13emit.Enabled = false
				--ProjectilePart["6"].Enabled = false
				--ProjectilePart.Other.Shards.Enabled = false
				--ProjectilePart.Anchored = true
--if not finisher then
							--game.Debris:AddItem(ProjectilePart,5)
--							game:GetService("TweenService"):Create(ProjectilePart,TweenInfo.new(.8,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
--							for i,v in pairs(ProjectilePart:GetDescendants()) do
--								if v:IsA('ParticleEmitter') then
--									v.Enabled = false
--								end
--								if v:IsA('BasePart') then
--								game:GetService("TweenService"):Create(v,TweenInfo.new(.8,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
--								end
--								if v:IsA('Decal') then
--									v.Transparency = 1
--								end
--								if v:IsA('Trail') then
--									v.Enabled = false
--									v.Lifetime = .3
--								end
--								if v:IsA('Beam') then
--									game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0}):Play()
--									game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width1 = 0}):Play()
--								end
--								if v:IsA('PointLight') then
--									game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Range = 0}):Play()
--								end
--							end
--					end
			--end
		--end
	--end))
--end
end))
end


function Skill2:CreateHitbox(callback)
	self:bindClassToAttack(self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = self.Character.HumanoidRootPart,
		Offset = self.Settings2.HitboxSettings.Offset,
		Size = self.Settings2.HitboxSettings.Size,
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = false,
		IgnoresBlock = false,
		Visualize = false,
		DelayTime = self.Settings2.HitboxSettings.DelayTime,
		Debris = self.Settings2.HitboxSettings.Debris,
	}, callback))
end
function Skill2:CreateHitbox2(callback)
	self:bindClassToAttack(self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = self.Character.HumanoidRootPart,
		Offset = self.Settings3.HitboxSettings.Offset,
		Size = self.Settings3.HitboxSettings.Size,
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = false,
		IgnoresBlock = true,
		Visualize = false,
		DelayTime = self.Settings3.HitboxSettings.DelayTime,
		Debris = self.Settings3.HitboxSettings.Debris,
	}, callback))
end

local rayparams = RaycastParams.new()
rayparams.FilterType = Enum.RaycastFilterType.Exclude
rayparams.FilterDescendantsInstances = {workspace.Ignore}

function Skill2:Release(InAir)	
	--if self.Character.Values:FindFirstChild("RagdollSuperArmor") then return end
	if self.Cancelled then return end
	if self.Character.Values:FindFirstChild("Stunned") then return end
	if self.Character.Values:FindFirstChild("Cant") then return end
	task.delay(.2,function()
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character,game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.Hold)
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character,game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.HoldClose)
	end)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.StartupNew)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.Startup)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit1"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit2"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit3"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit4"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Uppercut"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Downslam"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.Release2)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.Release)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.CloseVariant)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.Startup)
	if self.Character.HumanoidRootPart:FindFirstChild("wingloopsfx") then
		local addtime = 50/60
		game.Debris:AddItem(self.Character.HumanoidRootPart:FindFirstChild("wingloopsfx"),addtime)
		game:GetService("TweenService"):Create(self.Character.HumanoidRootPart:FindFirstChild("wingloopsfx"),TweenInfo.new(addtime,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Volume = 0}):Play()
	end
	if self.Character:FindFirstChild("HEARTBREAKCLOSEVARIANTHOLD") then
		local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 6), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
		--local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
		local Cant = Instance.new("BoolValue")
		Cant.Name = "Cant"
		Cant.Value = true
		Cant:SetAttribute("skill2cant",true)
		Cant.Parent = self.Character.Values
		if self.Character:FindFirstChild("HEARTBREAKCLOSEVARIANTHOLD") then
			self.Character:FindFirstChild("HEARTBREAKCLOSEVARIANTHOLD"):Destroy()
		end		--self.Character.gunganire.Value = false
		local attacking = true
		task.delay(29/60,function()
			if Cant.Parent ~= nil then
				Cant:Destroy()
			end	
			if Jump.Parent ~= nil then
				Jump:Destroy()
			end
			if Speed.Parent ~= nil then
				Speed:Destroy()
			end	
		end)
	else
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 100, self.Character:GetAttribute("Character"), "M1", "HEARTBREAKTHROWSFX", self.Character)
		if self.Character:FindFirstChild("Values") then
			for i,v in pairs(self.Character:GetDescendants()) do
				if v.Name == ("HeartBreakMovementUnability") or v:GetAttribute("HeartBreakMovementUnability") then
					v:Destroy()
				end
			end
		end
		local function flare()
			if self.Cancelled ~= true then
				self.Knit.GetService("CombatService"):FireAllClients(self.Character, 40, "Scarlet Empress", "M1", "FLARE", self.Character, self.Character)	
			end
		end
		local anim2 = game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.NewRelease


		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 40, "Scarlet Empress", "M1", "GUNGNIRSOUND", self.Character, self.Character)	

		task.delay(3/60,function()
			flare()
		end)

		local oldCF = self.Character.HumanoidRootPart.CFrame
		local IFrames = self.Knit.GetService("StateService"):CreateULTIFrames(self.Character)

		self.Knit.GetService("AnimationService"):playAnimation(self.Character,anim2)
		local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 6), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
		local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
		local holding = Instance.new("BoolValue",self.Character)
		holding.Value = true
		holding.Name = ("heartbreakingfr")
		game.Debris:AddItem(holding,1)
		self:listenForCancel(function()	
			if Cant ~= nil then
				Cant:Destroy()
			end
			if IFrames ~= nil then
				IFrames:Destroy()
			end
			self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill2", self.Settings.Cooldown)
			self.Knit.GetService("AttackService"):destroyBodyGyroHold(self.Character,"FullCam")
			self.Knit.GetService("AnimationService"):stopAnimation(self.Character,anim2)
			self.Cancelled = true
			if Jump ~= nil then
				Jump:Destroy()
			end
			if Speed ~= nil then
				Speed:Destroy()
			end	
			self:Destroy()
		end)
		local startCFrame = self.Character.HumanoidRootPart.CFrame
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {workspace.Ignore.Effects,self.Character}		

		local wait1 = 47
		wait(wait1/60)

		if self.Cancelled then
			return
		end
		local attacking = true	
		local hitable = {}
		if (self.Character["Right Arm"]:FindFirstChild("remiliaspear")) then
			for i,v in pairs(self.Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
				if v:IsA("BasePart") and v.Transparency == 0 then
					v.Transparency = 5
				end
			end
		end
		----for i,v in pairs(projectile:GetChildren()) do
		----	if v.Name:match("launch") then
		----		for ie,ve in pairs(v:GetDescendants()) do
		----			if ve:IsA('ParticleEmitter') then
		----				ve:Emit(ve:GetAttribute("EmitCount") or 1)
		----			end
		----		end
		----	end
		----end
		--coroutine.resume(coroutine.create(function()
		--	projectile.Changed:Connect(function()
		--		if projectile.Anchored == true then
		--			attacking = false
		--		end
		--	end)
		--	local dropphy = Vector3.new(0,0,0)
		--	--local factor = .3
		--	task.delay(2,function()
		--		if attacking == true then
					self:Explosion(self.Character.HumanoidRootPart.CFrame,attacking,true,true)
					attacking = false
			--	end		
			--end)

		--	local connection2
		--	connection2 = projectile.heartbreaksecondhitbox.Touched:Connect(function(part)
		--		if not part:IsDescendantOf(workspace.Ignore) then
		--			if not part:IsDescendantOf(projectile) then
		--				if not part:IsDescendantOf(self.Character) then
		--					connection2:Disconnect()
		--					projectile.CFrame = projectile.CFrame
		--					self:Explosion(projectile,attacking,true,false,part,false,projectile.CFrame)
		--					attacking = false
		--				end
		--			end
		--		end
		--	end)
		--end))
		self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill2", self.Settings.Cooldown)
		--if AutoRotate ~= nil then
		--	AutoRotate:Destroy()
		--end
		if IFrames ~= nil then
			IFrames:Destroy()
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
		self.Knit.GetService("AttackService"):destroyBodyGyroHold(self.Character,"FullCam")
		if (self.Character["Right Arm"]:FindFirstChild("remiliaspear")) then
			for i,v in pairs(self.Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
				if v:IsA("BasePart") and v.Transparency == 5 then
					v.Transparency = 0
				end
			end
		end
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 70, script.Parent.Name, "M1", "speartween1", self.Character)
		if Cant ~= nil then
			Cant:Destroy()
		end
		self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
		self.Knit.GetService("AnimationService"):adjustSpeed(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.NewRelease,1.8)

		self:Destroy()
	end
end

return Skill2
