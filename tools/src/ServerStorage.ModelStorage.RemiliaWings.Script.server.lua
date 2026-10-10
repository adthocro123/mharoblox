local humanoid = script.Parent.AnimationController
local anim = humanoid:LoadAnimation(script.Animation)
anim:Play()
local S = script.Parent.Parent:WaitForChild("HumanoidRootPart")
local dead = false
local Current_Force_Yn
--script.Parent.Parent.Humanoid.HealthChanged:Connect(function()
--	if script.Parent.Parent.Humanoid.Health <= 0 then
--		if dead == false then
--			Current_Force_Yn = 10
--			dead = true
--		end
--	end
--end)
--while wait(.1) do 
--	if script.Parent.default.Transparency == 0 then
--		if (dead == true) then
--			dead = true
--			if Current_Force_Yn <= 0 then
--				Current_Force_Yn = 0
--			else
--				Current_Force_Yn -= .1
--			end
--			anim:AdjustSpeed(Current_Force_Yn/16)
--		else
--			function Get_Velocity(_,a)
--				local _=_.Velocity
--				if a then 
--					_=Vector3.new(_.X,0,_.Z)
--				end
--				return math.sqrt(_.X^2+_.Y^2+_.Z^2)
--			end
--			Current_Force_Yn=Get_Velocity(S,true)
--			if script.Parent.Parent:FindFirstChild("INAIRREMILIAWINGS") then
--				Current_Force_Yn = 30
--			end
--			if Current_Force_Yn <= 2 then
--				anim:AdjustSpeed(1)
--			elseif Current_Force_Yn >= 25 then
--				Current_Force_Yn = 55
--				anim:AdjustSpeed(Current_Force_Yn/16)
--			else
--				anim:AdjustSpeed(Current_Force_Yn/20)
--			end
--		end
--	end
--end
