local Skill4 = {}
Skill4.Settings = {
	Cooldown = 35,
	Damage = .55,
	AttackLength = (76/60),
	AttackLength2 = (190/60),

	HitboxSettings = {
		DelayTime = .23,
		Debris = .22,

		Offset = CFrame.new(0,2.5,-3.2),
		Size = Vector3.new(10,5,20)
	},
	magnitudeForClose = 20,
}
Skill4.Settings2 = {
	Cooldown = 35,
	Damage = 8,
	AttackLength = 1.4,

	HitboxSettings = {
		DelayTime = 0,
		Debris = .4,

		Offset = CFrame.new(0,4,-3),
		Size = Vector3.new(15,18,20)
	},
}
Skill4.Settings3 = {
	Cooldown = 25,
	Damage = 7,
	AttackLength = 1.4,

	HitboxSettings = {
		DelayTime = 0,
		Debris = .1,

		Offset = CFrame.new(0,4.5,-4),
		Size = Vector3.new(10,23,20)
	},
}

function Skill4:CreateHitbox2(callback)
	if self.Character.Values:FindFirstChild("Stunned") then return end
	self:bindClassToAttack(self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = self.Character.HumanoidRootPart,
		Offset = self.Settings3.HitboxSettings.Offset,
		Size = self.Settings3.HitboxSettings.Size,
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = false,
		IgnoresBlock = false,
		Visualize = false,
		PerfectTrack = false,
		DelayTime = self.Settings3.HitboxSettings.DelayTime,
		Debris = self.Settings3.HitboxSettings.Debris,
	}, callback))
end

function Skill4:CreateHitbox(callback)
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

function Skill4:TagEnemy2(Enemy,startingPos)
	coroutine.resume(coroutine.create(function()
		local isClose = (Enemy.HumanoidRootPart.Position-startingPos).magnitude >= self.Settings.magnitudeForClose
		if self.Character.HumanoidRootPart:FindFirstChild("GrabWeld") then return end
		if not self.Character:FindFirstChild("canhitskill4") then return end
		if self.Cancelled then return end
		if Enemy.Values:FindFirstChild("IFrames") then return end
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

		if not Enemy:FindFirstChild("hitwithtecatoca") then
			local buffvalue = Instance.new("BoolValue",Enemy)
			buffvalue.Value = true
			buffvalue.Name = ("hitwithtecatoca")
			game.Debris:AddItem(buffvalue,1.5)
			local StunVal = self.Knit.GetService("StateService"):CreateStun(Enemy)
			StunVal:SetAttribute("RemiliaSpearSkill4StunUnability",true)
			local grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,1,-1.5)*CFrame.Angles(0,math.rad(180),0))
			--self.Knit.GetService("RagdollService"):unragdoll(self.Character, true,true)
			--self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
			--task.delay(1,function()
			--	for _, v in pairs(self.Character.HumanoidRootPart:GetDescendants()) do
			--		coroutine.resume(coroutine.create(function()
			--			if v.Name == ("GrabWeld") then
			--				v:Destroy()
			--			end
			--		end))
			--	end
			--end)
			--local networkOwner = self.Character

			--if game.Players:GetPlayerFromCharacter(self.Character) then			
			--	networkOwner = game.Players:GetPlayerFromCharacter(self.Character)			
			--end
			--Enemy.HumanoidRootPart:SetNetworkOwner(networkOwner)

			--for _, v in pairs(self.Character.HumanoidRootPart:GetDescendants()) do
			--	coroutine.resume(coroutine.create(function()
			--		if v.Name == ("GrabWeld") then
			--			v.Enabled = false
			--		end
			--	end))
			--end
			--Enemy.HumanoidRootPart.Anchored = true
			repeat wait(.01)
				--Enemy.HumanoidRootPart.CFrame = (self.Character.HumanoidRootPart.CFrame * (CFrame.new(0,1,-1.5)*CFrame.Angles(0,math.rad(180),0)))
				--local RedFX123=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.Hit:Clone()	
				--RedFX123.VFX["h"..math.random(1,4)]:Play()
				--RedFX123.CFrame = Enemy.Head.CFrame
				--game.Debris:AddItem(RedFX123,1)
				--RedFX123.Parent= workspace.Ignore.Effects
				--for i,v in pairs(RedFX123:GetDescendants()) do
				--	if v:IsA('ParticleEmitter') then
				--		v:Emit(v:GetAttribute('EmitCount'))
				--	end
				--end


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
							--AutoRotate = 1,
						},

						--RagdollData = {
						--	Time = .6,
						--},
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
					},function(State)		
						if State == "Hit" then
							self.Hit = true
							--local mathrandom = 2
							--if mathrandom == 2 then
								self.Knit.GetService("CombatService"):FireAllClients(self.Character, 25, script.Parent.Name, "M1", "Hit2", self.Character, Enemy, 1)
							--end
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
					--wait(.01)
			until not self.Character.HumanoidRootPart:FindFirstChild("GrabWeld")
			--networkOwner = Enemy

			--if game.Players:GetPlayerFromCharacter(Enemy) then			
			--	networkOwner = game.Players:GetPlayerFromCharacter(Enemy)			
			--end
			--Enemy.HumanoidRootPart:SetNetworkOwner(networkOwner)

			--task.delay(.15,function()
local ragdolltime = 3
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
					KnockbackType = "Velocity",
					MaxForce = Vector3.new(20000,20000,20000),
					Velocity = self.Character.HumanoidRootPart.CFrame.LookVector*(70), 
					Time = .15,
				},
				RagdollData =  {
					Time = ragdolltime,
				},
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
					Stunned = ragdolltime,
					AutoRotate = ragdolltime,
				},

				MovementData = {
					WalkSpeed = 0,
					JumpPower = 0,
					Time = ragdolltime,
				},

				BlockData = {			
					HitterOrigin = self.Character.HumanoidRootPart.CFrame,
				},

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
			if grab ~= nil then
				grab:Destroy()
			end
			if Enemy:FindFirstChild("Values") then
				for i,v in pairs(Enemy:FindFirstChild("Values"):GetDescendants()) do
					if v.Name == ("RemiliaSpearSkill4StunUnability") or v:GetAttribute("RemiliaSpearSkill4StunUnability") then
						v:Destroy()
					end
				end
			end
		end
	end))
