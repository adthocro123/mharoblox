local Skill3 = {}
Skill3.Settings = {
	Cooldown = 20,
	Damage = 4,
	AttackLength = (940/60),
	AttackLength2 = (873/60),

	HitboxSettings = {
		DelayTime = .2,
		Debris = .1,

		Offset = CFrame.new(0,2,-3.2),
		Size = Vector3.new(10,5,20)
	},
	magnitudeForClose = 20,
}
Skill3.Settings2 = {
	Cooldown = 25,
	Damage = 6,
	AttackLength = 1.4,

	HitboxSettings = {
		DelayTime = 0,
		Debris = 15/60,

		Offset = CFrame.new(0,4,-10),
		Size = Vector3.new(10,8,20)
		--Offset = CFrame.new(0,4,-15),
		--Size = Vector3.new(10,8,30)
	},

	HitboxSettings1 = {
		DelayTime = 0,
		Debris = .2,

		Offset = CFrame.new(0,15,-4.5),
		Size = Vector3.new(13,45,10)
	},
}
local ApplyHandlr = require(game.ServerStorage.Touhou.SimJump)

function Skill3:CreateHitbox(callback)
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
		IgnoresBlock = true,
		Visualize = false,
		PerfectTrack = true,
		DelayTime = self.Settings2.HitboxSettings.DelayTime,
		Debris = self.Settings2.HitboxSettings.Debris,
	}, callback))
end

function Skill3:TagEnemy(Enemy,pos)
	if self.Character.Values:FindFirstChild("Stunned") then return end
	if self.Cancelled then return end
	if self.Hit then return end
	if self.Character.HumanoidRootPart:FindFirstChild("GrabWeld") and not self.Character.HumanoidRootPart:FindFirstChild("GrabWeld"):GetAttribute("Stinger") then return end
	--if (Enemy.Values:FindFirstChild("RagdollSuperArmor")) or (Enemy:FindFirstChild("MilleniumVampire")) then return end
	Enemy:SetAttribute("Cancel", os.clock())
	--pos = self.Character.HumanoidRootPart.Position
	--local chrPos = Enemy.HumanoidRootPart.Position
	--local tPos = pos
	--local modTPos = (chrPos - tPos).Unit * Vector3.new(1,0,1)
	--local upVector = Enemy.HumanoidRootPart.CFrame.UpVector
	--local newCF = CFrame.lookAt(chrPos, chrPos + modTPos, upVector) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), math.pi)
	--Enemy.HumanoidRootPart.CFrame = newCF
	--self.Character.HumanoidRootPart.CFrame = Enemy.HumanoidRootPart.CFrame* (CFrame.new(0,0,-1)*CFrame.Angles(0,math.rad(180),0))
	if self.Character:FindFirstChild("STINGERLUNGE") then
		self.Character:FindFirstChild("STINGERLUNGE"):Destroy()
	end
	--self.Knit.GetService("RagdollService"):unragdoll(self.Character, true,true)
	if Enemy:GetAttribute("Ragdoll") then
		self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	end
	self.Hit = Enemy
	--self.Character.Humanoid.AutoRotate = true
	--self.Character.HumanoidRootPart.Anchored = true
	task.delay(.25,function()
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWSTAB)
	end)
	for _,v in pairs(self.Character:GetChildren()) do
		if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
			v.CollisionGroup = 'Visuals2'
		end
	end
	local grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,0,0),CFrame.Angles(0,0,0))
	task.delay(259/60,function()
		if grab ~= nil then
			grab:Destroy()
			wait()
			grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,0,-3),CFrame.Angles(0,0,0))
		end
	end)
	task.delay(700/60,function()
		if grab ~= nil then
			grab:Destroy()
			wait()
			grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,0,0),CFrame.Angles(0,0,0))
		end
	end)
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 150, "Scarlet Empress", "M1", "BEATDOWNVFX", self.Character, Enemy)	
	self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, 'Scarlet Empress', "BlitzKick2", "Cutscene", self.Character, self.Character)
	self.Knit.GetService("CombatService"):FireClient(Enemy, Enemy, 'Scarlet Empress', "BlitzKick2", "Cutscene", self.Character, self.Character)
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)

	local IFrames = self.Knit.GetService("StateService"):CreateULTIFrames(self.Character)
	task.delay(self.Settings.AttackLength,function()
		if IFrames ~= nil then
			IFrames:Destroy()
		end
	end)
	local IFramesEnemy = Instance.new("StringValue",Enemy.Values)
	IFramesEnemy.Name = "StunnedBy"
	IFramesEnemy.Value = self.Character.Name
	local AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
	local AutoRotateEnemy = self.Knit.GetService("StateService"):CreateAutoRotate(Enemy)
	task.delay(self.Settings.AttackLength2,function()
		if IFramesEnemy ~= nil then
			IFramesEnemy:Destroy()
		end
		if AutoRotateEnemy ~= nil then
			AutoRotateEnemy:Destroy()
		end
	end)


	local Cant2 = self.Knit.GetService("StateService"):CreateCant(Enemy)
	local StunVal = self.Knit.GetService("StateService"):CreateStun(Enemy)
	local Speed1, Jump2 = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, .001), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(Enemy, 0), self.Knit.GetService("MovementService"):CreateJump(Enemy, 0)
	task.delay(self.Settings.AttackLength2,function()
		if grab ~= nil then
			grab:Destroy()
		end
		self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill3", self.Settings.Cooldown)
		if Enemy ~= nil then
			self:TagEnemyThrow2515(Enemy)
		end
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end
		if IFramesEnemy ~= nil then
			IFramesEnemy:Destroy()
		end
		if StunVal ~= nil then
			StunVal:Destroy()
		end
		if Cant2 ~= nil then
			Cant2:Destroy()
		end
		if AutoRotateEnemy ~= nil then
			AutoRotateEnemy:Destroy()
		end
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
		end
		self.Knit.GetService("AnimationService"):stopAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWVICTIM)
	end)
	self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill3.Victim,1,nil,0)
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill3.Success,1,nil,0)
	task.delay(self.Settings.AttackLength,function()
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
		end
		if IFramesEnemy ~= nil then
			IFramesEnemy:Destroy()
		end
		if StunVal ~= nil then
			StunVal:Destroy()
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
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end
		if grab ~= nil then
			grab:Destroy()
		end
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Characters'
			end
		end
		if Speed1 ~= nil then
			Speed1:Destroy()
		end
		if Jump2 ~= nil then
			Jump2:Destroy()
		end
		if Cant ~= nil then
			Cant:Destroy()
		end
	end)	
