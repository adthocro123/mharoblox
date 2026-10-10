local Debris = game:GetService("Debris")
local ResourceFolder = game.ReplicatedStorage.Assets.VFX["Scarlet Empress"].Combat

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
local numberofrocksrubbleslam = math.random(3,4)

local function calculateClosestPartSide(target, dest)
	local targetPos = target.Position
	local destPos = dest.Position
	local destSize = dest.Size

	local positions = {
		Vector3.new(destPos.X + (destSize.X / 2), destPos.Y, destPos.Z),
		Vector3.new(destPos.X - (destSize.X / 2), destPos.Y, destPos.Z),
		Vector3.new(destPos.X, destPos.Y + (destSize.Y / 2), destPos.Z),
		Vector3.new(destPos.X, destPos.Y - (destSize.Y / 2), destPos.Z),
		Vector3.new(destPos.X, destPos.Y, destPos.Z + (destSize.Z / 2)),
		Vector3.new(destPos.X, destPos.Y, destPos.Z - (destSize.Z / 2))
	}

	local closestPos = positions[1]
	local smallestMagnitude = math.abs((positions[1] - targetPos).Magnitude)

	for _,pos in positions do
		local currentMagnitude = math.abs((pos - targetPos).Magnitude)
		if (currentMagnitude < smallestMagnitude) then
			closestPos = pos
			smallestMagnitude = currentMagnitude
		end
	end

	if closestPos == nil then
		warn("nil position")
	end

	return {closestPos, smallestMagnitude}
