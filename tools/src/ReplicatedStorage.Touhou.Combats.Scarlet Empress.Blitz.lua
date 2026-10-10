local Debris = game:GetService("Debris")
local Camera = workspace.CurrentCamera
local CameraShaker=require(game.ReplicatedStorage.Modules.Util.shaker)
local TS = game:GetService("TweenService")
local FXFolder = workspace.Ignore.Effects
local md = require(game.ReplicatedStorage.Modules.Util.baseassets)
local RunService = game:GetService("RunService")
local cam = workspace.CurrentCamera

local Knit = require(game.ReplicatedStorage.Packages.Knit)

function Cinematic(foldername,target,isgui)
	local Character
	local CinematicsFolder = foldername

	local CurrentCameraCFrame = workspace.CurrentCamera.CFrame

	Camera.CameraType = Enum.CameraType.Scriptable
	local FrameTime = 0
	local Connection

	local FOV = false -- fov stuff
	local FOVFrameTime = 0

	if CinematicsFolder:FindFirstChild("FOV") then
		FOV = true
	end

	Connection = RunService.RenderStepped:Connect(function(DT)
		local NewDT = DT * 60
		FrameTime += NewDT
		local NeededFrame = CinematicsFolder.Frames:FindFirstChild(tonumber(math.ceil(FrameTime)))
		if NeededFrame then
			if FOV == true then
				FOVFrameTime += NewDT
				local NeededFOVFrame = CinematicsFolder.FOV:FindFirstChild(tonumber(math.ceil(FOVFrameTime)))
				if NeededFOVFrame then
					Camera.FieldOfView = NeededFOVFrame.Value
				end
			end
			Camera.CFrame = target.CFrame * NeededFrame.Value
		else
			Connection:Disconnect()
			Camera.CameraType = Enum.CameraType.Custom
			Camera.CFrame = CurrentCameraCFrame    
			if FOV == true then
				Camera.FieldOfView = 70
			end
		end
	end)
