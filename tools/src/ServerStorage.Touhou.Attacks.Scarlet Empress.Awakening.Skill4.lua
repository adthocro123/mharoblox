local Skill4 = {}
Skill4.Settings = {
	Cooldown = 15,
	AttackLength = 487/60,
	HitboxSettings = {
		DelayTime = 0,
		Debris = .15,

		Offset = CFrame.new(0,0,-3),
		Size = Vector3.new(17,17,25)
	},
	HitboxSettings2 = {
		DelayTime = 0,
		Debris = .14,

		Offset = CFrame.new(0,0,-2),
		Size = Vector3.new(26,26,26)
	},
	HitboxSettings3 = {
		DelayTime = 0,
		Debris = .15,

		Offset = CFrame.new(0,0,-7),
		Size = Vector3.new(17,16,23)
	},
	Damage = 8
}

function Skill4:CreateHitbox(callback)
	self:bindClassToAttack(self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = self.Character.HumanoidRootPart,
		Offset = self.Settings.HitboxSettings.Offset,
		Size = self.Settings.HitboxSettings.Size,
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = false,
		IgnoresBlock = true,
		Visualize = false,
		DelayTime = self.Settings.HitboxSettings.DelayTime,
		Debris = self.Settings.HitboxSettings.Debris,
	}, callback))
end


function Skill4:CreateHitbox2(callback)
	self:bindClassToAttack(self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = self.Character.HumanoidRootPart,
		Offset = self.Settings.HitboxSettings2.Offset,
		Size = self.Settings.HitboxSettings2.Size,
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = false,
		IgnoresBlock = true,
		Visualize = false,
		DelayTime = self.Settings.HitboxSettings2.DelayTime,
		Debris = self.Settings.HitboxSettings2.Debris,
	}, callback))
end


function Skill4:CreateHitbox3(callback)
	self:bindClassToAttack(self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = self.Character.HumanoidRootPart,
		Offset = self.Settings.HitboxSettings3.Offset,
		Size = self.Settings.HitboxSettings3.Size,
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = false,
		IgnoresBlock = true,
		Visualize = false,
		DelayTime = self.Settings.HitboxSettings3.DelayTime,
		Debris = self.Settings.HitboxSettings3.Debris,
	}, callback))
end

function Skill4:TagEnemy(Enemy)
	if self.Cancelled then return end
	if Enemy:GetAttribute("Ragdoll") then
		self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	end
	local stuntime = 1.5
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,

		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(20000,0,20000),
			Velocity = ((Enemy.HumanoidRootPart.CFrame.Position - self.Character.HumanoidRootPart.CFrame.Position).Unit *(70)), 
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
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 35, "Scarlet Empress", "M1", "Hit", self.Character, Enemy, math.random(1,4))
		end
	end)
end


function Skill4:TagEnemy2(Enemy)
	if self.Cancelled then return end
	if Enemy:GetAttribute("Ragdoll") then
		self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	end
	--local stuntime = 1.6
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,

		KnockbackData = {
			KnockbackType = "ShortKnockback",
			--MaxForce = Vector3.new(100000,0,100000),
			VelocityOrigin = self.Character.HumanoidRootPart, 
			Velocity = 1.8, 
			VelocityUp = 5.5, 
			--Time = .25,
		} ,

		--StateData = {
		--	Stunned = stuntime,
		--	AutoRotate = stuntime
		--},

		--MovementData = {
		--	WalkSpeed = 0,
		--	JumpPower = 0,
		--	Time = stuntime,
		--},
		--BlockData = {			
		--	HitterOrigin = self.Character.HumanoidRootPart.CFrame,
		--},
		ReactionAnim = (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),

		EnemyFacesCharacter = true,

		Damage = self.Settings.Damage,
	},function(State)
		if State == "Hit" then
			self.HitSomeone = true
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 35, "Scarlet Empress", "M1", "Hit", self.Character, Enemy, math.random(1,4))
		end
	end)
end

