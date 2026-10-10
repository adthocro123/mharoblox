local RockModule = {}
local Debris = game:GetService("Debris")
local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

function RockModule.RockSpawn1(Main, numRocks, SizeX, SizeY, SizeZ, Distance,CollectAfter,HeightOffset,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,IgnoredRocks)
	
	local params = RaycastParams.new()
	params.IgnoreWater = true
	params.FilterDescendantsInstances = {workspace.Ignore, workspace.Ignore.Entities}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local angle = 0 
	local RockTable = {}
	task.delay(CollectAfter or 2,function()
		for i,rock in pairs(RockTable) do
			Debris:AddItem(rock,CollectLength)
			game.TweenService:Create(rock, TweenInfo.new(CollectLength), {Position = rock.Position+Vector3.new(0,-HowMuchDownCollect,0)}):Play()

		end
	end)
	if IgnoredRocks then
		for i=1, numRocks do
			local rocks = Instance.new("Part")
			Debris:AddItem(rocks,20)
			rocks.CollisionGroup = "Visuals"
			rocks.Anchored = true
			rocks.CanCollide = false
			rocks.CastShadow = false
			rocks.CFrame = Main.CFrame * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(Distance, 5, 0)
			rocks.Size = Vector3.new(SizeX, SizeY, SizeZ)

			local cast = workspace:Raycast(rocks.CFrame.Position + Vector3.new(0,7,0), rocks.CFrame.UpVector*-20, params)
			if cast then
				RockTable[i] = rocks
				rocks.Orientation += Vector3.new(
					math.random(-180, 180),
					math.random(-180, 180),
					math.random(-180, 180))
				rocks.Color = cast.Instance.Color
				rocks.Transparency =  cast.Instance.Transparency
				rocks.Position = cast.Position + Vector3.new(0, HowMuchDown, 0)
				rocks.Material = cast.Instance.Material
				rocks.Parent = workspace.Ignore.Rocks

				game.TweenService:Create(rocks, TweenInfo.new(AppearTime), {Position = rocks.Position+Vector3.new(0,-HowMuchDown+HeightOffset,0)}):Play()

			else
				rocks:Destroy()
			end
			angle += 360/numRocks
		end
	else
		for i=1, numRocks do
			local rocks = Instance.new("Part")

			rocks.Anchored = true
			rocks.CanCollide = false
			rocks.CastShadow = false
			rocks.CFrame = Main.CFrame * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(Distance, 5, 0)
			rocks.Size = Vector3.new(SizeX, SizeY, SizeZ)

			local cast = workspace:Raycast(rocks.CFrame.Position + Vector3.new(0,5,0), rocks.CFrame.UpVector*-20, params)
			if cast then
				RockTable[i] = rocks
				rocks.Orientation += Vector3.new(
					math.random(-180, 180),
					math.random(-180, 180),
					math.random(-180, 180))
				rocks.Color = cast.Instance.Color
				rocks.Transparency =  cast.Instance.Transparency
				rocks.Position = cast.Position + Vector3.new(0, HowMuchDown, 0)
				rocks.Material = cast.Instance.Material
				rocks.Parent = workspace.Ignore.Rocks

				game.TweenService:Create(rocks, TweenInfo.new(AppearTime), {Position = rocks.Position+Vector3.new(0,-HowMuchDown+HeightOffset,0)}):Play()

			else
				rocks:Destroy()
			end
			angle += 360/numRocks
		end
	end

end

