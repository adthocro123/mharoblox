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
		Debris = (90-30)/60,

		Offset = CFrame.new(0,0,-5),
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
	if (Enemy.Values:FindFirstChild("RagdollSuperArmor")) or (Enemy:FindFirstChild("MilleniumVampire")) then return end
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
	task.delay(.25,function()
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill1.STARTNEW)
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill1.MISSNEW)
	end)
	for _,v in pairs(self.Character:GetChildren()) do
		if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
			v.CollisionGroup = 'Characters'
		end
	end

	self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .5)
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
				self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy5, 4)
				self:TagEnemyThrow(Enemy5)
			end)
			--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 35, "Scarlet Empress", "M1", "DOWNCUT", self.Character, self.Character)	
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 35, script.Parent.Name, "M1", "HitNOVFX", self.Character, Enemy, math.random(2,4))
			self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .8)
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 70, "Scarlet Empress", "M1", "RUBBLESLAM", Enemy, Enemy)	
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 45, "Scarlet Empress", "M1", "GROUNDSLAMFIRSTSKILL", self.Character, self.Character)	
		end
	end
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 120, "Scarlet Empress", "M1", "KISSFIRSTSKILL", self.Character, Enemy)	
	--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 40, "Scarlet Empress", "M1", "BLOODSMASHVFX", self.Character, self.Character)	
	local damageheal = .6
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
		if IFramesEnemy ~= nil then
			IFramesEnemy:Destroy()
		end
		if Cant2 ~= nil then
			Cant2:Destroy()
		end
		if StunVal ~= nil then
			StunVal:Destroy()
		end
		if AutoRotateEnemy ~= nil then
			AutoRotateEnemy:Destroy()
		end
		self.Knit.GetService("AnimationService"):stopAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill1.VICTIMNEW)
	end)
	task.delay(self.Settings.AttackLength2,function()
		groundslam()
	end)
	self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill1.VICTIMNEW,1,nil,0)
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill1.SUCCESSNEW,1,nil,0)
	task.delay(self.Settings.AttackLength,function()
		if finish == true then return end
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

		Damage = .3,
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

		Damage = .3,
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

local function RayCastOnMap(origin,direction,returnAll)
	local raycastSettings = RaycastParams.new()
	raycastSettings.FilterType = Enum.RaycastFilterType.Blacklist
	raycastSettings.FilterDescendantsInstances = {workspace.Ignore}
	local ray = workspace:Raycast(origin, direction, raycastSettings)
	if ray and ray.Instance then
		if ray.Instance.CanCollide == false then
			ray = nil
		end
	end
	if returnAll then return ray end
	if ray then
		return ray.Position
	else
		return origin
	end
end
function Skill1:TagEnemy2(Enemy)
	--coroutine.resume(coroutine.create(function()
		if not self.Character:FindFirstChild("NIGHTLESSCASTLELUNGE") then return end
		if self.Cancelled then return end
		if not Enemy:FindFirstChild("hitwithncr") then
			self.Hit = true
			local buffvalue = Instance.new("BoolValue",Enemy)
			buffvalue.Value = true
			buffvalue.Name = ("hitwithncr")
			local StunVal = self.Knit.GetService("StateService"):CreateStun(Enemy)
			StunVal:SetAttribute("RemiliaSpearNCRStunUnability",true)
			local grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,0,-3)*CFrame.Angles(0,math.rad(180),0))
			self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill1.VICTIMNEW,1,nil,0)
			local pos = self.Knit.GetService("AnimationService"):getTimePos(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill1.STARTNEW)
			local oldpos = pos
			pos = (oldpos - (30/60))
			self.Knit.GetService("AnimationService"):setTimePos(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill1.VICTIMNEW,pos)
			local conn1
			conn1 = self.Character.ChildAdded:Connect(function(Child)
				if Child.Name == ("SMASHHITNCR") then
					conn1:Disconnect()
					--if buffvalue ~= nil then
					--	buffvalue:Destroy()
					--end
				if grab ~= nil then
					grab:Destroy()
				end
				for _,v in pairs(Enemy:GetChildren()) do
					if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
						v.CollisionGroup = 'Visuals2'
					end
				end
				local cframecolectadonagaras2 = self.Character.HumanoidRootPart.CFrame
				local cframecolectadonagaras = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,-.4,-40.287)
			task.delay(55/60,function()
					if not self.chosencfrm then
						local TPD = -45
						local raycastParams  = RaycastParams.new()
						raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
						raycastParams.FilterDescendantsInstances = {workspace.Ignore}
						local raycastResult = workspace:Raycast(cframecolectadonagaras2.p, cframecolectadonagaras2.LookVector*(-TPD), raycastParams)


						if raycastResult then

							local magnitude  = (cframecolectadonagaras2.p - raycastResult.Position).Magnitude

							TPD =  -magnitude
						end
						local chosencfrm2 = cframecolectadonagaras2 * CFrame.new(0,0,TPD)
						local chosencfrm = (cframecolectadonagaras2 * CFrame.new(0,0,TPD)).Position
						local floorInstance = RayCastOnMap((chosencfrm2*CFrame.new(0,0,-1)).p,Vector3.new(0,-80,0),true)
						if floorInstance then
							chosencfrm = floorInstance.Position + Vector3.new(0,1,0)
						end
						self.chosencfrm = chosencfrm
					end
					task.delay(.5,function()
						self.Knit.GetService("BodymoverService"):DestroyBodymovers(Enemy)
						if buffvalue ~= nil then
							buffvalue:Destroy()
						end
						if StunVal ~= nil then
							StunVal:Destroy()
						end
						local rotation = Enemy.HumanoidRootPart.CFrame.Rotation
						Enemy.HumanoidRootPart.CFrame = CFrame.new(self.chosencfrm) * rotation
					end)
					self.Knit.GetService("DamageService"):Damage({

						Character = self.Character,
						Enemy = Enemy,

						KnockbackData = {
							KnockbackType = "Position",
							MaxForce = Vector3.new(20000,20000,20000),
								Position = (self.chosencfrm), 
							Time = 5,
							P = 75000,
							D = 700,
						},
						--RagdollData =  {
						--	Time = ragdolltime,
						--},
						--RagdollData = isClose and {
						--	Time = 1,
						--},
						--StateData = {
						--	Stunned = 1,
						--	--AutoRotate = 1,
						--},
						--KnockbackData = isClose and {
						--	KnockbackType = "VelocityTweenDown",
						--	MaxForce = Vector3.new(50000000,0,50000000),
						--	Velocity = self.Character.HumanoidRootPart.CFrame.LookVector*(isClose and 35 or 7),
						--	Time = .2,
						--	TweenLength = .7
						--},

						StateData = {
							Stunned = 1,
							AutoRotate = 1,
						},

						MovementData = {
							WalkSpeed = 0,
							JumpPower = 0,
							Time = 1,
						},

						--BlockData = {			
						--	HitterOrigin = self.Character.HumanoidRootPart.CFrame,
						--},
						EnemyFacesCharacter = true,

						Damage = self.Settings.Damage,
						--ReactionAnim = isClose and game.ReplicatedStorage.Assets.Animations.Reactions.DashM1Reaction or isflying and game.ReplicatedStorage.Assets.Animations.ReactionsFlying["Reaction"..math.random(1,4)] or (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),
					},function(State)		
						if State == "Hit" then
							self.Hit = true
							--self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
							--self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
							--self.Knit.GetService("StateService"):RemoveStates(self.Character, {"Dashing"})
							--if isClose then
							--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Close", self.Character, Enemy)
							--else
							--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Far", self.Character, Enemy)
							--end
							--self.Character.Humanoid:MoveTo(self.Character.HumanoidRootPart.Position:Lerp(Enemy.HumanoidRootPart.Position, 0.5))
						elseif State == "Block" then
							--	task.delay(.1,function()
							--		self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
							--	end)
							--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Miss", self.Character)
							--	self.Knit.GetService("MovementService"):AddMovements(self.Character, {WalkSpeed = 0, JumpPower = 0}, .6)
						end
					end)
					for _,v in pairs(Enemy:GetChildren()) do
						if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
							v.CollisionGroup = 'Characters'
						end
					end
				end)
				--self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill1.VICTIMNEW,1,nil,0)
					--self.Knit.GetService("AnimationService"):stopAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill1.VICTIMNEW)
					--local ragdolltime = 3
					self.Knit.GetService("DamageService"):Damage({

						Character = self.Character,
						Enemy = Enemy,

						--KnockbackData = {
						--	KnockbackType = "ShortKnockback",
						--	--MaxForce = Vector3.new(100000,0,100000),
						--	VelocityOrigin = self.Character.HumanoidRootPart, 
						--	Velocity = 4, 
						--	VelocityUp = 1, 
						--	--Time = .25,
						--} ,
						KnockbackData = {
						KnockbackType = "Position",
						MaxForce = Vector3.new(20000,20000,20000),
						Position = (cframecolectadonagaras).p, 
						Time = 5,
					},
						--RagdollData =  {
						--	Time = ragdolltime,
						--},
						--RagdollData = isClose and {
						--	Time = 1,
						--},
						--StateData = {
						--	Stunned = 1,
						--	--AutoRotate = 1,
						--},
						--KnockbackData = isClose and {
						--	KnockbackType = "VelocityTweenDown",
						--	MaxForce = Vector3.new(50000000,0,50000000),
						--	Velocity = self.Character.HumanoidRootPart.CFrame.LookVector*(isClose and 35 or 7),
						--	Time = .2,
						--	TweenLength = .7
						--},

						StateData = {
							Stunned = 1,
							AutoRotate = 1,
						},

						MovementData = {
							WalkSpeed = 0,
							JumpPower = 0,
							Time = 1,
						},

						--BlockData = {			
						--	HitterOrigin = self.Character.HumanoidRootPart.CFrame,
						--},
					EnemyFacesCharacter = true,

						Damage = self.Settings.Damage,
						--ReactionAnim = isClose and game.ReplicatedStorage.Assets.Animations.Reactions.DashM1Reaction or isflying and game.ReplicatedStorage.Assets.Animations.ReactionsFlying["Reaction"..math.random(1,4)] or (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),
					},function(State)		
						if State == "Hit" then
							self.Hit = true
							--self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
							--self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
							--self.Knit.GetService("StateService"):RemoveStates(self.Character, {"Dashing"})
							--if isClose then
							--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Close", self.Character, Enemy)
							--else
							--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Far", self.Character, Enemy)
							--end
							--self.Character.Humanoid:MoveTo(self.Character.HumanoidRootPart.Position:Lerp(Enemy.HumanoidRootPart.Position, 0.5))
						elseif State == "Block" then
							--	task.delay(.1,function()
							--		self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
							--	end)
							--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, self.Character:GetAttribute("Combat"), "Dash", "DashM1Miss", self.Character)
							--	self.Knit.GetService("MovementService"):AddMovements(self.Character, {WalkSpeed = 0, JumpPower = 0}, .6)
						end
					end)

					--if grab ~= nil then
					--	grab:Destroy()
					--end
					--if Enemy:FindFirstChild("Values") then
					--	for i,v in pairs(Enemy:FindFirstChild("Values"):GetDescendants()) do
					--		if v.Name == ("RemiliaSpearNCRStunUnability") or v:GetAttribute("RemiliaSpearNCRStunUnability") then
					--			v:Destroy()
					--		end
					--	end
					--end
				end
			end)
		end
	--end))
