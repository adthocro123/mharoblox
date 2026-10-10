# Round 107: every animation and sound Mokou and Remilia brought over from the
# owner's Touhou place - the ids a new account has to upload again (Roblox
# only plays an animation the game's owner owns, and a private sound only in
# a game it's shared with) - and where each one sits.
#   python3 -I ids107.py <built place.rbxl> <out.md> [<out.json>]
# The JSON is { "animations": {id: [paths]}, "sounds": {id: [paths]},
# "scripts": {id: [files]} }: the old ids, for swapping in the new ones
# (reupload107.md has the command-bar snippet that does it).
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'jjba'))
import rbxgraft  # noqa: E402

PLACE, OUT = sys.argv[1], sys.argv[2]
OUT_JSON = sys.argv[3] if len(sys.argv) > 3 else None
SPEC = json.load(open(os.path.join(HERE, 'graft107.json'), encoding='utf-8'))
SRC = os.path.join(HERE, '..', 'src')
FILES = json.load(open(os.path.join(HERE, 'port107_files.json'), encoding='utf-8'))

# what was grafted: the new folders, and each item under its new parent
ROOTS = [k[0] for k in SPEC['kit']] + [it[1] + '.' + it[0].split('.')[-1] for it in SPEC['items']]

rbxl, raw_chunks, decompress = rbxgraft._load_helpers(os.path.join(HERE, '..', 'place'))
P = rbxgraft.Place(PLACE, rbxl, raw_chunks, decompress)


def grafted(path):
    return any(path == r or path.startswith(r + '.') for r in ROOTS)


def asset_id(text):
    m = re.search(r'(\d{4,})', text or '')
    return m.group(1) if m else None


def collect(cls, prop):
    found = {}
    cid = P.cid_of.get(cls)
    if cid is None:
        return found
    _, vals = P.prop_values(cid, prop)
    for r, v in zip(P.classes[cid]['refs'], vals or []):
        path = P.path(r)
        if not grafted(path):
            continue
        i = asset_id(v[4:].decode('utf-8', 'replace'))
        if i:
            found.setdefault(i, []).append(path)
    return found


anims = collect('Animation', 'AnimationId')
sounds = collect('Sound', 'SoundId')

# ids written into the ported scripts themselves
scripts = {}
for f in FILES:
    text = open(os.path.join(SRC, f), encoding='utf-8').read()
    for m in re.finditer(r'(?:rbxassetid://|[?&]id=)(\d{4,})', text):
        scripts.setdefault(m.group(1), set()).add(f)
scripts = {k: sorted(v) for k, v in scripts.items()}


def who(paths):
    text = ' '.join(paths)
    mok = 'Immortal Blaze' in text or 'Mokou' in text
    rem = 'Scarlet Empress' in text or 'Remilia' in text or 'remilia' in text
    return 'both' if mok == rem else ('Mokou' if mok else 'Remilia')


def short(path):
    for a, b in (('ReplicatedStorage.Assets.Animations.', 'Animations.'), ('ReplicatedStorage.Assets.VFX.', 'VFX.'),
                 ('ServerStorage.Touhou.Attacks.', 'Attacks.'), ('ReplicatedStorage.', 'RS.'), ('ServerStorage.', 'SS.')):
        if path.startswith(a):
            return b + path[len(a):]
    return path


def table(found, title):
    lines = ['', '## ' + title, '', '| id | for | where (first of n) | n |', '|---|---|---|---|']
    order = sorted(found, key=lambda i: (who(found[i]), sorted(found[i])[0]))
    for i in order:
        paths = sorted(found[i])
        lines.append('| %s | %s | `%s` | %d |' % (i, who(paths), short(paths[0]), len(paths)))
    return lines


