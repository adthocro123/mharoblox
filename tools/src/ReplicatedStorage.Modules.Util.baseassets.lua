local v1={}
local v2=game:GetService('Debris')
local v3=game:GetService('TweenService')
local v4=script:WaitForChild('rock')
local v5=workspace:FindFirstChild('Debris')
local v6=script:WaitForChild('rockfly')
local v7=game:GetService('RunService')
local v8=v7.Heartbeat
local v9=script:WaitForChild('rock2')

local self=v1

local Debris = game:GetService("Debris")
local Visuals = workspace.Ignore.Effects
function v1.SmashAllTile(CF,box)
	if CF then
		local Overlap=OverlapParams.new()
		Overlap.FilterType=Enum.RaycastFilterType.Exclude
		Overlap.FilterDescendantsInstances={workspace.Ignore.Entities,workspace.Ignore}
		if not box then box = Vector3.new(15,15,15) end 
		for i,v in pairs(workspace:GetPartBoundsInBox(CF,box,Overlap)) do
			if v:IsA('Part') and v.Parent.Name == 'Tiles' then
				if v:GetAttribute('Cant') ~= true then
					v:SetAttribute('Cant',true)
					local OldSize=v.Size
					local Particle = script.effect:Clone()
					Particle.Position = v.Position
					Particle.Orientation = Vector3.new(0,0,0)
					Particle.Parent = Visuals
					Debris:AddItem(Particle,4)
					Particle.Parent = v
					Particle.Smoke:Emit(15)

					v.Size=Vector3.new(0,0,0)
					v.Transparency = 1
					local Color=v.Color
					local Material=v.Material
					local TileSize=OldSize/1.5
 					local Tile=script.Part:Clone()			
					Tile.Color=Color
					Tile.Material=Material
					Tile.Parent=Visuals

					if math.random(1,2) == 2 then
						Tile['sfx'..tostring(math.random(2,3))]:Play()
					end

					Tile.CollisionGroup = "Visuals2"
					Tile.CFrame=CFrame.new(v.Position) * CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360)))
					Tile.v.Velocity=Vector3.new(math.random(-25,25),math.random(20,40),math.random(-25,25))
					game.Debris:AddItem(Tile.v,.3)
					game.Debris:AddItem(Tile,5.6)


					--task.delay(.76,function()

						Tile.CanCollide = true

					--end)

					local TimeToEnd=math.random(2,3)
					task.delay(TimeToEnd,function()
						game.Debris:AddItem(Tile,2)


						local p =	game.TweenService:Create(Tile,TweenInfo.new(2),{Size=Vector3.new(0,0,0)})
						p:Play()


						p.Completed:Connect(function()
							v.Transparency = 0
							local p =	game.TweenService:Create(v,TweenInfo.new(2),{Size=OldSize})
							p:Play()
							p.Completed:Connect(function()

								if v then

									v:SetAttribute('Cant',nil)

								end

							end)

						end)

					end)
				end
			end
		end
	end
