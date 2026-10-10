local Skill2 = {}
local RunService = game:GetService("RunService")
local Tween = game:GetService("TweenService")

Skill2.Settings = {
	Cooldown = 17,
	CounterLength = 40/60,
	AttackLength = 359/60,
	AttackLength2 = 283/60,
	Damage = 19,
	HitboxSettings = {
		Size = Vector3.new(18,10,18),
		Debris = .1,
	}
} 

function Skill2:Grab(Enemy)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character,game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill2.Cast)
	local animUser = game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill2.Success
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, animUser,1)	
	task.delay(15,function()
		self:Destroy()
	end)
	local chrPos = Enemy.HumanoidRootPart.Position
	local tPos = self.Character.HumanoidRootPart.Position
	local modTPos = (chrPos - tPos).Unit * Vector3.new(1,0,1)
	local upVector = Enemy.HumanoidRootPart.CFrame.UpVector
	local newCF = CFrame.lookAt(chrPos, chrPos + modTPos, upVector) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), math.pi)
	Enemy.HumanoidRootPart.CFrame = newCF
	self.Character.HumanoidRootPart.CFrame = Enemy.HumanoidRootPart.CFrame * (CFrame.new(0,0,-4.826)*CFrame.Angles(0,math.rad(180),0))
	local grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,0,-6)*CFrame.Angles(0,math.rad(180),0))
	local attackLength = self.Settings.AttackLength
	local attackLength2 = self.Settings.AttackLength2
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	local IFrames = self.Knit.GetService("StateService"):CreateULTIFrames(self.Character)
	local IFramesEnemy = Instance.new("StringValue",Enemy.Values)
	IFramesEnemy.Name = "StunnedBy"
	IFramesEnemy.Value = self.Character.Name
	local AutoRotateEnemy = self.Knit.GetService("StateService"):CreateAutoRotate(Enemy)
	local AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
	local Cant2 = self.Knit.GetService("StateService"):CreateCant(Enemy)
	local StunVal = self.Knit.GetService("StateService"):CreateStun(Enemy)
	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 0), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	local Speed1, Jump1 = self.Knit.GetService("MovementService"):CreateSpeed(Enemy, 0), self.Knit.GetService("MovementService"):CreateJump(Enemy, 0)
	local animVictim =game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill2.Victim
	self.Knit.GetService("AnimationService"):playAnimation(Enemy, animVictim)
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 150, "Scarlet Empress", "M1", "COUNTERVFX", self.Character, Enemy)	
	task.delay(15/60,function()
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 1.5)
	end)
	task.delay(35/60,function()
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 1.5)
	end)
	task.delay(61/60,function()
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 1.5)
	end)
	task.delay(84/60,function()
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 1)
	end)
	task.delay(99/60,function()
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .8)
	end)
	local function smalldamage()
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .4)
	end
	task.delay(109/60,function()
		smalldamage()
	end)
	task.delay(111/60,function()
		smalldamage()
	end)
	task.delay(113/60,function()
		smalldamage()
	end)
	task.delay(115/60,function()
		smalldamage()
	end)
	task.delay(117/60,function()
		smalldamage()
	end)
	task.delay(119/60,function()
		smalldamage()
	end)
	task.delay(121/60,function()
		smalldamage()
	end)
	task.delay(123/60,function()
		smalldamage()
	end)
	task.delay(125/60,function()
		smalldamage()
	end)
	task.delay(127/60,function()
		smalldamage()
	end)
	task.delay(129/60,function()
		smalldamage()
	end)
	task.delay(131/60,function()
		smalldamage()
	end)
	task.delay(133/60,function()
		smalldamage()
	end)
	task.delay(135/60,function()
		smalldamage()
	end)
	task.delay(137/60,function()
		smalldamage()
	end)
	task.delay(139/60,function()
		smalldamage()
	end)
	task.delay(141/60,function()
		smalldamage()
	end)
	task.delay(145/60,function()
		smalldamage()
	end)
	task.delay(147/60,function()
		smalldamage()
	end)
	task.delay(149/60,function()
		smalldamage()
	end)
	task.delay(151/60,function()
		smalldamage()
	end)
	task.delay(155/60,function()
		smalldamage()
	end)
	task.delay(157/60,function()
		smalldamage()
	end)
	task.delay(159/60,function()
		smalldamage()
	end)
	task.delay(161/60,function()
		smalldamage()
	end)
	task.delay(167/60,function()
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3)
	end)
	task.delay(185/60,function()
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3)
	end)
	task.delay(212/60,function()
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3)
	end)
	task.delay(236/60,function()
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3)
	end)
	task.delay(240/60,function()
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
	end)
	task.delay(247/60,function()
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
	end)
	task.delay(250/60,function()
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
	end)
	task.delay(280/60,function()
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2.5)
	end)
	task.delay(attackLength2,function()
		if grab ~= nil then
			grab:Destroy()
		end
		if IFramesEnemy.Parent ~= nil then
			IFramesEnemy:Destroy()
		end
		if Cant2 ~= nil then
			Cant2:Destroy()
		end
		if StunVal ~= nil then
			StunVal:Destroy()
		end
		if AutoRotateEnemy.Parent ~= nil then
			AutoRotateEnemy:Destroy()
		end
		if Cant2.Parent ~= nil then
			Cant2:Destroy()
		end
		if StunVal.Parent ~= nil then
			StunVal:Destroy()
		end
		if Jump1.Parent ~= nil then
			Jump1:Destroy()
		end
		if Speed1.Parent ~= nil then
			Speed1:Destroy()
		end
		if Enemy.Parent ~= nil then
			self:SmashEnemy(Enemy)
		end
	end)	
	task.delay(attackLength,function()
		if Cant2.Parent ~= nil then
			Cant2:Destroy()
		end	
		if StunVal ~= nil then
			StunVal:Destroy()
		end
	if grab ~= nil then
			grab:Destroy()
		end
		if IFrames.Parent ~= nil then
			IFrames:Destroy()
		end
		if AutoRotate.Parent ~= nil then
			AutoRotate:Destroy()
		end
		if Cant.Parent ~= nil then
			Cant:Destroy()
		end
		if Jump.Parent ~= nil then
			Jump:Destroy()
		end
		if Speed.Parent ~= nil then
			Speed:Destroy()
		end
		self:Destroy()
	end)	

	self:listenForCancel(function()
		self.Cancelled = true

		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, animUser)
		self.Knit.GetService("AnimationService"):stopAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill2.Victim)

		self:Destroy()
	end)
