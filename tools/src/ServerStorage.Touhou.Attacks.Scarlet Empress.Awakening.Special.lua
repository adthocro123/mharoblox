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

function Special:Release(InAir,torso)	
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit1"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit2"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit3"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit4"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Uppercut"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Downslam"])
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.Release2)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.Release)
	self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Skill2.CloseVariant)
	self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Special.Release)
	self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Special", 15)
	local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 0), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
	local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
	local cadeafolderfornewplayerverdaderomano = Instance.new("Folder",workspace.Ignore.Effects)
	cadeafolderfornewplayerverdaderomano.Name = ("CADEAFOLDER"..self.Character.Name.."TRUEINFORMATION"..math.random(1,75))
	local Emerald
	local ChainPortal
	local AutoRotate
	local connection2
	local exploded = false
	local function explode(part)
		if Emerald ~= nil then
			if exploded == false then
				if part ~= nil then
					if part:IsDescendantOf(self.Character) then return end
					if part:IsDescendantOf(workspace.Ignore.Effects) then return end
					if part.CanCollide == false then return end
				end
				exploded = true
				if connection2 ~= nil then
					connection2:Disconnect()
				end
			task.delay(.08,function()
				if AutoRotate ~= nil then
					AutoRotate:Destroy()
				end
				if Cant ~= nil then
					Cant:Destroy()
				end
				if Speed ~= nil then
					Speed:Destroy()
				end
				if Jump ~= nil then
					Jump:Destroy()
				end
			end)
				Emerald.chainLoop:Destroy()
				if not self.Cancelled then
				self.Knit.GetService("HitboxService"):createHitbox({
					Caster = self.Character,
					Origin = Emerald.CFrame * CFrame.new(0,0,5),
					Offset = CFrame.new(0,0,0),
					Size = Vector3.new(14,14,18),
					HitboxType = "Box",
					HitType = "OneHit",
					IgnoresRagdoll = true,
					IgnoresIFrames = false,
					IgnoresBlock = false,
					DelayTime = 0,
					Debris = .1,
					ReactionAnim = game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)],
				}, function(Enemy)
					local stuntime = 1
					if Enemy:GetAttribute("Ragdoll") then
						self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
					end
					self.Knit.GetService("DamageService"):Damage({

						Character = self.Character,
						Enemy = Enemy,

						StateData =   {
							Stunned =stuntime,
							AutoRotate = stuntime,
						},
						--RagdollData = ragdolled and {
						--	Time = .25,
						--},

						MovementData = {
							WalkSpeed = 0,
							JumpPower = 0,
							Time = stuntime,
						},
						BlockData = {			
							HitterOrigin = self.Character.HumanoidRootPart.CFrame,
						},

						--EnemyFacesCharacter = true,
						CharacterFacesEnemy = true,

						Damage = self.Settings.Damage,
					},function(State)
						if State == "Hit" then
							if not self.HitSomeone then
								self.HitSomeone = true
								wait(.07)
								if Enemy ~= nil then
									self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Special.Hit)
									local Victim = Enemy
									local VictimRootPart = Enemy:FindFirstChild("HumanoidRootPart")
									local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.clothsfx17:Clone()
									RedFX2425.Parent = self.Character.HumanoidRootPart
									game.Debris:AddItem(RedFX2425,5)
									RedFX2425:Play()
									local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.chainmail:Clone()
									RedFX2425.Parent = self.Character.HumanoidRootPart
									game.Debris:AddItem(RedFX2425,5)
									RedFX2425:Play()
									local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.chainsfx1:Clone()
									RedFX2425.Parent = self.Character.HumanoidRootPart
									game.Debris:AddItem(RedFX2425,5)
									RedFX2425:Play()

									local RedFX2425=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.chainsfx3:Clone()
									RedFX2425.Parent = Enemy.Torso
									game.Debris:AddItem(RedFX2425,5)
									RedFX2425:Play()
									local Speedenemy, Jumpenemy = self.Knit.GetService("MovementService"):CreateSpeed(Enemy, 0), self.Knit.GetService("MovementService"):CreateJump(Enemy, 0)
									game.Debris:AddItem(Speedenemy,stuntime)
									game.Debris:AddItem(Jumpenemy,stuntime)
									--self.Knit.GetService("AnimationService"):playAnimation(Enemy, game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)],1,nil,0)
									if AutoRotate ~= nil then
										AutoRotate:Destroy()
									end
									if Cant ~= nil then
										Cant:Destroy()
									end
									if Speed ~= nil then
										Speed:Destroy()
									end
									if Jump ~= nil then
										Jump:Destroy()
										end
										local isClose = (Enemy.HumanoidRootPart.Position-self.Character.HumanoidRootPart.Position).magnitude <= self.Settings.magnitudeForClose
									local tweentime = .3
									local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 0), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
									--self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "M1", "MISERABLEFATETWEEN", self.Character, Enemy, tweentime)	
									local IFrames = self.Knit.GetService("StateService"):CreateULTIFrames(self.Character)
									local AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
									local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
										local Stunned = self.Knit.GetService("StateService"):CreateStun(Enemy)
										local timefor4s = .1
										coroutine.resume(coroutine.create(function()
											for i = 0.1, 0.7, 0.1 do
												if i < 0.7 then
													local originallookvector1 = self.Character.HumanoidRootPart.CFrame.LookVector
													local pos = (self.Character.HumanoidRootPart.CFrame:Lerp(VictimRootPart.CFrame, timefor4s)).Position
													game:GetService("TweenService"):Create(self.Character.HumanoidRootPart, TweenInfo.new(.005), { CFrame = CFrame.new(pos, pos + originallookvector1)}):Play();
												--end
												--if i ~= 0.7 then
													timefor4s += .1
													wait(.005)
												end
											end
										self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Special.Hit)

											if Enemy ~= nil then
if isClose == true then
												self.Knit.GetService("DamageService"):Damage({

													Character = self.Character,
													Enemy = Enemy,

													KnockbackData = isClose and {
														KnockbackType = "ShortKnockback",
														--MaxForce = Vector3.new(100000,0,100000),
														VelocityOrigin = self.Character.HumanoidRootPart, 
														Velocity = 17, 
														VelocityUp = 1, 
														--Time = .25,
													} ,

													--RagdollData = isClose and {
													--	Time = 1,
													--},
													StateData = {
														Stunned = 1,
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
														Time = 1,
													},

													BlockData = {			
														HitterOrigin = self.Character.HumanoidRootPart.CFrame,
													},

													Damage = self.Settings.Damage,
													EnemyFacesCharacter = true,
												},function(State)		
													if State == "Hit" then
														self.Hit = true
														local bdposicionado2 = Instance.new("BodyPosition",self.Character.HumanoidRootPart)
														bdposicionado2.MaxForce = Vector3.new(math.huge,0,math.huge)
														bdposicionado2.Position = Enemy.HumanoidRootPart.Position
														game.Debris:AddItem(bdposicionado2,.15)
													end
													end)
													else
											self.Knit.GetService("DamageService"):Damage({

												Character = self.Character,
												Enemy = Enemy,

												KnockbackData = {
													KnockbackType = "Velocity",
													MaxForce = Vector3.new(20000,0,20000),
													Velocity = self.Character.HumanoidRootPart.CFrame.LookVector*(20), 
													Time = .25,
												},

												StateData = {
													Stunned = stuntime,
													--AutoRotate = 1,
												},

												MovementData = {
													WalkSpeed = 0,
													JumpPower = 0,
													Time = stuntime,
												},

												--RagdollData = {
												--	Time = stuntime,
												--},
												BlockData = {
													HitterOrigin = self.Character.HumanoidRootPart.CFrame,
												},

												EnemyFacesCharacter = true,

												Damage = 2,

												ReactionAnim = (game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,4)]),

											},function(State)		
												if State == "Hit" then
												end
											end)
												end
											self.Knit.GetService("CombatService"):FireAllClients(self.Character, 25, "Scarlet Empress", "M1", "DASHM1VFX", self.Character, self.Character)	
												self.Knit.GetService("CombatService"):FireAllClients(self.Character, 15, "Scarlet Empress", "M1", "LASTM1HIGHLIGHT", self.Character, self.Character)	
												self.Knit.GetService("CombatService"):FireAllClients(self.Character, 25, "Scarlet Empress", "M1", "HitNOSFX", self.Character, Enemy, math.random(1,4))
												self.Knit.GetService("CombatService"):FireAllClients(self.Character, 25, "Gungnir", "M1", "HitPunch1", self.Character, Enemy, math.random(1,2))
	end
										if AutoRotate ~= nil then
											AutoRotate:Destroy()
										end		
										if Cant ~= nil then
											Cant:Destroy()
										end
										task.delay(stuntime/1.5,function()
											if Stunned ~= nil then
												Stunned:Destroy()
											end
										end)
										if IFrames ~= nil then
											IFrames:Destroy()
										end
										if Speed ~= nil then
											Speed:Destroy()
										end
										if Jump ~= nil then
											Jump:Destroy()
										end
									end))
								end
							end
						end
					end)
				end)
			end
			task.delay(.1,function()
				self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Special.Release)
			end)
			game:GetService("TweenService"):Create(ChainPortal, TweenInfo.new(1), { Size = Vector3.new(0,0,0),Transparency = 1}):Play();
			game.Debris:AddItem(ChainPortal,1)
			game.Debris:AddItem(cadeafolderfornewplayerverdaderomano,2)
				self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Scarlet Empress", "M1", "CHAINDESTROY", self.Character,cadeafolderfornewplayerverdaderomano)

			for _,v in pairs(cadeafolderfornewplayerverdaderomano:GetChildren()) do
				coroutine.resume(coroutine.create(function()
					local origin = v
					--clone.Ice:Play()
					v.CanTouch = false
					v.CanQuery = false
					v.CanCollide = false
					--coroutine.resume(coroutine.create(function()
					--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, "Scarlet Empress", "M1", "CHAINDESTROY", self.Character,origin)
					--end))
				end))
			end
		end