end
function v1.SmashTile(CF,P)
	if game:GetService("RunService"):IsClient() then
		if game.Players.LocalPlayer:WaitForChild("Data").Settings.Destruction.Value == false then return end
	end
	for i = 1,20 do
		coroutine.resume(coroutine.create(function()
			local Overlap=RaycastParams.new()
			Overlap.FilterType=Enum.RaycastFilterType.Exclude
			Overlap.FilterDescendantsInstances={workspace.Ignore.Entities,workspace.Ignore}
			local mathrandom12 = math.random(1,2)
			local NewRay
			if mathrandom12 == 1 then
				NewRay=workspace:Raycast(CF.p,Vector3.new(math.random(-2,2),math.random(-2,2),math.random(-2,2)),Overlap)
			elseif mathrandom12 == 2 then
				NewRay=workspace:Raycast(CF.p,Vector3.new(math.random(-10,10),math.random(-10,10),math.random(-10,10)),Overlap)
			elseif mathrandom12 == 3 then
				NewRay=workspace:Raycast(CF.p,Vector3.new(math.random(-5,5),math.random(-5,5),math.random(-5,5)),Overlap)
			end
			if NewRay then
				if NewRay.Instance.Parent.Name=='Tiles' then
					if NewRay.Instance:GetAttribute('Cant') ~= true then
						local lastparent =NewRay.Instance.Parent
						NewRay.Instance.Parent = workspace.Ignore
						NewRay.Instance:SetAttribute('Cant',true)
						local OldSize=NewRay.Instance.Size
						local Particle = script.effect:Clone()
						Particle.Position = NewRay.Instance.Position
						Particle.Orientation = Vector3.new(0,0,0)
						Particle.Parent = Visuals
						Debris:AddItem(Particle,4)
						Particle.Parent = NewRay.Instance
						Particle.Smoke:Emit(15)

						NewRay.Instance.Size=Vector3.new(0,0,0)
						NewRay.Instance.Transparency = 1
						local Color=NewRay.Instance.Color
						local Material=NewRay.Instance.Material
						local TileSize=OldSize/1.5

						local Tile=script.Part1:Clone()			
						Tile.Color=Color
						Tile.Material=Material
						--Tile.Size=OldSize
						Tile.Parent=Visuals
						if not P then
							if math.random(1,2) == 2 then
								Tile['sfx'..tostring(math.random(2,3))]:Play()
							end
						end
						local TimeToEnd=math.random(18,26)
						Tile.CollisionGroup = "Visuals2"
						Tile.CFrame=CFrame.new(NewRay.Position) * CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360)))
						--Tile.v.Velocity=Vector3.new(math.random(-4,8),math.random(4,10),math.random(-4,8))
						Tile.AssemblyLinearVelocity = Vector3.new(
							math.random(-30,30)
							,math.random(40/1.5,40)
							,math.random(-35,35))
						game.Debris:AddItem(Tile,TimeToEnd + 5)
						game.Debris:AddItem(Tile,TimeToEnd + 5)
						Tile.CanCollide = true


						task.delay(.7,function()
							NewRay.Instance.Parent = lastparent
						end)

						task.delay(TimeToEnd,function()
							game.Debris:AddItem(Tile,2)

							if Tile ~= nil then
								local p =	game.TweenService:Create(Tile,TweenInfo.new(2),{Size=Vector3.new(0,0,0)})
								p:Play()
							end

							task.delay(2,function()
								NewRay.Instance.Transparency = 0
								if NewRay.Instance ~= nil then
									local p =game.TweenService:Create(NewRay.Instance,TweenInfo.new(2),{Size=OldSize})
									p:Play()
									task.delay(2,function()

										if NewRay.Instance then

											NewRay.Instance:SetAttribute('Cant',nil)

										end

									end)

								end
							end)
						end)
					end
				end
				if NewRay.Instance.Parent.Name=='vases' then
						if NewRay.Instance:GetAttribute('Cant') ~= true then
							local lastparent =NewRay.Instance.Parent
							NewRay.Instance.Parent = workspace.Ignore
						NewRay.Instance:SetAttribute('Cant',true)
						local OldSize=NewRay.Instance.Size
						local Particle = script.effect:Clone()
						Particle.Position = NewRay.Instance.Position
						Particle.Orientation = Vector3.new(0,0,0)
						Particle.Parent = Visuals
						Debris:AddItem(Particle,4)
						Particle.Parent = NewRay.Instance
						Particle.Smoke:Emit(15)

						NewRay.Instance.Size=Vector3.new(0,0,0)
						NewRay.Instance.Transparency = 1
						local Color=NewRay.Instance.Color
						local Material=NewRay.Instance.Material
						local TileSize=OldSize/1.5
						local TimeToEnd=math.random(18,26)
						for i = 1,math.random(6,8) do
						local Tile=script.vasepart2:Clone()			
						Tile.Color=Color
						Tile.Material=Material
						--Tile.Size=OldSize
						Tile.Parent=Visuals
						if not P then
							if math.random(1,2) == 2 then
								Tile['sfx'..tostring(math.random(2,3))]:Play()
							end
						end
						Tile.CollisionGroup = "Visuals2"
						Tile.CFrame=CFrame.new(NewRay.Position) * CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360)))
						Tile.v.Velocity=Vector3.new(math.random(-25,25),math.random(20,40),math.random(-25,25))
						game.Debris:AddItem(Tile.v,.3)
						game.Debris:AddItem(Tile,TimeToEnd + 5)
							Tile.CanCollide = true


						task.delay(.7,function()
							NewRay.Instance.Parent = lastparent


						end)

						task.delay(TimeToEnd,function()
							game.Debris:AddItem(Tile,2)


							local p =	game.TweenService:Create(Tile,TweenInfo.new(2),{Size=Vector3.new(0,0,0)})
							p:Play()


							p.Completed:Connect(function()
								NewRay.Instance.Transparency = 0
								local p =	game.TweenService:Create(NewRay.Instance,TweenInfo.new(2),{Size=OldSize})
								p:Play()
								p.Completed:Connect(function()

									if NewRay.Instance then

										NewRay.Instance:SetAttribute('Cant',nil)

									end

								end)

							end)

						end)
