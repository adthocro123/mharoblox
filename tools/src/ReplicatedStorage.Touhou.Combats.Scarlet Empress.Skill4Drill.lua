local Debris = game:GetService("Debris")
local Camera = workspace.CurrentCamera
local CameraShaker=require(game.ReplicatedStorage.Modules.Util.shaker)
local TS = game:GetService("TweenService")
local FXFolder = workspace.Ignore.Effects
local Basemd = require(game.ReplicatedStorage.Modules.Util.baseassets)
local Tween = game:GetService("TweenService")
local RockModule = require(game.ReplicatedStorage.Modules.Util.RockScript)
local RunService = game:GetService("RunService")
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

Blacklist2.FilterDescendantsInstances = {script.Parent,workspace.Terrain,workspace.Ignore,workspace.Ignore.Entities}

Blacklist2.FilterType = Enum.RaycastFilterType.Exclude

local Blacklist = RaycastParams.new()

Blacklist.FilterDescendantsInstances = {script.Parent,workspace.Terrain,workspace.Ignore,workspace.Ignore.Entities}

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

	--for num,Part in pairs(Parts) do
	--	if Part.Parent:FindFirstChildOfClass("Humanoid") then
	--		return true

	--	end
	--end
	return false
end

local Rayc = function(Hrp : BasePart)
	local ray = workspace:Raycast(Hrp.Position,Hrp.Velocity.Unit*10,Blacklist)

	if ray then
		return true
	end
	return false
end
return {
	['DrillVELOCIDAD'] = function(Character)
		local hrp = Character.HumanoidRootPart
		local lv = Instance.new("LinearVelocity")
		lv.Name = "Dashing"
		lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		lv.MaxAxesForce = Vector3.new(15000,15000,15000)

		lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
		lv.Parent = hrp
		lv.VectorVelocity = Vector3.new(0,10,-30)
		local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(100/60, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,10,0)})

		Tween:Play()
		wait(80/60)
		Tween:Cancel()
		lv:Destroy()
		local BodyPosition = Instance.new("BodyPosition")
		BodyPosition.Name = "DeleteMe2"
		BodyPosition.MaxForce = Vector3.new(20000,20000,20000)
		BodyPosition.Position = Character.HumanoidRootPart.Position
		BodyPosition.Parent = Character.HumanoidRootPart	
		task.delay((99-80)/60,function()
			if BodyPosition ~= nil then 
				BodyPosition:Destroy()
			end
		end)
	end,
	['DrillVELOCIDAD1'] = function(Character)
		local hrp = Character.HumanoidRootPart
		--wait(.1)
		if not Character.Values:FindFirstChild("Stunned") then
			local BodyPosition = Instance.new("BodyPosition")
			BodyPosition.Name = "DeleteMe2"
			BodyPosition.MaxForce = Vector3.new(12000,12000,12000)
			BodyPosition.Position = Character.HumanoidRootPart.Position + Vector3.new(0,1,0)
			BodyPosition.Parent = Character.HumanoidRootPart	
			local lv2 = Instance.new("LinearVelocity")
			lv2.Name = "Dashing"
			lv2.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv2.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv2.MaxAxesForce = Vector3.new(18000,18000,18000)

			lv2.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv2.Parent = hrp
			lv2.VectorVelocity = Vector3.new(0,0,-15)
			task.delay(87/60,function()
				if lv2 ~= nil then 
					lv2:Destroy()
				end
				if BodyPosition ~= nil then 
					BodyPosition:Destroy()
				end
			end)
		end
	end,
	['DrillVELOCIDAD2'] = function(Character)
		local hrp = Character.HumanoidRootPart
		local lv = Instance.new("LinearVelocity")
		lv.Name = "Dashing"
		lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		lv.MaxAxesForce = Vector3.new(800,8000,800)

		lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
		lv.Parent = hrp
		lv.VectorVelocity = Vector3.new(0,45,-5)
		local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(14/60, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,0)})
		Tween:Play()
		wait(19/60)
		Tween:Cancel()
		lv:Destroy()
		if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then
			local BodyPosition = Instance.new("BodyPosition")
			BodyPosition.Name = "DeleteMe2"
			BodyPosition.MaxForce = Vector3.new(12000,12000,12000)
			BodyPosition.Position = Character.HumanoidRootPart.Position
			BodyPosition.Parent = Character.HumanoidRootPart	
			local lv2 = Instance.new("LinearVelocity")
			lv2.Name = "Dashing"
			lv2.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv2.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv2.MaxAxesForce = Vector3.new(18000,18000,18000)

			lv2.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv2.Parent = hrp
			lv2.VectorVelocity = Vector3.new(0,0,-15)
			task.delay((87-20)/60,function()
				if lv2 ~= nil then 
					lv2:Destroy()
				end
				if BodyPosition ~= nil then 
					BodyPosition:Destroy()
				end
			end)
		end
	end,
	['DrillOLD'] = function(Character)
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

			--Hit = SimpleHitbox(hrp.CFrame)
			--HitRay = Rayc(hrp)
			wait(dt)
			Time += dt
		until-- Hit or HitRay or
		Time >= ((53/60) - (22/60)) or not Character.Values:FindFirstChild("Cant")

		Tween:Cancel()

		lv:Destroy()
	end,
	['Drill'] = function(Character)
		local hrp = Character.HumanoidRootPart
		local lv = Instance.new("LinearVelocity")
		lv.Name = "Dashing"
		lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		lv.MaxAxesForce = Vector3.new(20000,20000,20000)

		lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
		lv.Parent = hrp
		lv.VectorVelocity = Vector3.new(0,50,-60)
		local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(.7, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,0)})

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
		until-- Hit or HitRay or
		Time >= ((53/60) - (22/60)) or not Character.Values:FindFirstChild("Cant")  or Character.Values:FindFirstChild("Stunned")

		Tween:Cancel()

		lv:Destroy()
	end,
	['Dash'] = function(Character)
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
			lv.VectorVelocity = Vector3.new(0,0,-155)
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,0)})

			Tween:Play()

			local Hit = false

			local HitRay = false

			local Time = 0
			repeat
				coroutine.resume(coroutine.create(function()
					local dt = .0325
					Hit = SimpleHitbox(hrp.CFrame)
					HitRay = Rayc(hrp)
					wait(dt)
					Time += dt
				end))
				wait()
			until Hit or HitRay or Time >= ((48/60) - (22/60))  or Character.Values:FindFirstChild("Stunned")
 
			Tween:Cancel()
			Character.Humanoid.AutoRotate = true
			lv:Destroy()
		end))
	end,

}