end
	end
	self:listenForCancel(function()	
		self.Cancelled = true 
		coroutine.resume(coroutine.create(function()
			explode(nil)
		end))
		if AutoRotate ~= nil then
			AutoRotate:Destroy()
		end
		task.delay(1,function()
			if Emerald ~= nil then
				Emerald:Destroy()
			end
			if ChainPortal ~= nil then
				ChainPortal:Destroy()
			end
			if AutoRotate ~= nil then
				AutoRotate:Destroy()
			end
		end)
		task.delay(.5,function()
			coroutine.resume(coroutine.create(function()
				explode(nil)
			end))
			if AutoRotate ~= nil then
				AutoRotate:Destroy()
			end
		end)
		if Cant ~= nil then
			Cant:Destroy()
		end
		if Jump ~= nil then
			Jump:Destroy()
		end
		if Speed ~= nil then
			Speed:Destroy()
		end
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Scarlet Empress"].Special.Release)
		--self:Destroy()
	end)
	wait(18/60)
	if exploded == true then return end
	if self.Cancelled then return end
	AutoRotate = self.Knit.GetService("StateService"):CreateAutoRotate(self.Character)
	local pos = GetLocalCharPosition:InvokeClient(game.Players:GetPlayerFromCharacter(self.Character))

	Emerald = game.ServerStorage.ReplicatedAssets123.Models.ChainSpike:Clone()
	Emerald.Parent = cadeafolderfornewplayerverdaderomano
	local m = GetMouseHit:InvokeClient(game.Players:GetPlayerFromCharacter(self.Character))
	Emerald.CFrame = pos * CFrame.new(-.6,.5,-3.7)
	Emerald.chainLoop:Play()
	local originallookvector = Emerald.CFrame.LookVector
	ChainPortal = game.ServerStorage.ReplicatedAssets123.Models.ChainPortal:Clone()
	ChainPortal.Size = Vector3.new(0,0,0)
	ChainPortal.Transparency = 1
	ChainPortal.Parent = cadeafolderfornewplayerverdaderomano
	ChainPortal.CFrame = Emerald.CFrame * CFrame.new(0,0,1)
	game:GetService("TweenService"):Create(ChainPortal, TweenInfo.new(.15), { Size = game.ServerStorage.ReplicatedAssets123.Models.ChainPortal.Size,Transparency = .2}):Play();
	--Emerald:SetNetworkOwner(nil)
	connection2 = Emerald.Hitbox.Touched:Connect(function(part)
		if not part:IsDescendantOf(self.Character) then
			if not part:IsDescendantOf(workspace.Ignore.Effects) then
				if not part:IsDescendantOf(workspace.Ignore.Rocks) then
					if part.CanCollide == false then return end
					explode(part)
				end
			end
		end
	end)
	local function advance()
		coroutine.resume(coroutine.create(function()
		for _ = 1, 5 do
			if exploded == false then
				coroutine.resume(coroutine.create(function()
					--Emerald.CFrame = CFrame.new(Emerald.Position, m.Position)
					Emerald.Hitbox.CFrame = Emerald.CFrame

					Emerald.CFrame = Emerald.CFrame * CFrame.new(0,0,-1.6)
					--Emerald.CFrame = CFrame.new(Emerald.Position, Emerald.Position + originallookvector)
					Emerald.Hitbox.Anchored = false
					Emerald.Hitbox.CFrame = Emerald.CFrame
					task.delay(.0008,function()
						Emerald.Hitbox.CFrame = Emerald.CFrame
						Emerald.Hitbox.Anchored = true
					end)
					Emerald.Hitbox.CFrame = Emerald.CFrame

					local Emerald2 = game.ServerStorage.ReplicatedAssets123.Models.ChainLink:Clone()
					Emerald2.Parent = cadeafolderfornewplayerverdaderomano
					Emerald2.CFrame = Emerald.CFrame * CFrame.new(0,0,1.6)
					--Emerald2.CFrame = CFrame.new((Emerald.CFrame * CFrame.new(0,0,1.6)).Position, (Emerald.CFrame * CFrame.new(0,0,1.6)).Position + originallookvector)
					--if ((Emerald.Position - m.Position).Magnitude <= 3) then
					--	if exploded == false then
					--		explode(nil)
					--	end
					--end
				end))
			end
		end
end))
	end
	task.delay(1,function()
		if exploded == false then
			explode(nil)
		end
	end)
	advance()
	coroutine.resume(coroutine.create(function()
		while wait() do
			if exploded == false then
				coroutine.resume(coroutine.create(function()
					advance()
				end))
			else
				break
			end
		end
	end))
end

return Special