end
					end
				end
				if NewRay.Instance.Parent.Name=='sacks' then
					if NewRay.Instance:GetAttribute('Cant') ~= true then
						local lastparent =NewRay.Instance.Parent
						NewRay.Instance.Parent = workspace.Ignore
						NewRay.Instance:SetAttribute('Cant',true)
						local OldSize=NewRay.Instance.Size
						local Particle = script.effect:Clone()
						Particle.Position = NewRay.Instance.Position
						Particle.Orientation = Vector3.new(0,0,0)
						Particle.Parent = Visuals
						Debris:AddItem(Particle,4)
						Particle.Parent = NewRay.Instance
						Particle.Smoke:Emit(15)

						NewRay.Instance.Size=Vector3.new(0,0,0)
						NewRay.Instance.Transparency = 1
						local Color=NewRay.Instance.Color
						local Material=NewRay.Instance.Material
						local TileSize=OldSize/1.5
						local TimeToEnd=math.random(18,26)
						for i = 1,math.random(6,8) do
							local Tile=script.fabricpart:Clone()			
							Tile.Color=Color
							Tile.Material=Material
							--Tile.Size=OldSize
							Tile.Parent=Visuals
							if not P then
								if math.random(1,2) == 2 then
									Tile['sfx'..tostring(math.random(2,3))]:Play()
								end
							end
							Tile.CollisionGroup = "Visuals2"
							Tile.CFrame=CFrame.new(NewRay.Position) * CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360)))
							Tile.v.Velocity=Vector3.new(math.random(-25,25),math.random(20,40),math.random(-25,25))
							game.Debris:AddItem(Tile.v,.3)
							game.Debris:AddItem(Tile,TimeToEnd + 5)
							Tile.CanCollide = true


							task.delay(.7,function()
								NewRay.Instance.Parent = lastparent


							end)

							task.delay(TimeToEnd,function()
								game.Debris:AddItem(Tile,2)


								local p =	game.TweenService:Create(Tile,TweenInfo.new(2),{Size=Vector3.new(0,0,0)})
								p:Play()


								p.Completed:Connect(function()
									NewRay.Instance.Transparency = 0
									local p =	game.TweenService:Create(NewRay.Instance,TweenInfo.new(2),{Size=OldSize})
									p:Play()
									p.Completed:Connect(function()

										if NewRay.Instance then

											NewRay.Instance:SetAttribute('Cant',nil)

										end

									end)

								end)

							end)
						end
					end
				end
				if NewRay.Instance.Parent.Name=='floorDetail' or NewRay.Instance.Parent.Name=='izakayaDetail'  or NewRay.Instance.Parent.Name=='eientei'  or NewRay.Instance.Parent.Name=='deskDetail' then
					if NewRay.Instance:GetAttribute('Cant') ~= true then
						local lastparent =NewRay.Instance.Parent
						NewRay.Instance.Parent = workspace.Ignore
						NewRay.Instance:SetAttribute('Cant',true)
						local OldSize=NewRay.Instance.Size
						local Particle = script.effect:Clone()
						Particle.Position = NewRay.Instance.Position
						Particle.Orientation = Vector3.new(0,0,0)
						Particle.Parent = Visuals
						Debris:AddItem(Particle,4)
						Particle.Parent = NewRay.Instance
						Particle.Smoke:Emit(15)

						NewRay.Instance.Size=Vector3.new(0,0,0)
						NewRay.Instance.Transparency = 1
						local Color=NewRay.Instance.Color
						local Material=NewRay.Instance.Material
						local TileSize=OldSize/1.5

						local Tile=script["Part"..math.random(1,3)]:Clone()			
						Tile.Color=Color
						Tile.Material=Material
						Tile.Size=OldSize
						Tile.Parent=Visuals
						if not P then
							if math.random(1,2) == 2 then
								Tile['sfx'..tostring(math.random(2,3))]:Play()
							end
						end
						local TimeToEnd=math.random(18,26)
						Tile.CollisionGroup = "Visuals2"
						Tile.CFrame=CFrame.new(NewRay.Position) * CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360)))
						Tile.v.Velocity=Vector3.new(math.random(-25,25),math.random(20,40),math.random(-25,25))
						game.Debris:AddItem(Tile.v,.3)
						game.Debris:AddItem(Tile,TimeToEnd + 5)

						Tile.CanCollide = true

						task.delay(.7,function()
							NewRay.Instance.Parent = lastparent


						end)

						task.delay(TimeToEnd,function()
							game.Debris:AddItem(Tile,2)


							local p =	game.TweenService:Create(Tile,TweenInfo.new(2),{Size=Vector3.new(0,0,0)})
							p:Play()


							p.Completed:Connect(function()
								NewRay.Instance.Transparency = 0
								local p =	game.TweenService:Create(NewRay.Instance,TweenInfo.new(2),{Size=OldSize})
								p:Play()
								p.Completed:Connect(function()

									if NewRay.Instance then

										NewRay.Instance:SetAttribute('Cant',nil)

									end

								end)

							end)

						end)

					end
				end
	end
