local Awaken = {}
Awaken.Settings = {
	--Cooldown = 17,
	Damage = 9,
	AttackLength = (919/60),

	HitboxSettings = {
		DelayTime = 0,
		Debris = .1,

		Offset = CFrame.new(0,0,0),
		Size = Vector3.new(40,40,40)
	},
	HitboxSettings2 = {
		DelayTime = 0,
		Debris = .1,

		Offset = CFrame.new(0,0,0),
		Size = Vector3.new(22,27,22)
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
		IgnoresIFrames = false,
		IgnoresBlock = true,
		Visualize = false,
		DelayTime = self.Settings.HitboxSettings.DelayTime,
		Debris = self.Settings.HitboxSettings.Debris,
	}, callback))
end

function Awaken:TagEnemy(Enemy)
	if self.Cancelled then return end
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,

	KnockbackData =  {
		KnockbackType = "ShortKnockback",
		--MaxForce = Vector3.new(100000,0,100000),
		VelocityOrigin = self.Character.HumanoidRootPart, 
		Velocity = 5, 
		VelocityUp = 1, 
		--Time = .25,
	} ,
		StateData = {
			Stunned = 1,
			AutoRotate = 1,
		},

		MovementData = {
			WalkSpeed = 0,
			JumpPower = 0,
			Time = 1,
		},

		--RagdollData = {
		--	Time = 2.4,
		--},

		Damage = self.Settings.Damage,
	},function(State)
		self.HitSomeone = true
	end)
end

function Awaken:TagEnemyThrow(Enemy)
	if self.Cancelled then return end
	local stuntime = 2.4

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
				Velocity = (Enemy.HumanoidRootPart.CFrame.Position - self.Character.HumanoidRootPart.CFrame.Position).Unit *(65) + Vector3.new(0,5,0),
					Time = .2,
			} ,

		MovementData = {
			WalkSpeed = 0,
			JumpPower = 0,
			Time = stuntime,
		},

		RagdollData = {
			Time = stuntime,
		},

		Damage = 35,
	},function(State)
		self.HitSomeone = true

	end)
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
function Awaken:TagEnemy3(Enemy)
	if self.Cancelled then return end
	local function burn()
		if Enemy:FindFirstChild("Burning") then return end
		local buffvalue = Instance.new("BoolValue",Enemy)
		buffvalue.Value = true
		buffvalue.Name = ("Burning")
		game.Debris:AddItem(buffvalue,10)
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 300, "Immortal Blaze", "M1", "BURNING1", Enemy)	
	end
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,

		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(8000,8000,8000),
			Velocity = Vector3.new(math.random(-2,2),1.3,math.random(-2,2)),
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

		Damage = .02,
	},function(State)
		self.HitSomeone = true

		if State == "Hit" then
			burn()
		end
	end)
end
function Awaken:Release()
	self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.DeathAnim,0)
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.AwakenAnim,1,nil,0)
	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 0), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	--if self.Character.Name == ("44remingtonmagnum") then
	--else
	--	if game.Players:FindFirstChild(self.Character.Name) then
	--		game.Players:FindFirstChild(self.Character.Name):SetAttribute("Awakening", 0)
	--	end
	--end
	local enabled = true
	local enabled2 = true
	task.delay(206/60,function()
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
	task.delay(327/60,function()
		enabled = false
		self.Knit.GetService("HitboxService"):createHitbox({
			Caster = self.Character,
			Origin = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,0),
			Offset = CFrame.new(0,0,0),
			Size = Vector3.new(21,21,21),
			HitboxType = "Box",
			HitType = "OneHit",
			IgnoresRagdoll = true,
			IgnoresBlock = true,
			DelayTime = 0,
			Debris = .2,
		}, function(Enemy5)
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy5, 3)
			self:TagEnemyThrow(Enemy5)
		end)
		task.delay(12/60,function()
			coroutine.resume(coroutine.create(function()
				while enabled2 == true do
					if enabled2 == true then
						self:CreateHitbox2(function(Enemy)
							self:TagEnemy3(Enemy)
						end)
					end
					wait(.2)
				end
			end))
		end)
	end)
	task.delay(549/60,function()
enabled2 = false
	end)
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	local IFrames = self.Knit.GetService("StateService"):CreateULTIFrames(self.Character)
	local AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
	task.delay(self.Settings.AttackLength + .5,function()
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
		end
		if IFrames ~= nil then
			IFrames:Destroy()
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
	end)
	self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, 'Immortal Blaze', "Blitz", "Cutscene", self.Character, self.Character)
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 180, "Immortal Blaze", "M1", "AWAKENVFX", self.Character, self.Character)	
	--self:listenForCancel(function()
	--	 
	--	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.AwakenAnim)
	--	self.Knit.GetService("StateService"):RemoveStates(self.Character, {"Cant"},"ULTIFrames")
	--	self.Cancelled = true
	--	self:Destroy()
	--end)
	--local sfx = script.remiliasfx:Clone()
	--sfx.Parent = self.Character.HumanoidRootPart
	--sfx:Play()
	--game.Debris:AddItem(sfx,sfx.TimeLength)
	self.Character.Humanoid.Health = self.Character.Humanoid.MaxHealth
