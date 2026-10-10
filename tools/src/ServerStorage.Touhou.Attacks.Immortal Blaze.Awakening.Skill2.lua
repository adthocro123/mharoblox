local Skill1 = {}
Skill1.Settings = {
	Cooldown = 15,
	Damage = 7,
	AttackLength = (400/60),
	AttackLength2 = (328/60),

	HitboxSettings = {
		--DelayTime = .23,
		Debris = 1.1,

		Offset = CFrame.new(0,-1,-5),
		Size = Vector3.new(25,25,25)
	},
	magnitudeForClose = 20,
}
Skill1.Settings2 = {
	Cooldown = 15,
	Damage = 1,
	AttackLength = 1.4,

	HitboxSettings = {
		Debris = .25,

		Offset = CFrame.new(0, 0.126, -33.325),
		Size = Vector3.new(14, 14, 70)
	},
}
local GetLocalCharPosition = require(game.ServerStorage.Touhou.Bridge).GetLocalCharPosition

function Skill1:CreateHitbox()
	self.Knit.GetService("HitboxService"):createHitbox({
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
		DelayTime = 0,
		Debris = .1,
	}, function(Enemy)
		--Enemy.HumanoidRootPart.CFrame = self.Character.HumanoidRootPart.CFrame
		self:TagEnemy(Enemy, self.Character.HumanoidRootPart.Position)
	end)

end


function Skill1:TagEnemy(Enemy,pos)
	if self.Cancelled then return end
	if self.Hit then return end
	Enemy:SetAttribute("Cancel", os.clock())
	self.Hit = Enemy