end

local Blacklist2 = OverlapParams.new()

Blacklist2.FilterDescendantsInstances = {script.Parent,workspace.Terrain,workspace.Ignore}

Blacklist2.FilterType = Enum.RaycastFilterType.Exclude

local Blacklist = RaycastParams.new()

Blacklist.FilterDescendantsInstances = {script.Parent,workspace.Terrain,workspace.Ignore}

Blacklist.FilterType = Enum.RaycastFilterType.Exclude

function Skill4:TagEnemyThrow(Enemy)
	if self.Cancelled then return end
local stuntime = 2
	self.Knit.GetService("DamageService"):Damage({

		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(10000,10000,10000),
			Velocity = (self.Character.HumanoidRootPart.CFrame.LookVector*(70)) + Vector3.new(0,15,0),
			Time = .05,
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
		--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 70, "Scarlet Empress", "M1", "SmashWhenGround", Enemy,1)
	end)
end
function Skill4:TagEnemyThrow2(Enemy)
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
function Skill4:HitEnemyColl(Enemy, root)

	local Time = .2

	--task.delay(.1,function()

	--end)
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,

		KnockbackData  
			=
			{
				KnockbackType = "Velocity",
				MaxForce = Vector3.new(10000,0,10000),
				Velocity = self.Character.HumanoidRootPart.CFrame.LookVector*(25), 
				Time = .1,
			} ,
		StateData = {
			Stunned = 1,
			--AutoRotate = 1,
		},

		MovementData = {
			WalkSpeed = 0,
			JumpPower = 0,
			Time = 1,
		},

		BlockData = {			
			HitterOrigin = self.Character.HumanoidRootPart.CFrame,
		},

		Damage = .4,
		ReactionAnim = (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),
	},function(State)		
		if State == "Hit" then
			self.Hit = true
			--task.delay(.3,function()
			--if self.Character["Right Arm"]:FindFirstChild("remiliaspear") then
			--	self.Character["Right Arm"]:FindFirstChild("remiliaspear")["Impale"]:Play()
			--end
			--if self.Character["Right Arm"]:FindFirstChild("LowRes_Gungir2_Body") then
			--	self.Character["Right Arm"]:FindFirstChild("LowRes_Gungir2_Body")["Impale"]:Play()
			--end
			--end)
			--task.delay(.2,function()
			--if not self.Character:FindFirstChild("m1ing") then
			--self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
			--self.Knit.GetService("MovementService"):RemoveMovements(self.Character,{WalkSpeed = 0, JumpPower = 0})
			--end
			--end)
			--local CombatProfile = self.Knit.GetService("CharacterService"):GetProfile(self.Character).Combats[self.Character:GetAttribute("Combat")]
			--if CombatProfile.Combo <= 3 then
			--	local Clock = os.clock()
			--	CombatProfile.Combo = 1
			--	CombatProfile.LastM1 = Clock
			--end
			--if self.Character:GetAttribute("M1Cooldown") then
			--	self.Character:SetAttribute("M1Cooldown", nil)
			--end
			if Enemy:GetAttribute("Ragdoll") then
				self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
			end
			local sound151 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat["stab"..math.random(1,2)]:Clone()	
			sound151.Parent = Enemy.Torso
			sound151.Volume = .2
			sound151:Play()
			game.Debris:AddItem(sound151,1)
			local sound1521 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat["bloodstab"..math.random(1,4)]:Clone()	
			sound1521.Parent = Enemy.Torso
			sound1521.Volume = .2
			sound1521:Play()
			game.Debris:AddItem(sound1521,1)
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Gungnir", "M1", "HitPunch2", self.Character, Enemy, 3)
			--if self.Character["Right Arm"]:FindFirstChild("remiliaspear") then
			--	self.Character["Right Arm"]:FindFirstChild("remiliaspear").slash2:Play()
			--end
			--if self.Character["Right Arm"]:FindFirstChild("remiliaspear") then
			--	self.Character["Right Arm"]:FindFirstChild("remiliaspear").slash:Play()
			--end
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 65, script.Parent.Name, "M1", "Hit22", self.Character, Enemy, math.random(1,4))
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Gungnir", "M1", "Hit", self.Character, Enemy, math.random(1,4))
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Gungnir", "M1", "HitPunch", self.Character, Enemy, math.random(1,4))
			--self.Character.Humanoid:MoveTo(self.Character.HumanoidRootPart.Position:Lerp(Enemy.HumanoidRootPart.Position, 0.5))
		elseif State == "Block" then
		end
	end)
