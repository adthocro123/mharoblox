local Skill1 = {}
Skill1.Settings = {
	Cooldown = 30,
	Damage = 12,
	AttackLength = (196/60),
	AttackLength2 = (100/60),

	HitboxSettings = {
		DelayTime = .2,
		Debris = .14,

		Offset = CFrame.new(0,2.5,-3.2),
		Size = Vector3.new(10,5,20)
	},
	magnitudeForClose = 20,
}
Skill1.Settings2 = {
	Cooldown = 30,
	Damage = 12,
	AttackLength = 1.4,

	HitboxSettings = {
		DelayTime = 0,
		Debris = .15,

		Offset = CFrame.new(0,4.5,-6),
		Size = Vector3.new(15,9,24),
		Size2 = Vector3.new(15,15,24)
	},
}

function Skill1:CreateHitbox(callback)
	if self.Character.Values:FindFirstChild("Stunned") then return end
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
		PerfectTrack = true,
		DelayTime = self.Settings2.HitboxSettings.DelayTime,
		Debris = self.Settings2.HitboxSettings.Debris,
	}, callback))
end
function Skill1:CreateHitbox2(callback)
	if self.Character.Values:FindFirstChild("Stunned") then return end
	self:bindClassToAttack(self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = self.Character.HumanoidRootPart,
		Offset = self.Settings2.HitboxSettings.Offset,
		Size = self.Settings2.HitboxSettings.Size2,
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = false,
		IgnoresBlock = false,
		Visualize = false,
		DelayTime = 0,
		Debris = .1,
	}, callback))
end
function Skill1:TagEnemy(Enemy)
	if self.Character.Values:FindFirstChild("Stunned") then return end
	if self.Cancelled then return end
	if self.Hit then return end
	if self.Cancelled then return end
	if (Enemy.Values:FindFirstChild("RagdollSuperArmor")) or (Enemy:FindFirstChild("MilleniumVampire")) then return end
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
	Enemy:SetAttribute("Cancel", os.clock())

	if self.Knit.GetService("CounterService"):counter(self.Character, Enemy) then
		self.Cancelled = true
		self:Destroy()
	end
	--self.Knit.GetService("CombatService"):FireClient(Enemy, Enemy, "Scarlet Empress", "M1", "REDVIGNETTE", Enemy, Enemy)	

	--self.Knit.GetService("RagdollService"):unragdoll(self.Character, true,true)
	self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	self.Hit = Enemy
	--self.Character.Humanoid.AutoRotate = true
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 100, self.Character:GetAttribute("Character"), "M1", "SPEEDBLITZVFXLOLZHIT", self.Character,Enemy)
	self:AddFor(self.Settings.AttackLength, function()
		self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill1", self.Settings.Cooldown)
	end)
	local grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,0,-3.32)*CFrame.Angles(0,math.rad(180),0))
	task.delay(1,function()
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.Release)
	end)
	self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 20)
	local function groundslam()
		if self.Cancelled ~= true then
			self.Knit.GetService("HitboxService"):createHitbox({
				Caster = self.Character,
				Origin = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-5),
				Offset = CFrame.new(0,0,0),
				Size = Vector3.new(15,15,18),
				HitboxType = "Box",
				HitType = "OneHit",
				IgnoresRagdoll = true,
				IgnoresBlock = true,
				DelayTime = 0,
				Debris = .1,
			}, function(Enemy5)
				if Enemy5 == Enemy then return end
				self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy5, 20)
				self:TagEnemyThrow(Enemy5)
			end)
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 5)
		end
	end
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	local IFrames = self.Knit.GetService("StateService"):CreateULTIFrames(self.Character)
	local pos 

	task.delay(self.Settings.AttackLength,function()
		if IFrames ~= nil then
			IFrames:Destroy()
		end
	end)
	local IFramesEnemy = self.Knit.GetService("StateService"):CreateULTIFrames(Enemy)
	local AutoRotateEnemy = self.Knit.GetService("StateService"):CreateAutoRotate(Enemy)
	local AutoRotate = nil
	local Cant2 = self.Knit.GetService("StateService"):CreateCant(Enemy)
	local StunVal = self.Knit.GetService("StateService"):CreateStun(Enemy)
	--game.Debris:AddItem(StunVal,self.Settings.AttackLength2 + .15)
	local Speed1, Jump2 = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, .01), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	game.Debris:AddItem(Speed1, self.Settings.AttackLength)
	game.Debris:AddItem(Jump2, self.Settings.AttackLength + .15)

	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(Enemy, 0), self.Knit.GetService("MovementService"):CreateJump(Enemy, 0)
	game.Debris:AddItem(Speed, self.Settings.AttackLength2 + .15)
	game.Debris:AddItem(Jump, self.Settings.AttackLength2 + .15)
