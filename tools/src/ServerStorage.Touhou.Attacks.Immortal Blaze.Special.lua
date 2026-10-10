local Special = {}
Special.Settings = {
	Cooldown = 3,
	--Damage = .6,--same damage as saitama consecutive punches (really op)
	Damage = 3,
	AttackLength = 44/60,

	HitboxSettings = {
		DelayTime = 0,
		Debris = .2,

		Offset = CFrame.new(0,0,-4.5),
		Size = Vector3.new(10,15,23)
	},
	HitboxSettings2 = {
		DelayTime = 0,
		Debris = .1,

		Offset = CFrame.new(0,0,0),
		Size = Vector3.new(30, 30, 30)
	},
}
local ResourceFolder = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"]
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
local GetLocalCharPosition = require(game.ServerStorage.Touhou.Bridge).GetLocalCharPosition

function Special:TagEnemy(Enemy)
	if Enemy:GetAttribute("Blocking") then		
		return end
	if Enemy:FindFirstChild("BURNCD") then return end
	local buffvalue = Instance.new("BoolValue",Enemy)
	buffvalue.Value = true
	buffvalue.Name = ("BURNCD")
	game.Debris:AddItem(buffvalue,3)
	local function burn()
		if Enemy:FindFirstChild("Burning") then return end
		local buffvalue = Instance.new("BoolValue",Enemy)
		buffvalue.Value = true
		buffvalue.Name = ("Burning")
		game.Debris:AddItem(buffvalue,10)
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 300, "Immortal Blaze", "M1", "BURNING1", Enemy)	
	end
	--if Enemy:GetAttribute("Ragdoll") then
	local burninglol = false
	if Enemy:FindFirstChild("Burning") then
		burninglol = true
	else
		if Enemy:GetAttribute("Ragdoll") then
			self.Knit.GetService("RagdollService"):unragdoll(Enemy, true,true)
		end
	end
	self.Knit.GetService("DamageService"):Damage({

		Character = self.Character,
		Enemy = Enemy,


		--RagdollData = isClose and {
		--	Time = 1,
		--},
		StateData = {
			Stunned = (burninglol == false) and .4 or .6,
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
			Time = (burninglol == false) and .4 or .6,
		},

		BlockData = {			
			HitterOrigin = self.Character.HumanoidRootPart.CFrame,
		},

		Damage = 2,
	},function(State)		
		if State == "Hit" then
			self.Hit = true
			burn()
		elseif State == "Block" then
		end
		end)
