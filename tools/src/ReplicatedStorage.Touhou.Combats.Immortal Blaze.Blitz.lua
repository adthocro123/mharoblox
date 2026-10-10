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
		local camrig = game.ReplicatedStorage.Assets["CameraRig"]:Clone()
		camrig.RootPart.CFrame = character.HumanoidRootPart.CFrame * CFrame.new(-0.809, 1.847, 0)
		camrig.Parent = character
		cam.CameraType = Enum.CameraType.Scriptable
		game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,false)
		require(game.ReplicatedStorage.Packages.Knit).Hud.Enabled = false
		local anim = camrig.AnimationController:LoadAnimation(script.cam)
		anim:Play(0)
		local done = false
		local Val = Instance.new("NumberValue")
		Val.Name = "AutoRotate"
		Val.Parent = character.Values
		Camera.FieldOfView = 30
		game:GetService("TweenService"):Create(Camera, TweenInfo.new(10/60, Enum.EasingStyle.Linear), {FieldOfView = 70}):Play()
		task.delay(213/60,function()
			Camera.FieldOfView = 70
			game:GetService("TweenService"):Create(Camera, TweenInfo.new(45/60, Enum.EasingStyle.Sine), {FieldOfView = 60}):Play()
		end)
		task.delay(328/60,function()
			Camera.FieldOfView = 60
			game:GetService("TweenService"):Create(Camera, TweenInfo.new(2/60, Enum.EasingStyle.Linear), {FieldOfView = 70}):Play()
		end)
		task.delay(535/60,function()
			Camera.FieldOfView = 70
			game:GetService("TweenService"):Create(Camera, TweenInfo.new(10/60, Enum.EasingStyle.Linear), {FieldOfView = 30}):Play()
		end)
		local cframe1 = CFrame.new(-0.809, 1.847, 0)
		--local EventAction = anim:GetMarkerReachedSignal("ChangeCam"):Connect(function(value)
		--	cframe1 = CFrame.new(1, 4, 0)
		--	Camera.FieldOfView = 55
		--	game:GetService("TweenService"):Create(Camera, TweenInfo.new(190/60, Enum.EasingStyle.Sine), {FieldOfView = 15}):Play()
		--end)
		task.delay(710/60,function()
			Camera.FieldOfView = 30
			game:GetService("TweenService"):Create(Camera, TweenInfo.new(190/60, Enum.EasingStyle.Sine), {FieldOfView = 65}):Play()
		end)
		local map 
		if game.ReplicatedStorage:FindFirstChild("Map") then
			map = game.ReplicatedStorage.Map
		else
			map = workspace.Map
		end
		local doingthathang = true
		local superback
		task.delay(533/60,function()
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
		task.delay(327/60,function()
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
				superback = game.ReplicatedStorage.Assets.koback:Clone()
				superback.Parent = workspace.Ignore.Effects
				while doingthathang == true do
					superback.CFrame = camrig.Bone.CFrame * CFrame.new(0,0,-31)
					RunService.Heartbeat:Wait() 
				end
				superback:Destroy()
			end))
		end)
		task.spawn(function()
			while not done do
				camrig.RootPart.CFrame = character.HumanoidRootPart.CFrame * cframe1
				cam.CFrame = camrig.Bone.CFrame * CFrame.new(0,0,-.2)
				RunService.Heartbeat:Wait() 
			end
			Val:Destroy()
		end)
		--local deffov = Camera.FieldOfView
		--Camera.FieldOfView = 80
		--task.delay(167/60,function()
		--	local epilepsy = true
		--	task.delay((230/60) - (167/60),function()
		--		epilepsy = false
		--		game.Lighting.remimpactframe.Enabled = false
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
		wait(919/60)
		--if EventAction ~= nil then
		--	EventAction:Disconnect()
		--end
		require(game.ReplicatedStorage.Packages.Knit).Hud.Enabled = true
		game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,true)
		workspace.CurrentCamera.FieldOfView = 70
		--game:GetService("TweenService"):Create(Camera, TweenInfo.new(.5, Enum.EasingStyle.Linear), {FieldOfView = deffov}):Play()
		done = true
		cam.CameraType = Enum.CameraType.Custom
		camrig:Destroy()
	end,
}