end
function Skill4:TagEnemy3(Enemy)
	if self.Character.Values:FindFirstChild("Stunned") then return end
	if self.Character.HumanoidRootPart:FindFirstChild("GrabWeld") then return end
	if self.Cancelled then return end
	if self.Hit then return end
	if (Enemy.Values:FindFirstChild("RagdollSuperArmor")) or (Enemy:FindFirstChild("MilleniumVampire"))then return end
	Enemy:SetAttribute("Cancel", os.clock())
	task.delay(15/60,function()
		local RedF2X2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.remimovespin:Clone()
		RedF2X2425.Parent = self.Character.HumanoidRootPart
		game.Debris:AddItem(RedF2X2425,4)
		RedF2X2425:Play()
	end)
	if Enemy:GetAttribute("Ragdoll") then
		self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	end
	self.Hit = Enemy
	self:AddFor(self.Settings.AttackLength, function()
		self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill4", self.Settings.Cooldown)
	end)
	local grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,-.5,-1.5)*CFrame.Angles(0,math.rad(180),0),"LOOSEGRAB")
	task.delay(.2,function()
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.StartupNew)
	end)
	local attacking = true 
	task.delay(22/60,function()
		coroutine.resume(coroutine.create(function()
			while attacking == true do
				self.Knit.GetService("CombatService"):FireAllClients(self.Character, 65, script.Parent.Name, "M1", "Hit22", self.Character, Enemy, math.random(1,4))
				self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, .3)
				self.Knit.GetService("HitboxService"):createHitbox({
					Caster = self.Character,
					Origin = self.Character.HumanoidRootPart.CFrame,
					Offset = CFrame.new(0,0,0),
					Size = Vector3.new(17,26,26),
					HitboxType = "Box",
					HitType = "OneHit",
					IgnoresRagdoll = true,
					IgnoresBlock = true,
					DelayTime = 0,
					Debris = .1,
				}, function(Enemy5)
					if Enemy5 == Enemy then return end
					if attacking == true then
					self:HitEnemyColl(Enemy5,self.Character.HumanoidRootPart)
end
				end)
				wait(.06)
			end
		end))
	end)
	self.Knit.GetService("DamageService"):JustDamage(self.Character, Enemy, 1)

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
	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 100, self.Character:GetAttribute("Character"), "M1", "REMIMOVEUPPERCUTHIT", self.Character)
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)

	local IFrames = self.Knit.GetService("StateService"):CreateULTIFrames(self.Character)
	local IFramesEnemy = self.Knit.GetService("StateService"):CreateULTIFrames(Enemy)
	local AutoRotateEnemy = self.Knit.GetService("StateService"):CreateAutoRotate(Enemy)
	local AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
	local Cant2 = self.Knit.GetService("StateService"):CreateCant(Enemy)
	local StunVal = self.Knit.GetService("StateService"):CreateStun(Enemy)
	game.Debris:AddItem(Cant2,self.Settings.AttackLength2+.4)
	game.Debris:AddItem(StunVal,self.Settings.AttackLength2+.4)
	local Speed1, Jump2 = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 1), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	game.Debris:AddItem(Speed1, self.Settings.AttackLength + (11/60))
	game.Debris:AddItem(Jump2, self.Settings.AttackLength + (11/60))

	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(Enemy, 0), self.Knit.GetService("MovementService"):CreateJump(Enemy, 0)
	game.Debris:AddItem(Speed, self.Settings.AttackLength2)
	game.Debris:AddItem(Jump, self.Settings.AttackLength2)

	--task.delay(18/60,function()
	--	AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
	--end)
	self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.Victim)
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.Success)
	task.delay(self.Settings.AttackLength - .1,function()
		local buffvalue = Instance.new("BoolValue",Enemy)
		buffvalue.Value = true
		buffvalue.Name = ("CANTBEDETECTEDBYCLOSETORSODETECTION")
		game.Debris:AddItem(buffvalue,.8)
	end)
	task.delay(self.Settings.AttackLength,function()
		if self.Cancelled then return end
		coroutine.resume(coroutine.create(function()
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
			attacking = false
			self.Knit.GetService("HitboxService"):createHitbox({
				Caster = self.Character,
				Origin = self.Character.HumanoidRootPart.CFrame,
				Offset = CFrame.new(0,0,0),
				Size = Vector3.new(28,28,28),
				HitboxType = "Box",
				HitType = "OneHit",
				IgnoresRagdoll = true,
				IgnoresBlock = true,
				DelayTime = 0,
				Debris = .15,
			}, function(Enemy5)
				if Enemy5 ~= Enemy then
					self:TagEnemyThrow(Enemy5)
				end
			end)
			task.delay(11/60,function()
				if IFrames.Parent ~= nil then
					IFrames:Destroy()
				end
				if AutoRotate ~= nil then
					AutoRotate:Destroy()
				end
				--if (self.Character["Right Arm"]:FindFirstChild("remiliaspear")) then
				--	for i,v in pairs(self.Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
				--		if v:IsA("BasePart") and v.Transparency == 5 then
				--			v.Transparency = 0
				--			--game:GetService("TweenService"):Create(v,TweenInfo.new(1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 0}):Play()
				--		end
				--	end
				--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 50, "Scarlet Empress", "M1", "GUNGNIREXPLODESPAWN", self.Character["Right Arm"]:FindFirstChild("remiliaspear"))	
				--end
				if Jump2.Parent ~= nil then
					Jump2:Destroy()
				end
				if Speed1.Parent ~= nil then
					Speed1:Destroy()
				end
				if Cant.Parent ~= nil then
					Cant:Destroy()
				end
			end)
			if StunVal.Parent ~= nil then
				StunVal:Destroy()
			end
			if Jump.Parent ~= nil then
				Jump:Destroy()
			end
			if Speed.Parent ~= nil then
				Speed:Destroy()
			end
		end))
		if grab ~= nil then
			grab:Destroy()
		end
		if Enemy.Parent ~= nil then
			self:TagEnemyThrow2(Enemy)
		end
	end)	
