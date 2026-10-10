local Skill2 = {}
Skill2.Settings = {
	Cooldown = 30,
	Damage = 5,
	AttackLength = (315/60),
	AttackLength2 = (265/60),

	HitboxSettings = {
		DelayTime = .2,
		Debris = .14,

		Offset = CFrame.new(0,2.5,-3.2),
		Size = Vector3.new(10,5,20)
	},
	magnitudeForClose = 20,
}
Skill2.Settings2 = {
	Cooldown = 30,
	Damage = 7,
	AttackLength = 1.4,

	HitboxSettings = {
		DelayTime = 0,
		Debris = .4,

		Offset = CFrame.new(0,4.5,-7),
		Size = Vector3.new(10,10,25)
	},
}

function Skill2:CreateHitbox(callback)
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

function Skill2:TagEnemy(Enemy)
	if self.Character.Values:FindFirstChild("Stunned") then return end
	if self.Cancelled then return end
	if self.Hit then return end
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
	--self.Knit.GetService("RagdollService"):unragdoll(self.Character, true,true)
	self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	self.Hit = Enemy
	--self.Character.Humanoid.AutoRotate = true
	self:AddFor(self.Settings.AttackLength, function()
		self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill2", self.Settings.Cooldown)
	end)
	local grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,0,-3)*CFrame.Angles(0,math.rad(180),0))
	task.delay(1,function()
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill2OLD.Release)
	end)

	--task.delay(14/60,function()
	--	self.Character["Right Arm"]:FindFirstChild("remiliaspear")["Impale2"]:Play()
	--end)
	--task.delay(85/60,function()
	--	--groundslam()
	--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 150, "Immortal Blaze", "M1", "Skill2DOWNCUT", self.Character, self.Character)	
	--	if self.Character["Right Arm"]:FindFirstChild("remiliaspear") then
	--		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Gungnir", "M1", "HitPunch2", self.Character, Enemy, 1)
	--		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, script.Parent.Name, "M1", "HitNOVFX", self.Character, Enemy, math.random(2,4))
	--		self.Character["Right Arm"]:FindFirstChild("remiliaspear")["Impale2"]:Play()
	--	end
	--end)
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)

	local IFrames = self.Knit.GetService("StateService"):CreateULTIFrames(self.Character)
	local AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
	task.delay(self.Settings.AttackLength,function()
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
		end
		if IFrames ~= nil then
			IFrames:Destroy()
		end
	end)
	local IFramesEnemy = self.Knit.GetService("StateService"):CreateULTIFrames(Enemy)
	local AutoRotateEnemy = self.Knit.GetService("StateService"):CreateAutoRotate(Enemy)
	task.delay(self.Settings.AttackLength2,function()
		if IFramesEnemy ~= nil then
			IFramesEnemy:Destroy()
		end
		if AutoRotateEnemy ~= nil then
			AutoRotateEnemy:Destroy()
		end
	end)

	if self.Character:FindFirstChild("DashTrail") then
		self.Character:FindFirstChild("DashTrail"):Destroy()
	end
	if self.Character:FindFirstChild("DashTrail") then
		self.Character:FindFirstChild("DashTrail"):Destroy()
	end
	if self.Character['Right Leg']:FindFirstChild("DashTrail") then
		self.Character['Right Leg']:FindFirstChild("DashTrail"):Destroy()
	end
	if self.Character['Left Leg']:FindFirstChild("DashTrail") then
		self.Character['Left Leg']:FindFirstChild("DashTrail"):Destroy()
	end
	local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
	FX.Parent=self.Character
	FX.w.Part0= self.Character['Right Leg']
	local FX2= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
	FX2.Parent=self.Character
	FX2.w.Part0= self.Character['Left Leg']
	game.Debris:AddItem(FX,7)
	game.Debris:AddItem(FX2,7)

	local Cant2 = self.Knit.GetService("StateService"):CreateCant(Enemy)
	local StunVal = self.Knit.GetService("StateService"):CreateStun(Enemy)
	game.Debris:AddItem(Cant2,self.Settings.AttackLength2)
	game.Debris:AddItem(StunVal,self.Settings.AttackLength2)
	local Speed1, Jump2 = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 1), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	game.Debris:AddItem(Speed1, self.Settings.AttackLength)
	game.Debris:AddItem(Jump2, self.Settings.AttackLength + .1)

	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(Enemy, 0), self.Knit.GetService("MovementService"):CreateJump(Enemy, 0)
	game.Debris:AddItem(Speed, self.Settings.AttackLength2)
	game.Debris:AddItem(Jump, self.Settings.AttackLength2)
	self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill2OLD.Victim,1,nil,0)
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill2OLD.Success,1,nil,0)
	local beatdownsfx=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].mokoubeatdown2:Clone()
	beatdownsfx.Parent = self.Character.Torso
	game.Debris:AddItem(beatdownsfx,beatdownsfx.TimeLength + .1)
	beatdownsfx:Play()
	local function groundcrack()
	if self.Cancelled then return end
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Gungnir", "M1", "HitPunch2", self.Character, Enemy, math.random(1,2))
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Immortal Blaze", "M1", "groundcrack", self.Character, self.Character)	
	end
	local function firstonetwo()
		if self.Cancelled then return end
		--local RedFX2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat["BarrageHit"..math.random(1,2)]:Clone()
		--RedFX2425.Parent = Enemy.Torso
		--game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
		--RedFX2425:Play()
		--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, script.Parent.Name, "M1", "HitSFX", self.Character, Enemy, math.random(1,4))
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 1.5)
	end
	local function bigexplode()
		if self.Cancelled then return end
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Gungnir", "M1", "HitPunch2", self.Character, Enemy, math.random(1,2))
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Immortal Blaze", "M1", "bigexplode", self.Character, self.Character)	
	end
	bigexplode()
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, script.Parent.Name, "M1", "HitNOSFX", self.Character, Enemy, math.random(1,4))
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Gungnir", "M1", "HitPunch1", self.Character, Enemy, math.random(1,2))
	self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 1.5)
	task.delay(180/60,function()
		if self.Cancelled then return end
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Scarlet Empress", "M1", "SpinVFX", self.Character, self.Character)
	end)
	task.delay(211/60,function()
		if self.Cancelled then return end
		local RedFX2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.abysscswing:Clone()
		RedFX2425.Parent = self.Character.HumanoidRootPart
		game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
		RedFX2425:Play()
	end)
	task.delay(95/60,function()
		if self.Cancelled then return end
		firstonetwo()
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Immortal Blaze", "M1", "mokoubarragevfx2", self.Character, self.Character)	
	end)
	task.delay(108/60,function()
		if self.Cancelled then return end
		firstonetwo()
	end)
	task.delay(120/60,function()
		if self.Cancelled then return end
		firstonetwo()
	end)
	task.delay(120/60,function()
		if self.Cancelled then return end
		firstonetwo()
	end)
	task.delay(125/60,function()
		if self.Cancelled then return end
		firstonetwo()
	end)
	task.delay(131/60,function()
		if self.Cancelled then return end
		firstonetwo()
	end)
	task.delay(145/60,function()
		if self.Cancelled then return end
		firstonetwo()
	end)
	task.delay(154/60,function()
		if self.Cancelled then return end
		firstonetwo()
	end)
	task.delay(264/60,function()
		if self.Cancelled then return end
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, script.Parent.Name, "M1", "HitNOSFX", self.Character, Enemy, math.random(1,4))
		bigexplode()
	end)
	task.delay(266/60,function()
		if self.Cancelled then return end
		--local RedFX2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat["ROCKIMPACT1"]:Clone()
		--RedFX2425.Parent = self.Character.Torso
		--game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
		--RedFX2425:Play()
		self.Knit.GetService("HitboxService"):createHitbox({
			Caster = self.Character,
			Origin = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-4),
			Offset = CFrame.new(0,0,-3.7),
			Size = Vector3.new(17,17,19),
			HitboxType = "Box",
			HitType = "OneHit",
			IgnoresRagdoll = true,
			IgnoresBlock = true,
			DelayTime = 0,
			Debris = .1,
		}, function(Enemy5)
			if Enemy5 == Enemy then return end
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, script.Parent.Name, "M1", "HitNOSFX", self.Character, Enemy5, math.random(1,4))
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy5, 3)
			self:TagEnemyThrow3(Enemy5)
		end)
		groundcrack()
	end)
	task.delay(195/60,function()
		if self.Cancelled then return end
		--local RedFX2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat["ROCKIMPACT15"]:Clone()
		--RedFX2425.Parent = self.Character.Torso
		--game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
		--RedFX2425:Play()
		groundcrack()
		self.Knit.GetService("HitboxService"):createHitbox({
			Caster = self.Character,
			Origin = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-4),
			Offset = CFrame.new(0,0,-2.8),
			Size = Vector3.new(17,16,16),
			HitboxType = "Box",
			HitType = "OneHit",
			IgnoresRagdoll = true,
			IgnoresBlock = true,
			DelayTime = 0,
			Debris = .1,
		}, function(Enemy5)
			if Enemy5 == Enemy then return end
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, script.Parent.Name, "M1", "HitNOSFX", self.Character, Enemy5, math.random(1,4))
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy5, 3)
			self:TagEnemyThrow2(Enemy5)
		end)
		--local RedFX2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat["Kick"..math.random(2,3)]:Clone()
		--RedFX2425.Parent = Enemy.Torso
		--game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
		--RedFX2425:Play()
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Immortal Blaze", "M1", "mokouleftvfx", self.Character, self.Character)	
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, script.Parent.Name, "M1", "HitNOSFX", self.Character, Enemy, math.random(1,4))
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 1.8)
	end)
	task.delay(68/60,function()
		if self.Cancelled then return end
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Immortal Blaze", "M1", "mokouleftvfx", self.Character, self.Character)	
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, script.Parent.Name, "M1", "HitNOSFX", self.Character, Enemy, math.random(1,4))
		self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 1.8)
	end)
	local raycastResult
	local originalpos = self.Character.HumanoidRootPart.CFrame
	local function checkwall()
		local pos1 = self.Character.HumanoidRootPart.CFrame
		local pos =  pos1-- * CFrame.new(0,0,0)
		local raycastParams  = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
		raycastParams.FilterDescendantsInstances = {self.Character,workspace.Ignore.Effects,workspace.Ignore.Rocks,Enemy}
		raycastResult = workspace:Raycast(pos.p, pos.LookVector*4, raycastParams)

		if raycastResult then
			Enemy.HumanoidRootPart.CFrame = originalpos * CFrame.new(0,0,-.1)
		end
	end
