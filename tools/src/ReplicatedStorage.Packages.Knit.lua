-- (round 107) A stand-in for Knit, the framework the owner's Touhou place is
-- built on. Its effect modules (ReplicatedStorage.Touhou.Combats) require it
-- for very little:
--   GetController("AnimationController"): stopAnimation(anim, fade) on your
--     own body, playAnimationRINNOSUKE(model, anim, speed, looped, fade) on an
--     afterimage;
--   Loaded;
--   Hud: its HUD (PlayerGui.AwakeningBar there), hidden through its
--     cutscenes - here the game's own screens (Hud.Enabled = false hides
--     every screen showing, true brings back the ones it hid).
local Players = game:GetService("Players")

local Knit = { Loaded = true, Player = Players.LocalPlayer }

local function animatorOf(model)
	local holder = model and (model:FindFirstChildOfClass("Humanoid") or model:FindFirstChildOfClass("AnimationController"))
	if not holder then
		return nil
	end
	local animator = holder:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = holder
	end
	return animator
end

local controllers = {
	AnimationController = {
		stopAnimation = function(_, animation, fade)
			local me = Players.LocalPlayer
			local animator = animatorOf(me and me.Character)
			if not (animator and animation) then
				return
			end
			for _, track in animator:GetPlayingAnimationTracks() do
				if track.Animation and track.Animation.AnimationId == animation.AnimationId then
					track:Stop(fade)
				end
			end
		end,
		playAnimationRINNOSUKE = function(_, model, animation, speed, looped, fade)
			local animator = animatorOf(model)
			if not (animator and animation) then
				return nil
			end
			local ok, track = pcall(function()
				return animator:LoadAnimation(animation)
			end)
			if not ok or not track then
				return nil
			end
			track.Looped = looped == true
			track:Play(fade)
			if speed then
				track:AdjustSpeed(speed)
			end
			return track
		end,
	},
}

function Knit.GetController(name)
	return controllers[name] or {}
end

function Knit.GetService()
	return {}
end

Knit.Hud = setmetatable({}, {
	__newindex = function(_, key, value)
		if key ~= "Enabled" then
			return
		end
		local me = Players.LocalPlayer
		local gui = me and me:FindFirstChildOfClass("PlayerGui")
		if not gui then
			return
		end
		for _, g in gui:GetChildren() do
			if g:IsA("ScreenGui") then
				if value == false and g.Enabled then
					g.Enabled = false
					g:SetAttribute("TouhouHid", true)
				elseif value ~= false and g:GetAttribute("TouhouHid") then
					g.Enabled = true
					g:SetAttribute("TouhouHid", nil)
				end
			end
		end
	end,
	__index = function(_, key)
		if key == "Enabled" then
			return true
		end
		return nil
	end,
})

return Knit