end))
end
end
function v1.SmashTrees(CF,P)
	if game:GetService("RunService"):IsClient() then
		if game.Players.LocalPlayer:WaitForChild("Data").Settings.Destruction.Value == false then return end
	end
	for i = 1,10 do
coroutine.resume(coroutine.create(function()
	local Overlap=RaycastParams.new()
	Overlap.FilterType=Enum.RaycastFilterType.Exclude
	Overlap.FilterDescendantsInstances={workspace.Ignore.Entities,workspace.Ignore}
			local NewRay=workspace:Raycast(CF.p,Vector3.new(math.random(-15,15),math.random(-7,7),math.random(-15,15)),Overlap)
			if NewRay then
				if NewRay.Instance.Parent.Parent.Name=='trees' or NewRay.Instance.Parent.Parent.Name=='FixedTreeReplacer' then
			if NewRay.Instance.Parent.Parent:GetAttribute('Cant') ~= true then
				local lastparent =NewRay.Instance.Parent.Parent.Parent

						NewRay.Instance.Parent.Parent.Parent = workspace.Ignore
						NewRay.Instance.Parent.Parent:SetAttribute('Cant',true)
						local TimeToEnd=math.random(18,26)
						for i,v in pairs(NewRay.Instance.Parent.Parent:GetDescendants()) do
							if v:IsA("BasePart") then
								coroutine.resume(coroutine.create(function()
									local OldTransparency=v.Transparency
									local oldcancollide = v.CanCollide
									local OldCFrame=v.CFrame
									local OldSize=v.Size
									local Particle = script.effect:Clone()
									Particle.Position = v.Position
									Particle.Orientation = Vector3.new(0,0,0)
									Particle.Parent = Visuals
									Debris:AddItem(Particle,4)
									Particle.Parent = v
									Particle.Smoke:Emit(1)
									local Color=v.Color
									local Material=v.Material
									local Sizeado=v.Size
									local TileSize=OldSize/1.5
									local Tile=v:Clone()			
									for ie,ve in pairs(script.PartTree:GetChildren()) do
										ve:Clone().Parent = Tile
									end
									Tile.Anchored = false
									Tile.CanCollide = false
									Tile.CollisionGroup = "Visuals2"
									Tile.Color=Color
									Tile.Size=OldSize
									Tile.CFrame = OldCFrame  * CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360)))
									Tile.Parent = Visuals
									Tile.Massless = true
									Tile.Material=Material
									Debris:AddItem(Tile,3)
									v.Size=Vector3.new(0,0,0)
									v.Transparency = 1
									v.CanCollide = false
									--if Tile.Material == Enum.Material.Grass then
									--	Tile.Size=Vector3.new(0,0,0)
									--	Tile.Transparency = 1
									--end
									if not P then
										if math.random(1,2) == 2 then
											Tile['sfx'..tostring(math.random(2,3))]:Play()
										end

									end
									Tile.CollisionGroup = "Visuals"
									--Tile.CFrame=CFrame.new(NewRay.Position) * CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360)))
									Tile.v.Velocity=Vector3.new(math.random(-25,25),math.random(20,40),math.random(-25,25))
									game.Debris:AddItem(Tile.v,.3)
									--game.Debris:AddItem(Tile,TimeToEnd + 5)