function Skill4:TagEnemyENDALUCARD(Enemy)
	if Enemy:GetAttribute("Ragdoll") then
		self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	end
	--local stuntime = 1.6
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,

		KnockbackData = {
			KnockbackType = "ShortKnockback",
			--MaxForce = Vector3.new(100000,0,100000),
			VelocityOrigin = self.Character.HumanoidRootPart, 
			Velocity = 12, 
			VelocityUp = 4, 
			--Time = .25,
		} ,

		--StateData = {
		--	Stunned = stuntime,
		--	AutoRotate = stuntime
		--},

		--MovementData = {
		--	WalkSpeed = 0,
		--	JumpPower = 0,
		--	Time = stuntime,
		--},
		--BlockData = {			
		--	HitterOrigin = self.Character.HumanoidRootPart.CFrame,
		--},
		ReactionAnim = (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),

		EnemyFacesCharacter = true,

		Damage = self.Settings.Damage,
	},function(State)
		if State == "Hit" then
			self.HitSomeone = true
			--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 35, "Scarlet Empress", "M1", "Hit", self.Character, Enemy, math.random(1,4))
		end
	end)
end

function Skill4:TagEnemy3(Enemy)
	if self.Cancelled then return end
	if Enemy:GetAttribute("Ragdoll") then
		self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	end
	local stuntime = 1.5
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,

		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(20000,0,20000),
			Velocity = ((Enemy.HumanoidRootPart.CFrame.Position - self.Character.HumanoidRootPart.CFrame.Position).Unit *(30)), 
			Time = .15,
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
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 35, "Scarlet Empress", "M1", "Hit", self.Character, Enemy, math.random(1,4))
		end
	end)
end

function Skill4:TagEnemy4(Enemy)
	if self.Cancelled then return end
	if Enemy:GetAttribute("Ragdoll") then
		self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
	end
	local stuntime = 1.5
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,

		KnockbackData = {
			KnockbackType = "Velocity",
			MaxForce = Vector3.new(20000,0,20000),
			Velocity = ((Enemy.HumanoidRootPart.CFrame.Position - self.Character.HumanoidRootPart.CFrame.Position).Unit *(90)), 
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
		BlockData = {			
			HitterOrigin = self.Character.HumanoidRootPart.CFrame,
		},
		ReactionAnim = (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),

		EnemyFacesCharacter = true,

		Damage = self.Settings.Damage,
	},function(State)
		if State == "Hit" then
			self.HitSomeone = true
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 35, "Scarlet Empress", "M1", "Hit", self.Character, Enemy, math.random(1,4))
		end
	end)
end

function Skill4:AlucardHitbox(callback,character)
	local delayTime = 0
	self:bindClassToAttack(self.Knit.GetService("HitboxService"):createHitbox({
		Caster = self.Character,
		Origin = self.Character.HumanoidRootPart,
		Offset = CFrame.new(0,0,0),
		Size = Vector3.new(40,40,40),
		HitboxType = "Box",
		HitType = "OneHit",
		IgnoresRagdoll = true,
		IgnoresIFrames = true,
		IgnoresBlock = true,
		DelayTime = delayTime,
		Debris = (450-304)/60,
		--ABSOLUTECFRAME = character.HumanoidRootPart.CFrame,
	}, callback))
