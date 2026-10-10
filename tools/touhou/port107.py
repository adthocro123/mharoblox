# Round 107: the owner's Touhou place's scripts for Mokou (Immortal Blaze) and
# Remilia (Scarlet Empress), copied into tools/src at the paths they get in
# the game (graft107.json), so rbxl_write.py puts them in the place.
#   python3 -I port107.py <dumped sources of the Touhou place> <tools/src>
# Every one loses the "Powered by RoxzyFX ... discord" block the uploader
# stamped on the end of each script. The few lines that reach for things only
# the Touhou place has are pointed at the game's stand-ins (PATCHES: each one
# must match exactly as many times as it says, or this stops).
import json, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
SPEC = json.load(open(os.path.join(HERE, 'graft107.json'), encoding='utf-8'))
EXT = ('.server.lua', '.client.lua', '.lua')

# the uploader's stamp: a block comment from "Powered by RoxzyFX" to its end
STAMP = re.compile(r'\s*--\[\[\s*\n\s*Powered by RoxzyFX.*?\]\]\s*$', re.S)

BRIDGE = 'require(game.ServerStorage.Touhou.Bridge)'
KNIT = 'require(game.ReplicatedStorage.Packages.Knit)'
DATA = 'game.Players.LocalPlayer:WaitForChild("Data"):WaitForChild("Settings")'
# (new path suffix, old text, new text, how many times)
PATCHES = [
    # the server asked the mover's own machine where he was / where his mouse
    # was (RemoteFunctions): the game answers from the server (Bridge)
    ('Immortal Blaze.Awakening.Skill2.lua', 'game.ReplicatedStorage.Modules.GetLocalCharPosition', BRIDGE + '.GetLocalCharPosition', 1),
    ('Immortal Blaze.Awakening.Skill3.lua', 'game.ReplicatedStorage.Modules.GetLocalCharPosition', BRIDGE + '.GetLocalCharPosition', 1),
    ('Immortal Blaze.Awakening.Special.lua', 'game.ReplicatedStorage.Modules.GetLocalCharPosition', BRIDGE + '.GetLocalCharPosition', 1),
    ('Immortal Blaze.Special.lua', 'game.ReplicatedStorage.Modules.GetLocalCharPosition', BRIDGE + '.GetLocalCharPosition', 1),
    ('Scarlet Empress.Awakening.Special.lua', 'game.ReplicatedStorage.Modules.GetLocalCharPosition', BRIDGE + '.GetLocalCharPosition', 1),
    ('Scarlet Empress.Awakening.Special.lua', 'game.ReplicatedStorage.Modules.GetMouseHit', BRIDGE + '.GetMouseHit', 1),
    ('Scarlet Empress.Skill2.lua', 'game.ReplicatedStorage.Modules.GetLocalCharPosition', BRIDGE + '.GetLocalCharPosition', 1),
    ('Scarlet Empress.Special.lua', 'game.ReplicatedStorage.Modules.GetLocalCharPosition', BRIDGE + '.GetLocalCharPosition', 1),
    ('Scarlet Empress.Special.lua', 'game.ReplicatedStorage.Modules.GetMouseHit', BRIDGE + '.GetMouseHit', 1),
    # its jump physics module, moved in with the moves
    ('.lua', 'require(game.ServerScriptService.Other.SimJump)', 'require(game.ServerStorage.Touhou.SimJump)', None),
    # the bodies in a fight lived in workspace.Ignore.Entities there; here
    # they're wherever the game keeps them (Bridge.isEntity)
    ('Immortal Blaze.Awakening.Special.lua', 'part:IsDescendantOf(workspace.Ignore.Entities)', BRIDGE + '.isEntity(part)', 1),
    ('Immortal Blaze.Skill4.lua', 'part:IsDescendantOf(workspace.Ignore.Entities)', BRIDGE + '.isEntity(part)', 1),
    # a wall only its map had
    ('Scarlet Empress.Skill1.lua', 'workspace.nonsolidwall', '(workspace:FindFirstChild("nonsolidwall") or workspace.Ignore)', 1),
    # its "Character" collision group is the game's "Characters" (the bodies)
    ('.lua', "CollisionGroup = 'Character'", "CollisionGroup = 'Characters'", 42),
    # its train station, hidden in its cutscenes: not on this map
    ('.lua', 'workspace.YukarinStation:GetChildren()', '(workspace:FindFirstChild("YukarinStation") or Instance.new("Folder")):GetChildren()', None),
    # its HUD, hidden in its cutscenes: the game's HUD (the Knit stand-in's Hud)
    ('.lua', 'game.Players.LocalPlayer.PlayerGui.AwakeningBar', KNIT + '.Hud', 12),
    # its shop's heal sound
    ('downslamupthing.lua', 'game.Players.LocalPlayer.PlayerGui.ShopGui.Heal:Play()', 'pcall(function() game.Players.LocalPlayer.PlayerGui.ShopGui.Heal:Play() end)', 1),
]


def strip_stamp(src):
    out = STAMP.sub('\n', src)
    return out.rstrip() + '\n'


def scripts_under(srcdir, root):
    """dumped files for scripts at or under the dotted path root: (file, rest)"""
    for f in os.listdir(srcdir):
        for ext in EXT:
            if f.endswith(ext):
                p = f[:-len(ext)]
                if p == root:
                    yield f, '', ext
                elif p.startswith(root + '.'):
                    yield f, p[len(root) + 1:], ext
                break


def main(srcdir, outdir):
    written = {}
    for it in SPEC['items']:
        src, parent, newname = it[0], it[1], it[2]
        skip = set(it[3]) if len(it) > 3 else set()
        leaf = newname or src.split('.')[-1]
        for f, rest, ext in scripts_under(srcdir, src):
            if skip and any(seg in skip for seg in rest.split('.')):
                continue
            new = parent + '.' + leaf + ('.' + rest if rest else '') + ext
            text = open(os.path.join(srcdir, f), encoding='utf-8', errors='surrogateescape').read()
            written[new] = strip_stamp(text)
    for suffix, old, new, count in PATCHES:
        hits = 0
        for name in written:
            if name.endswith(suffix):
                n = written[name].count(old)
                if n:
                    written[name] = written[name].replace(old, new)
                    hits += n
        if count is not None and hits != count:
            sys.exit('patch %r in *%s: %d matches, expected %d' % (old, suffix, hits, count))
        print('patch %-60s %d' % (old[:60], hits))
    left = [n for n, s in written.items() if 'RoxzyFX' in s or 'discord.gg' in s]
    if left:
        sys.exit('stamp left in: %s' % left[:5])
    for name, text in sorted(written.items()):
        with open(os.path.join(outdir, name), 'w', encoding='utf-8', errors='surrogateescape') as fh:
            fh.write(text)
    json.dump(sorted(written), open(os.path.join(HERE, 'port107_files.json'), 'w'), indent=1)
    print(len(written), 'scripts ->', outdir)


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
