script.Parent.AncestryChanged:Connect(function()
	script.Parent.sfx:Play()
	for i,v in pairs(script.Parent:GetDescendants()) do
		if v:IsA('ParticleEmitter') then
			v:Emit(v:GetAttribute('EmitCount'))
		end
	end
	script:Destroy()
end)