end
return {
	['Cutscene'] = function(character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Cutscenes").Value == false then return end
		local wait = task.wait
		local camrig = game.ReplicatedStorage.Assets["CameraRig"]:Clone()
		camrig.RootPart.CFrame = character.HumanoidRootPart.CFrame * CFrame.new(0.035, 1.847, 1.461)
		require(game.ReplicatedStorage.Packages.Knit).Hud.Enabled = false
		game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,false)
		camrig.Parent = character
		cam.CameraType = Enum.CameraType.Scriptable
		local done = false
		local Val = Instance.new("NumberValue")
		Val.Name = "AutoRotate"
		Val.Parent = character.Values
		task.spawn(function()
			while not done do
				camrig.RootPart.CFrame = character.HumanoidRootPart.CFrame * CFrame.new(0.035, 1.847, 1.461) --0, 1.847, 1.508
				cam.CFrame = camrig.Bone.CFrame * CFrame.new(0,0,-.2)
				RunService.Heartbeat:Wait() 
			end
			Val:Destroy()
		end)
		Camera.FieldOfView = 40
		--task.delay(426/60,function()
		--	game.Players.LocalPlayer.PlayerGui.Dim.Enabled = true
		--	local epilepsy = true
		--	task.delay((500-426)/60,function()
		--		epilepsy = false
		--		game.Lighting.remimpactframe.Enabled = false
		--		game.Players.LocalPlayer.PlayerGui.Dim.Enabled = false
		--	end)
		--	game.Lighting.remimpactframe.Enabled = true
		--	coroutine.resume(coroutine.create(function()
		--		while epilepsy == true do
		--			if game.Lighting.remimpactframe.Brightness == 25 then
		--				game.Lighting.remimpactframe.Brightness = -25
		--				game.Lighting.remimpactframe.Contrast = -80
		--			else
		--				game.Lighting.remimpactframe.Brightness = 25
		--				game.Lighting.remimpactframe.Contrast = 80
		--			end
		--			wait() 
		--		end
		--	end))
		--end)
		local map 
		if game.ReplicatedStorage:FindFirstChild("Map") then
			map = game.ReplicatedStorage.Map
		else
			map = workspace.Map
		end
		local doingthathang = true
		local superback
		task.delay(497/60,function()
			coroutine.resume(coroutine.create(function()
				local time1 = 1
				for _,v in pairs((workspace:FindFirstChild("YukarinStation") or Instance.new("Folder")):GetChildren()) do
					if v:IsA("BasePart") then
						if v.Transparency == 55 then
							v.Transparency = 0
						end
					end
					if v:IsA("Folder") then
						for _,v in pairs(v:GetDescendants()) do
							if v:IsA("BasePart") then
								if v.Transparency == 55 then
									v.Transparency = 0
								end
							end
						end
					end
					if v:IsA("Model") then
						for _,v in pairs(v:GetDescendants()) do
							if v:IsA("BasePart") then
								if v.Transparency == 55 then
									v.Transparency = 0
								end
							end
						end
					end
				end
				for _,v in pairs(map:GetChildren()) do
					if v:IsA("BasePart") then
						if v.Transparency == 55 then
							v.Transparency = 0
						end
					end
					if v:IsA("Folder") then
						for _,v in pairs(v:GetDescendants()) do
							if v:IsA("BasePart") then
								if v.Transparency == 55 then
									v.Transparency = 0
								end
							end
						end
					end
					if v:IsA("Model") and v.Name == ("FixedTreeReplacer") or v.Name == ("TerrainPart") then
						for _,v in pairs(v:GetDescendants()) do
							if v:IsA("BasePart") then
								if v.Transparency == 55 then
									v.Transparency = 0
								end
							end
						end
					end
				end
				for i = 0, 1, .1 do
					superback.Beam.Transparency = NumberSequence.new(i,1)
					superback.Transparency = i + .1

					wait()

				end
				doingthathang = false
			end))
		end)
		task.delay(418/60,function()
			doingthathang = true
			--task.delay(.41,function()
			coroutine.resume(coroutine.create(function()
				for _,v in pairs((workspace:FindFirstChild("YukarinStation") or Instance.new("Folder")):GetChildren()) do
					if v:IsA("BasePart") then
						if v.Transparency == 0 then
							v.Transparency = 55
						end
					end
					if v:IsA("Folder") then
						for _,v in pairs(v:GetDescendants()) do
							if v:IsA("BasePart") then
								if v.Transparency == 0 then
									v.Transparency = 55
								end
							end
						end
					end
					if v:IsA("Model") then
						for _,v in pairs(v:GetDescendants()) do
							if v:IsA("BasePart") then
								if v.Transparency == 0 then
									v.Transparency = 55
								end
							end
						end
					end
				end
				for _,v in pairs(map:GetChildren()) do
					if v:IsA("BasePart") then
						if v.Transparency == 0 then
							v.Transparency = 55
						end
					end
					if v:IsA("Folder") then
						for _,v in pairs(v:GetDescendants()) do
							if v:IsA("BasePart") then
								if v.Transparency == 0 then
									v.Transparency = 55
								end
							end
						end
					end
					if v:IsA("Model") and v.Name == ("FixedTreeReplacer") or v.Name == ("TerrainPart") then
						for _,v in pairs(v:GetDescendants()) do
							if v:IsA("BasePart") then
								if v.Transparency == 0 then
									v.Transparency = 55
								end
							end
						end
					end
				end
				local enabled265 = true
				superback = game.ReplicatedStorage.Assets.kobackremilia:Clone()
				superback.Parent = workspace.Ignore.Effects
				for i,v in pairs(superback:GetDescendants()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA('ParticleEmitter')then
							v:Emit(v:GetAttribute("EmitCount") or 1)
						end
					end))
				end
				for i,v in pairs(superback:GetDescendants()) do
					coroutine.resume(coroutine.create(function()
						if v:IsA('ParticleEmitter') and v.Enabled == true then
							v.Enabled = false
							while enabled265 == true do
								local rate = v.Rate
								--if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Reduced Visuals").Value == true then
									rate = v.Rate / 2
								--end
								wait(1/rate)
								v:Emit(1)
							end
						end
					end))
				end
				while doingthathang == true do
					superback.CFrame = camrig.Bone.CFrame * CFrame.new(0,0,-31)
					RunService.Heartbeat:Wait() 
				end
				enabled265 = false
				superback:Destroy()
			end))
		end)
		local anim = camrig.AnimationController:LoadAnimation(script.cam)
		anim:Play()
		game:GetService("TweenService"):Create(Camera, TweenInfo.new(843/60, Enum.EasingStyle.Linear), {FieldOfView = 70}):Play()
		wait(844/60)
		workspace.CurrentCamera.FieldOfView = 70
		game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,true)
		require(game.ReplicatedStorage.Packages.Knit).Hud.Enabled = true
		done = true
		cam.CameraType = Enum.CameraType.Custom
		camrig:Destroy()
	end,
}