md = [
    '# Mokou and Remilia: the ids to upload again (round 107)',
    '',
    'Made by `tools/touhou/ids107.py` from the built place. %d animations, %d sounds, %d ids written in its scripts.'
    % (len(anims), len(sounds), len(scripts)),
    '',
    'Roblox plays an animation only in a game owned by the account (or group) that owns the animation,',
    'so every animation here has to be uploaded again from the account that owns Quirk Battlegrounds.',
    'A sound you uploaded yourself plays in a game it is shared with: either give Quirk Battlegrounds',
    'permission to use it from the old account (Creator Dashboard, the sound, Permissions) or upload it again.',
    "Sounds from Roblox's own library play anywhere and need nothing.",
    '',
    '## The quick way: `reupload_anims.py`',
    '',
    'It moves all of them with Roblox\'s own Open Cloud API: it downloads each one with the old account\'s',
    'key and uploads it with the new account\'s, then writes the Studio snippet that swaps the ids.',
    '',
    '1. Make two API keys at create.roblox.com/dashboard/credentials (Creator Dashboard, API Keys):',
    '   - signed in to the **old** account: add the API system **legacy-asset**, operation **manage**;',
    '   - signed in to the **new** account (or under the group, if a group owns the game): add the API',
    '     system **assets**, operations **Read** and **Write**.',
    '   Both: Accepted IP Addresses `0.0.0.0/0` (or your own IP), and an expiry date you like.',
    '2. Install Python 3 (python.org; tick "Add Python to PATH"), put `reupload_anims.py` in a folder,',
    '   and run `python reupload_anims.py` (or `py reupload_anims.py`) there.',
    '3. Paste each key when it asks (it won\'t show; it\'s never saved), and the new account\'s user id',
    '   (or the group\'s id).',
    '4. When it\'s done, open `reupload107/swap_animations.lua`, paste all of it into Studio\'s command bar',
    '   with Quirk Battlegrounds open, press Enter, and publish. (Or send `reupload107/map.json` - it has no',
    '   keys in it - and `tools/touhou/swap107.py` puts the new ids into the place file.)',
    '',
    'Stopped part-way, or some failed? Run it again: what\'s already done is skipped.',
    '',
    '## By hand in Studio (if the script can\'t)',
    '',
    '1. In Studio signed in to the **old** account, open the Touhou place and paste this into the command bar.',
    '   It fetches every animation as a KeyframeSequence into `ServerStorage.Reupload107`, named by its old id:',
    '',
    '```lua',
    'local ids = {%s}' % ', '.join(sorted(anims, key=int)),
    'local KSP = game:GetService("KeyframeSequenceProvider")',
    'local out = Instance.new("Folder"); out.Name = "Reupload107"; out.Parent = game.ServerStorage',
    'for _, id in ids do',
    '\tlocal ok, ks = pcall(function() return KSP:GetKeyframeSequenceAsync("rbxassetid://" .. id) end)',
    '\tif ok and ks then ks.Name = tostring(id); ks.Parent = out else warn("couldn\'t fetch", id, ks) end',
    'end',
    'print(#out:GetChildren(), "of", #ids)',
    '```',
    '',
    '2. Right-click `Reupload107`, Save to File. In Studio signed in to the **new** account, open Quirk',
    '   Battlegrounds, insert that file, and publish each KeyframeSequence (right-click, Save to Roblox).',
    '   Keep a note of new id against old id (the KeyframeSequence\'s name is the old id).',
    '3. Swap the ids everywhere with one command-bar paste (fill `MAP` as `[old] = new`):',
    '',
    '```lua',
    'local MAP = { --[[ [16941283510] = 123456789, ... ]] }',
    'local n = 0',
    'for _, d in game:GetDescendants() do',
    '\tlocal prop = d:IsA("Animation") and "AnimationId" or d:IsA("Sound") and "SoundId" or nil',
    '\tlocal old = prop and tonumber(string.match(d[prop], "%d+$"))',
    '\tif old and MAP[old] then d[prop] = "rbxassetid://" .. MAP[old]; n += 1 end',
    'end',
    'print(n, "ids swapped")',
    '```',
    '',
    'Anything left on an old id just doesn\'t play (the move still works).',
    '',
    'The two awakening songs are also set in `QuirkConfig` (`UltMusic.Tracks.Mokou` / `.Remilia`): change their `Id` there',
    'too. Until then each falls back to a Roblox-library track (its `Fallback`) when the song won\'t load.',
]
md += table(anims, 'Animations (%d)' % len(anims))
md += table(sounds, 'Sounds (%d)' % len(sounds))
if scripts:
    md += ['', '## Ids written in the scripts (%d)' % len(scripts), '',
           'These are in the code, not on an instance: the swap above doesn\'t reach them; search the script for the old id.', '',
           '| id | script |', '|---|---|']
    for i in sorted(scripts, key=int):
        md.append('| %s | `%s` |' % (i, short(scripts[i][0].rsplit('.', 1)[0].replace('.server', '').replace('.client', ''))))
open(OUT, 'w', encoding='utf-8').write('\n'.join(md) + '\n')
if OUT_JSON:
    json.dump({'animations': anims, 'sounds': sounds, 'scripts': scripts}, open(OUT_JSON, 'w', encoding='utf-8'), indent=1, sort_keys=True)
print('animations', len(anims), 'sounds', len(sounds), 'script ids', len(scripts), '->', OUT)