task.delay(265/60,function()
		if self.Cancelled then return end
		if grab ~= nil then
			grab:Destroy()
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
		if AutoRotateEnemy ~= nil then
			AutoRotateEnemy:Destroy()
		end
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end
		--Enemy.HumanoidRootPart.CFrame = Enemy.HumanoidRootPart.CFrame * CFrame.new(0,0,6.743)
		self:TagEnemyThrow(Enemy)
		--checkwall()
		task.delay(.1,function()
			checkwall()
			if StunVal ~= nil then
				StunVal:Destroy()
			end
			if Cant2 ~= nil then
				Cant2:Destroy()
			end
		end)
	end)
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 120, "Immortal Blaze", "M1", "LASTM1HIGHLIGHT", self.Character, self.Character)	
	task.delay(self.Settings.AttackLength - (4/60),function()
		if self.Cancelled then return end
		local pos1 = self.Character.HumanoidRootPart.CFrame
		local pos =  pos1 * CFrame.new(0,-1,1)
		local raycastParams  = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
		raycastParams.FilterDescendantsInstances = {self.Character,workspace.Ignore.Effects,workspace.Ignore.Rocks}
		raycastResult = workspace:Raycast(pos.p, pos.LookVector*5.404, raycastParams)

		local TPD = -5.404

		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill2OLD.Success, 0)
		if raycastResult then

			local magnitude  = (pos.p - raycastResult.Position).Magnitude

			TPD =  -magnitude
		else
			self.Character.HumanoidRootPart.CFrame = pos * CFrame.new(-0.656,0,TPD)
		end


		--self.Character.HumanoidRootPart.CFrame = self.Character.HumanoidRootPart.CFrame * CFrame.new(-0.656,0,-5.404)

		if FX2 ~= nil then
			game.Debris:AddItem(FX2,1)
			for i ,v in pairs(FX2:GetDescendants())do
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
				if v:IsA('Trail') then
					v.Enabled = false
				end
			end
		end
		if FX ~= nil then
			game.Debris:AddItem(FX,1)
			for i ,v in pairs(FX:GetDescendants())do
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
				if v:IsA('Trail') then
					v.Enabled = false
				end
			end
		end
		if FX2 ~= nil then
			game.Debris:AddItem(FX2,1)
			for i ,v in pairs(FX2:GetDescendants())do
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
				if v:IsA('Trail') then
					v.Enabled = false
				end
			end
		end
		if IFrames ~= nil then
			IFrames:Destroy()
		end
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
		end
		--local RedFX2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Throw:Clone()
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
		if Jump2 ~= nil then
			Jump2:Destroy()
		end
		if Speed1 ~= nil then
			Speed1:Destroy()
		end
		if Cant ~= nil then
			Cant:Destroy()
		end
		--self:TagEnemyThrow(Enemy)

		--self.Knit.GetService("AnimationService"):stopAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill2OLD.Victim)
		--self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, self.Settings.Damage)
		--self.Knit.GetService("RagdollService"):ragdoll(Enemy, 3)
	end)	

	self:listenForCancel(function()
		if beatdownsfx ~= nil then
			beatdownsfx:Destroy()
		end
		if FX2 ~= nil then
			game.Debris:AddItem(FX2,1)
			for i ,v in pairs(FX2:GetDescendants())do
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
				if v:IsA('Trail') then
					v.Enabled = false
				end
			end
		end
		if FX ~= nil then
			game.Debris:AddItem(FX,1)
			for i ,v in pairs(FX:GetDescendants())do
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
				if v:IsA('Trail') then
					v.Enabled = false
				end
			end
		end
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
		checkwall()
		local RedFX2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Throw:Clone()
		RedFX2425.Parent = Enemy.HumanoidRootPart
		game.Debris:AddItem(RedFX2425,1.117)
		RedFX2425:Play()
		--self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill2OLD.Success)
		--self.Knit.GetService("AnimationService"):stopAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill2OLD.Victim)
		if Cant ~= nil then
			Cant:Destroy()
		end
	end)