end
function Skill4:Release(InAir)
	if self.Character.HumanoidRootPart:FindFirstChild("GrabWeld") then return end
	--april fools
 if self.Character.Values:FindFirstChild("Cant") then return end
	if self.Character.Values:FindFirstChild("CantHeartBreak") and not self.Character:FindFirstChild("HEARTBREAKCLOSEVARIANTHOLD") then return end
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit1"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit2"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit3"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit4"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Uppercut"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Downslam"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.CloseVariant)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.Release2)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.NewRelease)
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.StartupNew)
	--if self.Character.Name == ("44remingtonmagnum") then
		--if (self.Character["Right Arm"]:FindFirstChild("remiliaspear")) then
		--	for i,v in pairs(self.Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
		--		if v:IsA("BasePart") and v.Transparency == 0 then
		--			v.Transparency = 5
		--			--game:GetService("TweenService"):Create(v,TweenInfo.new(1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 5}):Play()
		--		end
		--	end
		--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 50, "Scarlet Empress", "M1", "GUNGNIREXPLODESPAWN", self.Character["Right Arm"]:FindFirstChild("remiliaspear"))	
		--end
		if self.Character.Values:FindFirstChild("CantHeartBreak") and self.Character:FindFirstChild("HEARTBREAKCLOSEVARIANTHOLD") then 
			self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "Skill3Drill", "Dash2fiftiesz", self.Character, self.Character)	
			InAir = false
		end
		if self.Character:FindFirstChild("Values") then
			for i,v in pairs(self.Character:FindFirstChild("Values"):GetDescendants()) do
				if v.Name == ("HeartBreakMovementUnability") or v:GetAttribute("HeartBreakMovementUnability") then
					v:Destroy()
				end
			end
		end
		if InAir then
			self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Stuff", "downslamupthing", "downslamvelocity", self.Character, self.Character)	
			self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "Skill4Drill", "DrillVELOCIDAD1", self.Character, self.Character)	
			task.delay(15/60,function()
				local RedF2X2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.remimovespin:Clone()
				RedF2X2425.Parent = self.Character.HumanoidRootPart
				game.Debris:AddItem(RedF2X2425,4)
				RedF2X2425:Play()
			end)
			self:AddFor(self.Settings.AttackLength, function()
				self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill4", self.Settings.Cooldown)
			end)
			task.delay(.2,function()
				self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.StartupNew)
			end)
			local attacking = true 
			task.delay(22/60,function()
				coroutine.resume(coroutine.create(function()
					while attacking == true do
						self.Knit.GetService("HitboxService"):createHitbox({
							Caster = self.Character,
							Origin = self.Character.HumanoidRootPart.CFrame,
							Offset = CFrame.new(0,0,0),
							Size = Vector3.new(17,26,26),
							HitboxType = "Box",
							HitType = "OneHit",
							IgnoresRagdoll = true,
							IgnoresBlock = false,
							DelayTime = 0,
							Debris = .1,
						}, function(Enemy5)
							if Enemy5.Humanoid:GetState() == Enum.HumanoidStateType.Freefall or Enemy5.Humanoid:GetState() == Enum.HumanoidStateType.Jumping then
								local bdposicionado2 = Instance.new("BodyPosition",Enemy5.HumanoidRootPart)
								bdposicionado2.MaxForce = Vector3.new(math.huge,math.huge,math.huge)
								bdposicionado2.Position = self.Character.HumanoidRootPart.Position
								game.Debris:AddItem(bdposicionado2,.1)
							end
							if attacking == true then
								self:HitEnemyColl(Enemy5,self.Character.HumanoidRootPart)
							end
						end)
						wait(.06)
					end
				end))
			end)

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
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 100, self.Character:GetAttribute("Character"), "M1", "REMIMOVEUPPERCUTHIT", self.Character)
			local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)

			local IFrames = self.Knit.GetService("StateService"):CreateULTIFrames(self.Character)
			local AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
			local Speed1, Jump2 = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 1), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
			game.Debris:AddItem(Speed1, self.Settings.AttackLength + (11/60))
			game.Debris:AddItem(Jump2, self.Settings.AttackLength + (11/60))


			--task.delay(18/60,function()
			--	AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
			--end)
			self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.Success)
			task.delay(self.Settings.AttackLength,function()
				if self.Cancelled then return end
				coroutine.resume(coroutine.create(function()
					attacking = false
					self.Knit.GetService("HitboxService"):createHitbox({
						Caster = self.Character,
						Origin = self.Character.HumanoidRootPart.CFrame,
						Offset = CFrame.new(0,0,0),
						Size = Vector3.new(28,28,28),
						HitboxType = "Box",
						HitType = "OneHit",
						IgnoresRagdoll = true,
						IgnoresBlock = true,
						DelayTime = 0,
						Debris = .15,
					}, function(Enemy5)
						if Enemy5:FindFirstChild("HITWITHRANGEDHEARTBREAK") then
							self:TagEnemyThrow2(Enemy5)
						else
							self:TagEnemyThrow(Enemy5)
						end
					end)
					task.delay(11/60,function()
						if IFrames.Parent ~= nil then
							IFrames:Destroy()
						end
						if AutoRotate ~= nil then
							AutoRotate:Destroy()
						end
						--if (self.Character["Right Arm"]:FindFirstChild("remiliaspear")) then
						--	for i,v in pairs(self.Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
						--		if v:IsA("BasePart") and v.Transparency == 5 then
						--			v.Transparency = 0
						--			--game:GetService("TweenService"):Create(v,TweenInfo.new(1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 0}):Play()
						--		end
						--	end
						--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 50, "Scarlet Empress", "M1", "GUNGNIREXPLODESPAWN", self.Character["Right Arm"]:FindFirstChild("remiliaspear"))	
						--end
						if Jump2.Parent ~= nil then
							Jump2:Destroy()
						end
						if Speed1.Parent ~= nil then
							Speed1:Destroy()
						end
						if Cant.Parent ~= nil then
							Cant:Destroy()
						end
					end)
				end))
			end)	
		else
			local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 10), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
			local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
			self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
			self.Knit.GetService("AttackService"):destroyBodyGyroHold(self.Character,"FullMouse")
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 100, self.Character:GetAttribute("Character"), "M1", "REMIMOVEUPPERCUT", self.Character)
			local count = 0
			local AutoRotate = nil
			self:listenForCancel(function()	
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
				if AutoRotate ~= nil then
					AutoRotate:Destroy()
				end
				self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.StartupNew)
				self.Cancelled = true
				--if (self.Character["Right Arm"]:FindFirstChild("remiliaspear")) then
				--	for i,v in pairs(self.Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
				--		if v:IsA("BasePart") and v.Transparency == 5 then
				--			v.Transparency = 0
				--			--game:GetService("TweenService"):Create(v,TweenInfo.new(1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 0}):Play()
				--		end
				--	end
				--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 50, "Scarlet Empress", "M1", "GUNGNIREXPLODESPAWN", self.Character["Right Arm"]:FindFirstChild("remiliaspear"))	
				--end
				self:Destroy()
			end)
			local hrp = self.Character:FindFirstChild("HumanoidRootPart")
			local startingPos = self.Character.HumanoidRootPart.Position
			for _,v in pairs(self.Character:GetChildren()) do
				if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
					v.CollisionGroup = 'Visuals2'
				end
			end
			wait(16/60)
			self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
			self.Knit.GetService("AttackService"):destroyBodyGyroHold(self.Character,"FullMouse")

			task.delay(self.Settings3.HitboxSettings.Debris,function()
				if not self.Hit then
					self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill4", self.Settings.Cooldown)
				end
			end)
			if self.Cancelled then
				if Cant ~= nil then
					Cant:Destroy()
				end
				if Jump ~= nil then
					Jump:Destroy()
				end
				if Speed ~= nil then
					Speed:Destroy()
				end
				if AutoRotate ~= nil then
					AutoRotate:Destroy()
				end
				self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.StartupNew)
				self.Cancelled = true
				if (self.Character["Right Arm"]:FindFirstChild("remiliaspear")) then
					for i,v in pairs(self.Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
						if v:IsA("BasePart") and v.Transparency == 5 then
							v.Transparency = 0
							--game:GetService("TweenService"):Create(v,TweenInfo.new(1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 0}):Play()
						end
					end
					self.Knit.GetService("CombatService"):FireAllClients(self.Character, 50, "Scarlet Empress", "M1", "GUNGNIREXPLODESPAWN", self.Character["Right Arm"]:FindFirstChild("remiliaspear"))	
				end
				self:Destroy()
				return
			end
			AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)

			local function dashforward()
				self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "Skill4Drill", "DrillVELOCIDAD2", self.Character, self.Character)	
			end
			dashforward()
			local IFrames = self.Knit.GetService("StateService"):CreateIFrames(self.Character)
			task.delay(.3,function()
				if IFrames ~= nil then
					IFrames:Destroy()
				end
			end)
			if self.Cancelled then
				self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.StartupNew)
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
				self:CreateHitbox2(function(Enemy)
					if self.Character.HumanoidRootPart:FindFirstChild("GrabWeld") then return end
					self:TagEnemy3(Enemy,startingPos)
				end)
			end))
			wait((41/60) - (16/60))
			for _,v in pairs(self.Character:GetChildren()) do
				if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
					v.CollisionGroup = 'Characters'
				end
			end
			if AutoRotate ~= nil then
				AutoRotate:Destroy()
			end
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
			if not self.Hit then
				--if (self.Character["Right Arm"]:FindFirstChild("remiliaspear")) then
				--	for i,v in pairs(self.Character["Right Arm"]:FindFirstChild("remiliaspear"):GetDescendants()) do
				--		if v:IsA("BasePart") and v.Transparency == 5 then
				--			v.Transparency = 0
				--			--game:GetService("TweenService"):Create(v,TweenInfo.new(1,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 0}):Play()
				--		end
				--	end
				--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 50, "Scarlet Empress", "M1", "GUNGNIREXPLODESPAWN", self.Character["Right Arm"]:FindFirstChild("remiliaspear"))	
				--end
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
		end
