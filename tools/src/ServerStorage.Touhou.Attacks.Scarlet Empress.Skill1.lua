local Skill1 = {}
Skill1.Settings = {
	Cooldown = 25,
	Damage = 4,
	AttackLength = (143/60),
	AttackLength2 = (118/60),

	HitboxSettings = {
		DelayTime = .2,
		Debris = .1,

		Offset = CFrame.new(0,2,-3.2),
		Size = Vector3.new(10,5,20)
	},
	magnitudeForClose = 20,
}
Skill1.Settings2 = {
	Cooldown = 25,
	Damage = 6,
	AttackLength = 1.4,

	HitboxSettings = {
		DelayTime = 0,
		Debris = 65/60,

		Offset = CFrame.new(0,4,-5),
		Size = Vector3.new(10,8,20)
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
		IgnoresBlock = true,
		Visualize = false,
		PerfectTrack = true,
		DelayTime = self.Settings2.HitboxSettings.DelayTime,
		Debris = self.Settings2.HitboxSettings.Debris,
	}, callback))
end

function Skill1:TagEnemy(Enemy)
	if self.Character.Values:FindFirstChild("Stunned") then return end
	if self.Cancelled then return end
	if self.Hit then return end
	if not self.Character.Values:FindFirstChild("CantHeartBreak") then return end
	if not self.Character:FindFirstChild("HEARTBREAKCLOSEVARIANTHOLD") then return end
	--if (Enemy.Values:FindFirstChild("RagdollSuperArmor")) or (Enemy:FindFirstChild("MilleniumVampire")) then return end
	Enemy:SetAttribute("Cancel", os.clock())
	if self.Knit.GetService("CounterService"):counter(self.Character, Enemy) then
		self.Cancelled = true
		self:Destroy()
	end
	--self.Knit.GetService("RagdollService"):unragdoll(self.Character, true,true)
	self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	self.Hit = Enemy
	--self.Character.Humanoid.AutoRotate = true
	self:AddFor(self.Settings.AttackLength, function()
		self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill1", self.Settings.Cooldown)
	end)
	local grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,0,0)*CFrame.Angles(0,0,0))
	self.Knit.GetService("CombatService"):FireAllClients(self.Character,250, "Stuff", "downslamupthing", "VOICELINE", self.Character,"SentenceSecondTake","So this is just an afterimage!")
	task.delay(.25,function()
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.ReleaseNew)
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.Release2New)
	end)
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
	self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
	local function groundslam()
		if self.Cancelled ~= true then
			self.Knit.GetService("HitboxService"):createHitbox({
				Caster = self.Character,
				Origin = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-2),
				Offset = CFrame.new(0,0,0),
				Size = Vector3.new(15,15,15),
				HitboxType = "Box",
				HitType = "OneHit",
				IgnoresRagdoll = true,
				IgnoresBlock = true,
				DelayTime = 0,
				Debris = .1,
			}, function(Enemy5)
				if Enemy5 == Enemy then return end
				self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy5, 7)
				self:TagEnemyThrow(Enemy5)
			end)
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3.5)
		end
	end
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 120, "Scarlet Empress", "M1", "KISSFIRSTSKILL", self.Character, Enemy)	
	--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 40, "Scarlet Empress", "M1", "BLOODSMASHVFX", self.Character, self.Character)	
	local damageheal = 1.2
	local function sucky()
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, damageheal)
		self.Character.Humanoid.Health += (damageheal--/1.1
		)
	end
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)

	local IFrames = self.Knit.GetService("StateService"):CreateULTIFrames(self.Character)
	local IFramesEnemy = Instance.new("StringValue",Enemy.Values)
	IFramesEnemy.Name = "StunnedBy"
	IFramesEnemy.Value = self.Character.Name
	local AutoRotateEnemy = self.Knit.GetService("StateService"):CreateAutoRotate(Enemy)
	local Cant2 = self.Knit.GetService("StateService"):CreateCant(Enemy)
	local StunVal = self.Knit.GetService("StateService"):CreateStun(Enemy)
	local Speed1, Jump2 = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 1), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(Enemy, 0), self.Knit.GetService("MovementService"):CreateJump(Enemy, 0)
	task.delay(36/60,function()
		sucky()
	end)

	task.delay(44/60,function()
		sucky()
	end)
	
	task.delay(55/60,function()
		sucky()
	end)

	task.delay(65/60,function()
		sucky()
	end)

	task.delay(69/60,function()
		sucky()
	end)

	task.delay(76/60,function()
		sucky()
	end)

	task.delay(88/60,function()
		sucky()
	end)

	task.delay(91/60,function()
		sucky()
	end)
	local finish = false
	task.delay(self.Settings.AttackLength2,function()
		if self.Character:FindFirstChild("MilleniumVampire") or (Enemy.Humanoid.Health <= 10) then
			local finishhim = false			
			if (Enemy.Humanoid.Health <= 10) then
				finishhim = true
			end
			if finishhim == true then
				self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 150)
			end
			if self.Character:FindFirstChild("MilleniumVampire") then
				self.Character:FindFirstChild("MilleniumVampire"):Destroy()
			end
			finish = true
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 120, "Scarlet Empress", "M1", "KISSFIRSTSKILLFINISHER", self.Character, Enemy)	
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
end				end)
				task.delay(44/60,function()
					if Enemy then
						self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
end				end)
				task.delay(112/60,function()
					if Enemy then
						self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3)