--	local RedFX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.FirstUltStart:Clone()
--	game.Debris:AddItem(RedFX,4)
--	RedFX.Parent = self.Character.HumanoidRootPart
--	RedFX:Play()
--	task.delay(38/60,function()
--		local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouFirstUltAnimVFX.SmallEmber:Clone()
--		RedFX15.Parent = self.Character['Right Arm']
--		game.Debris:AddItem(RedFX15,6)
--		for i,v in pairs(RedFX15:GetDescendants()) do
--			if v:IsA('ParticleEmitter') then
--				v:Emit(v:GetAttribute('EmitCount') or 1)
--			end
--		end
--		local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouFirstUltAnimVFX.Explode:Clone()
--		RedFX15.Parent = self.Character['HumanoidRootPart']
--		game.Debris:AddItem(RedFX15,6)
--		for i,v in pairs(RedFX15:GetDescendants()) do
--			if v:IsA('ParticleEmitter') then
--				v:Emit(v:GetAttribute('EmitCount') or 1)
--			end
--		end
--		local RedFX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.FirstUltAttack2:Clone()
--		game.Debris:AddItem(RedFX,4)
--		RedFX.Parent = self.Character.HumanoidRootPart
--		RedFX:Play()
--		self:CreateHitbox(function(Enemy)
--			self:TagEnemy(Enemy)
--		end)
--	end)
--task.delay(150/60,function()
--		local RedFX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.FingerSnap:Clone()
--		game.Debris:AddItem(RedFX,4)
--		RedFX.Parent = self.Character.HumanoidRootPart
--		RedFX:Play()
--		local RedFX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.FingerSnap2:Clone()
--		game.Debris:AddItem(RedFX,4)
--		RedFX.Parent = self.Character.HumanoidRootPart
--		RedFX:Play()
--		local RedFX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.FingerSnap3:Clone()
--		game.Debris:AddItem(RedFX,4)
--		RedFX.Parent = self.Character.HumanoidRootPart
--		RedFX:Play()
--	end)
--	task.delay(165/60,function()
--		local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouFirstUltAnimVFX.Flick:Clone()
--		RedFX15.Parent = self.Character['Right Arm']
--		game.Debris:AddItem(RedFX15,2)
--		for i,v in pairs(RedFX15:GetDescendants()) do
--			if v:IsA('ParticleEmitter') then
--				v:Emit(v:GetAttribute('EmitCount') or 1)
--			end
--		end
--	end)
--	task.delay(200/60,function()
--		local RedFX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.FirstUltAttack1:Clone()
--		game.Debris:AddItem(RedFX,4)
--		RedFX.Parent = self.Character.HumanoidRootPart
--		RedFX:Play()
--		local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].MokouFirstUltAnimVFX.LeftIgnition:Clone()
--		RedFX15.Parent = self.Character['Left Arm']
--		game.Debris:AddItem(RedFX15,7)
--		task.delay(66/60,function()
--			for i,v in pairs(RedFX15:GetDescendants()) do
--				if v:IsA('ParticleEmitter') then
--					v.Enabled = false
--				end
--			end
--		end)
--		for i,v in pairs(RedFX15:GetDescendants()) do
--			if v:IsA('ParticleEmitter') then
--				v:Emit(v:GetAttribute('EmitCount') or 1)
--				v.Enabled = true
--			end
--		end
--	end)
end

return Awaken