end
function Special:CreateHitbox2(callback)
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
function Special:Explosion(ProjectilePart,attacking,destroy,instantdestroy,hitpart,finisher,cfran)
	coroutine.resume(coroutine.create(function()
		--if self.Finisher ~= true then
		--	coroutine.resume(coroutine.create(function()
		--		if attacking == true then
		--				if destroy == true then
		--self.Knit.GetService("CombatService"):FireAllClients(self.Character, 450, "Scarlet Empress", "M1", "AIMEDEXPL2", ProjectilePart)
		--game:GetService("TweenService"):Create(ProjectilePart.gungnirloop,TweenInfo.new(.35,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Volume = 0}):Play()
		--if not finisher then
		--coroutine.resume(coroutine.create(function()
		--	self.Knit.GetService("CombatService"):FireAllClients(self.Character, 250, script.Parent.Name, "M1", "heartbreakland", self.Character, ProjectilePart.heartbreak,hitpart)
		--end))
		local originallookvector1 = self.Character.HumanoidRootPart.CFrame.LookVector
		local ogcframe = self.Character.HumanoidRootPart.CFrame
		local ogcframerotation = self.Character.HumanoidRootPart.CFrame.Rotation
		local ogpos = self.Character.HumanoidRootPart.Position
		local MaxRange = 200
		--local GoalPosition = (ProjectilePart * CFrame.new(0,0,-MaxRange)).Position
		local goalpos2 = originallookvector1 * MaxRange
		local goalpos3 = (ProjectilePart * CFrame.new(0,0,-MaxRange)).Position
		--local Direction = (GoalPosition - self.Character.HumanoidRootPart.Position).Unit
		--local Distance = (GoalPosition - self.Character.HumanoidRootPart.Position).Magnitude
		--local TargetPos = self.Character.HumanoidRootPart.Position + Direction * MaxRange 

		--if Distance > MaxRange then
		--	TargetPos =  self.Character.HumanoidRootPart.Position + Direction * MaxRange 
		--else
		--	TargetPos = GoalPosition
		--end
		--local DetectedFloor = RayCastOnMap(TargetPos,Vector3.new(0,-TargetPos*2,0),{workspace.Ignore})
		--if DetectedFloor then
		--	if TargetPos ~= DetectedFloor then
		--		TargetPos = DetectedFloor + Vector3.new(0,2,0)
		--	end
		--else
		--	TargetPos = GoalPosition
		--end
		local ray = Ray.new(ogpos, goalpos2)
		local part, hitPosition = workspace:FindPartOnRay(ray, workspace.Ignore)
		local chosen = nil
		if part then 
			chosen = CFrame.new(hitPosition)
		else
			chosen = CFrame.new(goalpos3)
		end
		--self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Scarlet Empress", "M1", "KNOCKBACKRELATIVETO",self.Character,chosen)	
		self.Knit.GetService("CombatService"):FireAllClients(self.Character, 370, "Immortal Blaze", "M1", "HEARTBREAKLOOPVFX2", chosen,self.Character,ogcframe)	
		local speedlol = 100
		local time15 = ((self.Character.HumanoidRootPart.Position - chosen.Position).magnitude) / speedlol
		local timefor4s = .1
		local rootpart521 = Instance.new("Part")
		rootpart521.Parent = workspace.Ignore.Effects
		rootpart521.Anchored = true
		rootpart521.Size = self.Character.HumanoidRootPart.Size
		rootpart521.CFrame = chosen * ogcframerotation
		rootpart521.CanCollide = false
		rootpart521.Transparency = 1
		rootpart521.Name = ("DECOYETR")
		game.Debris:AddItem(rootpart521,5)
		local doingthat = true
		local val = 150
		local time152 = ((self.Character.HumanoidRootPart.Position - chosen.Position).magnitude) / speedlol
		local MaxRange64 = 0
		coroutine.resume(coroutine.create(function()
			--for i = (time15/10), time15, (time15/10) do
			--	if i < time15 then
			while doingthat == true do
				--local pos = (ogcframe:Lerp(ogcframe, chosen)).Position
				--timefor4s += .1
				--local GoalPosition = (ProjectilePart * CFrame.new(0,0,-MaxRange)).Position
				local goalpos215 = originallookvector1 * MaxRange64
				local goalpos3124 = (ProjectilePart * CFrame.new(0,0,-MaxRange64)).Position
				--local Direction = (GoalPosition - self.Character.HumanoidRootPart.Position).Unit
				--local Distance = (GoalPosition - self.Character.HumanoidRootPart.Position).Magnitude
				--local TargetPos = self.Character.HumanoidRootPart.Position + Direction * MaxRange 

				--if Distance > MaxRange then
				--	TargetPos =  self.Character.HumanoidRootPart.Position + Direction * MaxRange 
				--else
				--	TargetPos = GoalPosition
				--end
				--local DetectedFloor = RayCastOnMap(TargetPos,Vector3.new(0,-TargetPos*2,0),{workspace.Ignore})
				--if DetectedFloor then
				--	if TargetPos ~= DetectedFloor then
				--		TargetPos = DetectedFloor + Vector3.new(0,2,0)
				--	end
				--else
				--	TargetPos = GoalPosition
				--end
				local ray26 = Ray.new(ogpos, goalpos215)
				local part51, hitPositio52n = workspace:FindPartOnRay(ray26, workspace.Ignore)
				local chosen51 = nil
				if part51 then 
					chosen51 = CFrame.new(hitPositio52n)
				else
					chosen51 = CFrame.new(goalpos3124)
				end
				local rootpart5221 = Instance.new("Part")
				rootpart5221.Parent = workspace.Ignore.Effects
				rootpart5221.Anchored = true
				rootpart5221.Size = self.Character.HumanoidRootPart.Size
				rootpart5221.CFrame = chosen51 * ogcframerotation
				rootpart5221.CanCollide = false
				rootpart5221.Transparency = 1
				rootpart5221.Name = ("DECOYETR")
				game.Debris:AddItem(rootpart5221,1)
				self.Knit.GetService("HitboxService"):createHitbox({
					Caster = self.Character,
					Origin = rootpart5221,
					Offset = CFrame.new(0,0,0),
					Size = Vector3.new(10,5,10),
					HitboxType = "Box",
					HitType = "OneHit",
					IgnoresRagdoll = true,
					IgnoresIFrames = true,
					IgnoresBlock = false,
					DelayTime = 0,
					Debris = .15,
					--ReactionAnim = game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,3)],
				}, function(Enemy)
					self:TagEnemy(Enemy,rootpart5221)
				end)
				wait(.05)
				MaxRange64 += 10
			end
			--wait(.005)
			--end
			--end
		end))
		wait(time15)
doingthat = false
		local rootpart51 = Instance.new("Part")
		rootpart51.Parent = workspace.Ignore.Effects
		rootpart51.Anchored = true
		rootpart51.Size = self.Character.HumanoidRootPart.Size
		rootpart51.CFrame = chosen
		rootpart51.CanCollide = false
		rootpart51.Transparency = 1
		rootpart51.Name = ("DECOYETR")
		game.Debris:AddItem(rootpart51,1)
		self.Knit.GetService("HitboxService"):createHitbox({
			Caster = self.Character,
			Origin = rootpart51,
			Offset = CFrame.new(0,0,0),
			Size = Vector3.new(10,10,12),
			HitboxType = "Box",
			HitType = "OneHit",
			IgnoresRagdoll = true,
			IgnoresIFrames = true,
			IgnoresBlock = false,
			DelayTime = 0,
			Debris = .15,
			ReactionAnim = game.ReplicatedStorage.Assets.Animations.Reactions["Reaction"..math.random(1,3)],
		}, function(Enemy)
			self:TagEnemy(Enemy,rootpart51)
		end)
		--for i,v in pairs(ProjectilePart:GetDescendants()) do
		--	if v:IsA('Trail') then
		--		v.Enabled = false
		--	end
		--	if v:IsA('ParticleEmitter') then
		--		v.Enabled = false
		--	end
		--end
		--local timer = 5 
		--if instantdestroy == true then
		--	timer = 0 
		--else
		--	local RedFX=game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.HitHeartBreak:Clone()	
		--	RedFX.Parent = workspace.Ignore.Effects
		--	RedFX.CFrame = ProjectilePart.CFrame
		--	RedFX.VFX["h"..math.random(1,5)]:Play()
		--	game.Debris:AddItem(RedFX,4)
		--end
		--ProjectilePart.heartbreak.Flare12emit.Enabled = false
		--ProjectilePart.heartbreak.Flare13emit.Enabled = false
		--ProjectilePart["6"].Enabled = false
		--ProjectilePart.Other.Shards.Enabled = false
		--ProjectilePart.Anchored = true
		--if not finisher then
		--game.Debris:AddItem(ProjectilePart,5)
		--							game:GetService("TweenService"):Create(ProjectilePart,TweenInfo.new(.8,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
		--							for i,v in pairs(ProjectilePart:GetDescendants()) do
		--								if v:IsA('ParticleEmitter') then
		--									v.Enabled = false
		--								end
		--								if v:IsA('BasePart') then
		--								game:GetService("TweenService"):Create(v,TweenInfo.new(.8,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut),{Transparency = 1}):Play()
		--								end
		--								if v:IsA('Decal') then
		--									v.Transparency = 1
		--								end
		--								if v:IsA('Trail') then
		--									v.Enabled = false
		--									v.Lifetime = .3
		--								end
		--								if v:IsA('Beam') then
		--									game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width0 = 0}):Play()
		--									game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Width1 = 0}):Play()
		--								end
		--								if v:IsA('PointLight') then
		--									game:GetService("TweenService"):Create(v,TweenInfo.new(.5,Enum.EasingStyle.Back,Enum.EasingDirection.InOut),{Range = 0}):Play()
		--								end
		--							end
		--					end
		--end
		--end
		--end))
		--end
	end))
