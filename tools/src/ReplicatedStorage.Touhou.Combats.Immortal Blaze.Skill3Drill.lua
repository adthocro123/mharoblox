local Debris = game:GetService("Debris")
local Camera = workspace.CurrentCamera
local CameraShaker=require(game.ReplicatedStorage.Modules.Util.shaker)
local TS = game:GetService("TweenService")
local FXFolder = workspace.Ignore.Effects
local Basemd = require(game.ReplicatedStorage.Modules.Util.baseassets)
local Tween = game:GetService("TweenService")
local RockModule = require(game.ReplicatedStorage.Modules.Util.RockScript)
local RunService = game:GetService("RunService")
local md = require(game.ReplicatedStorage.Modules.Util.baseassets)
local ResourceFolder2 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat

function quadBezier(t, p0, p1, p2)
	local l1 = p0:Lerp(p1, t)
	local l2 = p1:Lerp(p2, t)
	local quad = l1:Lerp(l2, t)
	return quad
end
function lerp(p0,p1,t)
	return p0*(1-t) + p1*t
end
function quad(p0,p1,p2,t)
	local l1 = lerp(p0,p1,t)
	local l2 = lerp(p1,p2,t)
	local quad = lerp(l1,l2,t)

	return quad	
end
local Blacklist2 = OverlapParams.new()

Blacklist2.FilterDescendantsInstances = {script.Parent,workspace.Terrain,workspace.Ignore.Effects,workspace.Ignore.Entities}

Blacklist2.FilterType = Enum.RaycastFilterType.Exclude

local Blacklist = RaycastParams.new()

Blacklist.FilterDescendantsInstances = {script.Parent,workspace.Terrain,workspace.Ignore.Effects,workspace.Ignore.Entities}

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

local Rayc = function(Hrp : BasePart)
	local ray = workspace:Raycast(Hrp.Position,Hrp.Velocity.Unit*10,Blacklist)

	if ray then
		return true
	end
	return false