end				end)
			end
			self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.SuccessNew)
			self.Knit.GetService("AnimationService"):stopAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.VictimNew)
			self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.VictimNewFinisher,1,nil,0)
			self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.SuccessNewFinisher,1,nil,0)
			task.delay(90/60,function()
				if Enemy then
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
				end	
			end)
			task.delay(144/60,function()
				if Enemy then
					self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .01)
				end	

			coroutine.resume(coroutine.create(function()
					if grab ~= nil then
						grab:Destroy()
					end
				end))
				if Jump ~= nil then
					Jump:Destroy()
				end
				if Speed ~= nil then
					Speed:Destroy()
				end
				if Enemy ~= nil then
					self:TagEnemyThrow2515(Enemy)
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
				if Enemy then
					self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
end				--self.Knit.GetService("AnimationService"):stopAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.VictimNewFinisher)
			end)
			task.delay(175/60,function()
				if Enemy then
					self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .01)
end				if IFramesEnemy ~= nil then
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
		else
			if grab ~= nil then
				grab:Destroy()
			end
			if Enemy ~= nil then
				self:TagEnemyThrow(Enemy)
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
			if StunVal ~= nil then
				StunVal:Destroy()
			end
			if Cant2 ~= nil then
				Cant2:Destroy()
			end
			if AutoRotateEnemy ~= nil then
				AutoRotateEnemy:Destroy()
			end
			if Enemy then
				self.Knit.GetService("AnimationService"):stopAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.VictimNew)
end
end
	end)
	task.delay(self.Settings.AttackLength2,function()
		groundslam()
	end)
	self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.VictimNew,1,nil,0)
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.SuccessNew,1,nil,0)
	task.delay(self.Settings.AttackLength,function()
		if finish == true then return end
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
function Skill1:TagEnemyThrow(Enemy)
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

		Damage = 2,
	},function(State)
		self.HitSomeone = true

	end)
end
function Skill1:TagEnemyThrow2515(Enemy)
	if self.Cancelled then return end
	local stuntime = 2.2
	self.Knit.GetService("DamageService"):Damage({

		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(15000,15000,15000),
			Velocity = self.Character.HumanoidRootPart.CFrame.RightVector*(-45) + Vector3.new(0,20,0), 
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

		Damage = 2,
	},function(State)
		self.HitSomeone = true

	end)
end