end
function Skill4:AlucardTagEnemy(Enemy, startingPos)
	if not Enemy.Values:FindFirstChild("ULTIFrames") then

		--if Enemy.Values:FindFirstChild("RagdollIFrames") then return end
		if self.Cancelled then return end


		if not self.Hit  then
			--self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")].DashM1, 1)
		end

		--local bdposicionado2 = Instance.new("BodyPosition",Enemy.HumanoidRootPart)
		--bdposicionado2.MaxForce = Vector3.new(20000,20000,20000)
		--bdposicionado2.Position = self.Character.HumanoidRootPart.Position 
		--bdposicionado2.P = 90000
		--game.Debris:AddItem(bdposicionado2,.15)
		--Enemy.HumanoidRootPart.CFrame = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,1)
		self.Knit.GetService("DamageService"):Damage({

			Character = self.Character,
			Enemy = Enemy,

			--KnockbackData = isClose and {
			--	KnockbackType = "ShortKnockback",
			--	--MaxForce = Vector3.new(100000,0,100000),
			--	VelocityOrigin = self.Character.HumanoidRootPart, 
			--	Velocity = 5, 
			--	VelocityUp = 0, 
			--	--Time = .25,
			--} ,

			--RagdollData =  {
			--	Time = 1,
			--},
			StateData = {
				Stunned = 1.5,
				--AutoRotate = 1,
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
				Time = 1.5,
			},

			BlockData = {			
				HitterOrigin = self.Character.HumanoidRootPart.CFrame,
			},

			Damage = .01,
			--ReactionAnim =  game.ReplicatedStorage.Assets.Animations.ReactionsFlying["Reaction"..math.random(1,4)] or (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),
			--EnemyFacesCharacter = true,
		},function(State)		
			if State == "Hit" then
				self.Hit = true

				--task.delay(.3,function()
			end
		end)
	end
end
function Skill4:TagEnemy266(Enemy)
	coroutine.resume(coroutine.create(function()
		if not self.Character:FindFirstChild("canhitskill4") then return end
		if self.Cancelled then return end
		if self.Ended then return end
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
			game.Debris:AddItem(buffvalue,2)
--			local StunVal = self.Knit.GetService("StateService"):CreateStun(Enemy)
--			StunVal:SetAttribute("RemiliaSpearSkill4StunUnability",true)
			local grab = self.Knit.GetService("GrabService"):grabEnemy(self.Character, Enemy, "HumanoidRootPart", "HumanoidRootPart", CFrame.new(0,1,-1.5)*CFrame.Angles(0,math.rad(180),0))
			for i,v in pairs(Enemy:GetDescendants()) do
				if v:IsA('BasePart') or v:IsA('Decal') or v:IsA('Texture') then
					coroutine.resume(coroutine.create(function()
						if v.Transparency ~= 1 then
							local oldtransparenvy = Instance.new("NumberValue",v)
							oldtransparenvy.Value = v.Transparency
							oldtransparenvy.Name = ("oldtransparency")
							game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
						end	
					end))
				end
			end
			repeat wait(.01)
				if not self.Ended then
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

					Damage = .01,
					ReactionAnim = (game.ReplicatedStorage.Assets.Animations.ReactionsFlyingREAL["Reaction"..math.random(1,4)]),
				},function(State)		
					if State == "Hit" then
						self.Hit = true
					elseif State == "Block" then
					end
				end)
				--wait(.01)
end
			until not self.Character.HumanoidRootPart:FindFirstChild("GrabWeld") or self.Ended

			--networkOwner = Enemy

			--if game.Players:GetPlayerFromCharacter(Enemy) then			
			--	networkOwner = game.Players:GetPlayerFromCharacter(Enemy)			
			--end
			--Enemy.HumanoidRootPart:SetNetworkOwner(networkOwner)

			--task.delay(.15,function()
			if grab ~= nil then
				grab:Destroy()
			end
coroutine.resume(coroutine.create(function()
			for i,v in pairs(Enemy:GetDescendants()) do
				if v:IsA('BasePart') or v:IsA('Decal') or v:IsA('Texture') then
					coroutine.resume(coroutine.create(function()
						if v:FindFirstChild("oldtransparency") then
							game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Transparency = v:FindFirstChild("oldtransparency").Value}):Play()
							v:FindFirstChild("oldtransparency"):Destroy()
						end
					end))
				end
			end
end))
			if grab ~= nil then
				grab:Destroy()
			end
			local ragdolltime = 3.2
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
					Velocity = self.Character.HumanoidRootPart.CFrame.LookVector*70, 
					Time = .14,
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
--			if Enemy:FindFirstChild("Values") then
--				for i,v in pairs(Enemy:FindFirstChild("Values"):GetDescendants()) do
--					if v.Name == ("RemiliaSpearSkill4StunUnability") or v:GetAttribute("RemiliaSpearSkill4StunUnability") then
	--					v:Destroy()
--					end
--				end
--			end
		end
	end))