end
local dashtime = .2
return {
	['Dash2fifties'] = function(Character)
		local hrp = Character.HumanoidRootPart
		coroutine.resume(coroutine.create(function()
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(24000,0,24000)

			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			lv.VectorVelocity = Vector3.new(0,0,-150)
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,0)})

			Tween:Play()

			local Hit = false

			local HitRay = false

			local Time = 0

			repeat
				local dt = .0325

				--Hit = SimpleHitbox(hrp.CFrame)
				--HitRay = Rayc(hrp)
				wait(dt)
				Time += dt
			until
			Time >= ((80/60) - (48/60)) or not Character.Values:FindFirstChild("Cant") or Character.HumanoidRootPart:FindFirstChild("GrabWeld")  or Character.Values:FindFirstChild("Stunned")
			Tween:Pause()
			Tween:Destroy()
			lv:Destroy()
			--if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then
			--	Tween:Pause()
			--	Tween:Destroy()
			--	lv:Destroy()
			--end
			repeat wait() until not Character.HumanoidRootPart:FindFirstChild("GrabWeld")
			repeat wait() until not Character.Values:FindFirstChild("Cant") 
		end))
	end,
	['Drill'] = function(Character)
		local hrp = Character.HumanoidRootPart
		local lv = Instance.new("LinearVelocity")
		lv.Name = "Dashing"
		lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		lv.MaxAxesForce = Vector3.new(300000,300000,300000)

		lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
		lv.Parent = hrp
		lv.VectorVelocity = Vector3.new(0,60,-60)
		local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(.7, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,0)})

		Tween:Play()

		local Hit = false

		local HitRay = false

		local Time = 0

		repeat
			local dt = .0325

			Hit = SimpleHitbox(hrp.CFrame)
			HitRay = Rayc(hrp)
			wait(dt)
			Time += dt
		until Hit or HitRay or Time >= ((60/60) - (22/60))

		Tween:Cancel()

		lv:Destroy()
	end,
	['Right'] = function(Character)
		local hrp = Character.HumanoidRootPart
		coroutine.resume(coroutine.create(function()
			local effectfirst = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].FireTalonRightSlash
			for i,v in pairs(effectfirst:GetChildren()) do
				local effect = v:Clone()
				effect.Parent = Character['Right Arm']
				game.Debris:AddItem(effect,6)
				for i,ve in pairs(effect:GetDescendants()) do
					if ve:IsA('ParticleEmitter') then
						ve:Emit(ve:GetAttribute('EmitCount') or 1)
					end
				end
			end
			if Character["Right Arm"]:FindFirstChild("RCkar1") then
				Character["Right Arm"]:FindFirstChild("RCkar1").sfx2:Play()
				Character["Right Arm"]:FindFirstChild("RCkar1")["s"..math.random(1,4)]:Play()
				Character["Right Arm"]:FindFirstChild("RCkar1")["swing"..math.random(1,3)]:Play()
			end
			Character["Right Arm"]:FindFirstChild("RCkar1").Name = ("DeepwokenGaming52")
		end))
	end,
	['Left'] = function(Character)
		local hrp = Character.HumanoidRootPart
		coroutine.resume(coroutine.create(function()
			local effectfirst = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].FireTalonLeftSlash
			for i,v in pairs(effectfirst:GetChildren()) do
				local effect = v:Clone()
				effect.Parent = Character['Left Arm']
				game.Debris:AddItem(effect,6)
				for i,ve in pairs(effect:GetDescendants()) do
					if ve:IsA('ParticleEmitter') then
						ve:Emit(ve:GetAttribute('EmitCount') or 1)
					end
				end
			end
			if Character["Left Arm"]:FindFirstChild("LCkar1") then
				Character["Left Arm"]:FindFirstChild("LCkar1").sfx2:Play()
				Character["Left Arm"]:FindFirstChild("LCkar1")["s"..math.random(1,4)]:Play()
				Character["Left Arm"]:FindFirstChild("LCkar1")["swing"..math.random(1,3)]:Play()
			end
			Character["Left Arm"]:FindFirstChild("LCkar1").Name = ("DeepwokenGaming52")
		end))
	end,
	['Wind'] = function(Character)
		local hrp = Character.HumanoidRootPart
		coroutine.resume(coroutine.create(function()
			local effectfirst = game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].FireTalonWind
			for i,v in pairs(effectfirst:GetChildren()) do
				local effect = v:Clone()
				effect.Parent = hrp
				game.Debris:AddItem(effect,6)
				for i,ve in pairs(effect:GetDescendants()) do
					if ve:IsA('ParticleEmitter') then
						ve:Emit(ve:GetAttribute('EmitCount') or 1)
					end
				end
			end
			if hrp:FindFirstChild("Wind Front") then
				hrp:FindFirstChild("Wind Front").dash:Play()
			end
			hrp:FindFirstChild("Wind Front").Name = ("DeepwokenGaming48")
		end))
	end,
	["LOLDASH2525"] = function(Character)
		local hrp = Character.HumanoidRootPart
		game:GetService("TweenService"):Create(workspace.CurrentCamera,TweenInfo.new(23/60, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),{FieldOfView = 95}):Play()
		task.delay(24/60,function()
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(9000,0,9000)
			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			lv.VectorVelocity = Vector3.new(0,0,45)
			game.Debris:AddItem(lv,10/60)
			game:GetService("TweenService"):Create(workspace.CurrentCamera,TweenInfo.new(10/60, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),{FieldOfView = 70}):Play()
		end)
	end,
	["LOLDASH252"] = function(Character)
		local hrp = Character.HumanoidRootPart
		local lv = Instance.new("LinearVelocity")
		lv.Name = "Dashing"
		lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		lv.MaxAxesForce = Vector3.new(24000,0,24000)
		lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
		lv.Parent = hrp
		lv.VectorVelocity = Vector3.new(0,0,0)
		game.Debris:AddItem(lv,50/60)
		game:GetService("TweenService"):Create(lv,TweenInfo.new(25/60, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,-5)}):Play()
		task.delay(25/60,function()
			game:GetService("TweenService"):Create(lv,TweenInfo.new(25/60, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,3)}):Play()
		end)
	end,
	
	["LOLDASH"] = function(Character)
		local hrp = Character.HumanoidRootPart
		local lv = Instance.new("LinearVelocity")
		lv.Name = "Dashing"
		lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		lv.MaxAxesForce = Vector3.new(20000,0,20000)
		lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
		lv.Parent = hrp
		lv.VectorVelocity = Vector3.new(0,0,0)
		game.Debris:AddItem(lv,50/60)
		game:GetService("TweenService"):Create(lv,TweenInfo.new(25/60, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,5)}):Play()
		task.delay(25/60,function()
			game:GetService("TweenService"):Create(lv,TweenInfo.new(25/60, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,-5)}):Play()
		end)
	end,
	["LOLDASH21452"] = function(Character)
		local hrp = Character.HumanoidRootPart
		local lv = Instance.new("LinearVelocity")
		lv.Name = "Dashing"
		lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		lv.MaxAxesForce = Vector3.new(20000,0,20000)
		lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
		lv.Parent = hrp
		lv.VectorVelocity = Vector3.new(-20,0,15)
		game.Debris:AddItem(lv,30/60)
		game:GetService("TweenService"):Create(lv,TweenInfo.new(20/60, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,0)}):Play()
	end,
	["LOLDASH2"] = function(Character)
		local hrp = Character.HumanoidRootPart
		local lv = Instance.new("LinearVelocity")
		lv.Name = "Dashing"
		lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		lv.MaxAxesForce = Vector3.new(24000,0,24000)
		lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
		lv.Parent = hrp
		lv.VectorVelocity = Vector3.new(0,0,0)
		game.Debris:AddItem(lv,60/60)
		game:GetService("TweenService"):Create(lv,TweenInfo.new(25/60, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,30)}):Play()
		task.delay(35/60,function()
			game:GetService("TweenService"):Create(lv,TweenInfo.new(35/60, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,0)}):Play()
		end)
	end,
	['Dash252'] = function(Character)
		local hrp = Character.HumanoidRootPart
		coroutine.resume(coroutine.create(function()
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(24000,0,24000)

			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			lv.VectorVelocity = Vector3.new(0,0,-50)
			local originalfov = workspace.CurrentCamera.FieldOfView
			game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(30/60, Enum.EasingStyle.Linear, Enum.EasingDirection.In,0,false), {FieldOfView = 90}):Play()
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(30/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,-40)})
			task.delay(30/60,function()
				game:GetService("TweenService"):Create(lv,TweenInfo.new(60/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,0)}):Play()
				game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(60/60, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut,0,false), {FieldOfView = originalfov}):Play()
			end)
			local velocity = Instance.new('BodyVelocity')
			velocity.MaxForce = Vector3.new(0,3000,0)
			velocity.Velocity = Character.HumanoidRootPart.CFrame.UpVector * 4
			velocity.Parent = Character.HumanoidRootPart
			game:GetService("TweenService"):Create(velocity,TweenInfo.new(35/60, Enum.EasingStyle.Linear, Enum.EasingDirection.In),{MaxForce = Vector3.new(0,0,0)}):Play()
			local time115 = 110/60
			game.Debris:AddItem(velocity,time115)
			local conn1
			task.delay(time115,function()
				conn1:Disconnect()
			end)
			conn1 = Character:GetAttributeChangedSignal("Cancel"):Connect(function()
				conn1:Disconnect()
				velocity:Destroy()
			end)
			Tween:Play()

			local Hit = false

			local HitRay = false

			local Time = 0

			repeat
				local dt = .0325

				--Hit = SimpleHitbox(hrp.CFrame)
				--HitRay = Rayc(hrp)
				wait(dt)
				Time += dt
			until
			Time >= ((164/60) - (102/60)) or not Character.Values:FindFirstChild("Cant") or Character.HumanoidRootPart:FindFirstChild("GrabWeld") or Character.Values:FindFirstChild("Stunned")
			local onetwos = lv.VectorVelocity
			Tween:Pause()
			Tween:Destroy()
			lv:Destroy()
		end))
	end,
	['Dash'] = function(Character)
		local hrp = Character.HumanoidRootPart
		coroutine.resume(coroutine.create(function()
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(24000,0,24000)

			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			lv.VectorVelocity = Vector3.new(0,0,-60)
			local originalfov = workspace.CurrentCamera.FieldOfView
			game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(30/60, Enum.EasingStyle.Linear, Enum.EasingDirection.In,0,false), {FieldOfView = 100}):Play()
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(30/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,-45)})
			task.delay(30/60,function()
				game:GetService("TweenService"):Create(lv,TweenInfo.new(60/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,0)}):Play()
				game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(60/60, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut,0,false), {FieldOfView = originalfov}):Play()
			end)
			local velocity = Instance.new('BodyVelocity')
			velocity.MaxForce = Vector3.new(0,3000,0)
			velocity.Velocity = Character.HumanoidRootPart.CFrame.UpVector * 4
			velocity.Parent = Character.HumanoidRootPart
			game:GetService("TweenService"):Create(velocity,TweenInfo.new(35/60, Enum.EasingStyle.Linear, Enum.EasingDirection.In),{MaxForce = Vector3.new(0,0,0)}):Play()
			local time115 = 110/60
			game.Debris:AddItem(velocity,time115)
			local conn1
			task.delay(time115,function()
				conn1:Disconnect()
			end)
			conn1 = Character:GetAttributeChangedSignal("Cancel"):Connect(function()
				conn1:Disconnect()
				velocity:Destroy()
			end)
			Tween:Play()

			local Hit = false

			local HitRay = false

			local Time = 0

			repeat
				local dt = .0325

				--Hit = SimpleHitbox(hrp.CFrame)
				--HitRay = Rayc(hrp)
				wait(dt)
				Time += dt
			until
			Time >= ((120/60) - (51/60)) or not Character.Values:FindFirstChild("Cant") or Character.HumanoidRootPart:FindFirstChild("GrabWeld") or Character.Values:FindFirstChild("Stunned")
			local Tween2
			local onetwos = lv.VectorVelocity

			Tween:Pause()
			Tween:Destroy()
			if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then
				--lv.VectorVelocity = onetwos
				lv.VectorVelocity = Vector3.new(0,0,-60)
				game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(30/60, Enum.EasingStyle.Linear, Enum.EasingDirection.In,0,false), {FieldOfView = 100}):Play()
				task.delay(30/60,function()
					game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(65/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut,0,false), {FieldOfView = originalfov}):Play()
				end)
				Tween2 = game:GetService("TweenService"):Create(lv,TweenInfo.new(95/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,0)})
				Tween2:Play()
			end
			repeat wait() until not Character.HumanoidRootPart:FindFirstChild("GrabWeld")
			if Tween2 ~= nil then
				Tween2:Cancel()
				Tween2:Destroy()
			end
			lv:Destroy()
			repeat wait() until not Character.Values:FindFirstChild("Cant") 
		end))
	end,
	['Dashaz'] = function(Character)
		local hrp = Character.HumanoidRootPart
		coroutine.resume(coroutine.create(function()
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(24000,0,24000)

			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			lv.VectorVelocity = Vector3.new(0,0,-30)
			local originalfov = workspace.CurrentCamera.FieldOfView
			game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(30/60, Enum.EasingStyle.Linear, Enum.EasingDirection.In,0,false), {FieldOfView = 90}):Play()
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(30/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,-45)})
			task.delay(60/60,function()
				game:GetService("TweenService"):Create(lv,TweenInfo.new(90/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,0)}):Play()
				game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(70/60, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut,0,false), {FieldOfView = originalfov}):Play()
			end)
			local velocity = Instance.new('BodyVelocity')
			velocity.MaxForce = Vector3.new(0,3000,0)
			velocity.Velocity = Character.HumanoidRootPart.CFrame.UpVector * 4
			velocity.Parent = Character.HumanoidRootPart
			game:GetService("TweenService"):Create(velocity,TweenInfo.new(35/60, Enum.EasingStyle.Linear, Enum.EasingDirection.In),{MaxForce = Vector3.new(0,0,0)}):Play()
			local time115 = 125/60
			game.Debris:AddItem(velocity,time115)
			local conn1
			task.delay(time115,function()
				conn1:Disconnect()
			end)
			conn1 = Character:GetAttributeChangedSignal("Cancel"):Connect(function()
				conn1:Disconnect()
				velocity:Destroy()
			end)
			Tween:Play()

			local Hit = false

			local HitRay = false

			local Time = 0

			repeat
				local dt = .0325

				--Hit = SimpleHitbox(hrp.CFrame)
				--HitRay = Rayc(hrp)
				wait(dt)
				Time += dt
			until
			Time >= ((125/60) - (51/60)) or not Character.Values:FindFirstChild("Cant") or Character.HumanoidRootPart:FindFirstChild("GrabWeld") or Character.Values:FindFirstChild("Stunned")
			--Tween:Pause()
			--Tween:Destroy()
			--if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then
				lv:Destroy()
			--else
			--	lv.VectorVelocity = Vector3.new(0,0,-40)
			--	game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(30/60, Enum.EasingStyle.Linear, Enum.EasingDirection.In,0,false), {FieldOfView = 100}):Play()
			--	task.delay(30/60,function()
			--		game:GetService("TweenService"):Create(workspace.CurrentCamera, TweenInfo.new(65/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut,0,false), {FieldOfView = originalfov}):Play()
			--	end)
			--	Tween2 = game:GetService("TweenService"):Create(lv,TweenInfo.new(60/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,0)})
			--	Tween2:Play()
			--	game.Debris:AddItem(lv,(70/60))
			--end
			--repeat wait() until not Character.Values:FindFirstChild("Cant") 
		end))
	end,
	['DashUlt'] = function(Character)
		local hrp = Character.HumanoidRootPart
		local hrp = Character.HumanoidRootPart
		local lv = Instance.new("LinearVelocity")
		lv.Name = "Dashing"
		lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		lv.MaxAxesForce = Vector3.new(20000,20000,20000)
		lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
		lv.Parent = hrp
		lv.VectorVelocity = Vector3.new(0,0,0)
		game:GetService("TweenService"):Create(lv,TweenInfo.new(10/60, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,45)}):Play()
		local extratime = 40
		task.delay((extratime-25)/60,function()
			game:GetService("TweenService"):Create(lv,TweenInfo.new(25/60, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,-55)}):Play()
		end)
		wait(extratime/60)
		coroutine.resume(coroutine.create(function()
			--Character.Humanoid.AutoRotate = false

			lv.VectorVelocity = Vector3.new(0,0,-150)
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,-5)})

			Tween:Play()

			local Hit = false

			local HitRay = false

			local Time = 0

			repeat
				local dt = .0325

				--Hit = SimpleHitbox(hrp.CFrame)
				--HitRay = Rayc(hrp)
				wait(dt)
				Time += dt
			until
			Time >= (((90)-(60+extratime))/60) or not Character.Values:FindFirstChild("Cant") --or Character:GetAttribute("Dropkicking")
			if Tween ~= nil then
				Tween:Cancel()
				Tween:Destroy()
			end
			local waittime = .4
			local Tween2 = game:GetService("TweenService"):Create(lv,TweenInfo.new(waittime, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,0)})
			Tween2:Play()
			wait(waittime)
			if Tween2 ~= nil then
				Tween2:Cancel()
				Tween2:Destroy()
			end
			lv:Destroy()
		end))
	end,
	['Dash2'] = function(Character)
		local hrp = Character.HumanoidRootPart
		coroutine.resume(coroutine.create(function()
			Character.Humanoid.AutoRotate = false
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(300000,0,300000)

			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			lv.VectorVelocity = Vector3.new(0,0,-90)
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(.45, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,0)})

			Tween:Play()

			local Hit = false

			local HitRay = false

			local Time = 0
			repeat
				coroutine.resume(coroutine.create(function()
					if hrp:FindFirstChild("GrabWeld") then
						Character.Humanoid.AutoRotate = true
					end
					local dt = .0325
					Hit = SimpleHitbox(hrp.CFrame)
					HitRay = Rayc(hrp)
					wait(dt)
					Time += dt
				end))
				wait()
			until Hit or HitRay or Time >= ((75/60) - (45/60)) or Character.HumanoidRootPart:FindFirstChild("GrabWeld")

			Tween:Cancel()
			Character.Humanoid.AutoRotate = true
			lv:Destroy()
		end))
	end,
	['Dash4'] = function(Character)
		local hrp = Character.HumanoidRootPart
			local Time = 0
			local tim = .3
		local FX= ResourceFolder2.DashTrail:Clone()
			FX.Parent=Character
			FX.w.Part0= Character['Right Arm']
			--FX.sfx:Play()
			Debris:AddItem(FX,4)
		task.delay((42/60) - (20/60),function()
			if FX ~= nil then
			game.Debris:AddItem(FX,2)
				for i ,v in pairs(FX:GetDescendants())do
					if  v:IsA('Trail') then
						v.Enabled = false
					end
				end
			end
		end)

			tim = .6

			md.rockspawn(hrp,.37,.37,tim,.046,Vector3.new(-1.3,0,-1.3),true)

			md.rockspawn(hrp,.37,.37,tim,.046,Vector3.new(1.3,0,1.3))

			md.rockspawn(hrp,.37,.37,tim,.07,Vector3.new(-1.9,0,-1.9),false)

			md.rockspawn(hrp,.32,.32,tim,.07,Vector3.new(1.9,0,1.9))
	end,
	['Dash3'] = function(Character)
		local hrp = Character.HumanoidRootPart
		coroutine.resume(coroutine.create(function()
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(300000,0,300000)

			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			lv.VectorVelocity = Vector3.new(0,0,-80)
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,0)})

			Tween:Play()

			local Hit = false

			local HitRay = false

			local Time = 0
			repeat
				coroutine.resume(coroutine.create(function()
					if hrp:FindFirstChild("GrabWeld") then
						Character.Humanoid.AutoRotate = true
					end
					local dt = .0325
					Hit = SimpleHitbox(hrp.CFrame)
					HitRay = Rayc(hrp)
					wait(dt)
					Time += dt
				end))
				wait()
			until Hit or HitRay or Time >= ((46/60) - (20/60)) or Character.HumanoidRootPart:FindFirstChild("GrabWeld")
			Tween:Cancel()
			lv:Destroy()
		end))
	end,
}