function Skill1:Release()
	if self.Character.Values:FindFirstChild("Cant") then return end
	if self.Character:FindFirstChild("HEARTBREAKCLOSEVARIANTHOLD") and game:GetService("CollectionService"):HasTag(self.Character:FindFirstChild("HEARTBREAKCLOSEVARIANTHOLD"),"KISSLUNGE") then return end
	if self.Character:FindFirstChild("VAMPIREKISSLUNGE") then return end
	if self.Character.Values:FindFirstChild("CantHeartBreak") and not self.Character:FindFirstChild("HEARTBREAKCLOSEVARIANTHOLD") then return end
	if self.Character.Values:FindFirstChild("CantHeartBreak") and self.Character:FindFirstChild("HEARTBREAKCLOSEVARIANTHOLD") then 
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "Skill3Drill", "Dash2fiftiesz", self.Character, self.Character)	
	end
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.StartupNew)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.Startup)
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
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.ReleaseNew)
	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 1), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	Cant:SetAttribute("TemporaryKissVal",true)
	self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
	self.Knit.GetService("AttackService"):destroyBodyGyroHold(self.Character,"FullMouse")
	local count = 0
	self.Knit.GetService("CombatService"):FireAllClients(self.Character,250, "Stuff", "downslamupthing", "VOICELINE", self.Character,"Giggle")
	local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.jumpsfx:Clone()
	RedFX2425.Parent = self.Character.HumanoidRootPart
	game.Debris:AddItem(RedFX2425,2)
	RedFX2425:Play()
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 145, "Scarlet Empress", "M1", "KISSTARTVFX", self.Character)	
	task.delay(35/60,function()
		local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.abysscswing:Clone()
		RedFX2425.Parent = self.Character.HumanoidRootPart
		game.Debris:AddItem(RedFX2425,2)
		RedFX2425:Play()
	end)
	local buffvalue = Instance.new("BoolValue",self.Character)
	buffvalue.Value = true
	buffvalue.Name = ("VAMPIREKISSLUNGE")
	local AutoRotate = nil
	local ended = false
	local Cant3
	local Cant4
	self:listenForCancel(function()	
		if buffvalue ~= nil then
			buffvalue:Destroy()
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
		if self.Character:FindFirstChild("VAMPIREKISSLUNGE") then
			self.Character:FindFirstChild("VAMPIREKISSLUNGE"):Destroy()
		end
		if Cant ~= nil then
			Cant:Destroy()
		end
		if Cant3 ~= nil then
			Cant3:Destroy()
		end
		if Cant4 ~= nil then
			Cant4:Destroy()
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
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "Skill3Drill", "Dash2fiftiesNEWONE", self.Character, self.Character)	
	end
	
