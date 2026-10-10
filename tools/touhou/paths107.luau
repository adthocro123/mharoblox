-- Round 107: every place the Touhou place's ported scripts reach for by name
-- (game.ReplicatedStorage.Assets.VFX["Immortal Blaze"].Combat.Hit ...) is in
-- the built place - as far as each chain is spelled out (a name worked out
-- at run time, like ['h'..math.random(1,4)], ends it).
--   lune run paths107.luau <place.rbxl> <tools/src> <port107_files.json>
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local game = roblox.deserializePlace(fs.readFile(process.args[1]))
local src = process.args[2]
local files = serde.decode("json", fs.readFile(process.args[3]))

-- made at run time (the server's Kit.TH, the game, a body): not in the file
local RUNTIME = { ["Workspace.Ignore"] = true, ["Workspace.CurrentCamera"] = true, ["Workspace.Terrain"] = true, ["Workspace.Map"] = true }
-- the names its place itself never had, each where nothing reaches it or a
-- failure is caught (its Skill1's kick11 sound: the hit callback, TH.call)
local KNOWN = {
	-- Awakening.Special: the old ult 4 its AttackService never maps (unreachable)
	["ReplicatedStorage.Assets.Animations.Characters.Immortal Blaze.Special.Victim"] = true,
	["ServerStorage.BambooBomb"] = true,
	-- Skill1's hit sound: not in its place either
	["ReplicatedStorage.Assets.VFX.Immortal Blaze.Combat.kick11"] = true,
	-- Skill3Drill's Left / Right / Wind: no server script calls them
	["ReplicatedStorage.Assets.VFX.Immortal Blaze.FireTalonLeftSlash"] = true,
	["ReplicatedStorage.Assets.VFX.Immortal Blaze.FireTalonRightSlash"] = true,
	["ReplicatedStorage.Assets.VFX.Immortal Blaze.FireTalonWind"] = true,
	-- Blitz looks for it with FindFirstChild (and does without)
	["ReplicatedStorage.Map"] = true,
}
local IGNORE_MEMBERS = {
	Clone = true, FindFirstChild = true, WaitForChild = true, GetChildren = true, GetDescendants = true, Destroy = true,
	Play = true, Stop = true, FindFirstChildOfClass = true, IsA = true, GetAttribute = true, SetAttribute = true,
	Value = true, Enabled = true, Brightness = true, Contrast = true, Saturation = true, TintColor = true, Size = true,
	CFrame = true, Position = true, Parent = true, Name = true, Transparency = true, AnimationId = true, SoundId = true,
	Volume = true, PlaybackSpeed = true, TimePosition = true, Color = true, Orientation = true, Anchored = true,
	CanCollide = true, Material = true, LocalPlayer = true, Character = true, FieldOfView = true, Gravity = true,
}

local function lookup(chain)
	local node = game
	for i, name in chain do
		local c
		if node == game then
			local ok, s = pcall(function()
				return game:GetService(name)
			end)
			c = ok and s or nil
		else
			c = node:FindFirstChild(name)
		end
		if not c then
			return nil, i
		end
		node = c
	end
	return node
end

local missing, checked, seen, known = {}, 0, {}, 0
for _, file in files do
	local text = fs.readFile(src .. "/" .. file)
	-- (comments out)
	text = text:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\n]*", "")
	for start in text:gmatch("()game%.") do
		local chain = {}
		local pos = start + 5
		local rest = text:sub(pos, pos + 400)
		local i = 1
		while true do
			local name, after = rest:match("^([%a_][%w_]*)()", i)
			if name then
				table.insert(chain, name)
				i = after
			else
				local q, after2 = rest:match('^%[%s*"([^"]+)"%s*%]()', i)
				if not q then
					q, after2 = rest:match("^%[%s*'([^']+)'%s*%]()", i)
				end
				if not q then
					break
				end
				table.insert(chain, q)
				i = after2
			end
			local dot = rest:match("^%.()", i)
			if dot then
				i = dot
			elseif not rest:match("^%[", i) then
				break
			end
		end
		-- the service names Roblox spells differently
		if chain[1] == "Workspace" then
			chain[1] = "Workspace"
		end
		-- drop the trailing member (a property or a method)
		while #chain > 0 and IGNORE_MEMBERS[chain[#chain]] do
			table.remove(chain)
		end
		if #chain >= 2 and chain[1] ~= "Players" and chain[1] ~= "Debris" and chain[1] ~= "TweenService" then
			local key = table.concat(chain, ".")
			local runtime = false
			for prefix in RUNTIME do
				if key:sub(1, #prefix) == prefix then
					runtime = true
				end
			end
			if not seen[key] and not runtime then
				seen[key] = true
				checked += 1
				local node, at = lookup(chain)
				-- a member past an instance (a property we didn't list) is fine
				if not node and at and at > 2 then
					local parent = lookup(table.move(chain, 1, at - 1, 1, {}))
					if parent and not parent:IsA("Folder") and not parent:IsA("Model") and at == #chain then
						node = parent
					end
				end
				if not node and KNOWN[key] then
					known += 1
				elseif not node then
					table.insert(missing, key .. "   (" .. file .. ")")
				end
			end
		end
	end
end
table.sort(missing)
for _, m in missing do
	print("MISSING", m)
end
print(string.format("%d paths checked, %d missing (and %d its place never had, see KNOWN)", checked, #missing, known))
process.exit(#missing == 0 and 0 or 1)