end
function Special:Release(InAir)
	if self.Character:FindFirstChild("featherchargelevel") then
		local chargelevel = self.Character:FindFirstChild("featherchargelevel")
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit1"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit2"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit3"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Hit4"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Uppercut"])
		self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Combats[self.Character:GetAttribute("Combat")]["Downslam"])
		self.Knit.GetService("BodymoverService"):DestroyBodymovers(self.Character)
		if chargelevel.Value == 0 then		
			self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Specialnew.ReleaseTa)
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 110, "Immortal Blaze", "M1", "FEATHERVFXTA", self.Character, self.Character)	
			local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
			local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 15), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
			task.delay(28/60,function()
				if self.Cancelled then return end
				if Cant ~= nil then
					Cant:Destroy()
				end
				if Jump ~= nil then
					Jump:Destroy()
				end
				if Speed ~= nil then
					Speed:Destroy()
				end	
			end)
			task.delay(11/60,function()
				if self.Character.Humanoid.Health > 25 then
					if chargelevel.Value == 0 then
						self.Character.Humanoid.Health -= 25
						chargelevel.Value = 3
					end
				end
			end)
			--self.Knit.GetService("StateService"):AddStates(self.Character, {"IFrames"}, self.Settings.AttackLength)
			self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Special", self.Settings.Cooldown)
			self.Cancelled = false
			local attacking = true
			local RedFX251
			local RedFX2514
			self:listenForCancel(function()
				self.Cancelled = true
				attacking = false
				if Jump ~= nil then
					Jump:Destroy()
				end
				if Speed ~= nil then
					Speed:Destroy()
				end	
				self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Specialnew.ReleaseTa)
				if Cant ~= nil then
					Cant:Destroy()
				end
				--self.Knit.GetService("StateService"):RemoveStates(self.Character, {"IFrames"})
				self:Destroy()
			end)
		elseif chargelevel.Value > 0 then		
			self.Knit.GetService("AnimationService"):playAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Specialnew.Release)
			self.Knit.GetService("CombatService"):FireAllClients(self.Character, 110, "Immortal Blaze", "M1", "FEATHERVFX", self.Character, self.Character)	
			local Cant = self.Knit.GetService("StateService"):CreateCant(self.Character)
			local Speed, Jump = self.Knit.GetService("MovementService"):CreateSpeed(self.Character, 15), self.Knit.GetService("MovementService"):CreateJump(self.Character, 0)
			self.Knit.GetService("CombatService"):FireClient(self.Character, self.Character, "Immortal Blaze", "Skill3Drill", "LOLDASH2525", self.Character, self.Character)	
			task.delay(self.Settings.AttackLength,function()
				if self.Cancelled then return end
				if Cant ~= nil then
					Cant:Destroy()
				end
				if Jump ~= nil then
					Jump:Destroy()
				end
				if Speed ~= nil then
					Speed:Destroy()
				end	
			end)
			task.delay(23/60,function()
				self:Explosion(self.Character.HumanoidRootPart.CFrame,true,true,true)
				self:CreateHitbox(function(Enemy)
					self:TagEnemy(Enemy)
				end)
			end)
			if chargelevel.Value == 3 then
				chargelevel.Value = 2
			elseif chargelevel.Value == 2 then
				chargelevel.Value = 1
			elseif chargelevel.Value == 1 then
				chargelevel.Value = 0
			end
			--self.Knit.GetService("StateService"):AddStates(self.Character, {"IFrames"}, self.Settings.AttackLength)
			self.Knit.GetService("CooldownService"):createCooldown(self.Character, "Special", self.Settings.Cooldown)
			self.Cancelled = false
			local attacking = true
			local RedFX251
			local RedFX2514
			self:listenForCancel(function()
				self.Cancelled = true
				attacking = false
				if Jump ~= nil then
					Jump:Destroy()
				end
				if Speed ~= nil then
					Speed:Destroy()
				end	
				self.Knit.GetService("AnimationService"):stopAnimation(self.Character, game.ReplicatedStorage.Assets.Animations.Characters["Immortal Blaze"].Specialnew.Release)
				if Cant ~= nil then
					Cant:Destroy()
				end
				--self.Knit.GetService("StateService"):RemoveStates(self.Character, {"IFrames"})
				self:Destroy()
			end)
		end
	end
end

return Special
