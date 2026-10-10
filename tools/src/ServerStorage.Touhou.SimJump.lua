local Ke = {}
function getMass(model)
	assert(model and model:IsA("Model"), "Model argument of getMass must be a model.");
	local mass = 0;
	for i,v in pairs(model:GetDescendants()) do
		if(v:IsA("BasePart")) then
			mass += v:GetMass();
		end
	end
	return mass;
end

local debuged = false

function Ke.functioned(Hrp : BasePart,UpVector,ForwardVector,UpForce,ForwardForce,Speed,BW,IgnoreList,TrackHrp,OsClockTime)

	local TT = {
		Complet = false,
		ForceStop = false,
		UpVector = UpVector,
		ForwardVector = ForwardVector,
		FinalFinished = false
	}
	local started = false
	if not OsClockTime then
		started = true
	end
	Speed = Speed or 1
	local start = os.clock()
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Dashing"
	lv.Attachment0 = Hrp.RootAttachment
	lv.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	lv.MaxAxesForce = Vector3.new(30000,20000,30000)
	lv.RelativeTo = Enum.ActuatorRelativeTo.Attachment0
	lv.VectorVelocity = Vector3.new(0,0,0)
	lv.Parent = Hrp
	coroutine.resume(coroutine.create(function()
		local Completed = false

		local rayp = RaycastParams.new()

		if typeof(BW) ~= "string" and BW ~= nil then warn("argument #7 Must be string") end

		rayp.FilterType = BW ~= nil and Enum.RaycastFilterType[BW] or Enum.RaycastFilterType.Blacklist

		rayp.FilterDescendantsInstances = IgnoreList ~= nil and IgnoreList or {Hrp.Parent}

		local IsZero = UpForce == 0
		
		local partde
		if debuged then
			partde = Instance.new("Part",workspace.Terrain)
			partde.Color = Color3.fromRGB(255, 0, 0)
			partde.Anchored = true
			partde.CanCollide = false
			partde.Size = Vector3.new(.5,.5,1)
		end

		repeat
			local dt = .02
coroutine.resume(coroutine.create(function()
			if not _G.GameStop then
				ForwardVector = Hrp.CFrame.LookVector
				local Curret = Hrp:GetVelocityAtPosition(Hrp.Position)

				local LocalVelocity =Hrp.CFrame:ToObjectSpace(CFrame.new(Curret))
				


				if not IsZero then
					UpForce = UpForce - ((workspace.Gravity/12)*dt)
				else
					UpForce = 0
				end


					ForwardForce -= .2
					UpForce -= .2
					if ForwardForce <= .2 then
						ForwardForce = .01
					end
					lv.VectorVelocity = Vector3.new(0,((UpForce)*getMass(Hrp.Parent))*Speed,((-ForwardForce)*getMass(Hrp.Parent))*Speed)
					--lv.VectorVelocity = ((UpVector*(UpForce)*getMass(Hrp.Parent)*Speed+ForwardVector*(ForwardForce)*getMass(Hrp.Parent))*Speed)
					if not OsClockTime then
						started = true
					else
						if (os.clock() - start >= (OsClockTime or .1)) then
							started = true
						end
					end
					local ray = workspace:Raycast(Hrp.Position,(UpVector*UpForce+ForwardVector*ForwardForce),rayp)

					if ray then
						if started == true then
							if ((not ray.Instance.Parent:FindFirstChildOfClass("Humanoid"))-- and (ray.Instance.Transparency ~= 1) 
								and (ray.Instance.CanCollide == true)) and (UpForce >= .5 or UpForce <= -.5)   then
						--[[if ray.Normal:Dot(Vector3.new(0,1,0)) == 1 then
							UpForce = math.abs(UpForce)/2
							
							if UpForce < 3.5 then
								Completed = true
							end
						else \\For bounce]] 
								ForwardVector= ray.Normal
								ForwardForce = math.abs(ForwardForce)/1.25

								if partde then
									partde.Size = Vector3.new(.5,.5,(ForwardVector*ForwardForce+UpVector*UpForce).Magnitude)
									partde.CFrame = CFrame.new(Hrp.CFrame.Position,Hrp.CFrame.Position+ForwardVector*ForwardForce+UpVector*UpForce)*CFrame.new(0,0,-(ForwardVector*ForwardForce+UpVector*UpForce).Magnitude/2)
								end
								Completed = true --Delet this line if u want bounce
								--end
							end
						end
					end
				if IsZero then
					Completed = true
				end
			end
			end))
			wait(.0125)
		until (started == true) and (Completed or TT.ForceStop) 

		Completed = false

		ForwardForce = ForwardForce/2

		UpForce = 0

		local TimePast = 0

		--[[repeat
			local dt = .125

			if not _G.GameStop then
				local Curret = Hrp:GetVelocityAtPosition(Hrp.Position)

				local LocalVelocity =Hrp.CFrame:ToObjectSpace(CFrame.new(Curret))

				ForwardForce = ForwardForce

				TimePast += dt

				lv.VectorVelocity = Vector3.new(0,Hrp.Velocity.Y <= 0 and Hrp.Velocity.Y or 0,0)+(ForwardVector*ForwardForce*getMass(Hrp.Parent)*Speed)

				if TrackHrp == true then
					ForwardVector = Hrp.CFrame.LookVector
					UpVector = Hrp.CFrame.UpVector
				else
					ForwardVector = TT.ForwardVector
					UpVector = TT.UpVector
				end

				local ray = workspace:Raycast(Hrp.Position,UpVector*UpForce+ForwardVector*ForwardForce,rayp)
				if partde then
					partde.Size = Vector3.new(.5,.5,(ForwardVector*ForwardForce+UpVector*UpForce).Magnitude)
					partde.CFrame = CFrame.new(Hrp.CFrame.Position,Hrp.CFrame.Position+ForwardVector*ForwardForce+UpVector*UpForce)*CFrame.new(0,0,-(ForwardVector*ForwardForce+UpVector*UpForce).Magnitude/2)
				end
				if ray or ForwardForce == 0 or (SlideTiming== nil and  true)or (SlideTiming~= nil and  TimePast >=SlideTiming)then
					Completed = true
				end

			end

			wait(.125)
		until Completed or TT.ForceStop Sliding]]

		if TT.ForceStop then
			lv.VectorVelocity = Vector3.zero
		end
		lv:Destroy()
		TT.FinalFinished = true
		TT.Complet = true
		if partde then
			partde:Destroy()
		end
	end))
	return TT
end

Ke.T = "ApplyImpluseHandler"
return Ke
