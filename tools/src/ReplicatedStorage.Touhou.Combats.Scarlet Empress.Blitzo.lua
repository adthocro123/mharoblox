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
		local savedCF = character.HumanoidRootPart.CFrame:ToObjectSpace(Camera.CFrame) 
		local wait = task.wait
		local camrig = game.ReplicatedStorage.Assets["CamRigWithLe32tterBox 1"]:Clone()
		camrig.RootPart.CFrame = character.HumanoidRootPart.CFrame * CFrame.new(0.152, -2.949, -3.164)
		camrig.Parent = character
		cam.CameraType = Enum.CameraType.Scriptable
		require(game.ReplicatedStorage.Packages.Knit).Hud.Enabled = false
		game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,false)
		local done = false
		local Val = Instance.new("NumberValue")
		Val.Name = "AutoRotate"
		Val.Parent = character.Values
		task.spawn(function()
			while not done do
				camrig.RootPart.CFrame = character.HumanoidRootPart.CFrame * CFrame.new(0.152, -2.949, -3.164)
				cam.CFrame = camrig.camera.CFrame --* CFrame.new(0,0,-1.3)
				RunService.Heartbeat:Wait() 
			end
		end)
		local deffov = Camera.FieldOfView
		game:GetService("TweenService"):Create(Camera, TweenInfo.new(.4, Enum.EasingStyle.Linear), {FieldOfView = 100}):Play()
		task.delay(385/60,function()
			local timer = 1.4
			game.TweenService:Create(game.Lighting.remiframe2,TweenInfo.new(timer,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,0,false,0),{TintColor = Color3.fromRGB(255,255,255),Brightness = 0,Contrast = 0,Saturation = 0}):Play()
			task.delay(timer,function()
				game.Lighting.remiframe2.Enabled = false
			end)
		end)
		task.delay(8/60,function()
			game.Lighting.remiframe2.Brightness = 25
			game.Lighting.remiframe2.Contrast = 80
			game.Lighting.remiframe2.Saturation = -1
			game.Lighting.remiframe2.TintColor = Color3.fromRGB(255,12,12)
			game.Lighting.remiframe2.Enabled = true
			--task.delay((52/60) - (8/60),function()
			game.TweenService:Create(game.Lighting.remiframe2,TweenInfo.new((52/60) - (8/60),Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,0,false,0),{TintColor = Color3.fromRGB(255,46,46),Brightness = 1,Contrast = 3,Saturation = -1}):Play()

			--end)
		end)
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
		anim:Play()
		wait(58/60)
		game:GetService("TweenService"):Create(Camera, TweenInfo.new(.5, Enum.EasingStyle.Linear), {FieldOfView = deffov}):Play()
		done = true
		local originalCF = character.HumanoidRootPart.CFrame * savedCF -- Multiply heads cframe by our saved cframe.

		game:GetService("TweenService"):Create(Camera, TweenInfo.new(.5, Enum.EasingStyle.Linear), {CFrame = originalCF}):Play()
		task.delay(.5,function()
			Val:Destroy()
			cam.CameraType = Enum.CameraType.Custom
		end)
		workspace.CurrentCamera.FieldOfView = 70
		require(game.ReplicatedStorage.Packages.Knit).Hud.Enabled = true
		game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,true)
		camrig:Destroy()
	end,
}
