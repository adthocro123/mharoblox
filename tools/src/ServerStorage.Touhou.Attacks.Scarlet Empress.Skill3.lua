local Skill3 = {}
Skill3.Settings = {
	Cooldown = 25,
	Damage = 4.5,
	AttackLength = (50/60),
	AttackLength2 = (31/60),

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
	Damage = 7,
	AttackLength = 1.4,

	HitboxSettings = {
		DelayTime = 0,
		Debris = 3/60,

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
	if self.Knit.GetService("CounterService"):counter(self.Character, Enemy) then
		self.Cancelled = true
		self:Destroy()
	end
	--self.Knit.GetService("RagdollService"):unragdoll(self.Character, true,true)
	if Enemy:GetAttribute("Ragdoll") then
		self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	end
	if self.Character:FindFirstChild("MilleniumVampire") or (Enemy.Humanoid.Health <= 10) then
		if self.Character.Values:FindFirstChild("Stunned") then return end
		if self.Cancelled then return end
		if self.Hit then return end
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
		Enemy:SetAttribute("Cancel", os.clock())
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "Skill3Drill", "Dash", self.Character, self.Character)	

		task.delay(.1,function()
			self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWSTAB)
			self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWMISS)
		end)
		--self.Knit.GetService("RagdollService"):unragdoll(self.Character, true,true)
		if self.Character:FindFirstChild("MilleniumVampire") then
			self.Character:FindFirstChild("MilleniumVampire"):Destroy()
		end
		self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
		self.Hit = Enemy
		--self.Character.Humanoid.AutoRotate = true
		local attlength = (117/60)
		local attlength2 = (104/60)
		self:AddFor(attlength, function()
			self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill3", self.Settings.Cooldown)
		end)
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 35, self.Character:GetAttribute("Character"), "M1", "SKILL3HITSTARTVFX", self.Character, self.Character)	
		local grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,0,0)*CFrame.Angles(0,0,0))
		task.delay(1,function()
			self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.Release)
		end)
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 20, "Scarlet Empress", "M1", "2TRAIL", self.Character, self.Character)	

		if self.Character["Right Arm"]:FindFirstChild("remiliaspear") then
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 20, script.Parent.Name, "M1", "Hit53", self.Character, Enemy, math.random(1,3))
			self.Character["Right Arm"]:FindFirstChild("remiliaspear")["Impale"]:Play()
		end
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
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
					self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy5, 7)
					self:TagEnemyThrow(Enemy5)
				end)
				self.Knit.GetService("CombatService"):FireAllClients(self.Character, 20, script.Parent.Name, "M1", "Hit53", self.Character, Enemy, math.random(2,4))
				self.Knit.GetService("CombatService"):FireAllClients(self.Character, 20, "Gungnir", "M1", "HitPunch2", self.Character, Enemy, math.random(1,2))
				self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 4)
				self.Knit.GetService("CombatService"):FireAllClients(self.Character, 40, "Scarlet Empress", "M1", "RUBBLESLAM", Enemy, Enemy)	
				self.Knit.GetService("CombatService"):FireAllClients(self.Character, 40, "Scarlet Empress", "M1", "GROUNDSLAM", self.Character, self.Character)	
			end
		end
		local function flare()
			if self.Cancelled ~= true then
				self.Knit.GetService("CombatService"):FireAllClients(self.Character, 20, "Scarlet Empress", "M1", "FLARE", self.Character, self.Character)	

				--if self.Character["Right Arm"]:FindFirstChild("remiliaspear") then
				--	self.Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir"..math.random(1,2)]:Play()
				--	self.Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(self.Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
				--	self.Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(self.Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
				--end
			end
		end
		local function vortex()
			if self.Cancelled ~= true then
				self.Knit.GetService("CombatService"):FireAllClients(self.Character, 15, "Scarlet Empress", "M1", "CrokuranSponsorSpin", self.Character, self.Character)	
			end
		end
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 15, "Scarlet Empress", "M1", "M1TRAIL", self.Character, self.Character)	
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 15, "Scarlet Empress", "M1", "DASHM1TRAIL", self.Character, self.Character)	
		local RedF151X=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.BloodDash:Clone()
		RedF151X.Name = ("BloodDash2")
		game.Debris:AddItem(RedF151X,3)
		RedF151X.Parent = self.Character.HumanoidRootPart
		RedF151X:Play()
		--task.delay(14/60,function()
		--	self.Character["Right Arm"]:FindFirstChild("remiliaspear")["Impale2"]:Play()
		--end)
		task.delay(30/60,function()
			local RedFX=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.Sfx.Swings["s"..math.random(1,4)]:Clone()
			game.Debris:AddItem(RedFX,4)
			RedFX.Parent = self.Character.HumanoidRootPart
			RedFX:Play()
		end)
		task.delay(39/60,function()
			--groundslam()
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 5)
			if self.Character["Right Arm"]:FindFirstChild("remiliaspear") then
				self.Character["Right Arm"]:FindFirstChild("remiliaspear")["slash"]:Play()
				self.Knit.GetService("CombatService"):FireAllClients(self.Character, 25, "Scarlet Empress", "M1", "SpinVFX", self.Character, Enemy)
				self.Knit.GetService("CombatService"):FireAllClients(self.Character, 25, script.Parent.Name, "M1", "Hit53", self.Character, Enemy, 1)
			end
		end)
		task.delay(65/60,function()
			task.delay(6/60,function()
				if self.Cancelled ~= true then
					flare()
					self.Knit.GetService("CombatService"):FireAllClients(self.Character, 15, "Scarlet Empress", "M1", "LASTM1HIGHLIGHT", self.Character, self.Character)	
				end
			end)
			local RedFX=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.Sfx.Swings["s"..math.random(2,4)]:Clone()
			game.Debris:AddItem(RedFX,4)
			RedFX.Parent = self.Character.HumanoidRootPart
			RedFX:Play()
			if self.Cancelled ~= true then
			end
		end)
		task.delay(85/60,function()
			--groundslam()
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 5)
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 15, "Scarlet Empress", "M1", "SKILL3DOWNCUT", self.Character, self.Character)	
			if self.Character["Right Arm"]:FindFirstChild("remiliaspear") then
				self.Knit.GetService("CombatService"):FireAllClients(self.Character, 15, "Gungnir", "M1", "HitPunch2", self.Character, Enemy, 1)
				self.Knit.GetService("CombatService"):FireAllClients(self.Character, 15, script.Parent.Name, "M1", "Hit53", self.Character, Enemy, math.random(2,4))
				self.Character["Right Arm"]:FindFirstChild("remiliaspear")["Impale2"]:Play()
			end
		end)
		local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)

		local IFrames = self.Knit.GetService("StateService"):CreateIFrames(self.Character)

		task.delay(attlength,function()
			if IFrames ~= nil then
				IFrames:Destroy()
			end
		end)
		local IFramesEnemy = self.Knit.GetService("StateService"):CreateIFrames(Enemy)
		local AutoRotateEnemy = self.Knit.GetService("StateService"):CreateAutoRotate(Enemy)
		local AutoRotate = nil
		task.delay(attlength2,function()
			if IFramesEnemy ~= nil then
				IFramesEnemy:Destroy()
			end
			if AutoRotateEnemy ~= nil then
				AutoRotateEnemy:Destroy()
			end
		end)
		local Cant2 = self.Knit.GetService("StateService"):CreateCant(Enemy)
		local StunVal = self.Knit.GetService("StateService"):CreateStun(Enemy)
		game.Debris:AddItem(Cant2,attlength2)
		game.Debris:AddItem(StunVal,attlength2)
		local Speed1, Jump2 = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, .01), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
		game.Debris:AddItem(Speed1, attlength)
		game.Debris:AddItem(Jump2, attlength+ .2)

		local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(Enemy, 0), self.Knit.GetService("MovementService"):CreateJump(Enemy, 0)
		game.Debris:AddItem(Speed, attlength2)
		game.Debris:AddItem(Jump, attlength2)
		task.delay(85/60,function()
			AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
			task.delay(1,function()
				if AutoRotate ~= nil then
					AutoRotate:Destroy()
				end
			end)
		end)
		task.delay(88/60,function()
			groundslam()
			if IFramesEnemy ~= nil then
				IFramesEnemy:Destroy()
			end
			if grab ~= nil then
				grab:Destroy()
			end
			if Jump ~= nil then
				Jump:Destroy()
			end
			if Speed ~= nil then
				Speed:Destroy()
			end
			self:TagEnemyThrow(Enemy)

		end)
		self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.Victim)
		self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.Success)
		task.delay(attlength,function()
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
			--local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.Throw:Clone()
			--RedFX2425.Parent = Enemy.HumanoidRootPart
			--game.Debris:AddItem(RedFX2425,1.117)
			--RedFX2425:Play()
			--local RedFX=ResourceFolder.Throw:Clone()
			--RedFX.CFrame = Enemy.Head.CFrame
			--game.Debris:AddItem(RedFX,2.6)
			--RedFX.Parent = workspace.Ignore.Effects
			--for i,v in pairs(RedFX:GetDescendants()) do
			--	if v:IsA('ParticleEmitter') then
			--		v:Emit(v.Rate)
			--	end
			--end
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
			--self:TagEnemyThrow(Enemy)
			--self.Knit.GetService("AnimationService"):stopAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.Victim)
			--self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, self.Settings.Damage)
			--self.Knit.GetService("RagdollService"):ragdoll(Enemy, 3)
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
			local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.Throw:Clone()
			RedFX2425.Parent = Enemy.HumanoidRootPart
			game.Debris:AddItem(RedFX2425,1.117)
			RedFX2425:Play()


			--self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.Success)
			--self.Knit.GetService("AnimationService"):stopAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.Victim)
			if Cant ~= nil then
				Cant:Destroy()
			end
		end)
	else
	self.Hit = Enemy
	--self.Character.Humanoid.AutoRotate = true
	local grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,0,0)*CFrame.Angles(0,0,0))
	task.delay(.25,function()
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWSTAB)
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWMISS)
	end)
	for _,v in pairs(self.Character:GetChildren()) do
		if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
			v.CollisionGroup = 'Visuals2'
		end
	end

	self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 1.5)
	local function groundslam()
		if self.Cancelled ~= true then

			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, script.Parent.Name, "M1", "DownSlam", self.Character, Enemy)
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, script.Parent.Name, "M1", "Hit", self.Character, Enemy, 4)
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
				self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy5, 5)
				self:TagEnemyThrow(Enemy5)
			end)
			--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 35, "Scarlet Empress", "M1", "DOWNCUT", self.Character, self.Character)	
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 35, script.Parent.Name, "M1", "HitNOVFX", self.Character, Enemy, math.random(2,4))
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 1)
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 70, "Scarlet Empress", "M1", "RUBBLESLAM", Enemy, Enemy)	
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 45, "Scarlet Empress", "M1", "GROUNDSLAMFIRSTSKILL", self.Character, self.Character)	
		end
	end
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 120, "Scarlet Empress", "M1", "SKILL3GRAB", self.Character, Enemy)	
	--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 40, "Scarlet Empress", "M1", "BLOODSMASHVFX", self.Character, self.Character)	
	local damageheal = .9
	local function sucky()
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, damageheal)
		self.Character.Humanoid.Health += (damageheal--/1.1
		)
	end
	--task.delay(14/60,function()
	--	self.Character["Right Arm"]:FindFirstChild("remiliaspear")["Impale2"]:Play()
	--end)
	--task.delay(85/60,function()
	--	--groundslam()
	--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 150, "Scarlet Empress", "M1", "Skill1DOWNCUT", self.Character, self.Character)	
	--	if self.Character["Right Arm"]:FindFirstChild("remiliaspear") then
	--		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Gungnir", "M1", "HitPunch2", self.Character, Enemy, 1)
	--		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, script.Parent.Name, "M1", "HitNOVFX", self.Character, Enemy, math.random(2,4))
	--		self.Character["Right Arm"]:FindFirstChild("remiliaspear")["Impale2"]:Play()
	--	end
	--end)
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

	--self.Knit.GetService("CombatService"):FireClient(Enemy, Enemy, "Scarlet Empress", "M1", "DEVOURCOLORCORRECTION", Enemy, true)	
	--task.delay(4,function()
	--	self.Knit.GetService("CombatService"):FireClient(Enemy, Enemy, "Scarlet Empress", "M1", "DEVOURCOLORCORRECTION", Enemy, false)	
	--end)

	local Cant2 = self.Knit.GetService("StateService"):CreateCant(Enemy)
	local StunVal = self.Knit.GetService("StateService"):CreateStun(Enemy)
	--game.Debris:AddItem(Cant2,self.Settings.AttackLength2+.4)
	--game.Debris:AddItem(StunVal,self.Settings.AttackLength2+.4)
	local Speed1, Jump2 = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 1), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	--game.Debris:AddItem(Speed1, self.Settings.AttackLength)
	--game.Debris:AddItem(Jump2, self.Settings.AttackLength + .2)

	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(Enemy, 0), self.Knit.GetService("MovementService"):CreateJump(Enemy, 0)
	--game.Debris:AddItem(Speed, self.Settings.AttackLength2)
	--game.Debris:AddItem(Jump, self.Settings.AttackLength2)

	--task.delay(36/60,function()
	--	sucky()
	--end)

	--task.delay(44/60,function()
	--	sucky()
	--end)
	
	--task.delay(55/60,function()
	--	sucky()
	--end)

	--task.delay(65/60,function()
	--	sucky()
	--end)

	--task.delay(69/60,function()
	--	sucky()
	--end)

	--task.delay(76/60,function()
	--	sucky()
	--end)

	--task.delay(88/60,function()
	--	sucky()
	--end)

	--task.delay(91/60,function()
	--	sucky()
	--end)
	local finish = false
	task.delay(self.Settings.AttackLength2,function()
		if grab ~= nil then
			grab:Destroy()
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
		self.Knit.GetService("AnimationService"):stopAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWVICTIM)
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Immortal Blaze", "Skill3Drill", "LOLDASH21452", self.Character, self.Character)	
	end)
	task.delay(self.Settings.AttackLength2,function()
		groundslam()
	end)
	self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWVICTIM,1,nil,0)
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWHIT,1,nil,0)
	task.delay(self.Settings.AttackLength,function()
		if finish == true then return end
		local holding5 = Instance.new("BoolValue",self.Character)
		holding5.Value = true
		holding5.Name = ("canusetwice")
		game.Debris:AddItem(holding5,32/60)
		task.delay(32/60,function()
			if Jump2 ~= nil then
				Jump2:Destroy()
			end
			if not self.Character:FindFirstChild("usedtwice") then
				self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill3", self.Settings.Cooldown)
			end
		end)
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
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
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Characters'
			end
		end
		if Speed1 ~= nil then
			Speed1:Destroy()
		end
		if Cant ~= nil then
			Cant:Destroy()
		end
	end)	
