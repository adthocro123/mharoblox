# Round 107: who owns each of Mokou's and Remilia's animations on Roblox
# (Roblox's public asset details: economy.roblox.com/v2/assets/<id>/details),
# grouped by owner - the list to send whoever can grant Quirk Battlegrounds
# permission to use them (Creator Dashboard, the animation, Permissions,
# Experiences), so nothing has to be uploaded again.
#   python3 -I owners107.py <ids107.json from ids107.py> <out.md> [<cache.json>]
import collections
import json
import os
import sys
import time
import urllib.request

IDS, OUT = sys.argv[1], sys.argv[2]
CACHE = sys.argv[3] if len(sys.argv) > 3 else None
anims = json.load(open(IDS, encoding='utf-8'))['animations']

owners = json.load(open(CACHE, encoding='utf-8')) if CACHE and os.path.exists(CACHE) else {}
for i in sorted(anims, key=int):
    if i in owners and 'error' not in owners[i]:
        continue
    for attempt in range(4):
        try:
            with urllib.request.urlopen('https://economy.roblox.com/v2/assets/%s/details' % i, timeout=20) as r:
                d = json.loads(r.read())
            c = d.get('Creator') or {}
            owners[i] = {'name': d.get('Name'), 'type': c.get('CreatorType'), 'creator': c.get('Name'),
                         'creatorId': c.get('CreatorTargetId'), 'created': d.get('Created')}
            break
        except Exception as e:  # (a rate limit or a hiccup: try again a little later)
            owners[i] = {'error': str(e)}
            time.sleep(3 * (attempt + 1))
    time.sleep(0.35)
if CACHE:
    json.dump(owners, open(CACHE, 'w', encoding='utf-8'), indent=1)


def short(path):
    for a, b in (('ReplicatedStorage.Assets.Animations.', ''), ('ReplicatedStorage.Assets.', ''),
                 ('ReplicatedStorage.Touhou.Combats.', 'Touhou.Combats.'), ('ServerStorage.ModelStorage.', '')):
        if path.startswith(a):
            return b + path[len(a):]
    return path


by = collections.defaultdict(list)
for i, o in owners.items():
    key = (o.get('type') or '?', o.get('creator') or 'unknown (lookup failed)', o.get('creatorId'))
    by[key].append(i)

order = sorted(by, key=lambda k: -len(by[k]))
md = ['# Who owns Mokou\'s and Remilia\'s animations (round 107)', '',
      'From Roblox\'s public asset details, made by `tools/touhou/owners107.py`. %d animations.' % len(owners), '',
      'An animation only plays in a game its owner allows. Whoever controls each owner below can let Quirk',
      'Battlegrounds use theirs without uploading anything again:', '',
      '1. Creator Dashboard (create.roblox.com/dashboard/creations), **Development Items**, **Animations**',
      '   (for a group: switch to the group first; it needs someone with the right permissions in it).',
      '2. Pick the animation, then **Permissions** in the left-hand menu, the **Experiences** tab.',
      '3. **Add experiences**, type Quirk Battlegrounds\' **universe ID**, **Add**, **Done**.',
      '   (The universe ID is on the game\'s Creator Dashboard page; it isn\'t the place ID in the game\'s link.)',
      '',
      'Or, for a group: a game owned by that same group plays the group\'s animations as they are.', '',
      '| owner | type | animations |', '|---|---|---|']
for k in order:
    t, name, cid = k
    link = ('roblox.com/communities/%s' % cid) if t == 'Group' else ('roblox.com/users/%s/profile' % cid)
    md.append('| %s (%s) | %s | %d |' % (name, link if cid else '?', t, len(by[k])))
for k in order:
    t, name, cid = k
    md += ['', '## %s (%s, %d)' % (name, t.lower(), len(by[k])), '', '| id | its name on Roblox | where it\'s used |', '|---|---|---|']
    for i in sorted(by[k], key=int):
        md.append('| %s | %s | `%s` |' % (i, (owners[i].get('name') or '').strip().replace('|', '/'),
                                          short(sorted(anims[i])[0])))
open(OUT, 'w', encoding='utf-8').write('\n'.join(md) + '\n')
print(', '.join('%s %s: %d' % (k[0], k[1], len(by[k])) for k in order), '->', OUT)
