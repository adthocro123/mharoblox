tool = script.Parent
while not tool:FindFirstChild("WeldProfile") do wait() end
profile = tool.WeldProfile
function reweld()
	for k, v in pairs(profile:GetChildren()) do
		local b = v.Value
		b:BreakJoints()
		local w = Instance.new("ManualWeld")
		w.Name = "HandleWeld"
		w.Part0 = b
		w.Part1 = profile.Value
		w.C0 = v.C0.Value
		w.C1 = v.C1.Value
		w.Parent = game.JointsService
	end
end
tool.AncestryChanged:connect(reweld)
reweld()