--									task.delay(.7,function()
--										if Tile then

--										Tile.CanCollide = true
--end
--									end)

									task.delay(TimeToEnd,function()
										--if Tile then
										--	game.Debris:AddItem(Tile,2)
										--	local p =	game.TweenService:Create(Tile,TweenInfo.new(2),{Size=Vector3.new(0,0,0)})
										--	p:Play()
										--end

										task.delay(2,function()
											v.Transparency = 0
											local p =	game.TweenService:Create(v,TweenInfo.new(2),{Size=OldSize})
											p:Play()
											p.Completed:Connect(function()
												v.CFrame = OldCFrame
												v.Transparency = OldTransparency
												v.CanCollide = oldcancollide
												if v then
													NewRay.Instance.Parent.Parent.Parent = lastparent
													NewRay.Instance.Parent.Parent:SetAttribute('Cant',nil)

												end

											end)

										end)

									end)
								end))
							end
						end
					end
				end
--				if NewRay.Instance.Parent.Name=='shortDresser' or NewRay.Instance.Parent.Name=='shelf' or NewRay.Instance.Parent.Name=='dresserShort' or NewRay.Instance.Parent.Name=='display' or NewRay.Instance.Parent.Parent.Name=='doctor' or NewRay.Instance.Parent.Parent.Name=='doors' or NewRay.Instance.Parent.Name=='bamboocounter' or NewRay.Instance.Parent.Name=='dresserTall' or NewRay.Instance.Parent.Name=='gaming' or NewRay.Instance.Parent.Name=='lampTall' or NewRay.Instance.Parent.Name=='lampCeiling' or NewRay.Instance.Parent.Name=='lamp' or NewRay.Instance.Parent.Name=='futon'  or NewRay.Instance.Parent.Name=='crate' or NewRay.Instance.Parent.Name=='shelf' or NewRay.Instance.Parent.Name=='table' or NewRay.Instance.Parent.Name=='closet' or NewRay.Instance.Parent.Name=='stool' then
--					if NewRay.Instance.Parent:GetAttribute('Cant') ~= true then
--						local lastparent =NewRay.Instance.Parent.Parent
--						NewRay.Instance.Parent.Parent = workspace.Ignore
--						NewRay.Instance.Parent:SetAttribute('Cant',true)
--						local TimeToEnd=math.random(18,26)
--						for i,v in pairs(NewRay.Instance.Parent:GetChildren()) do
--							coroutine.resume(coroutine.create(function()
--								local OldSize=v.Size
--								local OldCFrame=v.CFrame
--								local OldTransparency=v.Transparency
--								local oldcancollide = v.CanCollide
--								local Particle = script.effect:Clone()
--								Particle.Position = v.Position
--								Particle.Orientation = Vector3.new(0,0,0)
--								Particle.Parent = Visuals
--								Debris:AddItem(Particle,4)
--								Particle.Parent = v
--								Particle.Smoke:Emit(15)
--								v.CanCollide = false
--								v.CFrame = CFrame.new(0,0,0)
--								v.Size=Vector3.new(0,0,0)
--								v.Transparency = 1
--								local Color=v.Color
--								local Material=v.Material
--								local Sizeado=v.Size
--								local Tile=script.PartTree:Clone()			
--								Tile.Color=Color
--								Tile.Size=OldSize
--								Tile.CFrame = OldCFrame  * CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360)))
--								Tile.Transparency = OldTransparency
--								Tile.Parent = Visuals
--								for ii,vv in pairs(v:GetChildren()) do
--									vv:Clone().Parent = Tile
--								end
--								Tile.Material=Material
--								if Tile.Color == Color3.fromRGB(109, 139, 95) then
--									Tile.Transparency = 1
--								end
--								if not P then
--									if math.random(1,2) == 2 then
--										Tile['sfx'..tostring(math.random(2,3))]:Play()
--									end