--else
--	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit1"])
--	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit2"])
--	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit3"])
--	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit4"])
--	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Uppercut"])
--	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Downslam"])
--	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.CloseVariant)
--	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill1.Release)
--	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.Release2)
--	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.Release)
--	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.CloseVariant)
--	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.Startup)
--	local holding = Instance.new("BoolValue",self.Character)
--	holding.Value = true
--	holding.Name = ("canhitskill4")
--	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.Startup)
--	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 12), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
--	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
--	self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
--	self.Knit.GetService("AttackService"):destroyBodyGyroHold(self.Character,"FullMouse")
--	self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill4", self.Settings.Cooldown)
--	for _,v in pairs(self.Character:GetChildren()) do
--		if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
--			v.CollisionGroup = 'Visuals2'
--		end
--	end
--	local attacking = true
--	self:listenForCancel(function()	
--		if holding ~= nil then
--			holding:Destroy()
--		end	
--		for _,v in pairs(self.Character:GetChildren()) do
--			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
--				v.CollisionGroup = 'Characters'
--			end
--		end
--		attacking = false
--		for _, v in pairs(self.Character.HumanoidRootPart:GetDescendants()) do
--			coroutine.resume(coroutine.create(function()
--				if v.Name == ("GrabWeld") then
--					v:Destroy()
--				end
--			end))
--		end
--		if Cant ~= nil then
--			Cant:Destroy()
--		end
--		if Jump ~= nil then
--			Jump:Destroy()
--		end
--		if Speed ~= nil then
--			Speed:Destroy()
--		end
--		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.Startup)
--		self.Cancelled = true 
--		self:Destroy()
--	end)
--	local function flare()
--		if self.Cancelled ~= true then
--			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 25, "Scarlet Empress", "M1", "FLARE", self.Character, self.Character)	
--		end
--	end
--	flare()
--	local hrp = self.Character:FindFirstChild("HumanoidRootPart")
--	local startingPos = self.Character.HumanoidRootPart.Position
--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 25, "Scarlet Empress", "M1", "M1TRAIL", self.Character, self.Character)	
--	wait(34/60)
--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 25, "Scarlet Empress", "M1", "2TRAIL", self.Character, self.Character)	
--	if self.Cancelled then
--		if holding ~= nil then
--			holding:Destroy()
--		end	
--		attacking = false
--		for _, v in pairs(self.Character.HumanoidRootPart:GetDescendants()) do
--			coroutine.resume(coroutine.create(function()
--				if v.Name == ("GrabWeld") then
--					v:Destroy()
--				end
--			end))
--		end
--		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill4.Startup)
--		if Cant ~= nil then
--			Cant:Destroy()
--		end
--		if Jump ~= nil then
--			Jump:Destroy()
--		end
--		if Speed ~= nil then
--			Speed:Destroy()
--		end
--		self.Cancelled = true
--		self:Destroy()
--		return
--	end
--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 40, "Scarlet Empress", "M1", "CEILINGFEARVFX", self.Character, self.Character)	
--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 40, "Scarlet Empress", "M1", "DRILLSFX", self.Character, self.Character)	
--	local function dashforward()
--		self.Character["Right Arm"]:FindFirstChild("remiliaspear")["spinny"]:Play()