end
function Skill3:TagEnemyThrow(Enemy)
	if self.Cancelled then return end
	local stuntime = 2.2
	self.Knit.GetService("DamageService"):Damage({

		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(15000,15000,15000),
			Velocity = Vector3.new(0,47,0),
			Time = .35,
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

		Damage = .3,
	},function(State)
		self.HitSomeone = true

	end)
end
function Skill3:TagEnemyThrow2515(Enemy)
	if self.Cancelled then return end
	local stuntime = 2.2
	self.Knit.GetService("DamageService"):Damage({

		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(15000,15000,15000),
			Velocity = self.Character.HumanoidRootPart.CFrame.LookVector*(-80) + Vector3.new(0,18,0), 
			Time = .31,
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

		Damage = 65,
	},function(State)
		self.HitSomeone = true

	end)
end

function Skill3:CreateHitbox2(callback)
	self:bindClassToAttack(self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = self.Character.HumanoidRootPart,
		Offset = self.Settings2.HitboxSettings1.Offset,
		Size = self.Settings2.HitboxSettings1.Size,
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = false,
		IgnoresBlock = true,
		Visualize = false,
		DelayTime = self.Settings2.HitboxSettings1.DelayTime,
		Debris = self.Settings2.HitboxSettings1.Debris,
	}, callback))
end
function Skill3:TagEnemyThrow215(Enemy)
	if self.Cancelled then return end
	local stuntime = .7
	self.Knit.GetService("DamageService"):Damage({

		KnockbackData = {
			KnockbackType = "ShortKnockback",
			--MaxForce = Vector3.new(100000,0,100000),
			VelocityOrigin = self.Character.HumanoidRootPart, 
			Velocity = 6, 
			VelocityUp = 1, 
			--Time = .25,
		} ,

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
		EnemyFacesCharacter = true,

	},function(State)
		self.HitSomeone = true
		--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 70, "Scarlet Empress", "M1", "SmashWhenGround", Enemy,1)
	end)
end
function Skill3:Release(InAir)
	if self.Character.HumanoidRootPart:FindFirstChild("GrabWeld") then return end
	--april fools 