--								end
--								Tile.CollisionGroup = "Visuals"
--								--Tile.CFrame=CFrame.new(NewRay.Position) * CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360)))
--								Tile.v.Velocity=Vector3.new(math.random(-25,25),math.random(20,40),math.random(-25,25))
--								game.Debris:AddItem(Tile.v,.3)
--								game.Debris:AddItem(Tile,TimeToEnd + 11)


--								task.delay(.7,function()

--									Tile.CanCollide = true

--								end)

--								task.delay(TimeToEnd,function()
--									game.Debris:AddItem(Tile,2)


--									local p =	game.TweenService:Create(Tile,TweenInfo.new(2),{Size=Vector3.new(0,0,0)})
--									p:Play()


--									p.Completed:Connect(function()
--										v.Transparency = OldTransparency
--										v.CanCollide = oldcancollide
--										v.CFrame = OldCFrame
--										local p =	game.TweenService:Create(v,TweenInfo.new(2),{Size=OldSize,CFrame=OldCFrame})
--										p:Play()
--										p.Completed:Connect(function()
--											task.delay(2,function()
--											if v then
--												NewRay.Instance.Parent.Parent = lastparent
--												NewRay.Instance.Parent:SetAttribute('Cant',nil)

--											end
--end)
--										end)

--									end)

--								end)
--							end))
--						end
--					end
--				end
				if NewRay.Instance.Parent.Parent.Name=='bamboozle' and NewRay.Instance.Parent.Name == ("bamboo") then
					if NewRay.Instance.Parent:GetAttribute('Cant') ~= true then
						local lastparent =NewRay.Instance.Parent.Parent
						NewRay.Instance.Parent.Parent = workspace.Ignore
						NewRay.Instance.Parent:SetAttribute('Cant',true)
						local TimeToEnd=math.random(18,26)
						for i,v in pairs(NewRay.Instance.Parent:GetChildren()) do
							coroutine.resume(coroutine.create(function()
								local OldSize=v.Size
								local Particle = script.effect:Clone()
								Particle.Position = v.Position
								Particle.Orientation = Vector3.new(0,0,0)
								Particle.Parent = Visuals
								Debris:AddItem(Particle,4)
								Particle.Parent = v
								Particle.Smoke:Emit(15)

								v.Size=Vector3.new(0,0,0)
								v.Transparency = 1
								local Color=v.Color
								local Material=v.Material
								local Sizeado=v.Size
								local TileSize=OldSize/1.5
								for i = 1,math.random(4,6) do
								local Tile=script.bamboopart:Clone()			
								--Tile.Color=Color
								--Tile.Size=OldSize
								Tile.Parent = Visuals

								--Tile.Material=Material
								--if Tile.Color == Color3.fromRGB(109, 139, 95) then
								--	Tile.Transparency = 1
								--end
								if not P then
									if math.random(1,2) == 2 then
										Tile['sfx'..tostring(math.random(2,3))]:Play()
									end

								end
								Tile.CollisionGroup = "Visuals2"
								Tile.CFrame=CFrame.new(NewRay.Position) * CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360)))
								Tile.v.Velocity=Vector3.new(math.random(-25,25),math.random(20,40),math.random(-25,25))
								game.Debris:AddItem(Tile.v,.3)
								game.Debris:AddItem(Tile,TimeToEnd + 5)


								--task.delay(.7,function()

									Tile.CanCollide = true

								--end)

								task.delay(TimeToEnd,function()
									game.Debris:AddItem(Tile,2)


									local p =	game.TweenService:Create(Tile,TweenInfo.new(2),{Size=Vector3.new(0,0,0)})
									p:Play()


									p.Completed:Connect(function()
										v.Transparency = 0
										local p =	game.TweenService:Create(v,TweenInfo.new(2),{Size=OldSize})
										p:Play()
										p.Completed:Connect(function()

											if v then
												NewRay.Instance.Parent.Parent = lastparent
												NewRay.Instance.Parent:SetAttribute('Cant',nil)

											end

										end)

									end)

								end)
end
							end))
						end
					end
				end
	end