end
function Skill4:Release()
	--if self.Character.Name == ("44remingtonmagnum") then
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character,game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")].DashM1Mode)
		self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Awakening.Skill4.Release)
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 700, "Scarlet Empress", "M1", "MISERABLEMULTITUDE", self.Character, self.Character)	
		self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "M1", "MISERABLEMULTITUDEVELOCITY", self.Character, self.Character)	
		local IFrames = self.Knit.GetService("StateService"):CreateULTIFrames(self.Character)
		local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
		local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, .1), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
		for _,v in pairs(self.Character:GetChildren()) do
			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
				v.CollisionGroup = 'Visuals2'
			end
		end
		task.delay(53/60,function()
			self:CreateHitbox(function(Enemy)
				self:TagEnemy(Enemy)
			end)
		end)
		task.delay(142/60,function()
			self:CreateHitbox2(function(Enemy)
				self:TagEnemy2(Enemy)
			end)
		end)
		task.delay(219/60,function()
			self:CreateHitbox3(function(Enemy)
				self:TagEnemy3(Enemy)
			end)
		end)
		task.delay(268/60,function()
			self:CreateHitbox3(function(Enemy)
				self:TagEnemy4(Enemy)
			end)
		end)
		task.delay(304/60,function()
			local attacking = true
			local holding = Instance.new("BoolValue",self.Character)
			holding.Value = true
			holding.Name = ("canhitskill4")
		coroutine.resume(coroutine.create(function()
				while attacking == true do
					--alucardeyepuddle.CFrame = self.Character.HumanoidRootPart.CFrame + Vector3.new(0,-2.9,0)
					self:AlucardHitbox(function(Enemy)
						if not Enemy.Values:FindFirstChild("ULTIFrames") then
							----local tween = game:GetService("TweenService"):Create(Enemy.HumanoidRootPart, TweenInfo.new(.05, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {CFrame = self.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-8)})
							----tween:Play()
							--Enemy.HumanoidRootPart.CFrame = self.Character.HumanoidRootPart.CFrame * (CFrame.new(0,0,-3)*CFrame.Angles(0,math.rad(180),0))

							--coroutine.resume(coroutine.create(function()
							--	if not Enemy:FindFirstChild("transparentealucardo") then
							--		local boolvalue =  Instance.new("BoolValue")
							--		boolvalue.Name = ("transparentealucardo")
							--		boolvalue.Parent = Enemy
							--		for _,v in pairs(Enemy:GetChildren()) do
							--			if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
							--				v.CollisionGroup = 'Visuals2'
							--			end
							--		end
							--		coroutine.resume(coroutine.create(function()
							--			repeat wait() until attacking == false
							--			boolvalue:Destroy()
							--			Enemy.HumanoidRootPart.CFrame = self.Character.HumanoidRootPart.CFrame * (CFrame.new(0,0,-2)*CFrame.Angles(0,math.rad(180),0))
							--			self:TagEnemyENDALUCARD(Enemy)
							--			for _,v in pairs(Enemy:GetChildren()) do
							--				if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
							--					v.CollisionGroup = 'Characters'
							--				end
							--			end
							--		end))

							--		for i,v in pairs(Enemy:GetDescendants()) do
							--			if v:IsA('BasePart') or v:IsA('Decal') or v:IsA('Texture') then
							--				coroutine.resume(coroutine.create(function()
							--					if v.Transparency ~= 1 then
							--						local originaltransparency = v.Transparency
							--						game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
							--						repeat wait() until attacking == false
							--						game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Transparency = originaltransparency}):Play()
							--					end	
							--				end))
							--			end
							--		end
							--	end
							--end))
							self:TagEnemy266(Enemy)
						end
					end)
					wait()
				end
			end))
			task.delay((445-304)/60,function()
				self.Ended = true
				self.Cancelled = true
				if holding ~= nil then
					holding:Destroy()
				end	
				for _, v in pairs(self.Character.HumanoidRootPart:GetDescendants()) do
					coroutine.resume(coroutine.create(function()
						if v.Name == ("GrabWeld") then
							v:Destroy()
						end
					end))
				end
				for _, v in pairs(self.Character.HumanoidRootPart:GetDescendants()) do
					coroutine.resume(coroutine.create(function()
						if v.Name == ("GrabWeld") then
							v:Destroy()
						end
					end))
				end
				attacking = false
			end)
		end)
		task.delay(self.Settings.AttackLength,function()
			if Cant ~= nil then
				Cant:Destroy()
			end
			if IFrames ~= nil then
				IFrames:Destroy()
			end
			if Jump ~= nil then
				Jump:Destroy()
			end
			if Speed ~= nil then
				Speed:Destroy()
			end	
			self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Skill4", self.Settings.Cooldown)
			for _,v in pairs(self.Character:GetChildren()) do
				if v.Name == ("HumanoidRootPart") and v:IsA("Part") then
					v.CollisionGroup = 'Characters'
				end
			end
			self:Destroy()
		end)
	--end
end

return Skill4
