local Skill3 = {}
Skill3.Settings = {
	Cooldown = 15,
	Damage = 45,
	AttackLength = (200/60),
	AttackLength2 = (121/60),

	HitboxSettings = {
		--DelayTime = .23,
		Debris = .15,

		Offset = CFrame.new(0,-1,-2),
		Size = Vector3.new(10,8,14)
	},
	magnitudeForClose = 20,
}
Skill3.Settings2 = {
	Cooldown = 15,
	Damage = 7,
	AttackLength = 1.4,

	HitboxSettings = {
		Debris = .15,

		Offset = CFrame.new(0,-1,-7),
		Size = Vector3.new(15,30,35)
	},
}

local GetLocalCharPosition = require(game.ServerStorage.Touhou.Bridge).GetLocalCharPosition
local function RayCastOnMap(origin,direction,returnAll)
	local raycastSettings = RaycastParams.new()
	raycastSettings.FilterDescendantsInstances = {workspace.Ignore}
	raycastSettings.FilterType = Enum.RaycastFilterType.Blacklist
	local ray = workspace:Raycast(origin, direction, raycastSettings)

	if returnAll then return ray end
	if ray then
		return ray.Position
	else
		return origin
	end
end
function Skill3:CreateHitbox(callback)
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
		DelayTime = self.Settings2.HitboxSettings.DelayTime,
		Debris = self.Settings2.HitboxSettings.Debris,
	}, callback))
end
local ApplyHandlr = require(game.ServerStorage.Touhou.SimJump)
function Skill3:TagEnemy45(Enemy)
	if self.Cancelled then return end
	if self.Knit.GetService("CounterService"):counter(self.Character, Enemy) then
		self.Cancelled = true
		self:Destroy()
		return
	end
	if Enemy:GetAttribute("Ragdoll") then
		self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	end
	local stuntime = 1
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,

		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(20000,0,20000),
			Velocity = ((Enemy.HumanoidRootPart.CFrame.Position - self.Character.HumanoidRootPart.CFrame.Position).Unit *(4)), 
			Time = .25,
		},

		StateData = {
			Stunned = stuntime,
			AutoRotate = stuntime
		},

		MovementData = {
			WalkSpeed = 0,
			JumpPower = 0,
			Time = stuntime,
		},
		--BlockData = {			
		--	HitterOrigin = self.Character.HumanoidRootPart.CFrame,
		--},
		ReactionAnim = (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),

		EnemyFacesCharacter = true,

		Damage = self.Settings.Damage,
	},function(State)
		if State == "Hit" then
			self.HitSomeone = true
			local RedF2X2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.althit:Clone()
			RedF2X2425.Parent = Enemy.Torso
			game.Debris:AddItem(RedF2X2425,2)
			RedF2X2425:Play()
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 45, script.Parent.Name, "M1", "HitNOSFX", self.Character, Enemy, math.random(1,4))
		end
	end)
