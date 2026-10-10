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
local function orangevignette()
	local vignet = game.ReplicatedStorage.Assets.Vignette:Clone()
	vignet.ImageLabel.ImageColor3 = Color3.fromRGB(255, 60, 0)
	vignet.Parent = game.Players.LocalPlayer.PlayerGui
	game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(8/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = .65}):Play()
	task.delay(7/60,function()
		game.Debris:AddItem(vignet,14/60)
		game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(14/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = 1}):Play()
	end)
end
local function flasheffect()
	coroutine.resume(coroutine.create(function()
		local vignet = game.ReplicatedStorage.Assets.Vignette:Clone()
	vignet.ImageLabel.BackgroundTransparency = Color3.fromRGB(255, 255, 255)
	vignet.ImageLabel.BackgroundTransparency = 0
	vignet.ImageLabel.ImageColor3 = Color3.fromRGB(0, 0, 0)
	vignet.Parent = game.Players.LocalPlayer.PlayerGui
	vignet.ImageLabel.ImageTransparency = .8
		game.Debris:AddItem(vignet,10/60)
	game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(10/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = 1,BackgroundTransparency = 1}):Play()
end))
end
local function flasheffect2()
coroutine.resume(coroutine.create(function()
	local vignet = game.ReplicatedStorage.Assets.Vignette:Clone()
	vignet.ImageLabel.BackgroundTransparency = Color3.fromRGB(255, 255, 255)
	vignet.ImageLabel.BackgroundTransparency = .05
	vignet.ImageLabel.ImageColor3 = Color3.fromRGB(0, 0, 0)
	vignet.Parent = game.Players.LocalPlayer.PlayerGui
	vignet.ImageLabel.ImageTransparency = .8
	game.Debris:AddItem(vignet,7/60)
	game:GetService("TweenService"):Create(vignet.ImageLabel, TweenInfo.new(7/60, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {ImageTransparency = 1,BackgroundTransparency = 1}):Play()
end))
end
local ExtraEffect = game.Lighting.MokouCinematic
return {
	['Cutscene'] = function(character)
		if game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings"):WaitForChild("Cutscenes").Value == false then return end
		local wait = task.wait
		local camrig = game.ReplicatedStorage.Assets["CameraRig"]:Clone()
		camrig.RootPart.CFrame = character.HumanoidRootPart.CFrame * CFrame.new(12.6, 2.6, -1.6)
		local EventAction 
		camrig.Parent = character
		cam.CameraType = Enum.CameraType.Scriptable
		camrig["Bone.001"].Transparency = 1
		camrig["Bone.002"].Transparency = 1
		require(game.ReplicatedStorage.Packages.Knit).Hud.Enabled = false
		game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,false)
		local done = false
		task.spawn(function()
			while not done do
				camrig.RootPart.CFrame = character.HumanoidRootPart.CFrame * CFrame.new(12.6, 2.6, -1.6)
				cam.CFrame = camrig.Bone.CFrame * CFrame.new(0,0,-1)
				RunService.Heartbeat:Wait() 
			end
		end)
		local anim = camrig.AnimationController:LoadAnimation(script.cam)
		anim:Play(0)
		local first = true
		EventAction = anim:GetMarkerReachedSignal("FlashEffect"):Connect(function(value)
			flasheffect()
		end)
		local map 
		if game.ReplicatedStorage:FindFirstChild("Map") then
			map = game.ReplicatedStorage.Map
		else
			map = workspace.Map
		end
		local doingthathang = true
		task.delay(252/60,function()
			ExtraEffect.Enabled = true
			game:GetService("TweenService"):Create(workspace.CurrentCamera,TweenInfo.new(.4),{FieldOfView = 105}):Play()
			game:GetService("TweenService"):Create(ExtraEffect,TweenInfo.new(.4),{Contrast = 0.25, Saturation = -1, Brightness = -0.1,TintColor = Color3.fromRGB(175, 192, 255)}):Play()
			doingthathang = true
			--task.delay(.41,function()
				coroutine.resume(coroutine.create(function()
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
					local superback = game.ReplicatedStorage.Assets.superback:Clone()
					superback.Parent = workspace.Ignore.Effects
					while doingthathang == true do
						superback.CFrame = camrig.Bone.CFrame * CFrame.new(0,0,-20)
						RunService.Heartbeat:Wait() 
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
					superback:Destroy()
				end))
			--end)
		end)
		wait(352/60)
		if EventAction ~= nil then
			EventAction:Disconnect()
		end
		game:GetService("TweenService"):Create(ExtraEffect,TweenInfo.new(.3),{Contrast = 0, Saturation = 0, Brightness = 0,TintColor = Color3.fromRGB(255,255,255)}):Play()
		game:GetService("TweenService"):Create(workspace.CurrentCamera,TweenInfo.new(.55),{FieldOfView = 70}):Play()
		doingthathang = false
		task.delay(.75,function()
			ExtraEffect.Enabled = false
		end)
		require(game.ReplicatedStorage.Packages.Knit).Hud.Enabled = true
		game.StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,true)
		done = true
		flasheffect2()
		cam.CameraType = Enum.CameraType.Custom
		camrig:Destroy()
	end,
}