function RockModule.RockSpawn2(Main, numRocks, SizeX, SizeY, SizeZ, Distance,CollectAfter,HeightOffset,Tilt,CollectLength,AppearTime,HowMuchDown,HowMuchDownCollect,IgnoredRocks)
	local params = RaycastParams.new()
	params.IgnoreWater = true
	params.FilterDescendantsInstances = {workspace.Ignore, workspace.Ignore.Entities}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local angle = 0 
	local RockTable = {}
	task.delay(CollectAfter or 2,function()
		for i,rock in pairs(RockTable) do
			local num = math.random(CollectLength,CollectLength*1.4)
			Debris:AddItem(rock,num)
			game.TweenService:Create(rock, TweenInfo.new(num), {Position = rock.Position+Vector3.new(0,HowMuchDownCollect,0)}):Play()

		end
	end)
	if IgnoredRocks then
		for i=1, numRocks do
			local rocks = Instance.new("Part")
			rocks.CollisionGroup = "Visuals"
			rocks.Anchored = true
			rocks.CanCollide = true
			rocks.CastShadow = true
			rocks.CFrame = Main * CFrame.Angles(0,math.rad(angle),0) * CFrame.new(0, -4, -Distance) * CFrame.Angles(math.rad(Tilt), 0, 0)
			rocks.Size = Vector3.new(SizeX, SizeY, SizeZ)

			local cast = workspace:Raycast(rocks.CFrame.Position+ Vector3.new(0,7,0) , rocks.CFrame.UpVector*-20, params)
			if cast then
				RockTable[i] = rocks
				rocks.Color = cast.Instance.Color
				rocks.Transparency =  cast.Instance.Transparency
				rocks.Position = cast.Position + Vector3.new(0, HowMuchDown, 0)
				rocks.Material = cast.Instance.Material
				rocks.Parent = workspace.Ignore.Rocks

				game.TweenService:Create(rocks, TweenInfo.new(AppearTime), {Position = rocks.Position+Vector3.new(0,-HowMuchDown+HeightOffset ,0)}):Play()

			else
				rocks:Destroy()
			end
			angle += 360/numRocks
		end
	else
		for i=1, numRocks do
			local rocks = Instance.new("Part")

			rocks.Anchored = true
			rocks.CanCollide = true
			rocks.CastShadow = true
			rocks.CFrame = Main * CFrame.Angles(0,math.rad(angle),0) * CFrame.new(0, -4, -Distance) * CFrame.Angles(math.rad(Tilt), 0, 0)
			rocks.Size = Vector3.new(SizeX, SizeY, SizeZ)

			local cast = workspace:Raycast(rocks.CFrame.Position+ Vector3.new(0,5,0) , rocks.CFrame.UpVector*-20, params)
			if cast then
				RockTable[i] = rocks
				rocks.Color = cast.Instance.Color
				rocks.Transparency =  cast.Instance.Transparency
				rocks.Position = cast.Position + Vector3.new(0, HowMuchDown, 0)
				rocks.Material = cast.Instance.Material
				rocks.Parent = workspace.Ignore.Rocks

				game.TweenService:Create(rocks, TweenInfo.new(AppearTime), {Position = rocks.Position+Vector3.new(0,-HowMuchDown+HeightOffset ,0)}):Play()

			else
				rocks:Destroy()
			end
			angle += 360/numRocks
		end
	end
	
end

local TS = game:GetService("TweenService")
function RockModule.RockFlying(Main, Height, SizeZ, SizeX, SizeY, numRocks,CollideAfter,Spread)
	CollideAfter+= .2
	local RockTable = {}
	for v = 1, numRocks do
		
		local Part = Instance.new("Part")
		--Part.CanCollide = false
		Part.CanCollide = true

		RockTable[v] = Part
		Part.Position = Main.Position
		Debris:AddItem(Part,30)
		Part.Anchored = false
		Part.Parent = workspace.Ignore.Rocks
		Part.AssemblyLinearVelocity = Vector3.new(
			math.random(-Spread,Spread)
			,math.random(Height/1.5,Height)
			,math.random(-Spread,Spread))

		Part.Size = Vector3.new(SizeZ, SizeX, SizeY)
		Part.CastShadow = false
		local Params = RaycastParams.new()
		Params.FilterDescendantsInstances = {workspace.Ignore, workspace.Ignore.Entities}
		Params.FilterType = Enum.RaycastFilterType.Exclude

		game:GetService("CollectionService"):AddTag(Part,"IgnoreCamera")

		local CheckGround = Ray.new(Part.Position + Vector3.new(0,5,0),Vector3.new(0,-40,0))
		local Ingore = {workspace.Ignore, workspace.Ignore.Entities}
		local IgnorePart = game.Workspace:FindPartOnRayWithIgnoreList(CheckGround, Ingore)

		if IgnorePart then
			
			Part.Color = IgnorePart.Color
			Part.Transparency =  IgnorePart.Transparency
			Part.Material = IgnorePart.Material
		end

		TS:Create(Part,TweenInfo.new(.2),{Size =Vector3.new(SizeZ, SizeX, SizeY); Rotation = Vector3.new(math.random(90,180),math.random(90,180),math.random(90,180))}):Play()

		Part.CollisionGroup = "Visuals"
	end
	task.delay(CollideAfter,function()
		for i,Part in pairs(RockTable) do
			Part.CanCollide = true
		end
		task.wait(5)
		local num = math.random(0.3,1)
		for i,Part in pairs(RockTable) do
			Debris:AddItem(Part,num)
			TS:Create(Part,TweenInfo.new(num),{Size =Vector3.new(0,0,0),Transparency = 1}):Play()
		end


	end)
	
end

return RockModule