if self.Character.Values:FindFirstChild("Cant") then return end
	if self.Character.Values:FindFirstChild("CantHeartBreak") and not self.Character:FindFirstChild("HEARTBREAKCLOSEVARIANTHOLD") then return end
	if self.Character.Values:FindFirstChild("CantHeartBreak") and self.Character:FindFirstChild("HEARTBREAKCLOSEVARIANTHOLD") then 
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "Skill3Drill", "Dash2fiftiesz", self.Character, self.Character)	
		--InAir = false
	end
	if self.Character:FindFirstChild("Values") then
		for i,v in pairs(self.Character:FindFirstChild("Values"):GetDescendants()) do
			if v.Name == ("HeartBreakMovementUnability") or v:GetAttribute("HeartBreakMovementUnability") then
				v:Destroy()
			end
		end
	end
	--if self.Character.Values:FindFirstChild("CantHeartBreak") and self.Character:FindFirstChild("HEARTBREAKCLOSEVARIANTHOLD") then 
	--	self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "Skill3Drill", "Dash2fiftiesz", self.Character, self.Character)	
	--end
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit1"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.NewRelease)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit2"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit3"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit4"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Uppercut"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Downslam"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.CloseVariant)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character,game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")].DashM1Mode)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character,game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")].DashM1)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.Release2)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWAIRVARIANTSTARTUP)
		if self.Character.HumanoidRootPart:FindFirstChild("GrabWeld") then return end
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill3.Release2,1,nil,.1)
		local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 1), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
	self.Knit.GetService("AttackService"):destroyBodyGyroHold(self.Character,"FullMouse")
	--self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill1", self.Settings.Cooldown)
	--RedF151X:Play()
	--for _,v in pairs(self.Character:GetChildren()) do
	--	if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
	--		v.CollisionGroup = 'Visuals2'
	--	end
	--end
	local count = 0

	--local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.jumpsfx:Clone()
	--RedFX2425.Parent = self.Character.HumanoidRootPart
	--game.Debris:AddItem(RedFX2425,2)
	--RedFX2425:Play()
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 145, "Scarlet Empress", "M1", "3STARTVFX25", self.Character)	
	--task.delay(35/60,function()
	--	local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.abysscswing:Clone()
	--	RedFX2425.Parent = self.Character.HumanoidRootPart
	--	game.Debris:AddItem(RedFX2425,2)
	--	RedFX2425:Play()
		--end)
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Visuals2'
			end
		end
	local buffvalue = Instance.new("BoolValue",self.Character)
	buffvalue.Value = true
		buffvalue.Name = ("STINGERLUNGE")
	local AutoRotate = nil
	local ended = false
	self:listenForCancel(function()	
		if buffvalue ~= nil then
			buffvalue:Destroy()
		end
			if self.Character:FindFirstChild("STINGERLUNGE") then
				self.Character:FindFirstChild("STINGERLUNGE"):Destroy()
			end
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
		end	
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Characters'
			end
		end
		ended = true
		if Cant ~= nil then
			Cant:Destroy()
		end
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.ReleaseNew)
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.Release2New)
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.Release)
		self.Cancelled = true
		self:Destroy()
	end)
	local hrp = self.Character:FindFirstChild("HumanoidRootPart")
	local startingPos = self.Character.HumanoidRootPart.Position
	local function dashforward()
			self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "Skill3Drill", "Dash2fiftiesz25", self.Character, self.Character)	
		end
		task.delay(30/60,function()
			if self.Cancelled then return end
			AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
			dashforward()
		end)
	wait(30/60)
		--self.Knit.GetService("AnimationService"):adjustSpeed(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWSTAB,.14)
		task.delay(self.Settings2.HitboxSettings.Debris,function()
		if not self.Hit then
			self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill3", self.Settings.Cooldown)
		end
	end)
	if self.Cancelled then
		return
	end
	--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 110, "Scarlet Empress", "M1", "LUNGELOOPVFX3SKILL", self.Character)	
	local IFrames = self.Knit.GetService("StateService"):CreateIFrames(self.Character)
	task.delay(self.Settings2.HitboxSettings.Debris,function()
		if IFrames ~= nil then
			IFrames:Destroy()
		end
	end)
	if self.Cancelled then
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWSTAB)
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
		self:CreateHitbox(function(Enemy)
			--if buffvalue ~= nil then
			--	buffvalue:Destroy()
			--end
				if self.Character.HumanoidRootPart:FindFirstChild("GrabWeld") then return end
				local buffvalue523 = Instance.new("BoolValue",self.Character.HumanoidRootPart)
				buffvalue523.Value = true
				buffvalue523.Name = ("GrabWeld")
				buffvalue523:SetAttribute("Stinger",true)
				game.Debris:AddItem(buffvalue523,1)
			self:TagEnemy(Enemy,self.Character.HumanoidRootPart.Position)
				if buffvalue ~= nil then
					buffvalue:Destroy()
				end
			if self.Hit then
				--for _,v in pairs(self.Character:GetChildren()) do
				--	if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				--		v.CollisionGroup = 'Characters'
				--	end
				--end
			end
		end)
	end))
	local function endlunge()
		if ended == true then return end
		ended = true
		if buffvalue ~= nil then
			buffvalue:Destroy()
		end
		if not self.Hit then
			--repeat wait() until not self.Character.HumanoidRootPart:FindFirstChild("GrabWeld")
			self.Cancelled = true
			--task.delay(.25,function()
			--	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill3.Release2)
			--end)
			--wait(10/60)
		end
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Characters'
			end
		end
		if Cant ~= nil then
			Cant:Destroy()
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
		self:Destroy()
	end
	task.delay((20)/60,function()
		endlunge()
	end)
end

return Skill3