end
function Skill2:TagEnemyThrow2(Enemy)
	if self.Cancelled then return end

	local isflying = false if Enemy:GetAttribute("Character") == ("Scarlet Empress") then isflying = true end self.Knit.GetService("DamageService"):Damage({

	KnockbackData = {
		KnockbackType = "Velocity",
		MaxForce = Vector3.new(20000,20000,20000),
		Velocity = Vector3.new(1,25,1),
		Time = .3,
	},

	Character = self.Character,
	Enemy = Enemy,

	StateData = {
		Stunned = 2,
		AutoRotate = 2,
	},

	MovementData = {
		WalkSpeed = 0,
		JumpPower = 0,
		Time = 2,
	},

	RagdollData = {
		Time = 2,
	},

	ReactionAnim = (game.ReplicatedStorage.Assets.Animations.ReactionsFlyingREAL["Reaction"..math.random(1,4)]),

	Damage = .3,
	},function(State)
		self.HitSomeone = true

	end)
end
function Skill2:TagEnemyThrow3(Enemy)
	if self.Character.Values:FindFirstChild("Stunned") then return end
	if self.Cancelled then return end
	local damage = 3
	--Enemy.HumanoidRootPart.CFrame = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-1.5)
	self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,
		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(20000,20000,20000),
			Velocity = ((Enemy.HumanoidRootPart.CFrame.Position - self.Character.HumanoidRootPart.CFrame.Position).Unit *(85)) + Vector3.new(0,10,0), 
			Time = .2,
		},
		RagdollData =  {
			Time = 2,
		},
		StateData = {
			Stunned = 2,
			AutoRotate = 2,
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
			Time = 2,
		},

		BlockData = {			
			HitterOrigin = self.Character.HumanoidRootPart.CFrame,
		},

		Damage = .3,
		ReactionAnim = (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),
		--EnemyFacesCharacter = true,
	},function(State)
		self.HitSomeone = true

	end)