end))
end
end
function v1.flyrock(u1,u2,u3,u4)
	if game.Players.LocalPlayer:GetAttribute('NoDebris') then return end
	spawn(function()
		if u1 and u2 then
			local p1=CFrame.new(u1)
			for v=1,u2 do
				spawn(function()
					local p2=p1*CFrame.new(math.random(-u3,u3),0,math.random(-u3,u3))
					local Overlap=RaycastParams.new()
					Overlap.FilterType=Enum.RaycastFilterType.Exclude
					Overlap.FilterDescendantsInstances={workspace.Ignore,workspace.Ignore.Entities}
					local p3,p4 = workspace:Raycast(p1.p,Vector3.new(0,-10,0),Overlap)
					if p3 then
						if p3.Instance.CanCollide==true then
							local p5=p3.Instance.Color
							local p6=p3.Instance.Material
							local p7=v6:Clone()
							local p8=v
							local p11=CFrame.new(p3.Position,p3.Position)
							local p9=Vector3.new(math.random(.25,2),math.random(.25,2),math.random(.25,2))
							local p10=Vector3.new(math.random(-15,15),math.random(30,40),math.random(-15,15))
							if p3.Instance.Parent.Name=='Plates' and not p3.Instance:GetAttribute('Cant') then
								p3.Instance:SetAttribute('Cant',true)
								local OldSize=p3.Instance.Size
								p3.Instance.Size=Vector3.new(0,0,0)
								p9=OldSize/2
								task.delay(2,function()
									if p3 then
										p3.Instance:SetAttribute('Cant',nil)
										local p11=TweenInfo.new(.5,Enum.EasingStyle.Quint,Enum.EasingDirection.Out,0,false)
										local p12={Size=OldSize}
										local p13=v3:Create(p3.Instance,p11,p12)
										p13:Play()
									end
								end)
							end
							p7.Color=p5
							p7.Material=p6
							p7.Name=p7.Name..v
							p7.Parent=v5
							p7.Size=p9
							p7.CFrame=CFrame.new(p3.Position)
							p7.v.Velocity=p10
							v2:AddItem(p7.v,.3)
							local p11=TweenInfo.new(.5,Enum.EasingStyle.Quint,Enum.EasingDirection.Out,0,false,math.random(4,6))
							local p12={Transparency=1}
							local p13=v3:Create(p7,p11,p12)
							p13:Play()
							p13.Completed:Wait()
							if p7 then
								p7:Destroy()
							end
						end
					end
				end)
			end
		end
	end)
end
function v1.rockspawnfast(Part,MinimumSize,MaxSize,Time,TimeToWait,PosInCFrame,HasParticle,char)
	if game.Players.LocalPlayer:GetAttribute('NoDebris') then return end
	local can = true
--	local oldStopRocks = char:GetAttribute("StopRocks")
	task.spawn(function()
		
		local con =  char:GetAttributeChangedSignal("StopRocks"):Connect(function()
			can = false
		end)
		
		local Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Exclude
		Params.FilterDescendantsInstances = {workspace.Ignore,workspace.Ignore.Entities}
		local StartTick=tick()
		repeat 
			if Part.Parent then
				local CF=Part.CFrame*CFrame.new(PosInCFrame)
				local NewRay,Pos=workspace:Raycast(CF.p,Vector3.new(0,-10,0),Params)
				if NewRay then
					if NewRay.Instance:IsA('BasePart') and NewRay.Instance.CanCollide==true then
						local NewSize=math.random(MinimumSize,MaxSize)
						if NewSize == 0 then
							NewSize = MaxSize
						end
						local Rock=script.rock2:Clone()
						Rock.Parent=workspace.Ignore.Rocks
						Rock.Size = Vector3.new(0,0,0)	Rock.CFrame=CFrame.new(NewRay.Position)*CFrame.fromEulerAnglesXYZ(math.random(-45,45),math.random(-45,45),math.random(-45,45))
						Rock.Color=NewRay.Instance.Color
						Rock.Transparency=NewRay.Instance.Transparency
						Rock.Material=NewRay.Instance.Material
						Rock.Smoke.Color=ColorSequence.new(Rock.Color)
						Rock.CanCollide=false

						if HasParticle then

							local ChanceToEmit=math.random(0,100)
							if ChanceToEmit <=80 then
								Rock.Smoke:Emit(2)
							end

						end
						local delaytable = {0,0.05,0.13,0.078}

						local P=game.TweenService:Create(Rock,TweenInfo.new(.1,Enum.EasingStyle.Sine,Enum.EasingDirection.Out,0,false,delaytable[math.random(1,4)]),{Size=Vector3.new(NewSize,NewSize,NewSize)})
						P:Play()
						P.Completed:Connect(function()
							local P=game.TweenService:Create(Rock,TweenInfo.new(.1,Enum.EasingStyle.Sine,Enum.EasingDirection.Out,0,false,3),{Size=Vector3.new(0,0,0)})
							P:Play()
							P.Completed:Connect(function()
								Rock:Destroy()
							end)
						end)
					end
				end
			else
				break
			end
			task.wait(TimeToWait)
		until tick()-StartTick>=Time or can  == false
	
	end)
