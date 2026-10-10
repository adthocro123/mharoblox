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
		local camrig = game.ReplicatedStorage.Assets["MJokUltCam"]:Clone()
		camrig.RootPart.CFrame = character.HumanoidRootPart.CFrame * CFrame.new(0.514, -3.779, -4.947)
		camrig.Parent = character
		cam.CameraType = Enum.CameraType.Scriptable
		camrig["letterboxbot"].Transparency = 1
		camrig["letterboxtop"].Transparency = 1
		require(game.ReplicatedStorage.Packages.Knit).Hud.Enabled = false
		game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,false)
	local done = false
		task.spawn(function()
			while not done do
				character.Humanoid.AutoRotate = false
				camrig.RootPart.CFrame = character.HumanoidRootPart.CFrame * CFrame.new(0.514, -3.779, -4.947)
				cam.CFrame = camrig.camera.CFrame --* CFrame.new(0,0,-1.3)
				RunService.Heartbeat:Wait() 
			end
			character.Humanoid.AutoRotate = true
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
		local anim = camrig.AnimationController:LoadAnimation(script.cam)
		anim:Play(0)
		wait(400/60)
		--game:GetService("TweenService"):Create(Camera, TweenInfo.new(.5, Enum.EasingStyle.Linear), {FieldOfView = deffov}):Play()
		workspace.CurrentCamera.FieldOfView = 70
		require(game.ReplicatedStorage.Packages.Knit).Hud.Enabled = true
		game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,true)
		done = true
		cam.CameraType = Enum.CameraType.Custom
		camrig:Destroy()
	end,
}
