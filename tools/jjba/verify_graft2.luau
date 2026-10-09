-- verify_graft2.luau <original.rbxl> <merged.rbxl> <source.rbxl> <spec.json> <excludeCSV>
-- 1. every instance of the original is in the merged place with the same
--    properties (same order, same values) - the grafted instances skipped
-- 2. each grafted subtree matches its source subtree (excluded classes /
--    names left out; the root renamed)
-- spec.json: { "items": [[srcPath, dstParentPath, newName|null, [extraExcludes]?], ...] }
local roblox = require("@lune/roblox")
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local args = process.args
local db = roblox.getReflectionDatabase()
local propCache = {}
local function propsOf(cls)
	if propCache[cls] then
		return propCache[cls]
	end
	local names, c = {}, db:GetClass(cls)
	while c do
		for name in c.Properties do
			table.insert(names, name)
		end
		c = c.Superclass and db:GetClass(c.Superclass) or nil
	end
	table.sort(names)
	propCache[cls] = names
	return names
end
local function describe(inst, refName)
	local out = { inst.ClassName }
	for _, p in propsOf(inst.ClassName) do
		if p ~= "Parent" then
			local ok, v = pcall(function()
				return inst[p]
			end)
			if ok then
				if typeof(v) == "Instance" then
					v = refName(v)
				end
				table.insert(out, p .. "=" .. tostring(v))
			end
		end
	end
	return table.concat(out, "|")
end
local function load(path)
	return roblox.deserializePlace(fs.readFile(path))
end
local function loadAny(path)
	local ok, g = pcall(load, path)
	if ok then
		return g, true
	end
	return roblox.deserializeModel(fs.readFile(path)), false
end
local orig, merged = load(args[1]), load(args[2])
local src, srcIsPlace = loadAny(args[3])
local spec = serde.decode("json", fs.readFile(args[4]))
local exclude = {}
for c in string.gmatch(args[5] or "", "[^,]+") do
	exclude[c] = true
end
local function find(root, path)
	local i = root
	for part in string.gmatch(path, "[^.]+") do
		if typeof(i) == "table" then
			local hit
			for _, x in i do
				if x.Name == part then
					hit = x
				end
			end
			i = hit
		elseif i then
			if i == root and srcIsPlace == false then
				i = nil
			else
				i = i:FindFirstChild(part)
			end
		end
	end
	return i
end
local function pathOf(i, root)
	local p = {}
	while i and i ~= root do
		table.insert(p, 1, i.Name)
		i = i.Parent
	end
	return table.concat(p, ".")
end
-- the grafted roots in the merged place: the last children of their parents
-- with the new (or the source's) name
local newRoots = {}
local pairsList = {}
for _, it in spec.items do
	local s = srcIsPlace and find(src, it[1]) or find(src, it[1])
	assert(s, "source missing: " .. it[1])
	local parent = find(merged, it[2])
	assert(parent, "target parent missing: " .. it[2])
	local name = it[3] or s.Name
	local cands = {}
	for _, k in parent:GetChildren() do
		if k.Name == name then
			table.insert(cands, k)
		end
	end
	local d = cands[#cands]
	assert(d, "grafted root missing: " .. it[2] .. "." .. name)
	newRoots[d] = true
	local ex = {}
	for _, e in it[4] or {} do
		ex[e] = true
	end
	table.insert(pairsList, { s = s, d = d, ex = ex, name = name })
end
local function walk(root, skip)
	local list = {}
	local function rec(i)
		for _, k in i:GetChildren() do
			if not (skip and skip[k]) then
				table.insert(list, k)
				rec(k)
			end
		end
	end
	rec(root)
	return list
end
local a = walk(orig)
local b = walk(merged, newRoots)
print("original instances", #a, "merged (old part)", #b)
assert(#a == #b, "instance count differs")
local bad = 0
for i = 1, #a do
	local da = describe(a[i], function(v)
		return pathOf(v, orig)
	end)
	local dbb = describe(b[i], function(v)
		return pathOf(v, merged)
	end)
	if da ~= dbb then
		bad += 1
		if bad <= 5 then
			print("DIFF", pathOf(a[i], orig), "\n  " .. da:sub(1, 300), "\n  " .. dbb:sub(1, 300))
		end
	end
end
print("old instances differing:", bad)
local bad2, n2 = 0, 0
for _, pr in pairsList do
	local function keep(i, isRoot)
		return isRoot or not (exclude[i.ClassName] or pr.ex[i.ClassName] or pr.ex[i.Name])
	end
	local function walk2(root)
		local list = { root }
		local function rec(i)
			for _, k in i:GetChildren() do
				if keep(k, false) then
					table.insert(list, k)
					rec(k)
				end
			end
		end
		rec(root)
		return list
	end
	local la, lb = walk2(pr.s), walk2(pr.d)
	if #la ~= #lb then
		bad2 += 1
		print(("SIZE %s: %d vs %d"):format(pr.name, #la, #lb))
	else
		for i = 1, #la do
			n2 += 1
			local da = describe(la[i], function(v)
				return pathOf(v, pr.s.Parent)
			end)
			local dbb = describe(lb[i], function(v)
				return pathOf(v, pr.d.Parent)
			end)
			if i == 1 then
				da = da:gsub("|Name=[^|]*", "")
				dbb = dbb:gsub("|Name=[^|]*", "")
			end
			if pr.name ~= pr.s.Name then
				dbb = dbb:gsub(pr.name, pr.s.Name)
			end
			if da ~= dbb then
				bad2 += 1
				if bad2 <= 5 then
					print("GDIFF", pr.name, pathOf(la[i], pr.s), "\n  " .. da:sub(1, 400), "\n  " .. dbb:sub(1, 400))
				end
			end
		end
	end
end
print("grafted instances checked", n2, "differing", bad2)
