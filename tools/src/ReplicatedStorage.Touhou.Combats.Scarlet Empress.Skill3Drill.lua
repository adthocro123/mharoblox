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
local function RayCastOnMap(origin,direction,returnAll)
	local raycastSettings = RaycastParams.new()
	raycastSettings.FilterType = Enum.RaycastFilterType.Blacklist
	raycastSettings.FilterDescendantsInstances = {workspace.Ignore}
	local ray = workspace:Raycast(origin, direction, raycastSettings)

	if returnAll then return ray end
	if ray then
		return ray.Position
	else
		return origin
	end
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
	['Drill'] = function(Character)
		local hrp = Character.HumanoidRootPart
		local lv = Instance.new("LinearVelocity")
		lv.Name = "Dashing"
		lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
		lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		lv.MaxAxesForce = Vector3.new(20000,20000,20000)

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
			wait(dt)
			Time += dt
		until Hit or HitRay or Time >= ((60/60) - (22/60)) or not Character.Values:FindFirstChild("Cant") or Character.Values:FindFirstChild("Stunned")

		Tween:Cancel()

		lv:Destroy()
	end,
	['DashULTIMATUM'] = function(Character)
		local hrp = Character.HumanoidRootPart
		coroutine.resume(coroutine.create(function()
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(24000,0,24000)

			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			lv.VectorVelocity = Vector3.new(0,0,-70)
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(.8, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,0)})

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
			Time >= ((60/60) - (22/60)) or not Character.Values:FindFirstChild("Cant") or Character.HumanoidRootPart:FindFirstChild("GrabWeld") or Character.Values:FindFirstChild("Stunned")
			local Tween2
			local onetwos = lv.VectorVelocity

			Tween:Pause()
			Tween:Destroy()
			lv:Destroy()
			repeat wait() until not Character.Values:FindFirstChild("Cant") 
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
			lv.VectorVelocity = Vector3.new(0,0,-90)
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(.6, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,0)})

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
			Time >= ((122/60) - (48/60)) or not Character.Values:FindFirstChild("Cant") or Character.HumanoidRootPart:FindFirstChild("GrabWeld") or Character.Values:FindFirstChild("Stunned")
			local Tween2
			local onetwos = Vector3.new(0,0,-55)

			Tween:Pause()
			Tween:Destroy()
			if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then
				lv.VectorVelocity = onetwos
				if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == false then
					local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.blooddashvfx.Attachment:Clone()
					RedFX15.Parent = Character.Torso
					task.delay(26/60,function()
						game.Debris:AddItem(RedFX15,2)
						for i,v in pairs(RedFX15:GetDescendants()) do
							if v:IsA('ParticleEmitter') then
								v.Enabled = false
							end
						end
					end)
				end
				--task.delay(14/60,function()
				--	local velocity = Instance.new('BodyVelocity')
				--	velocity.MaxForce = Vector3.new(0,20000,0)
				--	velocity.Velocity = Character.HumanoidRootPart.CFrame.UpVector * 6
				--	velocity.Parent = Character.HumanoidRootPart
				--	local uptime = .9
				--	game.Debris:AddItem(velocity,uptime)
				--	local conn1
				--	task.delay(uptime,function()
				--		conn1:Disconnect()
				--	end)
				--	conn1 = Character:GetAttributeChangedSignal("Cancel"):Connect(function()
				--		conn1:Disconnect()
				--		velocity:Destroy()
				--	end)
				--end)
				Tween2 = game:GetService("TweenService"):Create(lv,TweenInfo.new(1.44, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,0)})
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
	['Dash2fifties5'] = function(Character)
		local hrp = Character.HumanoidRootPart
		--if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == false then
		--	local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.blooddashvfx.Attachment:Clone()
		--	RedFX15.Parent = Character["Right Arm"]
		--	task.delay(16/60,function()
		--		game.Debris:AddItem(RedFX15,2)
		--		for i,v in pairs(RedFX15:GetDescendants()) do
		--			if v:IsA('ParticleEmitter') then
		--				v.Enabled = false
		--			end
		--		end
		--	end)
		--end
		coroutine.resume(coroutine.create(function()
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(24000,0,24000)

			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			lv.VectorVelocity = Vector3.new(0,0,-90)
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(.4, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,0)})

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
			Time >= ((67/60) - (44/60)) or not Character.Values:FindFirstChild("Cant") or Character.HumanoidRootPart:FindFirstChild("GrabWeld")  or Character.Values:FindFirstChild("Stunned")
			Tween:Pause()
			Tween:Destroy()
			lv:Destroy()
		end))
	end,
	['Dash2fifties55'] = function(Character)
		local hrp = Character.HumanoidRootPart
		--if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == false then
		--	local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.blooddashvfx.Attachment:Clone()
		--	RedFX15.Parent = Character["Right Arm"]
		--	task.delay(16/60,function()
		--		game.Debris:AddItem(RedFX15,2)
		--		for i,v in pairs(RedFX15:GetDescendants()) do
		--			if v:IsA('ParticleEmitter') then
		--				v.Enabled = false
		--			end
		--		end
		--	end)
		--end
		coroutine.resume(coroutine.create(function()
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(24000,0,24000)

			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			lv.VectorVelocity = Vector3.new(0,0,-75)
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,0)})

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
			Time >= ((40/60) - (15/60)) or not Character.Values:FindFirstChild("Cant") or Character.HumanoidRootPart:FindFirstChild("GrabWeld")  or Character.Values:FindFirstChild("Stunned")
			Tween:Pause()
			Tween:Destroy()
			lv:Destroy()
		end))
	end,
	['Dash2fiftiesz25'] = function(Character)
		local hrp = Character.HumanoidRootPart
		coroutine.resume(coroutine.create(function()
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(24000,0,24000)

			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			lv.VectorVelocity = Vector3.new(0,0,-125)
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(25/60, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,0)})

			Tween:Play()

			local Hit = false

			local HitRay = false

			local Time = 0
			--local conn1
			--conn1 = Character.HumanoidRootPart.ChildAdded:Connect(function(Child)
			--	if Child.Name == ("GrabWeld") then
			--		if conn1 then 
			--			conn1:Disconnect()
			--		end
			--		Character.HumanoidRootPart.Velocity = Vector3.new(0,0,0)
			--		lv:Destroy()
			--		Tween:Pause()
			--		Tween:Destroy()
			--	end
			--end)
			repeat
				local dt = .0325

				--Hit = SimpleHitbox(hrp.CFrame)
				--HitRay = Rayc(hrp)
				wait(dt)
				Time += dt
			until
			(Time >= ((30/60))) or (not Character.Values:FindFirstChild("Cant")) or (Character.HumanoidRootPart:FindFirstChild("GrabWeld")) or (Character.Values:FindFirstChild("Stunned"))
			--Character.HumanoidRootPart.Velocity = Vector3.new(0,0,0)
			--if conn1 then 
			--	conn1:Disconnect()
			--end
			lv:Destroy()
			Tween:Pause()
			Tween:Destroy()
		end))
	end,
	['Dash2fiftiesz'] = function(Character)
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
			Time >= ((10/60)) or not Character.Values:FindFirstChild("Cant") or Character.HumanoidRootPart:FindFirstChild("GrabWeld") or Character.Values:FindFirstChild("Stunned")
			local Tween2
			Tween:Pause()
			Tween:Destroy()
			lv:Destroy()
		end))
	end,
	['Dash2fiftiesNEWONE'] = function(Character)
		local hrp = Character.HumanoidRootPart
		coroutine.resume(coroutine.create(function()
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(10000,0,10000)

			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			local velocidadd = -50
			if Character:FindFirstChild("MilleniumVampire") then
				velocidadd = -60
			end
			lv.VectorVelocity = Vector3.new(0,0,velocidadd)
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,0)})

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
			until (not Character:FindFirstChild("VAMPIREKISSLUNGE")) or (not Character.Values:FindFirstChild("CantHeartBreak")) or (Character.HumanoidRootPart:FindFirstChild("GrabWeld")) or (Character.HumanoidRootPart:FindFirstChild("STOPLUNGE")) or (Character.Values:FindFirstChild("Stunned"))
			local Tween2
			local onetwos = lv.VectorVelocity
			Tween:Pause()
			Tween:Destroy()
			if (not Character.Values:FindFirstChild("Stunned")) and (not Character.Values:FindFirstChild("STOPLUNGE")) then
				--if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then
				local waittime = .7
				if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then
					waittime = 1.5
				end
				if Character:FindFirstChild("HITWALLVAMPIRE") then
					lv.VectorVelocity = -onetwos
				else
					lv.VectorVelocity = onetwos
				end
				Tween2 = game:GetService("TweenService"):Create(lv,TweenInfo.new(waittime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,0)})
				Tween2:Play()
				--end
				--if (Character.HumanoidRootPart:FindFirstChild("GrabWeld")) then
				--	repeat wait() until not Character.HumanoidRootPart:FindFirstChild("GrabWeld")
				--	if Tween2 ~= nil then
				--		Tween2:Cancel()
				--		Tween2:Destroy()
				--	end
				--else
				wait(waittime)
				if Tween2 ~= nil then
					Tween2:Cancel()
					Tween2:Destroy()
				end
				--end)
				--end
			end
			lv:Destroy()
		end))
	end,
	['NCRVELOCITY'] = function(Character)
		local hrp = Character.HumanoidRootPart
		local bdposicionado2 = Instance.new("BodyPosition",Character.HumanoidRootPart)
		bdposicionado2.MaxForce = Vector3.new(0,10000,0)
		bdposicionado2.Position = Character.HumanoidRootPart.Position + Vector3.new(0,3.1,0)
		task.delay(29/60,function()
			local velocity = Instance.new('BodyVelocity')
			velocity.MaxForce = Vector3.new(0,7300,0)
			velocity.Velocity = Character.HumanoidRootPart.CFrame.UpVector * 8
			velocity.Parent = Character.HumanoidRootPart
			local waititme15 = 1
			game.Debris:AddItem(velocity,waititme15+.1)
			game:GetService("TweenService"):Create(velocity,TweenInfo.new(waititme15, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),{MaxForce = Vector3.new(0,0,0)}):Play()
			bdposicionado2:Destroy()
		end)
		wait(29/60)
		coroutine.resume(coroutine.create(function()
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(10000,6000,10000)

			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			lv.VectorVelocity = Vector3.new(0,0,0)
			local Tween25 = game:GetService("TweenService"):Create(lv,TweenInfo.new(3/60, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,-50)})
			Tween25:Play()
			wait(3/60)
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,-6)})
			Tween:Play()
			local bdposicionado251
			task.delay((((107-29)-3))/60,function()
				lv:Destroy()
				bdposicionado251 = Instance.new("BodyPosition",Character.HumanoidRootPart)
				bdposicionado251.MaxForce = Vector3.new(0,10000,0)
				bdposicionado251.Position = Character.HumanoidRootPart.Position + Vector3.new(0,5.2,0)
				bdposicionado251.D = 980
				bdposicionado251.P = 15000
				coroutine.resume(coroutine.create(function()
					local lv51 = Instance.new("LinearVelocity")
					lv51.Name = "Dashing"
					lv51.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
					lv51.ForceLimitMode = Enum.ForceLimitMode.PerAxis
					lv51.MaxAxesForce = Vector3.new(10000,0,10000)

					lv51.Attachment0 = hrp:FindFirstChild("RootAttachment")
					lv51.Parent = hrp
					lv51.VectorVelocity = Vector3.new(0,0,0)
					local Tween251 = game:GetService("TweenService"):Create(lv51,TweenInfo.new(3/60, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,-26)})
					Tween251:Play()
					wait(18/60)
					local Tween15 = game:GetService("TweenService"):Create(lv51,TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,0)})
					Tween15:Play()
					game.Debris:AddItem(lv51,.9)
				end))
			end)
			task.delay((((149-29)-3))/60,function()
				bdposicionado251.Position = Character.HumanoidRootPart.Position - Vector3.new(0,2,0)
				wait(17/60)
				--bdposicionado251:Destroy()
				bdposicionado251.D = 1000
				bdposicionado251.P = 12000
				--bdposicionado251.P = 70000
				local floorInstance = RayCastOnMap(Character.HumanoidRootPart.Position,Vector3.new(0,-40,0),true)
				if floorInstance then
					bdposicionado251.Position = floorInstance.Position
				else
					bdposicionado251.Position = Character.HumanoidRootPart.Position - Vector3.new(0,4,0)
				end
				game.Debris:AddItem(bdposicionado251,.3)
			end)
			--local Hit = false

			--local HitRay = false

			--local Time = 0

			--repeat
			--	local dt = .0325

			--	--Hit = SimpleHitbox(hrp.CFrame)
			--	--HitRay = Rayc(hrp)
			--	wait(dt)
			--	Time += dt
			--until (not Character:FindFirstChild("NIGHTLESSCASTLELUNGE")) or (not Character.Values:FindFirstChild("Cant")) or (Character.HumanoidRootPart:FindFirstChild("GrabWeld")) or (Character.Values:FindFirstChild("Stunned"))
			--local Tween2
			--local onetwos = lv.VectorVelocity
			--Tween:Pause()
			--Tween:Destroy()
			--if (not Character.Values:FindFirstChild("Stunned")) then
			--	--if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then
			--	local waittime = .7
			--	if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then
			--		waittime = 1.5
			--	end
			--	--if Character:FindFirstChild("HITWALLVAMPIRE") then
			--	--	lv.VectorVelocity = -onetwos
			--	--else
			--		lv.VectorVelocity = onetwos

			--	--end
			--	Tween2 = game:GetService("TweenService"):Create(lv,TweenInfo.new(waittime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,0)})
			--	Tween2:Play()
			--	--end
			--	--if (Character.HumanoidRootPart:FindFirstChild("GrabWeld")) then
			--	--	repeat wait() until not Character.HumanoidRootPart:FindFirstChild("GrabWeld")
			--	--	if Tween2 ~= nil then
			--	--		Tween2:Cancel()
			--	--		Tween2:Destroy()
			--	--	end
			--	--else
			--	wait(waittime)
			--	if Tween2 ~= nil then
			--		Tween2:Cancel()
			--		Tween2:Destroy()
			--	end
			--	--end)
			--	--end
			--end
			--lv:Destroy()
		end))
	end,
	['Dash2fifties'] = function(Character)
		local hrp = Character.HumanoidRootPart
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == false then
		local RedFX15 = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat.blooddashvfx.Attachment:Clone()
		RedFX15.Parent = Character["Left Arm"]
		task.delay(16/60,function()
			game.Debris:AddItem(RedFX15,2)
			for i,v in pairs(RedFX15:GetDescendants()) do
				if v:IsA('ParticleEmitter') then
					v.Enabled = false
				end
			end
		end)