end
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

		Damage = 1,
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
			Velocity = self.Character.HumanoidRootPart.CFrame.RightVector*(30) + Vector3.new(0,16,0), 
			Time = .33,
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

		Damage = 4.4,
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
function Skill3:TagEnemy2OLD(Enemy)
	if self.Character.Values:FindFirstChild("Stunned") then return end
	if self.Cancelled then return end
	local damage = 3
	local KnockbackData1 = {
			KnockbackType = "Velocity",
		MaxForce = Vector3.new(20000,20000,20000),
			Velocity = Vector3.new(0,45,0),
			Time = .05,
		}
local knockbackdata = 2
	--self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Victim2,1,nil,0)
	--wait()
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,


		KnockbackData = KnockbackData1,

		StateData = {
			Stunned = knockbackdata,
			AutoRotate = knockbackdata,
		},

		MovementData = {
			WalkSpeed = 0,
			JumpPower = 0,
			Time = knockbackdata,
		},

		RagdollData = {
			Time = knockbackdata,
		},
		Damage = damage,
		--EnemyFacesCharacter = true,
	},function(State)
		if State == "Hit" then
			self.HitSomeone = true
			--local RedF2X2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.althit:Clone()
			--RedF2X2425.Parent = Enemy.Torso
			--game.Debris:AddItem(RedF2X2425,2)
			--RedF2X2425:Play()
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 45, script.Parent.Name, "M1", "HitNOSFX", self.Character, Enemy, math.random(1,4))
		end
	end)