end
local fullfiendmodedelay = 53/60
local dashtime2 = 110/60
local CameraShaker=require(game.ReplicatedStorage.Modules.Util.shaker)
local Camera = workspace.CurrentCamera
return {
	["CRASHGAME"] = function(Character)
		local function crashgame1()
			for i ,v in pairs(Character:GetDescendants())do
				if  v:IsA('ParticleEmitter') then
					v:Emit(515151512)
				end
			end
			local littlesaintjamespizzategateislandbillclintonseal = game.ReplicatedStorage.Assets.crashremiliaspear:Clone()
			littlesaintjamespizzategateislandbillclintonseal.Parent = Character["Right Arm"]
			littlesaintjamespizzategateislandbillclintonseal.remiliaspear.Part0 = Character["Right Arm"]
			local littlesaintjamespizzategateislandbillclintonseal = game.ReplicatedStorage.Assets.crashremiliaspear:Clone()
			littlesaintjamespizzategateislandbillclintonseal.Parent = Character["Right Arm"]
			littlesaintjamespizzategateislandbillclintonseal.remiliaspear.Part0 = Character["Right Arm"]
			local littlesaintjamespizzategateislandbillclintonseal = game.ReplicatedStorage.Assets.crashremiliaspear:Clone()
			littlesaintjamespizzategateislandbillclintonseal.Parent = Character["Right Arm"]
			littlesaintjamespizzategateislandbillclintonseal.remiliaspear.Part0 = Character["Right Arm"]	
			while wait() do
				for i ,v in pairs(Character:GetDescendants())do
					if  v:IsA('ParticleEmitter') then
						v:Emit(500000000000)
					end
				end
				for i ,v in pairs(Character:GetDescendants())do
					if  v:IsA('ParticleEmitter') then
						v:Emit(262532423432452)
					end
				end
				for i ,v in pairs(Character:GetDescendants())do
					if  v:IsA('ParticleEmitter') then
						v:Emit(234234)
					end
				end
				for i ,v in pairs(Character["Right Arm"]:GetDescendants())do
					if  v:IsA('Trail') then
						local v1 = v:Clone()
						v1.Enabled = true
						v1.Parent =Character["Right Arm"]:FindFirstChild("crashremiliaspear")
						local v1 = v:Clone()
						v1.Enabled = true
						v1.Parent =Character["Right Arm"]:FindFirstChild("crashremiliaspear")
						local v1 = v:Clone()
						v1.Enabled = true
						v1.Parent =Character["Right Arm"]:FindFirstChild("crashremiliaspear")
						task.delay(100/60,function()
							local v1 = v:Clone()
							v1.Enabled = true
							v1.Parent =Character["Right Arm"]:FindFirstChild("crashremiliaspear")
							v1.Enabled = false
							v1.Enabled = true
							game.Debris:AddItem(v1,1479)
						end)
						task.delay(5050/60,function()
							v1.Enabled = false
							game.Debris:AddItem(v1,1517)
						end)
					end
				end
				repeat wait()
					for i ,v in pairs(Character:GetDescendants())do
						if  v:IsA('ParticleEmitter') then
							v:Emit(948740655934543)
						end
					end
					for i ,v in pairs(Character["Right Arm"]:GetDescendants())do
						if  v:IsA('Trail') then
							local v1 = v:Clone()
							v1.Enabled = true
							v1.Parent =Character["Right Arm"]:FindFirstChild("crashremiliaspear")
							local v1 = v:Clone()
							v1.Enabled = true
							v1.Parent =Character["Right Arm"]:FindFirstChild("crashremiliaspear")
							local v1 = v:Clone()
							v1.Enabled = true
							v1.Parent =Character["Right Arm"]:FindFirstChild("crashremiliaspear")
							task.delay(100/60,function()
								local v1 = v:Clone()
								v1.Enabled = true
								v1.Parent =Character["Right Arm"]:FindFirstChild("crashremiliaspear")
								v1.Enabled = false
								v1.Enabled = true
								game.Debris:AddItem(v1,1479)
							end)
							task.delay(5050/60,function()
								v1.Enabled = false
								game.Debris:AddItem(v1,1517)
							end)
						end
					end
				until game.Players.LocalPlayer == nil
			end
			for i ,v in pairs(Character:GetDescendants())do
				if  v:IsA('ParticleEmitter') then
					v:Emit(500000000000)
				end
			end
			local littlesaintjamespizzategateislandbillclintonseal = game.ReplicatedStorage.Assets.crashremiliaspear:Clone()
			littlesaintjamespizzategateislandbillclintonseal.Parent = Character["Right Arm"]
			littlesaintjamespizzategateislandbillclintonseal.remiliaspear.Part0 = Character["Right Arm"]
			local littlesaintjamespizzategateislandbillclintonseal = game.ReplicatedStorage.Assets.crashremiliaspear:Clone()
			littlesaintjamespizzategateislandbillclintonseal.Parent = Character["Right Arm"]
			littlesaintjamespizzategateislandbillclintonseal.remiliaspear.Part0 = Character["Right Arm"]
			local littlesaintjamespizzategateislandbillclintonseal = game.ReplicatedStorage.Assets.crashremiliaspear:Clone()
			littlesaintjamespizzategateislandbillclintonseal.Parent = Character["Right Arm"]
			littlesaintjamespizzategateislandbillclintonseal.remiliaspear.Part0 = Character["Right Arm"]	
			while wait() do

				for i ,v in pairs(Character:GetDescendants())do
					if  v:IsA('ParticleEmitter') then
						v:Emit(500000000000)
					end
				end
				repeat wait()
					for i ,v in pairs(Character["Right Arm"]:GetDescendants())do
						if  v:IsA('Trail') then
							local v1 = v:Clone()
							v1.Enabled = true
							v1.Parent =Character["Right Arm"]:FindFirstChild("crashremiliaspear")
							local v1 = v:Clone()
							v1.Enabled = true
							v1.Parent =Character["Right Arm"]:FindFirstChild("crashremiliaspear")
							local v1 = v:Clone()
							v1.Enabled = true
							v1.Parent =Character["Right Arm"]:FindFirstChild("crashremiliaspear")
							task.delay(100/60,function()
								local v1 = v:Clone()
								v1.Enabled = true
								v1.Parent =Character["Right Arm"]:FindFirstChild("crashremiliaspear")
								v1.Enabled = false
								v1.Enabled = true
								game.Debris:AddItem(v1,1479)
							end)
							task.delay(5050/60,function()
								v1.Enabled = false
								game.Debris:AddItem(v1,1517)
							end)
						end
					end
				until game.Players.LocalPlayer == nil
			end
			for i ,v in pairs(Character:GetDescendants())do
				if  v:IsA('ParticleEmitter') then
					v:Emit(50000000000000000)
				end
			end
		end
		crashgame1()
	end,	
}
