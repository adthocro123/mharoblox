local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local game = roblox.deserializePlace(fs.readFile(process.args[1]))
local rs = game:GetService("ReplicatedStorage")
local anims = rs:FindFirstChild("Animations")
print("Animations:", anims and anims.ClassName, anims and #anims:GetChildren())
for _, ks in anims:GetChildren() do
	local n, hit = 0, nil
	for _, kf in ks:GetChildren() do
		n += 1
		if kf.Name == "Hit" then
			hit = kf.Time
		end
	end
	local kf = ks:FindFirstChild("Hit")
	local ra = kf and kf.HumanoidRootPart.Torso["Right Arm"]
	print(ks.Name, n, "keys; hit at", hit, ra and ra.CFrame.Position, ra and ra.EasingStyle.Name, ra and ra.EasingDirection.Name)
end
local total = 0
for _ in game:GetDescendants() do
	total += 1
end
print("descendants", total)
print("shared still there:", rs:FindFirstChild("Shared") ~= nil, rs.Shared:FindFirstChild("VFX") ~= nil)