end
function Skill3:TagEnemy(Enemy)
	if self.Character.Values:FindFirstChild("Stunned") then return end
	if self.Cancelled then return end
	if self.Hit then return end

	Enemy:SetAttribute("Cancel", os.clock())

	if self.Character:GetAttribute("Ragdoll") then
		self.Knit.GetService("RagdollService"):unragdoll(self.Character, true,true)
	end
	if Enemy:GetAttribute("Ragdoll") then
		self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	end
	self.Hit = Enemy
	local grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,0,-3)*CFrame.Angles(0,math.rad(180),0))
	local chrPos = Enemy.HumanoidRootPart.Position
	local tPos = self.Character.HumanoidRootPart.Position
	local modTPos = (chrPos - tPos).Unit * Vector3.new(1,0,1)
	local upVector = Enemy.HumanoidRootPart.CFrame.UpVector
	local newCF = CFrame.lookAt(chrPos, chrPos + modTPos, upVector) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), math.pi)
	Enemy.HumanoidRootPart.CFrame = newCF
	task.delay(.2,function()
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill3.Release)
	end)
	local secondaddon = .5
	local AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
	game.Debris:AddItem(AutoRotate,156/60)
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	local StunVal = self.Knit.GetService("StateService"):CreateStun(Enemy)
	local Speed1, Jump2 = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, .1), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(Enemy, 0), self.Knit.GetService("MovementService"):CreateJump(Enemy, 0)
	local IFrames = self.Knit.GetService("StateService"):CreateULTIFrames(self.Character)
	self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill3.Victim,1,nil,0)
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill3.Success,1,nil,0)
	task.delay(35/60,function()
		if grab ~= nil then
			grab:Destroy()
		end
		self.Knit.GetService("DamageService"):Damage({

			Character = self.Character,
			Enemy = Enemy,

			KnockbackData = {
				KnockbackType = "Velocity",
				MaxForce = Vector3.new(15000,0,15000),
				Velocity = self.Character.HumanoidRootPart.CFrame.LookVector*90, 
				Time = .1,
			},

			StateData = {
				Stunned = 1,
			},

			MovementData = {
				WalkSpeed = 0,
				JumpPower = 0,
				Time = 1,
			},

			EnemyFacesCharacter = true,

			Damage = 10,
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
	end)
	for _,v in pairs(self.Character:GetChildren()) do
		if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
			v.CollisionGroup = 'Visuals2'
		end
	end
	task.delay(64/60,function()
		--if grab ~= nil then
		--	grab:Destroy()
		--end
		local rotation = self.Character.HumanoidRootPart.CFrame.Rotation
		self.Character.HumanoidRootPart.CFrame = CFrame.new(Enemy.HumanoidRootPart.Position) * rotation
		local cframecolectadonagaras = Enemy.HumanoidRootPart.CFrame * CFrame.new(0,140,0)
		local floorInstance = RayCastOnMap((cframecolectadonagaras).p,Vector3.new(0,140,0),true)
		if floorInstance then
			cframecolectadonagaras = floorInstance.Position - Vector3.new(0,1,0)
		end
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
				MaxForce = Vector3.new(14000,14000,14000),
				Position = (cframecolectadonagaras).p, 
				Time = ((123-28)/60),
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
	end)
	task.delay(((156)/60),function()
		self.Knit.GetService("BodymoverService"):DestroyBodymovers(Enemy)
		local rotation = self.Character.HumanoidRootPart.CFrame.Rotation
		--self.Character.HumanoidRootPart.CFrame = Enemy.HumanoidRootPart.CFrame
		self.Character.HumanoidRootPart.CFrame = CFrame.new(Enemy.HumanoidRootPart.Position + Vector3.new(0,10,0)) * rotation
		--task.delay(.1,function()
			grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,0,-2)*CFrame.Angles(0,math.rad(180),0))
		--end)
	end)
	local buffvalue = Instance.new("BoolValue",self.Character)
	buffvalue.Value = true
	buffvalue.Name = ("wawoonga")
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 150, "Immortal Blaze", "M1", "hiteff3", self.Character, Enemy)	
	self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Immortal Blaze", "M1", "hiteff3pers", self.Character, Enemy)	
	self.Character.HumanoidRootPart.CFrame = Enemy.HumanoidRootPart.CFrame* (CFrame.new(0,0,-1)*CFrame.Angles(0,math.rad(180),0))-- * (CFrame.new(0,0,-5)*CFrame.Angles(0,math.rad(180),0))
	task.delay(180/60,function()
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Stuff", "downslamupthing", "DISRUPTIVE", self.Character)	
		self.Knit.GetService("CombatService"):FireClient(Enemy, Enemy, "Stuff", "downslamupthing", "DISRUPTIVE", self.Character)	
	end)
	task.delay(181/60,function()
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Stuff", "downslamupthing", "DISRUPTIVE", self.Character)	
		self.Knit.GetService("CombatService"):FireClient(Enemy, Enemy, "Stuff", "downslamupthing", "DISRUPTIVE", self.Character)	
	end)
	task.delay(182/60,function()
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Stuff", "downslamupthing", "DISRUPTIVE", self.Character)	
		self.Knit.GetService("CombatService"):FireClient(Enemy, Enemy, "Stuff", "downslamupthing", "DISRUPTIVE", self.Character)	
	end)
	task.delay(183/60,function()
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Stuff", "downslamupthing", "DISRUPTIVE", self.Character)	
		self.Knit.GetService("CombatService"):FireClient(Enemy, Enemy, "Stuff", "downslamupthing", "DISRUPTIVE", self.Character)	
	end)
	task.delay(184/60,function()
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Stuff", "downslamupthing", "DISRUPTIVE", self.Character)	
		self.Knit.GetService("CombatService"):FireClient(Enemy, Enemy, "Stuff", "downslamupthing", "DISRUPTIVE", self.Character)	
	end)
	--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 20, script.Parent.Name, "M1", "HitNOSFX", self.Character, Enemy, math.random(1,4))
	--local startpoint = 13
	--wait(13/60)
	--self.Knit.GetService("DamageService"):Damage({

	--	Character = self.Character,
	--	Enemy = Enemy,

	--	KnockbackData = {
	--		KnockbackType = "Velocity",
	--		MaxForce = Vector3.new(20000,0,20000),
	--		Velocity = ((Enemy.HumanoidRootPart.CFrame.Position - self.Character.HumanoidRootPart.CFrame.Position).Unit *(40)), 
	--		Time = .25,
	--	},

	--	StateData = {
	--		Stunned = 1,
	--	},

	--	MovementData = {
	--		WalkSpeed = 0,
	--		JumpPower = 0,
	--		Time = 1,
	--	},

	--	CharacterFacesEnemy = true,
	--	EnemyFacesCharacter = true,

	--	Damage = 1,
	--},function(State)
	--	if State == "Hit" then
	--		self.HitSomeone = true
	--		--local RedF2X2425=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.althit:Clone()
	--		--RedF2X2425.Parent = Enemy.Torso
	--		--game.Debris:AddItem(RedF2X2425,2)
	--		--RedF2X2425:Play()
	--		--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 45, script.Parent.Name, "M1", "HitNOSFX", self.Character, Enemy, math.random(1,4))
	--	end
	--end)
	--task.delay((43.999-startpoint)/60,function()
	--	for _,v in pairs(self.Character:GetChildren()) do
	--		if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
	--			v.CollisionGroup = 'Visuals'
	--		end
	--	end
	--end)
	--task.delay((55-startpoint)/60,function()
	--	for _,v in pairs(self.Character:GetChildren()) do
	--		if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
	--			v.CollisionGroup = 'Characters'
	--		end
	--	end
	--end)
	--task.delay((44-startpoint)/60,function()
	--	self.Character.HumanoidRootPart.Anchored = true
	--	local tweena = game:GetService("TweenService"):Create(self.Character.HumanoidRootPart,TweenInfo.new(10/60,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{CFrame = Enemy.HumanoidRootPart.CFrame * (CFrame.new(0,0,-3)*CFrame.Angles(0,math.rad(180),0))})
	--	tweena:Play()
	--	task.delay(9/60,function()
	--		tweena:Pause()
	--		self.Character.HumanoidRootPart.Anchored = false
	--		grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,0,-2)*CFrame.Angles(0,math.rad(180),0))
	--		--if AutoRotate ~= nil then
	--		--	AutoRotate:Destroy()
	--		--end
	--		tweena:Destroy()
	--	end)
	--end)
	--task.delay(90 - startpoint/60,function()

	--end)
	coroutine.resume(coroutine.create(function()
		wait((156)/60)
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
		end
		--self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Immortal Blaze", "M1", "VELOCITYULT31FC", self.Character, self.Character)	
		self.Knit.GetService("BodymoverService"):DestroyLinears(self.Character)
		self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit1"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit2"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit3"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit4"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Uppercut"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Downslam"])
		self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
		--self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Skill1.Victim)
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Stuff", "downslamupthing", "downslamvelocity", self.Character, self.Character)	
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Stuff", "downslamupthing", "ENABLEAIRLIMBS", self.Character, self.Character)	
		if self.Cancelled ~= true then
			local RedFX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Wind15:Clone()
			game.Debris:AddItem(RedFX,4)
			RedFX.Parent = self.Character.Torso
			RedFX:Play()
		end
		local RedFX=game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Wind152:Clone()
		game.Debris:AddItem(RedFX,4)
		RedFX.Parent = self.Character.Torso
		RedFX:Play()
		local Pos = self.Character.HumanoidRootPart.Position
		local stophitting = false
		local NewJump = ApplyHandlr.functioned(self.Character.HumanoidRootPart,Vector3.new(0,1.8,0),self.Character.HumanoidRootPart.CFrame.LookVector,8,15,1.4,nil,{workspace.Ignore},false,.1)
		--local NewJump = ApplyHandlr.functioned(self.Character.HumanoidRootPart,Vector3.new(0,1,0),self.Character.HumanoidRootPart.CFrame.LookVector,8,15,1,nil,{workspace.Ignore},true,1)
		local start = os.clock()
		repeat
			wait()
		until NewJump.Complet and (os.clock() - start >= .5)				 
		if buffvalue ~= nil then
			buffvalue:Destroy()
		end
	self.Knit.GetService("AnimationService"):adjustSpeed(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill3.Victim,1)
		self.Knit.GetService("AnimationService"):adjustSpeed(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill3.Success,1)
		self.Knit.GetService("AnimationService"):setTimePos(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill3.Success,(380/60))
		self.Knit.GetService("AnimationService"):setTimePos(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill3.Victim,(380/60))
		--wait(3/60)
		self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill3", self.Settings2.Cooldown)
		grab:Destroy()
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Characters'
			end
		end
		self:TagEnemyThrow(Enemy)
		--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 200, "Immortal Blaze", "M1", "explodeeff3", self.Character, self.Character)	
		--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 35, "Immortal Blaze", "M1", "LASTM1HIGHLIGHT", self.Character, self.Character)	
		task.delay((65)/60,function()
			self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill3", self.Settings.Cooldown)
			if Jump2 ~= nil then
				Jump2:Destroy()
			end
			if Speed1 ~= nil then
				Speed1:Destroy()
			end
			if IFrames ~= nil then
				IFrames:Destroy()
			end
			if Cant ~= nil then
				Cant:Destroy()
			end
		end)
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Stuff", "downslamupthing", "DISABLEAIRLIMBS", self.Character, self.Character)	
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end
		if StunVal ~= nil then
			StunVal:Destroy()
		end
	end))	