end
function Skill3:TagEnemy2(Enemy)
	if self.Character.Values:FindFirstChild("Stunned") then return end
	if self.Cancelled then return end
	local damage = 1.4
	local KnockbackData1 = {
		KnockbackType = "Velocity",
		MaxForce = Vector3.new(20000,20000,20000),
		Velocity = Vector3.new(0,0,0),
		Time = .05,
	}
	local knockbackdata = 1
	if Enemy:GetAttribute("Ragdoll") then
		self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	end
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,


		KnockbackData = KnockbackData1,

		StateData = {
			Stunned = knockbackdata,
			AutoRotate = knockbackdata,
		},

		MovementData = {
			WalkSpeed = 0,
			JumpPower = 0,
			Time = knockbackdata,
		},

		ReactionAnim = (game.ReplicatedStorage.Assets.Animations.ReactionsFlyingREAL["Reaction"..math.random(1,4)]),

		Damage = damage,
	},function(State)
		if State == "Hit" then
			self.Hit = true
			self.HitSomeone = true
			--local RedF2X2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.althit:Clone()
			--RedF2X2425.Parent = Enemy.Torso
			--game.Debris:AddItem(RedF2X2425,2)
			--RedF2X2425:Play()
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 45, script.Parent.Name, "M1", "HitNOSFX", self.Character, Enemy, math.random(1,4))
		end
	end)
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

		Damage = 2,
		EnemyFacesCharacter = true,

	},function(State)
		self.HitSomeone = true
		--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 70, "Scarlet Empress", "M1", "SmashWhenGround", Enemy,1)
	end)