local defaultsong
	local chrPos = Enemy.HumanoidRootPart.Position
	local tPos = pos
	local modTPos = (chrPos - tPos).Unit * Vector3.new(1,0,1)
	local upVector = Enemy.HumanoidRootPart.CFrame.UpVector
	local newCF = CFrame.lookAt(chrPos, chrPos + modTPos, upVector) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), math.pi)
	Enemy.HumanoidRootPart.CFrame = newCF
	local grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,0,0)*CFrame.Angles(0,math.rad(180),0))

	if self.Character.Torso:FindFirstChild("AwakeningScarySong") then
		game:GetService("TweenService"):Create(self.Character.Torso:FindFirstChild("AwakeningScarySong"),TweenInfo.new(.2,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Volume = .35}):Play()
	end
	self:AddFor(self.Settings.AttackLength, function()
		self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill2", self.Settings.Cooldown)
	end)
	--task.delay(.4,function()
	--	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill2.Release)
	--end)
	--if self.Character["Right Arm"]:FindFirstChild("remiliaspear") then
	--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, script.Parent.Name, "M1", "Hit", self.Character, Enemy, 1)
	--	self.Character["Right Arm"]:FindFirstChild("remiliaspear")["Impale"]:Play()
	--end
	--local Red12FX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Wind162:Clone()
	--game.Debris:AddItem(Red12FX,7)
	--Red12FX.Parent = Enemy.HumanoidRootPart
	--Red12FX:Play()
	

		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Immortal Blaze", "M1", "DIABLEJAMBLELOL", self.Character, self.Character)	
	self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 1)
	task.delay(5/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
		end
	end)
	task.delay(11/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
		end
	end)
	task.delay(45/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
		end
	end)
	task.delay(53/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
		end
	end)
	task.delay(100/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
		end
	end)
	task.delay(216/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
		end
	end)
	task.delay(161/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3)
		end
	end)
	task.delay(171/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3)
		end
	end)
	task.delay(179/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
		end
	end)
	task.delay(188/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3)
		end
	end)
	task.delay(192/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
		end
	end)
	task.delay(327/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3)
		end
	end)
	task.delay(47/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3)
		end
	end)
	task.delay(225/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3)
		end
	end)
	task.delay(194/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
		end
	end)
	task.delay(198/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3)
		end
	end)
	task.delay(221/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3)
		end
	end)
	task.delay(221/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3)
		end
	end)
	task.delay(282/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
		end
	end)
	task.delay(287/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3)
		end
	end)
	task.delay(287/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
		end
	end)
	task.delay(294/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3)
		end
	end)
	task.delay(310/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
		end
	end)
	task.delay(312/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
		end
	end)
	task.delay(314/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
		end
	end)
	task.delay(316/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 2)
		end
	end)
	task.delay(318/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3)
		end
	end)
	task.delay(322/60,function()
		if self.Cancelled ~= true then
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 3)
		end
	end)


	self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, 'Immortal Blaze', "BlitzKick", "Cutscene", self.Character, self.Character)
	self.Knit.GetService("CombatService"):FireClient(Enemy, Enemy, 'Immortal Blaze', "BlitzKick", "Cutscene", self.Character, self.Character)

	local secondaddon = .5
	local function tweenscarysongback()
		if self.Character.Torso:FindFirstChild("AwakeningScarySong") then
			game:GetService("TweenService"):Create(self.Character.Torso:FindFirstChild("AwakeningScarySong"),TweenInfo.new(.2,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Volume = 0.52}):Play()
		end
	end
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	task.delay(self.Settings.AttackLength + secondaddon,function()
		tweenscarysongback()
		if Cant ~= nil then
			Cant:Destroy()
		end
	end)
	self.Knit.GetService("StateService"):AddStates(self.Character, {"ULTIFrames","AutoRotate"}, self.Settings.AttackLength + secondaddon)
	self.Knit.GetService("StateService"):AddStates(Enemy, {"ULTIFrames","AutoRotate"}, self.Settings.AttackLength2)
	local StunVal = self.Knit.GetService("StateService"):CreateStun(Enemy)
	game.Debris:AddItem(StunVal,self.Settings.AttackLength2)
	--self.Knit.GetService("MovementService"):AddMovements(self.Character, {WalkSpeed = 0, JumpPower = 0}, self.Settings.AttackLength2)
	--self.Knit.GetService("MovementService"):AddMovements(Enemy, {WalkSpeed = 0, JumpPower = 0}, self.Settings.AttackLength2)
	local Speed1, Jump2 = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 0), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	game.Debris:AddItem(Speed1, self.Settings.AttackLength + secondaddon)
	game.Debris:AddItem(Jump2, self.Settings.AttackLength + secondaddon)

	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(Enemy, 0), self.Knit.GetService("MovementService"):CreateJump(Enemy, 0)
	game.Debris:AddItem(Speed, self.Settings.AttackLength2)
	game.Debris:AddItem(Jump, self.Settings.AttackLength2)
	self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill2.Victim)
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill2.Success)

	task.delay(self.Settings.AttackLength2,function()
		if self.Cancelled then return end
		grab:Destroy()
		if Jump ~= nil then
			Jump:Destroy()
		end
		--if Speed ~= nil then
		--	Speed:Destroy()
		--end
		if Speed ~= nil then
			Speed:Destroy()
		end
		self:TagEnemyThrow(Enemy)
		if StunVal ~= nil then
			StunVal:Destroy()
		end
		self.Knit.GetService("StateService"):RemoveStates(self.Character, {"ULTIFrames"})
end)	

	self:listenForCancel(function()
		if StunVal ~= nil then
			StunVal:Destroy()
		end
		if Cant ~= nil then
			Cant:Destroy()
		end
		tweenscarysongback()
		self.Cancelled = true
		grab:Destroy()
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
		self.Knit.GetService("StateService"):RemoveStates(self.Character, {"ULTIFrames"})
	end)