end
function Skill1:TagEnemyBigOne(Enemy)
	if self.Cancelled then return end
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,

		--KnockbackData = {
		--	KnockbackType = "Velocity",
		--	MaxForce = Vector3.new(20000,20000,20000),
		--	Velocity = Vector3.new(0,0,0),
		--	Time = .05,
		--},

		StateData = {
			Stunned = 3,
			AutoRotate = 3,
		},

		MovementData = {
			WalkSpeed = 0,
			JumpPower = 0,
			Time = 3,
		},

		--RagdollData = {
		--	Time = 3,
		--},
		ReactionAnim = (game.ReplicatedStorage.Assets.Animations.ReactionsFlyingREAL["Reaction"..math.random(1,4)]),

		Damage = 1,
	},function(State)
		self.HitSomeone = true

		if State == "Hit" then
			--Enemy.HumanoidRootPart.Velocity = Vector3.new(0,0,0)
			self.Knit.GetService("AnimationService"):stopAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill1.VICTIMNEW)
		end
	end)
end
function Skill1:TagEnemyBigOne2(Enemy)
	if self.Cancelled then return end
	self.Knit.GetService("BodymoverService"):DestroyBodymovers(Enemy)

	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,

		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(20000,20000,20000),
			Velocity = Vector3.new(math.random(-74,74),math.random(75,85),math.random(-74,74)),
			Time = .2,
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
		ReactionAnim = (game.ReplicatedStorage.Assets.Animations.ReactionsFlyingREAL["Reaction"..math.random(1,4)]),

		Damage = 10,
	},function(State)
		self.HitSomeone = true

		if State == "Hit" then
			self.Knit.GetService("AnimationService"):stopAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill1.VICTIMNEW)
		end
	end)