end
function Skill3:Release(InAir)
	if self.Character.HumanoidRootPart:FindFirstChild("GrabWeld") then return end
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
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWAIRVARIANTSTARTUP)
	if (InAir) or (self.Character:FindFirstChild("canusetwice")) then
		if self.Character.HumanoidRootPart:FindFirstChild("GrabWeld") then return end
		local seconduse = false
	if self.Character:FindFirstChild("canusetwice") then
		self.Character:FindFirstChild("canusetwice"):Destroy()
		local holding5 = Instance.new("BoolValue",self.Character)
		holding5.Value = true
		holding5.Name = ("usedtwice")
		game.Debris:AddItem(holding5,100/60)
		seconduse = true
	end
	self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
	--self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill3", self.Settings2.Cooldown)
		self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWAIRVARIANTSTARTUP)
		local Speed1, Jump2 = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, .2), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	local Speed, Jump
	--if InAir then
	--	self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Stuff", "downslamupthing", "downslamvelocity", self.Character, self.Character)	
		--end
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Visuals2'
			end
		end
	--self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Stuff", "downslamupthing", "ENABLEAIRLIMBS", self.Character, self.Character)	
	local IFrames = self.Knit.GetService("StateService"):CreateIFrames(self.Character)
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
		local buffvalue = Instance.new("BoolValue",self.Character)
		buffvalue.Value = true
		buffvalue.Name = ("LEROY")
		self:listenForCancel(function()
			self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill3", self.Settings2.Cooldown)
			if buffvalue ~= nil then
				buffvalue:Destroy()
			end
			if self.Character:FindFirstChild("LEROY") then
				self.Character:FindFirstChild("LEROY"):Destroy()
			end
		--self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Stuff", "downslamupthing", "DISABLEAIRLIMBS", self.Character, self.Character)	
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
		if Cant ~= nil then
			Cant:Destroy()
		end
		self.Cancelled = true
		self:Destroy()
	end)
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Stuff", "downslamupthing", "downslamvelocity", self.Character, self.Character)	
		wait(8/60)
	--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 50, script.Parent.Name, "M1", "Impact25", self.Character, self.Character)
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 110, "Scarlet Empress", "M1", "LEROY3SKILL", self.Character)	

		local Pos = self.Character.HumanoidRootPart.Position
		--if (self.Character.Humanoid:GetState() == Enum.HumanoidStateType.Running) then
		--end
		local stophitting = false
		local NewJump = ApplyHandlr.functioned(self.Character.HumanoidRootPart,Vector3.new(0,1.8,0),self.Character.HumanoidRootPart.CFrame.LookVector,3,7,1.4,nil,{workspace.Ignore},false,.1)
		local start = os.clock()

		repeat
			wait()
		until (NewJump.Complet and (os.clock() - start >= .1)) or (os.clock() - start >= 4)					 
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
			self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWAIRVARIANTSTARTUP)
		if Cant ~= nil then
			Cant:Destroy()
		end
		self.Cancelled = true
		self:Destroy()
		return
	end
		self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWAIRVARIANTSLAM)
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWAIRVARIANTSTARTUP)
	--self.Knit.GetService("AnimationService"):setTimePos(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Startup1,(36/60))
	--self.Knit.GetService("AnimationService"):adjustSpeed(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Startup1,1)
	local AutoRotate
	if not self.Cancelled then
		AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
			self.Knit.GetService("CombatService"):FireAllClients(self.Character,250, "Stuff", "downslamupthing", "VOICELINE", self.Character,"Giggle")
			self:CreateHitbox2(function(Enemy)
				if self.Character.Values:FindFirstChild("Stunned") then return end
				if self.Cancelled then return end
				--self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Victim2,1,nil,0)
				self:TagEnemy2(Enemy)
			end)
			task.delay(10/60,function()
				if self.Cancelled then return end
				self:CreateHitbox2(function(Enemy)
					if self.Character.Values:FindFirstChild("Stunned") then return end
					if self.Cancelled then return end
					--self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Victim2,1,nil,0)
					self:TagEnemy2(Enemy)
				end)
			end)
			task.delay(20/60,function()
				if self.Cancelled then return end
				self:CreateHitbox2(function(Enemy)
					if self.Character.Values:FindFirstChild("Stunned") then return end
					if self.Cancelled then return end
					--self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Victim2,1,nil,0)
					self:TagEnemy2(Enemy)
				end)
			end)
			task.delay(30/60,function()
				if self.Cancelled then return end
				self:CreateHitbox2(function(Enemy)
					if self.Character.Values:FindFirstChild("Stunned") then return end
					if self.Cancelled then return end
					--self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Victim2,1,nil,0)
					self:TagEnemyThrow215(Enemy)
				end)
			end)
			local buffvalue51 = Instance.new("BoolValue",self.Character)
			buffvalue51.Value = true
			buffvalue51.Name = ("createdhitbox3")
			game.Debris:AddItem(buffvalue51,1)
			if buffvalue ~= nil then
				buffvalue:Destroy()
			end
			if self.Character:FindFirstChild("LEROY") then
				self.Character:FindFirstChild("LEROY"):Destroy()
			end
		--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 50, script.Parent.Name, "M1", "DownSlam2", self.Character, self.Character)
		--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 50, "Immortal Blaze", "M1", "groundcrack2", self.Character, self.Character)	
		--task.delay(.1,function()
		--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 35, "Immortal Blaze", "M1", "mokouleftvfx", self.Character, self.Character)	
		--end)
		--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 35, "Immortal Blaze", "M1", "LASTM1HIGHLIGHT", self.Character, self.Character)	
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
	--for i ,v in pairs(FX:GetDescendants())do
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
		wait(35/60)
		if not self.Cancelled then
			self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill3", self.Settings2.Cooldown)
		end
	--self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Stuff", "downslamupthing", "DISABLEAIRLIMBS", self.Character, self.Character)	
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
else
		if self.Character.HumanoidRootPart:FindFirstChild("GrabWeld") then return end
		self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWSTAB,1,nil,.1)
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
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 145, "Scarlet Empress", "M1", "3STARTVFX", self.Character)	
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
			self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWHIT)
			self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWSTAB)
			self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWMISS)
			self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWAIRVARIANTSLAM)
		self.Cancelled = true
		self:Destroy()
	end)
	local hrp = self.Character:FindFirstChild("HumanoidRootPart")
	local startingPos = self.Character.HumanoidRootPart.Position
	local function dashforward()
			self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "Skill3Drill", "Dash2fiftiesz25", self.Character, self.Character)	
		end
		task.delay(16/60,function()
			if self.Cancelled then return end
			AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
			dashforward()
		end)
	wait(19/60)
		--self.Knit.GetService("AnimationService"):adjustSpeed(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWSTAB,.14)
		task.delay(self.Settings2.HitboxSettings.Debris,function()
		if not self.Hit then
			self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill3", self.Settings.Cooldown)
		end
	end)
	if self.Cancelled then
		return
	end
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 110, "Scarlet Empress", "M1", "LUNGELOOPVFX3SKILL", self.Character)	
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
				task.delay(.25,function()
					self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWSTAB)
				end)
				self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill3.NEWMISS,1,nil,0)
				wait(55.1/60)
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
	task.delay(self.Settings2.HitboxSettings.Debris,function()
		endlunge()
	end)
end
end

return Skill3