task.delay(40/60,function()
		if self.Cancelled then return end
game.Debris:AddItem(Cant,.16)
		Cant3 = Instance.new("NumberValue")
		Cant3.Name = "CantHeartBreak"
		Cant3.Parent = self.Character.Values
		Cant3:SetAttribute("HeartBreakMovementUnability",true)
		Cant4 = Instance.new("NumberValue")
		Cant4.Name = "HEARTBREAKCLOSEVARIANTHOLD"
		Cant4.Parent = self.Character
		Cant4:SetAttribute("HeartBreakMovementUnability",true)
		game:GetService("CollectionService"):AddTag(Cant4,"KISSLUNGE")
		AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Visuals2'
			end
		end
		dashforward()
	end)
	wait(44/60)
	local start152 = os.clock()
	task.delay(self.Settings2.HitboxSettings.Debris,function()
		if not self.Hit then
			self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill1", self.Settings.Cooldown)
		end
	end)
	if self.Cancelled then
		return
	end
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 110, "Scarlet Empress", "M1", "LUNGELOOPVFX", self.Character)	
	local IFrames = self.Knit.GetService("StateService"):CreateIFrames(self.Character)
	task.delay(self.Settings2.HitboxSettings.Debris,function()
		if IFrames ~= nil then
			IFrames:Destroy()
		end
	end)
	if self.Cancelled then
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.Release)
		if Cant ~= nil then
			Cant:Destroy()
		end
		if Cant3 ~= nil then
			Cant3:Destroy()
		end
		if Cant4 ~= nil then
			Cant4:Destroy()
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
	local connection1
	coroutine.resume(coroutine.create(function()
		self:CreateHitbox(function(Enemy)
			--if buffvalue ~= nil then
			--	buffvalue:Destroy()
			--end
			if not self.Character:FindFirstChild("HEARTBREAKCLOSEVARIANTHOLD") then return end
			local Can5t = Instance.new("NumberValue")
			Can5t.Name = "Cant"
			Can5t:SetAttribute("TemporaryKissVal",true)
			Can5t.Parent = self.Character.Values
			game.Debris:AddItem(Can5t,.4)
			--if connection1 ~= nil then
			--	connection1:Disconnect()
			--end
			self:TagEnemy(Enemy,startingPos)
			if self.Hit then
				if connection1 ~= nil then
					connection1:Disconnect()
				end
				for _,v in pairs(self.Character:GetChildren()) do
					if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
						v.CollisionGroup = 'Characters'
					end
				end
			end
		end)
	end))
	local function endlunge(punish)
		if ended == true then return end
		if not self.Hit then
			if self.Character:FindFirstChild("MilleniumVampire") then
				self.Character:FindFirstChild("MilleniumVampire"):Destroy()
			end
		end
		ended = true
		local Cant2 = self.Knit.GetService("StateService"):CreateCant(self.Character)
		Cant2:SetAttribute("TemporaryKissVal",true)
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Characters'
			end
		end
		if buffvalue ~= nil then
			buffvalue:Destroy()
		end
		if punish ~= false then
			if not self.Hit then
				--repeat wait() until not self.Character.HumanoidRootPart:FindFirstChild("GrabWeld")
				self.Cancelled = true
				if self.Character:FindFirstChild("HITWALLVAMPIRE") then
					local mathq = math.random(1,3)
					if mathq == 1 then
						self.Knit.GetService("CombatService"):FireAllClients(self.Character,250, "Stuff", "downslamupthing", "VOICELINE", self.Character,"Sound","Owchies")
					elseif mathq == 2 then
						self.Knit.GetService("CombatService"):FireAllClients(self.Character,250, "Stuff", "downslamupthing", "VOICELINE", self.Character,"SentenceSecondTake","I don't like the sun...")
					elseif mathq == 3 then
						self.Knit.GetService("CombatService"):FireAllClients(self.Character,250, "Stuff", "downslamupthing", "VOICELINE", self.Character,"SentenceFirstTake","I don't like the sun...")
					end
				else
					local mathq = math.random(1,3)
					if mathq == 1 then
						self.Knit.GetService("CombatService"):FireAllClients(self.Character,250, "Stuff", "downslamupthing", "VOICELINE", self.Character,"Sound",'(¬_¬")')
					elseif mathq == 2 then
						self.Knit.GetService("CombatService"):FireAllClients(self.Character,250, "Stuff", "downslamupthing", "VOICELINE", self.Character,"SentenceSecondTake",'Hmm, I have no one to kill time with...')
					elseif mathq == 3 then
						self.Knit.GetService("CombatService"):FireAllClients(self.Character,250, "Stuff", "downslamupthing", "VOICELINE", self.Character,"SentenceFirstTake",'Hmm, I have no one to kill time with...')
					end
				end
				task.delay(.25,function()
					self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.ReleaseNew)
				end)
				self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.Release2New,1,nil,0)
				wait(45/60)
			end
		else
			self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.ReleaseNew)
			self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.Release2New)
			self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.Release)
			--self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
		end
		if Cant2 ~= nil then
			Cant2:Destroy()
		end
		if Cant ~= nil then
			Cant:Destroy()
		end
		if Cant3 ~= nil then
			Cant3:Destroy()
		end
		if Cant4 ~= nil then
			Cant4:Destroy()
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
		if connection1 ~= nil then
			connection1:Disconnect()
		end
		self:Destroy()
	end
	connection1 = self.Character.Values.ChildAdded:Connect(function(child)
		if self.Hit then return end
		--if (os.clock() - start152 >= .15) then
		if (child.Name == ("Cant")) or (child.Name == ("STOPLUNGE")) then
			if child:GetAttribute("TemporaryKissVal") then return end
			if child:GetAttribute("TemporaryVal") then return end
			endlunge(false)
		end
		--end
	end)
	coroutine.resume(coroutine.create(function()
		while not ended do
			if self.Hit then 
				if AutoRotate ~= nil then
					AutoRotate:Destroy()
				end	
				break
			end
			if ended then
				break
			end
			local ray = Ray.new(self.Character.HumanoidRootPart.Position, self.Character.HumanoidRootPart.CFrame.LookVector * 13)
			local part, hitPosition = workspace:FindPartOnRayWithIgnoreList(ray, {workspace.Ignore,(workspace:FindFirstChild("nonsolidwall") or workspace.Ignore)})
			if part then
				--if (part.CanCollide == false) then return end
				--if (part.Shape == Enum.PartType.Wedge)  then return end
				local buffvalue5 = Instance.new("BoolValue",self.Character)
				buffvalue5.Value = true
				buffvalue5.Name = ("HITWALLVAMPIRE")
				game.Debris:AddItem(buffvalue5,1.5)
				self.Knit.GetService("CombatService"):FireAllClients(self.Character, 100, script.Parent.Name, "M1", "hitheadreallyhard", self.Character, self.Character.HumanoidRootPart,part)
				self.Character.Humanoid.Health -= 5
				self.Knit.GetService("CombatService"):FireAllClients(self.Character, 100, "Scarlet Empress", "M1", "LASTM1HIGHLIGHT", self.Character, self.Character)	
				endlunge()
				break
			end
			wait(.003)
		end
	end))
	task.delay(self.Settings2.HitboxSettings.Debris,function()
		endlunge()
	end)
end

return Skill1
