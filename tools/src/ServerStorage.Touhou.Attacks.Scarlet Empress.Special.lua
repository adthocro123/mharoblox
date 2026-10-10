local Special = {}
Special.Settings = {
	Cooldown = 20,
	Damage = 1,
	AttackLength = 1.4,

	HitboxSettings = {
		DelayTime = 0,
		Debris = .1,

		Offset = CFrame.new(0,0,-25),
		Size = Vector3.new(15,35,70)
	},
	magnitudeForClose = 18,
}

local GetLocalCharPosition = require(game.ServerStorage.Touhou.Bridge).GetLocalCharPosition
local GetMouseHit = require(game.ServerStorage.Touhou.Bridge).GetMouseHit
local TweenModule = require(game.ReplicatedStorage.Modules.TweenModule)

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
		IgnoresBlock = false,
		Visualize = false,
		DelayTime = self.Settings.HitboxSettings.DelayTime,
		Debris = self.Settings.HitboxSettings.Debris,
	}, callback))
end
function Special:TagEnemyThrow(Enemy)
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
				Velocity = (Enemy.HumanoidRootPart.CFrame.Position - self.Character.HumanoidRootPart.CFrame.Position).Unit *(45) + Vector3.new(0,5,0),
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

		Damage = 1,
	},function(State)
		self.HitSomeone = true

	end)
end
function Special:Release(InAir,torso)	
	--april fools 
	if self.Character:FindFirstChild("MilleniumVampire") then return end
		if self.Character.Values:FindFirstChild("Cant") then return end
	if self.Character.Values:FindFirstChild("CantHeartBreak") and not self.Character:FindFirstChild("HEARTBREAKCLOSEVARIANTHOLD") then return end
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit1"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit2"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit3"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.StartupNew)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.Startup)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit4"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Uppercut"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Downslam"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.Release2)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.Release)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.CloseVariant)
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Special.ReleaseNew)
--self.Character.HumanoidRootPart.Velocity = Vector3.new(0,0,0)
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 145, "Scarlet Empress", "M1", "SPECIALSTARTVFX", self.Character)	
	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, .01), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	local AutoRotate
	local connection2
	local function hitbox()
		self.Knit.GetService("HitboxService"):createHitbox({
			Caster = self.Character,
			Origin = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,0),
			Offset = CFrame.new(0,0,0),
			Size = Vector3.new(20,20,20),
			HitboxType = "Box",
			HitType = "OneHit",
			IgnoresRagdoll = true,
			IgnoresBlock = true,
			DelayTime = 0,
			Debris = .2,
		}, function(Enemy5)
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy5, 1)
			self:TagEnemyThrow(Enemy5)
		end)
	end
	self:listenForCancel(function()	
		self.Cancelled = true 
		self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Special", 25)
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
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
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Special.ReleaseNew)
		self:Destroy()
	end)
	task.delay(208/60,function()
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
		end
	end)
	task.delay(20/60,function()
		hitbox()
		self.Knit.GetService("CombatService"):FireAllClients(self.Character,250, "Stuff", "downslamupthing", "VOICELINE", self.Character,"Giggle","Giggle1")
end)
	task.delay(125/60,function()
		if self.Cancelled then return end
		hitbox()
		self.Knit.GetService("CombatService"):FireAllClients(self.Character,250, "Stuff", "downslamupthing", "VOICELINE", self.Character,"Giggle","Giggle2")
		local buffvalue = Instance.new("BoolValue",self.Character)
		buffvalue.Value = true
		buffvalue.Name = ("MilleniumVampire")
		task.delay(15,function()
			if buffvalue ~= nil then
				if self.Character:FindFirstChild("MilleniumVampire") then
					repeat wait() until not self.Character.Values:FindFirstChild("Cant") or self.Character.Values:FindFirstChild("CantHeartBreak")
					if buffvalue ~= nil then
						buffvalue:Destroy()
					end
				end
			end
		end)
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 300, "Scarlet Empress", "M1", "MILLVAMP1", self.Character)	
	end)
	task.delay(239/60,function()
		if self.Cancelled then return end
		self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Special", 25)
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
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
	task.delay(22/60,function()
		if self.Cancelled then return end
		AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
	end)
end

return Special