end
function v1.rockspawn(Part,MinimumSize,MaxSize,Time,TimeToWait,PosInCFrame,HasParticle)
	if game.Players.LocalPlayer:GetAttribute('NoDebris') then return end
	task.spawn(function()
		local Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Exclude
		Params.FilterDescendantsInstances = {workspace.Ignore,workspace.Ignore.Entities}
		local StartTick=tick()
		repeat 

			if Part.Parent then
				local CF=Part.CFrame*CFrame.new(PosInCFrame)
				local NewRay,Pos=workspace:Raycast(CF.p,Vector3.new(0,-5,0),Params)
				if NewRay then
					if NewRay.Instance:IsA('BasePart') and NewRay.Instance.CanCollide==true then
						local NewSize=math.random(MinimumSize,MaxSize)
						if NewSize == 0 then
							NewSize = MaxSize
						end
						local Rock=script.rock2:Clone()
						Rock.Parent=workspace.Ignore.Rocks
						Rock.Size = Vector3.new(0,0,0)	Rock.CFrame=CFrame.new(NewRay.Position)*CFrame.fromEulerAnglesXYZ(math.random(-45,45),math.random(-45,45),math.random(-45,45))
						Rock.Color=NewRay.Instance.Color
						Rock.Transparency=NewRay.Instance.Transparency
						Rock.Material=NewRay.Instance.Material
						Rock.Smoke.Color=ColorSequence.new(Rock.Color)
						Rock.CanCollide=false

						if HasParticle then
							local ChanceToEmit=math.random(0,100)
							if ChanceToEmit <=55 then
								Rock.Smoke:Emit(2)
							else
								Rock.Smoke:Destroy()
							end
						end
						local delaytable = {0,0.05,0.1,0.07}

						local P=game.TweenService:Create(Rock,TweenInfo.new(.2,Enum.EasingStyle.Sine,Enum.EasingDirection.Out,0,false,delaytable[math.random(1,4)]),{Size=Vector3.new(NewSize,NewSize,NewSize)})
						P:Play()
						P.Completed:Connect(function()
							local P=game.TweenService:Create(Rock,TweenInfo.new(.2,Enum.EasingStyle.Sine,Enum.EasingDirection.Out,0,false,1.4),{Size=Vector3.new(0,0,0)})
							P:Play()
							P.Completed:Connect(function()
								Rock:Destroy()
							end)
						end)
					end
				end
			else
				break
			end
			task.wait(TimeToWait)
		until tick()-StartTick>=Time
	end)
end
function v1.makering(u1:CFrame,u2:Size,u3:Orientation)
	--if u1 then
	--	local Circle = script.wind:Clone()
	--	Circle.Parent = workspace.Ignore
	--	Circle.CFrame = u1
	--	Circle.Orientation += u3
	--	game.Debris:AddItem(Circle,1)

	--	if u2 == nil then

	--		local TweenFX = game:GetService("TweenService"):Create(Circle, TweenInfo.new(0.35, Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {Transparency = 1,Size = Vector3.new(0.45, 21.92, 21.92) })
	--		TweenFX:Play()

	--	else

	--		local TweenFX = game:GetService("TweenService"):Create(Circle, TweenInfo.new(0.35, Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {Transparency = 1,Size = u2 })
	--		TweenFX:Play()

	--	end
	--end
end
return v1