end
function Skill1:TagEnemyThrow(Enemy)
	if self.Cancelled then return end
	--Enemy.HumanoidRootPart.CFrame = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-1.5)
	self.Knit.GetService("DamageService"):Damage({

	
			Character = self.Character,
			Enemy = Enemy,

			KnockbackData = {
				KnockbackType = "Velocity",
				MaxForce = Vector3.new(20000,20000,20000),
				Velocity = Vector3.new(0,85,0),
				Time = .3,
			},

			StateData = {
				Stunned = 4,
				AutoRotate = 4,
			},

			MovementData = {
				WalkSpeed = 0,
				JumpPower = 0,
				Time = 4,
			},

			RagdollData = {
				Time = 4,
			},

			BlockData = {
				HitterOrigin = self.Character.HumanoidRootPart.CFrame,
			},

			Damage = self.Settings.Damage,
			ReactionAnim =(game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),
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



local Rayc = function(Hrp)
	local ray = workspace:Raycast(Hrp.Position,Hrp.CFrame.LookVector*4,Blacklist)

	if ray then
		return true
	end
	return false
end
function Skill1:Release()
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit1"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit2"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit3"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit4"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Uppercut"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Downslam"])
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill2.Release)
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
	self.Knit.GetService("AttackService"):destroyBodyGyroHold(self.Character,"FullMouse")
	--self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill1", self.Settings.Cooldown)
	--local RedF151X=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.BloodDash:Clone()
	--game.Debris:AddItem(RedF151X,4)
	--RedF151X.Parent = self.Character.HumanoidRootPart
	--RedF151X:Play()
		local sound151 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat["dropkicksfx"]:Clone()	
		sound151.Parent = self.Character.Torso
		sound151:Play()
		game.Debris:AddItem(sound151,6)
	local count = 0
	--local function flare()
	--	if self.Cancelled ~= true then
	--		if self.Character["Right Arm"]:FindFirstChild("remiliaspear") then
	--			if count == 0 then
	--				if self.Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir1"].IsPlaying then
	--					self.Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir2"]:Play()
	--				else
	--					self.Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir1"]:Play()
	--				end
	--			end
	--			count += 1
	--			self.Character["Right Arm"]:FindFirstChild("remiliaspear")["gunganir3"]:Play()
	--			self.Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):Emit(self.Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare12emit"):GetAttribute('EmitCount'))
	--			self.Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):Emit(self.Character["Right Arm"]:FindFirstChild("remiliaspear"):FindFirstChild("Flare13emit"):GetAttribute('EmitCount'))
	--		end
	--	end
	--end
	--local function slash()
	--	if self.Cancelled ~= true then
	--		if self.Character["Right Arm"]:FindFirstChild("remiliaspear") then
	--			self.Character["Right Arm"]:FindFirstChild("remiliaspear")["swing1"]:Play()
	--			self.Character["Right Arm"]:FindFirstChild("remiliaspear")["swing12"]:Play()
	--			self.Character["Right Arm"]:FindFirstChild("remiliaspear")["swing2"]:Play()

	--			local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Skill1Slash.Attach221ment:Clone()
	--			RedFX15.Parent = self.Character.HumanoidRootPart
	--			game.Debris:AddItem(RedFX15,1.5)
	--			for i,v in pairs(RedFX15:GetDescendants()) do
	--				if v:IsA('ParticleEmitter') then
	--					v:Emit(v:GetAttribute('EmitCount') or 1)
	--				end
	--			end

	--			local RedFX156 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Skill1Slash["emit 011"]:Clone()
	--			RedFX156.Parent = self.Character.HumanoidRootPart
	--			game.Debris:AddItem(RedFX156,1.5)
	--			for i,v in pairs(RedFX156:GetDescendants()) do
	--				if v:IsA('ParticleEmitter') then
	--					v:Emit(v:GetAttribute('EmitCount') or 1)
	--				end
	--			end

	--		end
	--	end
	--end
	--local RedFX2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.ClothAwakening2:Clone()
	--RedFX2425.Parent = self.Character.HumanoidRootPart
	--game.Debris:AddItem(RedFX2425,RedFX2425.TimeLength + .1)
	--RedFX2425:Play()
	--self.Character["Right Arm"]:FindFirstChild("remiliaspear")["spearswing2"]:Play()


	--task.delay(11/60,function()
	--	flare()
	--end)
	--task.delay(38/60,function()
	--	flare()
	--end)
	--task.delay(60/60,function()
	--	slash()
	--end)
		local IFrames = self.Knit.GetService("StateService"):CreateULTIFrames(self.Character)
		local AutoRotate = nil
	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 0), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	local FX= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
	FX.Parent=self.Character
	FX.w.Part0= self.Character['Right Leg']
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Visuals2'
			end
		end
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

	local FX2= game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.DashTrail:Clone()
	FX2.Parent=self.Character
	FX2.w.Part0= self.Character['Left Leg']

	game.Debris:AddItem(FX2,3)
	task.delay(2,function()
		for i ,v in pairs(FX2:GetDescendants())do
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

	self:listenForCancel(function()	


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
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill2.Release)
		self.Cancelled = true
		self:Destroy()
	end)
	task.delay(80/60,function()
		local Red12FX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Wind16:Clone()
		game.Debris:AddItem(Red12FX,4)
		Red12FX.Parent = self.Character.HumanoidRootPart
		Red12FX:Play()
	end)
	local hrp = self.Character:FindFirstChild("HumanoidRootPart")
	local startingPos = self.Character.HumanoidRootPart.Position
	task.delay(31/60,function()
		task.delay(self.Settings2.HitboxSettings.Debris,function()
			if not self.Hit then
				self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill2", self.Settings.Cooldown)
			end
		end)
	end)
		local function dashforward()
			self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Immortal Blaze", "Skill3Drill", "DashUlt", self.Character, self.Character)	
		end
		task.delay(60/60,function()
			dashforward()
		end)
	wait(98/60)
	if self.Cancelled then return end
	--local RedFX15 = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].WindFX.Attachment:Clone()
	--RedFX15.Parent = self.Character.HumanoidRootPart
	--game.Debris:AddItem(RedFX15,6)
	--for i,v in pairs(RedFX15:GetDescendants()) do
	--	if v:IsA('ParticleEmitter') then
	--		v:Emit(v:GetAttribute('EmitCount') or 1)
	--	end
	--end
	if self.Cancelled then
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end
			if IFrames ~= nil then
				IFrames:Destroy()
			end
		--self.Character["Right Arm"]:FindFirstChild("remiliaspear")["spearswing2"]:Stop()
		--RedF151X:Destroy()
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill2.Release)
		if Cant ~= nil then
			Cant:Destroy()
		end
		self.Cancelled = true
		self:Destroy()
		return
	end

	coroutine.resume(coroutine.create(function()

		self.Character:SetAttribute("Dropkicking",true)

			AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 110, "Immortal Blaze", "M1", "dropkkick", self.Character, self.Character)	

		--local RedFX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].DropKickHitbox:Clone()
		--RedFX.CFrame = rootpart51.CFrame * game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].DropKickHitbox.CFrame
		--game.Debris:AddItem(RedFX,10)
		--RedFX.Parent = workspace.Ignore.Effects
		--for i,v in pairs(RedFX:GetDescendants()) do
		--	if v:IsA('ParticleEmitter') then
		--		v:Emit(v:GetAttribute("EmitCount"))
		--	end
		--end
			--self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Immortal Blaze", "M1", "BITBYADOGWITHARABIDTOOTH", self.Character, self.Character)	

		self:CreateHitbox()
	end))
	wait((171/60) - (98/60))
	self.Character:SetAttribute("Dropkicking",nil)
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Characters'
			end
		end
		if IFrames ~= nil then
			IFrames:Destroy()
		end
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
		end
	--wait((40/60) - ((48/60) - (22/60))) 
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

return Skill1