end
		coroutine.resume(coroutine.create(function()
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(24000,0,24000)

			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			lv.VectorVelocity = Vector3.new(0,0,-90)
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(.6, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,0)})

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
			Time >= ((145/60) - (48/60)) or not Character.Values:FindFirstChild("Cant") or Character.HumanoidRootPart:FindFirstChild("GrabWeld")  or Character.Values:FindFirstChild("Stunned")
			local Tween2
			local onetwos = lv.VectorVelocity

			Tween:Pause()
			Tween:Destroy()
			if Character.HumanoidRootPart:FindFirstChild("GrabWeld") then
				lv.VectorVelocity = onetwos
				Tween2 = game:GetService("TweenService"):Create(lv,TweenInfo.new(1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),{VectorVelocity = Vector3.new(0,0,0)})
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
	['DashULT2'] = function(Character)
		local hrp = Character.HumanoidRootPart
		coroutine.resume(coroutine.create(function()
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(15000,0,15000)

			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			lv.VectorVelocity = Vector3.new(0,0,-150)
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,0)})

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
			Time >= ((80/60) - (55/60)) or not Character.Values:FindFirstChild("Cant")  or Character.Values:FindFirstChild("Stunned")

			Tween:Cancel()
			lv:Destroy()
		end))
	end,
	['Dash2'] = function(Character)
		local hrp = Character.HumanoidRootPart
		coroutine.resume(coroutine.create(function()
			--Character.Humanoid.AutoRotate = false
			local lv = Instance.new("LinearVelocity")
			lv.Name = "Dashing"
			lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
			lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
			lv.MaxAxesForce = Vector3.new(15000,0,15000)

			lv.Attachment0 = hrp:FindFirstChild("RootAttachment")
			lv.Parent = hrp
			lv.VectorVelocity = Vector3.new(0,0,-90)
			local Tween = game:GetService("TweenService"):Create(lv,TweenInfo.new(.4, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{VectorVelocity = Vector3.new(0,0,0)})

			Tween:Play()

			local Hit = false

			local HitRay = false

			local Time = 0
			repeat
					local dt = .0325
					wait(dt)
					Time += dt
				wait()
			until Time >= ((75/60) - (45/60)) or not Character.Values:FindFirstChild("Cant") or Character.Values:FindFirstChild("Stunned")

			Tween:Cancel()
			--Character.Humanoid.AutoRotate = true
			lv:Destroy()
		end))
	end,
	['Dash4'] = function(Character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then return end

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
					if  v:IsA('ParticleEmitter') then
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
			lv.MaxAxesForce = Vector3.new(15000,0,15000)

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
					wait(dt)
					Time += dt
				end))
				wait()
			until Time >= ((46/60) - (20/60)) or Character.HumanoidRootPart:FindFirstChild("GrabWeld") or not Character.Values:FindFirstChild("Cant")  or Character.Values:FindFirstChild("Stunned")
			Tween:Cancel()
			lv:Destroy()
		end))
	end,
}
