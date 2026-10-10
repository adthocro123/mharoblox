local Awaken = {}
Awaken.Settings = {
	--Cooldown = 17,
	Damage = 40,
	AttackLength = (844/60) + .25,

	HitboxSettings = {
		DelayTime = 0,
		Debris = .17,

		Offset = CFrame.new(0,10,0),
		Size = Vector3.new(77,77,77)
	},
	HitboxSettings2 = {
		DelayTime = 0,
		Debris = .1,

		Offset = CFrame.new(0,10,0),
		Size = Vector3.new(37,37,37)
	},
}

function Awaken:CreateHitbox(callback)
	self:bindClassToAttack(self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = self.Character.HumanoidRootPart,
		Offset = self.Settings.HitboxSettings.Offset,
		Size = self.Settings.HitboxSettings.Size,
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = true,
		IgnoresBlock = true,
		Visualize = false,
		DelayTime = self.Settings.HitboxSettings.DelayTime,
		Debris = self.Settings.HitboxSettings.Debris,
	}, callback))
end

function Awaken:CreateHitbox2(callback)
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

function Awaken:TagEnemy2(Enemy)
	if self.Cancelled then return end
	if Enemy:GetAttribute("Ragdoll") then
		self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	end
	self.Knit.GetService("BodymoverService"):DestroyBodymovers(Enemy)

	--local stuntime = 1.6
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,

		KnockbackData = {
			KnockbackType = "ShortKnockback",
			--MaxForce = Vector3.new(100000,0,100000),
			VelocityOrigin = self.Character.HumanoidRootPart, 
			Velocity = 1.8, 
			VelocityUp = 5.5, 
			--Time = .25,
		} ,

		--StateData = {
		--	Stunned = stuntime,
		--	AutoRotate = stuntime
		--},

		--MovementData = {
		--	WalkSpeed = 0,
		--	JumpPower = 0,
		--	Time = stuntime,
		--},
		--BlockData = {			
		--	HitterOrigin = self.Character.HumanoidRootPart.CFrame,
		--},
		ReactionAnim = (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),

		EnemyFacesCharacter = true,

		Damage = 8,
	},function(State)
		if State == "Hit" then
			self.HitSomeone = true
		end
	end)
end


function Awaken:TagEnemy(Enemy)
	if self.Cancelled then return end
self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,

	KnockbackData = {
		KnockbackType = "Velocity",
		MaxForce = Vector3.new(20000,20000,20000),
		Velocity = ((Enemy.HumanoidRootPart.CFrame.Position - self.Character.HumanoidRootPart.CFrame.Position).Unit *(100)) + Vector3.new(0,40,0), 
		Time = .25,
	},
	RagdollData =  {
		Time = 2,
	},
		StateData = {
			Stunned = 2,
			AutoRotate = 2,
		},

		MovementData = {
			WalkSpeed = 0,
			JumpPower = 0,
			Time = 2,
		},

		--RagdollData = {
		--	Time = 2.4,
		--},

		Damage = self.Settings.Damage,
	},function(State)
		self.HitSomeone = true
	end)
end
function Awaken:TagEnemy3(Enemy)
	if self.Cancelled then return end
	self.Knit.GetService("DamageService"):Damage({

	Character = self.Character,
	Enemy = Enemy,

		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(8000,8000,8000),
			Velocity = Vector3.new(math.random(-2,2),4,math.random(-2,2)),
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
		Time = 1,
	},
	ReactionAnim = (game.ReplicatedStorage.Assets.Animations.ReactionsCrazy["Reaction"..math.random(1,4)]),

	Damage = .03,
	},function(State)
		self.HitSomeone = true

		if State == "Hit" then
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, script.Parent.Name, "Smash", "Hit", self.Character, Enemy)
		end
	end)