local racyast = false
	task.delay(100/60,function()
		coroutine.resume(coroutine.create(function()
			groundslam()
		end))
		if AutoRotateEnemy ~= nil then
			AutoRotateEnemy:Destroy()
		end
		if IFramesEnemy ~= nil then
			IFramesEnemy:Destroy()
		end
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
		end
		self:TagEnemyThrow(Enemy)
		if grab ~= nil then
			grab:Destroy()
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
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Immortal Blaze", "Skill3Drill", "LOLDASH2", self.Character, self.Character)	
	end)
	self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill1.Victim)
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill1.Success)
	task.delay(self.Settings.AttackLength,function()
		if self.Cancelled then return end
		if IFramesEnemy ~= nil then
			IFramesEnemy:Destroy()
		end
		if AutoRotateEnemy ~= nil then
			AutoRotateEnemy:Destroy()
		end
		if IFrames ~= nil then
			IFrames:Destroy()
		end
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
		end
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
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
		--self.Knit.GetService("AnimationService"):stopAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.Victim)
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, self.Settings.Damage)
		--self.Knit.GetService("RagdollService"):ragdoll(Enemy, 3)
		self:Destroy()
	end)	

	self:listenForCancel(function()
		if IFramesEnemy ~= nil then
			IFramesEnemy:Destroy()
		end
		if AutoRotateEnemy ~= nil then
			AutoRotateEnemy:Destroy()
		end
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
		end
		if IFrames ~= nil then
			IFrames:Destroy()
		end
		if StunVal ~= nil then
			StunVal:Destroy()
		end
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
		self.Cancelled = true
		grab:Destroy()
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.Success)
		--self.Knit.GetService("AnimationService"):stopAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.Victim)
		if Cant ~= nil then
			Cant:Destroy()
		end
		self:Destroy()
	end)
end

function Skill1:TagEnemy45(Enemy)
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
			Velocity = ((Enemy.HumanoidRootPart.CFrame.Position - self.Character.HumanoidRootPart.CFrame.Position).Unit *(50)), 
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

		Damage = 1,
	},function(State)
		if State == "Hit" then
			self.HitSomeone = true
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 45, script.Parent.Name, "M1", "HitNOSFX", self.Character, Enemy, math.random(1,4))
		end
	end)
end

function Skill1:TagEnemyThrow(Enemy)
	if self.Cancelled then return end
	self.Knit.GetService("DamageService"):Damage({

		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(0,20000,0),
			Velocity = Vector3.new(0,55,0),
			Time = .1,
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

		Damage = 12,
	},function(State)
		self.HitSomeone = true

	end)
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
function Skill1:Release()
		if self.Character.Values:FindFirstChild("Cant") then return end
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit1"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit2"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit3"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit4"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Uppercut"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Downslam"])
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill1.Release)
	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 1), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
	self.Knit.GetService("AttackService"):destroyBodyGyroHold(self.Character,"FullMouse")
	for _,v in pairs(self.Character:GetChildren()) do
		if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
			v.CollisionGroup = 'Visuals2'
		end
	end
	local count = 0
local Val
	self:listenForCancel(function()	
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Characters'
			end
		end
		if Cant ~= nil then
			Cant:Destroy()
		end
		if Val ~= nil then
			Val:Destroy()
		end
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill1.Release)
		self.Cancelled = true
		self:Destroy()
	end)
	local hrp = self.Character:FindFirstChild("HumanoidRootPart")
	local startingPos = self.Character.HumanoidRootPart.Position
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 100, self.Character:GetAttribute("Character"), "M1", "SPEEDBLITZVFXLOLZ", self.Character)
	self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Immortal Blaze", "Skill3Drill", "LOLDASH", self.Character, self.Character)	
	local function dashforward()
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Immortal Blaze", "Skill3Drill", "Dash", self.Character, self.Character)	
	end
	task.delay(51/60,function()
		if self.Cancelled then return end
		dashforward()
		self:CreateHitbox2(function(Enemy)
			self:TagEnemy45(Enemy,startingPos)
		end)
		Val = Instance.new("StringValue")
		Val.Parent =  self.Character:FindFirstChild("Values")
		Val.Name = "M1IFRAMES"
		game.Debris:AddItem(Val,(122/60) - (51/60))
	end)
		task.delay(61/60,function()
			if self.Cancelled then return end
			self:CreateHitbox2(function(Enemy)
				self:TagEnemy45(Enemy,startingPos)
			end)
		end)
		task.delay(71/60,function()
			if self.Cancelled then return end
			self:CreateHitbox2(function(Enemy)
				self:TagEnemy45(Enemy,startingPos)
			end)
		end)
		task.delay(81/60,function()
			if self.Cancelled then return end
			self:CreateHitbox2(function(Enemy)
				self:TagEnemy45(Enemy,startingPos)
			end)
		end)
		task.delay(91/60,function()
			if self.Cancelled then return end
			self:CreateHitbox2(function(Enemy)
				self:TagEnemy45(Enemy,startingPos)
			end)
		end)
	wait(106/60)
	task.delay(self.Settings2.HitboxSettings.Debris,function()
		if not self.Hit then
			self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill1", self.Settings.Cooldown)
		end
	end)
	if self.Cancelled then
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill1.Release)
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
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 15, "Scarlet Empress", "M1", "2TRAIL", self.Character, self.Character)	
	coroutine.resume(coroutine.create(function()
		self:CreateHitbox(function(Enemy)
			self:TagEnemy(Enemy,startingPos)
		end)
	end))
	wait((122/60) - (106/60))
	for _,v in pairs(self.Character:GetChildren()) do
		if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
			v.CollisionGroup = 'Characters'
		end
	end
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
end

return Skill1