end

function Skill2:SmashEnemy(Enemy)
	if self.Cancelled then return end
local stuntime = 3
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,

		--KnockbackData = {
		--	KnockbackType = "Velocity",
		--	MaxForce = Vector3.new(50000000,50000000,50000000),
		--	Velocity = Vector3.new(math.random(-20,20),math.random(20,40),math.random(-20,20)),
		--	Time = .7,
		--},

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

		Damage = 4,
	},function(State)
		self.HitSomeone = true

		if State == "Hit" then
		end
	end)
end

function Skill2:Release(InAir)	

	--if InAir then
	--	self:Smash()
	--	return
	--end
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit1"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit2"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit3"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit4"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Uppercut"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Downslam"])
	self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill2", self.Settings.Cooldown)

	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 4), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)

	self:listenForCancel(function()
		if Speed ~= nil then 
			Speed:Destroy()
		end
		if Jump ~= nil then 
			Jump:Destroy()
		end
		if Cant ~= nil then 
			Cant:Destroy()
		end
		self.Cancelled = true
		self.Knit.GetService("CounterService").Counters[self.Character] = nil
		self:Destroy() 
	end)

	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill2.Cast,1,nil,0)
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 100, self.Character:GetAttribute("Character"), "M1", "COUNTERSTARTUP", self.Character)
	self.Knit.GetService("CounterService").Counters[self.Character] = function(Enemy)
		if self.Cancelled or self.Destroyed then return end
		if Speed ~= nil then 
			Speed:Destroy()
		end
		if Jump ~= nil then 
			Jump:Destroy()
		end
		if Cant ~= nil then 
			Cant:Destroy()
		end
		Enemy:SetAttribute("Cancel", os.clock())
		self.Countered = true
		self.Knit.GetService("CounterService").Counters[self.Character] = nil
		self:Grab(Enemy)
	end

	task.delay(self.Settings.CounterLength, function()
		if self.Countered then return end
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character,  game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill2.Cast,0)
		if Speed ~= nil then 
			Speed:Destroy()
		end
		if Jump ~= nil then 
			Jump:Destroy()
		end
		if Cant ~= nil then 
			Cant:Destroy()
		end
		if self.Countered == true then
		else
			self:Destroy()
		end
		self.Knit.GetService("CounterService").Counters[self.Character] = nil
	end)
end

return Skill2
