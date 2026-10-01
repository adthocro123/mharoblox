local RunService = game:GetService('RunService')

local Player = game.Players.LocalPlayer
local Character = Player.Character
local Humanoid = Character:WaitForChild('Humanoid')
local HumanoidRootPart = Character:WaitForChild('HumanoidRootPart')
local Torso = Character:WaitForChild('Torso')

-- Original C0 Reference

local RootJointOriginalC0 = HumanoidRootPart.RootJoint.C0
local NeckOriginalC0 = Torso.Neck.C0
local RightHipOriginalC0 = Torso['Right Hip'].C0
local LeftHipOriginalC0 = Torso['Left Hip'].C0

local PlayersTable = {}

-- (patched for this game) a body that rescales (All Might's muscle form) keeps
-- its joints where they belong: the original offsets grow with the torso
local BaseTorsoHeight = Torso.Size.Y
local function Scaled(cf, torso)
	local k = torso.Size.Y / BaseTorsoHeight
	return CFrame.new(cf.Position * k) * cf.Rotation
end

--Customizable Settings

local RangeOfMotion = 45
local RangeOfMotionTorso = 90 - RangeOfMotion
local RangeOfMotionXZ = RangeOfMotion/140
local LerpSpeed = 0.005

--Main Code

RangeOfMotion = math.rad(RangeOfMotion)
RangeOfMotionTorso = math.rad(RangeOfMotionTorso)

function Calculate( dt, HumanoidRootPart, Humanoid, Torso )

	local DirectionOfMovement = HumanoidRootPart.CFrame:VectorToObjectSpace( HumanoidRootPart.AssemblyLinearVelocity )
	-- (patched) stunned bodies have WalkSpeed 0: never divide by it
	local Speed = math.max( Humanoid.WalkSpeed, 1 )
	DirectionOfMovement = Vector3.new( math.clamp(DirectionOfMovement.X / Speed, -1, 1), 0, math.clamp(DirectionOfMovement.Z / Speed, -1, 1) )

	local XResult = ( DirectionOfMovement.X * (RangeOfMotion - (math.abs( DirectionOfMovement.Z ) * (RangeOfMotion / 2) ) ) )
	local XResultTorso = ( DirectionOfMovement.X * (RangeOfMotionTorso - (math.abs( DirectionOfMovement.Z ) * (RangeOfMotionTorso / 2) ) ) )
	local XResultXZ = ( DirectionOfMovement.X * (RangeOfMotionXZ - (math.abs( DirectionOfMovement.Z ) * (RangeOfMotionXZ / 2) ) ) )

	if DirectionOfMovement.Z > 0.1 then

		XResult *= -1
		XResultTorso *= -1
		XResultXZ *= -1

	end

	if Humanoid.Health <= 0 or Humanoid.Parent:GetAttribute("Ragdolled") then
		return -- (patched) a limp body belongs to the ragdoll
	end
	local RightHipResult = Scaled(RightHipOriginalC0, Torso) * CFrame.new(-XResultXZ, 0, -math.abs(XResultXZ) + math.abs( -XResultXZ ) ) * CFrame.Angles( 0, -XResult, 0 )
	local LeftHipResult = Scaled(LeftHipOriginalC0, Torso) * CFrame.new(-XResultXZ, 0, -math.abs(-XResultXZ) + math.abs( -XResultXZ ) ) * CFrame.Angles( 0, -XResult, 0 )
	local RootJointResult = Scaled(RootJointOriginalC0, Torso) * CFrame.Angles( 0, 0, -XResultTorso )
	local NeckResult = Scaled(NeckOriginalC0, Torso) * CFrame.Angles( 0, 0, XResultTorso )

	local LerpTime = 1 - LerpSpeed ^ dt

	Torso['Right Hip'].C0 = Torso['Right Hip'].C0:Lerp(RightHipResult, LerpTime)
	Torso['Left Hip'].C0 = Torso['Left Hip'].C0:Lerp(LeftHipResult, LerpTime)
	HumanoidRootPart.RootJoint.C0 = HumanoidRootPart.RootJoint.C0:Lerp(RootJointResult, LerpTime)
	Torso.Neck.C0 = Torso.Neck.C0:Lerp(NeckResult, LerpTime)

end

RunService.RenderStepped:Connect(function(dt)

	for _, Player in game.Players:GetPlayers() do

		if Player.Character == nil then continue end
		if table.find( PlayersTable, Player ) then continue end
		table.insert(PlayersTable, Player)

	end

	for i, Player in pairs(PlayersTable) do

		if Player == nil then

			table.remove( PlayersTable, i )
			continue

		end


		if game.Players:FindFirstChild(Player.Name) == nil then

			table.remove( PlayersTable, i )
			continue

		end


		if Player.Character == nil then

			table.remove( PlayersTable, i )
			continue

		end

		local HumanoidRootPart = Player.Character:FindFirstChild('HumanoidRootPart')
		local Humanoid = Player.Character:FindFirstChild('Humanoid')
		local Torso = Player.Character:FindFirstChild('Torso')

		if HumanoidRootPart == nil or Humanoid == nil or Torso == nil then
			continue
		end

		Calculate(dt, HumanoidRootPart, Humanoid, Torso)

	end

end)