end
function Skill3:TagEnemyThrow(Enemy)
	if self.Cancelled then return end

	self.Knit.GetService("DamageService"):Damage({


		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(10000,10000,10000),
			Velocity = Vector3.new(0,43,0),
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

		Damage = 3,
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
function Skill3:Release()
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit1"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit2"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit3"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit4"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Uppercut"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Downslam"])
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill3.Release)
		--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 85, "Immortal Blaze", "M1", "attachmnt1", self.Character, self.Character)	
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
	self.Knit.GetService("AttackService"):destroyBodyGyroHold(self.Character,"FullMouse")
	local count = 0
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 100, self.Character:GetAttribute("Character"), "M1", "startupvfx3", self.Character)
		local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 1), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0) 
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Visuals2'
			end
		end
		self:listenForCancel(function()	
			for _,v in pairs(self.Character:GetChildren()) do
				if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
					v.CollisionGroup = 'Characters'
				end
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
			self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Awakening.Skill3.Release)
			self.Cancelled = true
			self:Destroy()
		end)
		local hrp = self.Character:FindFirstChild("HumanoidRootPart")
		local startingPos = self.Character.HumanoidRootPart.Position
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Immortal Blaze", "Skill3Drill", "LOLDASH", self.Character, self.Character)	
		task.delay(123/60,function()
			coroutine.resume(coroutine.create(function()
				self:CreateHitbox(function(Enemy)
					self:TagEnemy(Enemy,startingPos)
				end)
			end))
			task.delay(self.Settings2.HitboxSettings.Debris,function()
				if not self.Hit then
					self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill3", self.Settings.Cooldown)
				else
					for _,v in pairs(self.Character:GetChildren()) do
						if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
							v.CollisionGroup = 'Characters'
						end
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
				end
			end)
		end)
		wait(51/60)
		if self.Cancelled == true then return end
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Immortal Blaze", "Skill3Drill", "Dashaz", self.Character, self.Character)	
		wait((198/60) - (51/60))
		if self.Cancelled == true then return end
		if self.Hit then return end
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
		self.Cancelled = true
		self:Destroy()
		return
	
end

return Skill3