--		coroutine.resume(coroutine.create(function()
--			self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "Skill4Drill", "Drill", self.Character, self.Character)	
--		end))
--	end
--	coroutine.resume(coroutine.create(function()
--		dashforward()
--		self:CreateHitbox(function(Enemy)
--				if self.Character.HumanoidRootPart:FindFirstChild("GrabWeld") then return end
--				self:TagEnemy2(Enemy,startingPos)
--		end)
--	end))
--	wait((58/60) - (34/60))
--	attacking = false
--	if holding ~= nil then
--		holding:Destroy()
--	end	
--	for _, v in pairs(self.Character.HumanoidRootPart:GetDescendants()) do
--		coroutine.resume(coroutine.create(function()
--			if v.Name == ("GrabWeld") then
--				v:Destroy()
--			end
--		end))
--	end
--	for _, v in pairs(self.Character.HumanoidRootPart:GetDescendants()) do
--		coroutine.resume(coroutine.create(function()
--			if v.Name == ("GrabWeld") then
--				v:Destroy()
--			end
--		end))
--	end
--	wait(.1)
--	for _,v in pairs(self.Character:GetChildren()) do
--		if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
--			v.CollisionGroup = 'Characters'
--		end
--	end

--	--local bufftime = 15
--	--local RedFX = ResourceFolder.Parent.MilleniumExplosion.Attachment:Clone()
--	--RedFX.Parent = self.Character.Torso
--	--game.Debris:AddItem(RedFX,bufftime)
--	--for i,v in pairs(RedFX:GetDescendants()) do
--	--	if v:IsA('ParticleEmitter') then
--	--		v:Emit(v:GetAttribute('EmitCount') or 1)
--	--	end
--	--end
--	--RedFX.shockwave:Play()
--	--RedFX.shockwave2:Play()
--	--RedFX.shockwave3:Play()
--	--local buffvalue = Instance.new("BoolValue",self.Character)
--	--buffvalue.Value = true
--	--buffvalue.Name = ("MilleniumVampire")
--	--game.Debris:AddItem(buffvalue,bufftime)
--	--local RedFX251 = ResourceFolder.Parent.MilleniumSmoke.Attachment:Clone()
--	--RedFX251.Parent = self.Character.Torso
--	--game.Debris:AddItem(RedFX251,bufftime + 2)
--	--for i,v in pairs(RedFX251:GetChildren()) do
--	--	if v:IsA("ParticleEmitter") then
--	--		task.delay(bufftime,function()
--	--			v.Enabled = false
--	--		end)
--	--	end
--	--end
--	--for i,v in pairs(ResourceFolder:GetChildren()) do
--	--	if v:IsA("ParticleEmitter") then
--	--		local cloneado = v:Clone()
--	--		cloneado.Parent = self.Character.Torso
--	--		task.delay(bufftime,function()
--	--			cloneado.Enabled = false
--	--			game.Debris:AddItem(cloneado,2)
--	--		end)
--	--	end
--	--end
--	--task.wait(.9)
--	if holding ~= nil then
--		holding:Destroy()
--	end	
--	for _, v in pairs(self.Character.HumanoidRootPart:GetDescendants()) do
--		coroutine.resume(coroutine.create(function()
--			if v.Name == ("GrabWeld") then
--				v:Destroy()
--			end
--		end))
--	end
--	if Jump ~= nil then
--		Jump:Destroy()
--	end
--	if Speed ~= nil then
--		Speed:Destroy()
--	end
--	wait(.1)
--	for _, v in pairs(self.Character.HumanoidRootPart:GetDescendants()) do
--		coroutine.resume(coroutine.create(function()
--			if v.Name == ("GrabWeld") then
--				v:Destroy()
--			end
--		end))
--	end
--	if Cant ~= nil then
--		Cant:Destroy()
--	end
--	task.delay(1,function()
--		self:Destroy()
--	end)
--end
end

return Skill4