end
function Awaken:Release()
	if self.Character:GetAttribute("Awakened") then return end
	self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.AwakenAnim,1,nil,0)
	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 0), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)

	task.delay(838/60,function()
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.AwakenAnim,0)
		self.Character.HumanoidRootPart.CFrame = self.Character.HumanoidRootPart.CFrame * CFrame.new(-0.132,0,-1.871)
	end)
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	local IFrames = self.Knit.GetService("StateService"):CreateULTIFrames(self.Character)
	local AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
	local enabled = true
	task.delay(75/60,function()
		coroutine.resume(coroutine.create(function()
			while enabled == true do
				if enabled == true then
					self:CreateHitbox2(function(Enemy)
						self:TagEnemy3(Enemy)
					end)
				end
				wait(.2)
			end
		end))
	end)
	task.delay(215/60,function()
		enabled = false
		self:CreateHitbox2(function(Enemy)
			self:TagEnemy2(Enemy)
		end)
	end)
	task.delay(self.Settings.AttackLength,function()
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
		end
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end
		if IFrames ~= nil then
			IFrames:Destroy()
		end
		if Cant ~= nil then
			Cant:Destroy()
		end
		self:Destroy()
	end)
	self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, 'Scarlet Empress', "Blitz", "Cutscene", self.Character, self.Character)
	--self:listenForCancel(function()
	--	 
	--	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.AwakenAnim)
	--	self.Knit.GetService("StateService"):RemoveStates(self.Character, {"Cant"},"ULTIFrames")
	--	self.Cancelled = true
	--	self:Destroy()
	--end)
	
	--if self.Character  ~= nil then self.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end
	self.Character.Humanoid.Health = self.Character.Humanoid.MaxHealth
	--task.delay(self.Settings.AttackLength + .1,function()
	--	if self.Character  ~= nil then self.Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end
	--end)
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 180, "Scarlet Empress", "M1", "AWAKENVFX", self.Character, self.Character)	

	task.delay((498/60),function()
		self:CreateHitbox(function(Enemy)
			self:TagEnemy(Enemy)
		end)
	end)
	
	--task.delay((516/60),function()
	--	local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].RemiliaJump.Attachment:Clone()
	--	RedFX15.Parent = self.Character.Torso
	--	game.Debris:AddItem(RedFX15,4)
	--	for i,v in pairs(RedFX15:GetDescendants()) do
	--		if v:IsA('ParticleEmitter') then
	--			v:Emit(v:GetAttribute('EmitCount') or 1)
	--		end
	--	end
	--	--self:CreateHitbox(function(Enemy)
	--	--	self:TagEnemy(Enemy)
	--	--end)
	--end)
	--local function vortex()
	--	if self.Cancelled ~= true then
	--		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 40, "Scarlet Empress", "M1", "CrokuranSponsorSpin", self.Character, self.Character)	
	--	end
	--end
	--task.delay(605/60,function()
	--	vortex()
	--end)
	--task.delay(70/60,function()
	--	local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.blooddashvfxtonedtfdown.Attachment:Clone()
	--	RedFX15.Parent = self.Character.Torso
	--	task.delay((210-70)/60,function()
	--		game.Debris:AddItem(RedFX15,5)
	--		for i,v in pairs(RedFX15:GetDescendants()) do
	--			if v:IsA('ParticleEmitter') then
	--				v.Enabled = false
	--			end
	--		end
	--	end)
	--end)
	--task.delay((68/60),function()
	--	local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].RemiliaJump.Attachment:Clone()
	--	RedFX15.Parent = self.Character.Torso
	--	game.Debris:AddItem(RedFX15,4)
	--	for i,v in pairs(RedFX15:GetDescendants()) do
	--		if v:IsA('ParticleEmitter') then
	--			v:Emit(v:GetAttribute('EmitCount') or 1)
	--		end
	--	end
	--	--self:CreateHitbox(function(Enemy)
	--	--	self:TagEnemy(Enemy)
	--	--end)
	--end)
	--task.delay((420/60),function()
	--	local RedFX251 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].LeftHandOrb.RemiOrb:Clone()
	--	RedFX251.Parent = self.Character["Left Arm"]
	--	for i,v in pairs(RedFX251:GetChildren()) do
	--		if v:IsA("ParticleEmitter") then
	--			v.Enabled = true
	--		end
	--	end
	--	task.delay((490/60) - (420/60),function()
	--		game.Debris:AddItem(RedFX251,5)
	--		for i,v in pairs(RedFX251:GetChildren()) do
	--			if v:IsA("ParticleEmitter") then
	--				v.Enabled = false
	--			end
	--		end
	--	end)
	--end)
	--wait(self.Settings.AttackLength)
	--self:Destroy()
end

return Awaken