end
function Skill1:CreateHitboxBigOne(ProjectilePart)
	self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = ProjectilePart,
		Offset = CFrame.new(0,43,0),
		Size = Vector3.new(50,100,50),
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = false,
		IgnoresBlock = false,
		DelayTime = 0,
		Debris = .1,
	}, function(Enemy)
		self:TagEnemyBigOne(Enemy, ProjectilePart.Position)
	end)
end
function Skill1:CreateHitboxBigOne2(ProjectilePart)
	self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = ProjectilePart,
		Offset = CFrame.new(0,43,0),
		Size = Vector3.new(80,100,80),
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = false,
		IgnoresBlock = false,
		DelayTime = 0,
		Debris = .1,
	}, function(Enemy)
		self:TagEnemyBigOne2(Enemy, ProjectilePart.Position)
	end)
end
function Skill1:Release()
	--april fools
	if self.Character.Values:FindFirstChild("Cant") then return end
	if self.Character.Values:FindFirstChild("CantHeartBreak") and not self.Character:FindFirstChild("HEARTBREAKCLOSEVARIANTHOLD") then return end
	if self.Character.Values:FindFirstChild("CantHeartBreak") and self.Character:FindFirstChild("HEARTBREAKCLOSEVARIANTHOLD") then 
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "Skill3Drill", "Dash2fiftiesz", self.Character, self.Character)	
	end
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
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill1.STARTNEW)
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

	--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 145, "Scarlet Empress", "M1", "KISSTARTVFX", self.Character)	
	local buffvalue = Instance.new("BoolValue",self.Character)
	buffvalue.Value = true
	buffvalue.Name = ("NIGHTLESSCASTLELUNGE")
	--local AutoRotate = nil
	local ended = false
	self:listenForCancel(function()	
		if buffvalue ~= nil then
			buffvalue:Destroy()
		end
		--if AutoRotate ~= nil then
		--	AutoRotate:Destroy()
		--end	
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Characters'
			end
		end
		ended = true
		if self.Character:FindFirstChild("NIGHTLESSCASTLELUNGE") then
			self.Character:FindFirstChild("NIGHTLESSCASTLELUNGE"):Destroy()
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
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.ReleaseNew)
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.Release2New)
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.Release)
		self.Cancelled = true
		self:Destroy()
	end)
	local hrp = self.Character:FindFirstChild("HumanoidRootPart")
	local startingPos = self.Character.HumanoidRootPart.Position
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "Skill3Drill", "NCRVELOCITY", self.Character, self.Character)	
	local IFrames = self.Knit.GetService("StateService"):CreateULTIFrames(self.Character)
	--task.delay(30/60,function()
		--if self.Cancelled then return end
		--AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Visuals2'
			end
		end
		--dashforward()
	--end)
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 550, "Scarlet Empress", "M1", "NCRNEWSTART",self.Character)	

	task.delay(107/60,function()
		local buffv124alue = Instance.new("BoolValue")
		buffv124alue.Value = true
		buffv124alue.Name = ("SMASHHITNCR")
		buffv124alue.Parent = self.Character
		game.Debris:AddItem(buffv124alue,1.5)
		task.delay(50/60,function()
			local cframecolectadonagaras2 = self.Character.HumanoidRootPart.CFrame
			local cframecolectadonagaras = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,-.4,-40.287)
			local TPD = -45
			local raycastParams  = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
			raycastParams.FilterDescendantsInstances = {workspace.Ignore}
			local raycastResult = workspace:Raycast(cframecolectadonagaras2.p, cframecolectadonagaras2.LookVector*(-TPD), raycastParams)


			if raycastResult then

				local magnitude  = (cframecolectadonagaras2.p - raycastResult.Position).Magnitude

				TPD =  -magnitude
			end
			local chosencfrm2 = cframecolectadonagaras2 * CFrame.new(0,0,TPD)
			local chosencfrm = (cframecolectadonagaras2 * CFrame.new(0,0,TPD)).Position
			local floorInstance = RayCastOnMap((chosencfrm2*CFrame.new(0,0,-1)).p,Vector3.new(0,-80,0),true)
			if floorInstance then
				chosencfrm = floorInstance.Position + Vector3.new(0,1,0)
			end
			self.chosencfrm = chosencfrm
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 370, "Scarlet Empress", "M1", "SPEARTHROW1", chosencfrm,self.Character)	
			task.delay(.2,function()
				local rootpart51 = Instance.new("Part")
				rootpart51.Parent = workspace.Ignore.Effects
				rootpart51.Anchored = true
				rootpart51.Size = self.Character.HumanoidRootPart.Size
				rootpart51.CFrame = CFrame.new(chosencfrm)
				rootpart51.CanCollide = false
				rootpart51.Transparency = 1
				game.Debris:AddItem(rootpart51,3)
				task.delay(1.3,function()
					self:CreateHitboxBigOne2(rootpart51,chosencfrm)
				end)
				for i = 1,8 do
					if not self.Cancelled then
						self:CreateHitboxBigOne(rootpart51,chosencfrm)
					end
					task.wait(.1)
				end
			end)
		end)
	end)
	wait(30/60)
	task.delay(self.Settings2.HitboxSettings.Debris,function()
		if self.Hit then
			local AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
			game.Debris:AddItem(AutoRotate,1.5)
		end
		if self.Character:FindFirstChild("NIGHTLESSCASTLELUNGE") then
			self.Character:FindFirstChild("NIGHTLESSCASTLELUNGE"):Destroy()
		end
		if buffvalue ~= nil then
			buffvalue:Destroy()
		end
		ended = true
	end)
	--coroutine.resume(coroutine.create(function()
		self:CreateHitbox(function(Enemy)
			--if buffvalue ~= nil then
			--	buffvalue:Destroy()
			--end
			self:TagEnemy2(Enemy)
			--if self.Hit then
			--	for _,v in pairs(self.Character:GetChildren()) do
			--		if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
			--			v.CollisionGroup = 'Characters'
			--		end
			--	end
			--end
		end)
	--end))
	task.delay((304-30)/60,function()
		self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill1", self.Settings.Cooldown)
		if IFrames ~= nil then
			IFrames:Destroy()
		end
		ended = true
		if Cant ~= nil then
			Cant:Destroy()
		end
		if self.Character:FindFirstChild("NIGHTLESSCASTLELUNGE") then
			self.Character:FindFirstChild("NIGHTLESSCASTLELUNGE"):Destroy()
		end
		if buffvalue ~= nil then
			buffvalue:Destroy()
		end
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end
		self:Destroy()
	end)
	--local function endlunge()
	--end
	--task.delay(self.Settings2.HitboxSettings.Debris,function()
	--	endlunge()
	--end)
end

return Skill1