end
function Skill2:TagEnemyThrow(Enemy)
	if self.Character.Values:FindFirstChild("Stunned") then return end
	if self.Cancelled then return end
	local damage = 3
	--Enemy.HumanoidRootPart.CFrame = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-1.5)
	self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	if damage >= Enemy.Humanoid.Health then
		self.Knit.GetService("DamageService"):Damage({

			Character = self.Character,
			Enemy = Enemy,

			KnockbackData = {
				KnockbackType = "Velocity",
				MaxForce = Vector3.new(100000,100000,100000),
				Velocity = (self.Character.HumanoidRootPart.CFrame.LookVector*(150)) + Vector3.new(0,80,0), 
				Time = .5,
			},

			--StateData = {
			--	Stunned = 3,
			--	AutoRotate = 3,
			--},

			--MovementData = {
			--	WalkSpeed = 0,
			--	JumpPower = 0,
			--	Time = 3,
			--},

			--RagdollData = {
			--	Time = 3,
			--},

			Damage = damage * 500,
		},function(State)
			self.HitSomeone = true

		end)
	else
		self.Knit.GetService("DamageService"):Damage({

			Character = self.Character,
			Enemy = Enemy,

			KnockbackData = {
				KnockbackType = "ShortKnockback",
				--MaxForce = Vector3.new(100000,0,100000),
				VelocityOrigin = self.Character.HumanoidRootPart, 
				Velocity = 7, 
				VelocityUp = 6, 
				--Time = .25,
			} ,

			--StateData = {
			--	Stunned = 3,
			--	AutoRotate = 3,
			--},

			--MovementData = {
			--	WalkSpeed = 0,
			--	JumpPower = 0,
			--	Time = 3,
			--},

			--RagdollData = {
			--	Time = 3,
			--},

			Damage = damage,
		},function(State)
			self.HitSomeone = true

		end)
	end
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
function Skill2:Release()
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit1"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit2"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit3"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit4"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Uppercut"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Downslam"])
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill2OLD.Release)
	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 1), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
	self.Knit.GetService("AttackService"):destroyBodyGyroHold(self.Character,"FullMouse")
	--self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill2", self.Settings.Cooldown)
	--RedF151X:Play()
	for _,v in pairs(self.Character:GetChildren()) do
		if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
			v.CollisionGroup = 'Visuals2'
		end
	end
	local count = 0

	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 70, "Scarlet Empress", "M1", "CLOTHAWAKENING2", self.Character, self.Character)	
	task.delay(9/60,function()
		local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.jumpsfx:Clone()
		RedFX2425.Parent = self.Character.Torso
		game.Debris:AddItem(RedFX2425,3)
		RedFX2425:Play()
	end)
	
	local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
	FX.Parent=self.Character
	FX.w.Part0= self.Character['Left Arm']

	game.Debris:AddItem(FX,3)
	task.delay(2,function()
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
	end)  
	--end)
	--task.delay(19/60,function()
	--	local RedFX2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.abysscswing:Clone()
	--	RedFX2425.Parent = self.Character.HumanoidRootPart
	--	game.Debris:AddItem(RedFX2425,2)
	--	RedFX2425:Play()
	--end)
	--local RedF15141X=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.BloodDash:Clone()
	----RedF151X.Volume = 0
	--RedF15141X:Play()
	--RedF15141X.Parent = self.Character.HumanoidRootPart
	--game.Debris:AddItem(RedF15141X,4)
	local FX2= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
	FX2.Parent=self.Character['Left Arm']
	game.Debris:AddItem(FX2,7)
	for i ,v in pairs(FX2:GetDescendants())do
		if v:IsA('ParticleEmitter') then
			v.Enabled = true
		end
		if v:IsA('Trail') then
			v.Enabled = true
		end
	end
	self:listenForCancel(function()	
		if FX2 ~= nil then
			game.Debris:AddItem(FX2,1)
			for i ,v in pairs(FX2:GetDescendants())do
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
				if v:IsA('Trail') then
					v.Enabled = false
				end
			end
		end
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Characters'
			end
		end
		--if RedF15141X ~= nil then
		--	RedF15141X:Destroy()
		--end
		if Cant ~= nil then
			Cant:Destroy()
		end
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill2OLD.Release)
		self.Cancelled = true
		self:Destroy()
	end)
	local hrp = self.Character:FindFirstChild("HumanoidRootPart")
	local startingPos = self.Character.HumanoidRootPart.Position
	wait(46/60)
	if self.Cancelled then return end
	local AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
	local function dashforward()
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 100, self.Character:GetAttribute("Combat"), "Dash", "Start", self.Character, "Back")
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Immortal Blaze", "Skill3Drill", "Dash2fifties", self.Character, self.Character)	
	end
	dashforward()
	local IFrames = self.Knit.GetService("StateService"):CreateIFrames(self.Character)
	task.delay(.3,function()
		if IFrames ~= nil then
			IFrames:Destroy()
		end
		if FX2 ~= nil then
			game.Debris:AddItem(FX2,1)
			for i ,v in pairs(FX2:GetDescendants())do
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
				if v:IsA('Trail') then
					v.Enabled = false
				end
			end
		end
	end)
	task.delay(self.Settings2.HitboxSettings.Debris,function()
		if not self.Hit then
			self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill2", self.Settings.Cooldown)
		end
	end)
	if self.Cancelled then
		--if RedF15141X ~= nil then
		--	RedF15141X:Destroy()
		--end
		--RedF151X:Destroy()
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
		end
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill2OLD.Release)
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
			self:TagEnemy(Enemy,startingPos)
		end)
	end))
	wait((119/60) - (46/60))
	if AutoRotate ~= nil then
		AutoRotate:Destroy()
	end
	if FX2 ~= nil then
		game.Debris:AddItem(FX2,1)
		for i ,v in pairs(FX2:GetDescendants())do
			if v:IsA('ParticleEmitter') then
				v.Enabled = false
			end
			if v:IsA('Trail') then
				v.Enabled = false
			end
		end
	end
	--if RedF15141X ~= nil then
	--	RedF15141X:Destroy()
	--end
	--wait((40/60) - ((48/60) - (22/60)))

	--local bufftime = 15
	--local RedFX = ResourceFolder.Parent.MilleniumExplosion.Attachment:Clone()
	--RedFX.Parent = self.Character.Torso
	--game.Debris:AddItem(RedFX,bufftime)
	--for i,v in pairs(RedFX:GetDescendants()) do
	--	if v:IsA('ParticleEmitter') then
	--		v:Emit(v:GetAttribute('EmitCount') or 1)
	--	end
	--end
	--RedFX.shockwave:Play()
	--RedFX.shockwave2:Play()
	--RedFX.shockwave3:Play()
	--local buffvalue = Instance.new("BoolValue",self.Character)
	--buffvalue.Value = true
	--buffvalue.Name = ("MilleniumVampire")
	--game.Debris:AddItem(buffvalue,bufftime)
	--local RedFX251 = ResourceFolder.Parent.MilleniumSmoke.Attachment:Clone()
	--RedFX251.Parent = self.Character.Torso
	--game.Debris:AddItem(RedFX251,bufftime + 2)
	--for i,v in pairs(RedFX251:GetChildren()) do
	--	if v:IsA("ParticleEmitter") then
	--		task.delay(bufftime,function()
	--			v.Enabled = false
	--		end)
	--	end
	--end
	--for i,v in pairs(ResourceFolder:GetChildren()) do
	--	if v:IsA("ParticleEmitter") then
	--		local cloneado = v:Clone()
	--		cloneado.Parent = self.Character.Torso
	--		task.delay(bufftime,function()
	--			cloneado.Enabled = false
	--			game.Debris:AddItem(cloneado,2)
	--		end)
	--	end
	--end
	--task.wait(.9)
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
end

return Skill2
