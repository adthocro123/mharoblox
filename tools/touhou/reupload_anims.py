# Round 107: Mokou's and Remilia's 185 animations, from the account that made
# them to the account that owns Quirk Battlegrounds - Roblox's own Open Cloud
# API, nothing else. Run it on your own computer (Python 3.8 or newer, no
# extra packages):
#
#   python reupload_anims.py      (on a Mac: python3 reupload_anims.py)
#
# It asks for two API keys (typed hidden, never saved anywhere):
#   1. the OLD account's key, with the API system "legacy-asset" and its
#      "manage" operation - to download each animation (Roblox's Asset
#      Delivery API: GET apis.roblox.com/asset-delivery-api/v1/assetId/<id>);
#   2. the NEW account's key, with the API system "assets" and its Read and
#      Write operations - to upload each one again (POST
#      apis.roblox.com/assets/v1/assets, assetType Animation).
# and the new account's user id (or the group's id, if a group owns the game).
#
# What it writes, next to itself:
#   reupload107/<old id>.rbxm      each animation as downloaded
#   reupload107/map.json           old id -> new id, saved after every upload
#   reupload107/swap_animations.lua  paste into Studio's command bar (in
#                                  Quirk Battlegrounds) to swap every old id
#                                  for its new one
# Run it again any time: what's already downloaded or uploaded is skipped, so
# a stop part-way (a rate limit, a lost connection) just picks up where it was.
#
#   python reupload_anims.py --download-only   (just step 1, old key only)
#   python reupload_anims.py --upload-only     (just step 2, new key only: the
#                                               .rbxm files already in reupload107/)
import argparse
import getpass
import gzip
import json
import os
import random
import string
import sys
import time
import urllib.error
import urllib.request

API = os.environ.get('REUPLOAD_API_BASE', 'https://apis.roblox.com')
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'reupload107')
MAP = os.path.join(OUT, 'map.json')
SNIPPET = os.path.join(OUT, 'swap_animations.lua')
# (Roblox allows 120 uploads a minute per key owner; animations have a
# tighter limit of their own - one every 2 s stays under both)
UPLOAD_GAP = float(os.environ.get('REUPLOAD_GAP', '2'))

# the old id -> a name for it on the new account (where it sits in the game)
ANIMATIONS = {
    "15695297816": "Immortal Blaze Awakening FantasySeal Camera",
    "15695395145": "Combats Immortal Blaze Idle",
    "15930242639": "Immortal Blaze Skill4 SuccessFinisher",
    "15930243864": "Immortal Blaze Skill4 VictimFinisher",
    "17029138699": "Immortal Blaze Skill3Fists Hold",
    "17029142737": "Immortal Blaze Skill3Fists ReleaseAir",
    "17312856852": "Combats Immortal Blaze Run",
    "17370044273": "ReactionsCrazy DashM1Reaction",
    "17373812220": "Immortal Blaze Skill2OLD InAir Smash",
    "17373814145": "Immortal Blaze Skill2OLD InAir Cast",
    "17409311963": "Immortal Blaze Awakening FantasySeal User",
    "17409403714": "Immortal Blaze Awakening Skill2OLD Hold",
    "17551095296": "Scarlet Empress Skill4 Miss",
    "17573216998": "Scarlet Empress Skill2 Finisher",
    "17812390527": "Scarlet Empress Skill2 Startup",
    "18145472727": "ReactionsFlyingREAL Reaction1",
    "18145475842": "ReactionsFlyingREAL Reaction2",
    "18145477841": "ReactionsFlyingREAL Reaction3",
    "18145480060": "ReactionsFlyingREAL Reaction4",
    "18149433144": "Immortal Blaze Awakening Skill2OLD Startup",
    "18283767231": "Scarlet Empress Skill2 GrabVictim",
    "18352920455": "Scarlet Empress Skill2 GrabAttacker",
    "18429859590": "Combats Immortal Blaze BlockFlinch2",
    "18429861347": "Combats Immortal Blaze BlockFlinch1",
    "18445733559": "Combats Scarlet Empress BlockFlinch1",
    "18511195410": "Immortal Blaze Skill3Old Success",
    "18596488404": "Scarlet Empress Skill2 GroundPull",
    "18612081451": "Immortal Blaze Skill3Fists Release",
    "18612375563": "Immortal Blaze Skill3Fists Success",
    "18612383886": "Immortal Blaze Skill3Fists Victim",
    "18658792595": "Scarlet Empress Skill1Fists Success",
    "18658797810": "Scarlet Empress Skill1Fists Victim",
    "18661538385": "Scarlet Empress Skill1Fists Release",
    "18677782250": "Combats Hit3",
    "18677788193": "Combats Hit2",
    "18677792869": "Combats Hit1",
    "18677798018": "Combats Hit4",
    "18810371910": "Immortal Blaze Skill1 Miss",
    "18899476416": "Immortal Blaze Skill1 Startupold",
    "70374968022434": "Immortal Blaze Awakening Skill1 Victim",
    "71464565385340": "Scarlet Empress Skill4 Victim",
    "71532812870582": "Scarlet Empress Skill2 CloseVariant",
    "72323173649922": "Scarlet Empress Skill1 VictimNewFinisher",
    "72980469747201": "Scarlet Empress Skill3 NEWAIRVARIANTSTARTUP",
    "73287521538162": "Scarlet Empress Awakening Skill2 Startup",
    "73712744544567": "Scarlet Empress Skill3 Release",
    "73746123899436": "Combats Scarlet Empress Block2",
    "73755645375655": "Immortal Blaze Specialnew ReleaseTa",
    "77776207323955": "ReactionsCrazy Reaction1",
    "78332699411211": "Scarlet Empress Skill2 NewRelease",
    "78481800158366": "Scarlet Empress Skill2 HoldClose",
    "78489585784552": "Scarlet Empress Skill4 Startup",
    "79071329180694": "Combats Immortal Blaze Hit4",
    "81165337623816": "Combats Scarlet Empress DownslamSecond",
    "81251122896633": "Combats Immortal Blaze DashM1",
    "81340248017777": "Immortal Blaze Skill1 Success",
    "81935136729809": "Scarlet Empress Awakening Skill1 MISSNEW",
    "82871872174505": "Scarlet Empress Skill4 StartupNew",
    "84664466945559": "Combats Immortal Blaze Hit2",
    "84978033686757": "Scarlet Empress Skill2Fists Release",
    "85337556992087": "MokouWings Script Animation",
    "85401870749911": "Combats Scarlet Empress HitSecond2",
    "85675893869792": "Immortal Blaze Awakening Skill3 Release",
    "85755598829892": "Scarlet Empress Skill4 Success",
    "86208985982958": "Immortal Blaze Awakening Skill1 Release",
    "87273756597526": "Reactions Reaction4",
    "88128088729866": "Touhou Combats Immortal Blaze BlitzKick cam",
    "88554512282085": "Immortal Blaze Skill1 StartupGrab",
    "88734040000550": "Reactions Reaction3",
    "88799907085956": "Scarlet Empress Skill1 SuccessNewFinisher",
    "89186898022356": "Touhou Combats Immortal Blaze Blitz cam",
    "89450561243568": "Reactions Reaction2",
    "89951073993390": "Combats Scarlet Empress DashM1",
    "90572488446664": "Immortal Blaze Awakening Skill3 Victim",
    "91696202815496": "Immortal Blaze Special Release",
    "92360162228187": "Combats Immortal Blaze FrontDash",
    "93301883197633": "RemiliaWings Script Animation",
    "94311448312548": "Combats Scarlet Empress Hit1",
    "95005368970029": "Scarlet Empress Skill1 Release2New",
    "95478203831208": "Combats Scarlet Empress Hit2",
    "95546273858325": "Immortal Blaze Skill2OLD Success",
    "95589433738932": "Immortal Blaze Awakening Skill2 Release",
    "95601120048515": "Immortal Blaze Awakening Skill2 Victim",
    "95954856512475": "Immortal Blaze Skill2OLD Release",
    "96049252470351": "Scarlet Empress Awakening Skill1 STARTNEW",
    "96621879258942": "Scarlet Empress Awakening Skill3 Victim",
    "97264893487499": "Scarlet Empress Special Release",
    "98639356796203": "Immortal Blaze Skill1 Startup",
    "98841667934972": "Combats Scarlet Empress Hit3",
    "98939326579670": "Immortal Blaze Specialnew Release2",
    "99010286305154": "Scarlet Empress Skill2 Victim",
    "99058026163893": "Immortal Blaze Awakening Skill3 Success",
    "99415271075232": "Combats Immortal Blaze Uppercut",
    "100156864186007": "Immortal Blaze Awakening Skill4 Release",
    "100830467870612": "Combats Immortal Blaze RightDash",
    "101867295338279": "Immortal Blaze RankedSpawnAnimation",
    "102560249007590": "Scarlet Empress Awakening Skill2 Victim",
    "102818347988488": "Scarlet Empress Awakening Skill1 Startup",
    "103437648238860": "Immortal Blaze Awakening Skill1 Success",
    "103901385332562": "Scarlet Empress Awakening Skill2 Cast",
    "104021859653778": "Scarlet Empress Awakening Skill4 Release",
    "105167650055806": "Immortal Blaze Skill1 Victim",
    "105290718623603": "Immortal Blaze Skill4 Release",
    "105347340587524": "Scarlet Empress Skill1 VictimNew",
    "106025773955713": "ReactionsCrazy Reaction4",
    "106205693845137": "ReactionsCrazy Reaction2",
    "106284116960538": "Combats Immortal Blaze Hit3",
    "106595932906570": "BLSRAFTERIMAGES BLSR 1",
    "108217279087207": "Combats Immortal Blaze UppercutOld",
    "109175025011855": "Scarlet Empress Skill2 Hold",
    "109368316634074": "Scarlet Empress Skill2 Release",
    "109739299132189": "Scarlet Empress Special Hit",
    "109794938761166": "Scarlet Empress Skill3 SuccessENDLAG",
    "110475242863679": "Combats Immortal Blaze Block",
    "110485203042029": "Immortal Blaze Specialnew Release",
    "111972266386532": "Scarlet Empress Skill2Fists Victim",
    "112049695372365": "Scarlet Empress Awakening Skill1 SUCCESSNEW",
    "112214037939666": "BLSRAFTERIMAGES BLSR 2",
    "112285075775053": "Combats Scarlet Empress FrontDash",
    "112405239051544": "Immortal Blaze Skill3Old Victim",
    "112685577131623": "Immortal Blaze Awakening Skill4 Success",
    "112820707497987": "Touhou Combats Scarlet Empress BlitzKick2 cam",
    "113153033751095": "Scarlet Empress Skill2 Success",
    "113503086858505": "Immortal Blaze Skill3 Victim",
    "113715472766145": "ReactionsCrazy Reaction3",
    "113818101455706": "Immortal Blaze Skill1 Victim2",
    "114527304087612": "Immortal Blaze Skill1 Startup1",
    "114680013127948": "Immortal Blaze Skill4 Victim",
    "114694958626815": "Scarlet Empress Skill3 NEWSTAB",
    "115152468957804": "Combats Scarlet Empress FrontDashMode",
    "115741366398216": "Touhou Combats Scarlet Empress Blitz cam",
    "115916590606773": "Scarlet Empress Skill2 ReleaseClose",
    "116528496998535": "Immortal Blaze Awakening AwakenAnim",
    "116677254193558": "Immortal Blaze Skill3 Release",
    "116694727194817": "Scarlet Empress Skill1 Release",
    "117322473499719": "Scarlet Empress Special ReleaseNew",
    "117759742720341": "Scarlet Empress Skill3 Success",
    "117826107919894": "Immortal Blaze Skill2OLD Victim",
    "117926942626963": "Scarlet Empress Skill1 Victim",
    "118580204277633": "Scarlet Empress Skill1 SuccessNew",
    "118826387368191": "Scarlet Empress Awakening Skill3 Release2",
    "118941982890586": "Scarlet Empress Awakening Skill3 Success",
    "119019934070297": "Scarlet Empress RankedSpawnAnimation",
    "119770714667862": "BLSRAFTERIMAGES BLSR 3",
    "119788919749366": "Scarlet Empress Skill3 NEWVICTIM",
    "120674619121800": "Immortal Blaze Skill4 Releaseoldspin",
    "121396696849223": "Scarlet Empress Awakening Skill1 VICTIMNEW",
    "121954213907376": "Touhou Combats Immortal Blaze BlitzKick2 cam",
    "122222337018536": "Combats Immortal Blaze BackDash",
    "122278729092408": "RemiliaWingsUlt Script Animation",
    "122942537936440": "Scarlet Empress Awakening Skill2 Success",
    "123471770763857": "Combats Scarlet Empress Uppercut",
    "123548284046255": "Immortal Blaze Awakening Skill2 Success",
    "123638711644021": "Scarlet Empress Skill2Fists BeingPulled",
    "124402989349373": "Immortal Blaze Skill4 ReleaseOLD",
    "125013873256822": "Scarlet Empress Skill3 NEWMISS",
    "126650249505888": "BLSRAFTERIMAGES BLSR 4",
    "126659012932837": "Reactions DashM1Reaction",
    "126666515307802": "Reactions Reaction1",
    "126770669106638": "Immortal Blaze Skill3 Success",
    "128147647540876": "Immortal Blaze Skill3Old Release",
    "128675044478123": "Combats Scarlet Empress HitSecond3",
    "128854900592291": "Scarlet Empress Skill2Fists Success",
    "128875824406345": "Immortal Blaze Skill4 Success",
    "129581595461291": "Scarlet Empress Skill1 ReleaseNew",
    "129760642655211": "Combats Scarlet Empress Block",
    "130187509617447": "Scarlet Empress Skill3 NEWAIRVARIANTSLAM",
    "130196013814350": "Scarlet Empress Awakening Skill3 Release",
    "130198022684545": "Touhou Combats Scarlet Empress Blitzo cam",
    "131184751372079": "Scarlet Empress Skill3 NEWHIT",
    "132060711277270": "Combats Scarlet Empress Downslam",
    "132231122450051": "Scarlet Empress Skill3 Victim",
    "132464988285463": "Combats Scarlet Empress Hit4",
    "133097663801152": "Scarlet Empress SpinningRemiliaSpear MainAnimation",
    "133250196272173": "Combats Immortal Blaze Downslam",
    "133312172613881": "Combats Immortal Blaze LeftDash",
    "133800367771260": "Combats Scarlet Empress DashM1Second",
    "133851040563942": "Combats Scarlet Empress DashM1Mode",
    "134413792479820": "Scarlet Empress Awakening AwakenAnim",
    "136545287121629": "Immortal Blaze Awakening DeathAnim",
    "136919141396902": "Combats Immortal Blaze Hit1",
    "137680639825079": "Immortal Blaze Awakening Skill4 Victim",
    "137701041431404": "Combats Scarlet Empress HitSecond1",
    "138941292691749": "Combats Scarlet Empress HitSecond4",
    "139557574586154": "Scarlet Empress Skill1 Success",
}


class CertError(Exception):
    """HTTPS can't be checked - a python.org Python on a Mac before its certificates are installed."""


CERT_HINT = ('Python can\'t check Roblox\'s HTTPS certificate. On a Mac with Python from python.org, open\n'
             'Applications > Python 3.x and double-click "Install Certificates.command", then run this again.')


class ApiError(Exception):
    def __init__(self, status, body):
        super().__init__('HTTP %s: %s' % (status, body[:300]))
        self.status = status
        self.body = body


def request(method, url, key=None, data=None, headers=None, tries=6):
    """One call, retried on a rate limit (429) or a server hiccup (5xx)."""
    headers = dict(headers or {})
    if key:
        headers['x-api-key'] = key
    headers.setdefault('User-Agent', 'QuirkBattlegrounds-reupload107')
    wait = 4.0
    for attempt in range(tries):
        req = urllib.request.Request(url, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                body = r.read()
                if r.headers.get('Content-Encoding') == 'gzip' or body[:2] == b'\x1f\x8b':
                    body = gzip.decompress(body)
                return body
        except urllib.error.HTTPError as e:
            body = e.read().decode('utf-8', 'replace')
            if (e.code == 429 or e.code >= 500) and attempt < tries - 1:
                after = e.headers.get('Retry-After')
                pause = float(after) if after and after.replace('.', '', 1).isdigit() else wait
                print('    (%s - waiting %.0f s)' % ('rate limited' if e.code == 429 else 'Roblox error %d' % e.code, pause))
                time.sleep(pause)
                wait = min(wait * 2, 120)
                continue
            raise ApiError(e.code, body)
        except urllib.error.URLError as e:
            if 'CERTIFICATE_VERIFY_FAILED' in str(e.reason):
                raise CertError(str(e.reason))
            if attempt < tries - 1:
                print('    (connection problem: %s - trying again in %.0f s)' % (e.reason, wait))
                time.sleep(wait)
                wait = min(wait * 2, 120)
                continue
            raise
    raise ApiError(0, 'gave up')


def hint(err, step):
    s = err.status
    if s in (401, 403):
        if step == 'download':
            return ('the OLD account\'s key was refused. It needs the API system "legacy-asset" with the '
                    '"manage" operation, and the key must belong to the account that owns the animations '
                    '(make it on that account itself - a group\'s key may not be able to).')
        return ('the NEW account\'s key was refused. It needs the API system "assets" with Read and Write, '
                'and the user id (or group id) you gave must be the key\'s own account (or a group it can '
                'upload to).')
    if s == 404:
        return 'Roblox says there is no such asset (or this key can\'t see it).'
    if s == 400:
        return 'Roblox refused the request: ' + err.body[:300]
    return err.body[:300]


# --- step 1: download -------------------------------------------------------

def download(key, ids):
    os.makedirs(OUT, exist_ok=True)
    got, failed = 0, {}
    for n, old in enumerate(ids, 1):
        path = os.path.join(OUT, '%s.rbxm' % old)
        if os.path.exists(path) and os.path.getsize(path) > 0:
            got += 1
            continue
        print('[%d/%d] downloading %s  (%s)' % (n, len(ids), old, ANIMATIONS[old]))
        try:
            meta = json.loads(request('GET', '%s/asset-delivery-api/v1/assetId/%s' % (API, old), key))
            where = meta.get('location') or ((meta.get('locations') or [{}])[0].get('location'))
            if not where:
                raise ApiError(0, 'no download location in ' + json.dumps(meta)[:200])
            blob = request('GET', where, headers={'Accept-Encoding': 'gzip'})
            if not (blob.startswith(b'<roblox!') or blob.startswith(b'<roblox')):
                raise ApiError(0, 'that isn\'t an animation file (starts %r)' % blob[:16])
            with open(path + '.part', 'wb') as f:
                f.write(blob)
            os.replace(path + '.part', path)
            got += 1
        except ApiError as e:
            failed[old] = hint(e, 'download')
            print('    could not download it: ' + failed[old])
            if e.status in (401, 403) and got == 0 and len(failed) >= 3:
                print('\nThe key is being refused every time - stopping here. Fix the key and run again.')
                break
        time.sleep(0.25)
    return got, failed


# --- step 2: upload ---------------------------------------------------------

def multipart(fields, files):
    boundary = '----reupload107' + ''.join(random.choice(string.ascii_letters) for _ in range(16))
    out = []
    for name, value in fields.items():
        out.append(('--%s\r\nContent-Disposition: form-data; name="%s"\r\n\r\n%s\r\n' % (boundary, name, value)).encode('utf-8'))
    for name, (filename, ctype, blob) in files.items():
        out.append(('--%s\r\nContent-Disposition: form-data; name="%s"; filename="%s"\r\nContent-Type: %s\r\n\r\n'
                    % (boundary, name, filename, ctype)).encode('utf-8'))
        out.append(blob)
        out.append(b'\r\n')
    out.append(('--%s--\r\n' % boundary).encode('utf-8'))
    return b''.join(out), 'multipart/form-data; boundary=' + boundary


def load_map():
    if os.path.exists(MAP):
        with open(MAP, encoding='utf-8') as f:
            return {str(k): str(v) for k, v in json.load(f).items()}
    return {}


def save_map(m):
    with open(MAP + '.part', 'w', encoding='utf-8') as f:
        json.dump(m, f, indent=1, sort_keys=True)
    os.replace(MAP + '.part', MAP)


def wait_for(key, operation):
    path = operation if operation.startswith('operations/') else 'operations/' + operation
    for _ in range(60):
        op = json.loads(request('GET', '%s/assets/v1/%s' % (API, path), key))
        if op.get('done'):
            if op.get('error'):
                raise ApiError(0, json.dumps(op['error'])[:300])
            return op.get('response') or {}
        time.sleep(1.5)
    raise ApiError(0, 'Roblox is still working on it after 90 s (operation %s) - run again later' % path)


def upload(key, creator, ids, only_present=False):
    m = load_map()
    done, failed, skipped = 0, {}, 0
    if only_present:  # (--upload-only: just the files that are there)
        have = [i for i in ids if os.path.exists(os.path.join(OUT, '%s.rbxm' % i))]
        skipped = len(ids) - len(have)
        ids = have
        print('%d animation files to upload (%d of the %d have none here).' % (len(ids), skipped, len(ids) + skipped))
    todo = [i for i in ids if i not in m]
    for n, old in enumerate(ids, 1):
        if old in m:
            done += 1
            continue
        path = os.path.join(OUT, '%s.rbxm' % old)
        if not os.path.exists(path):
            failed[old] = 'not downloaded (step 1 didn\'t get it)'
            continue
        with open(path, 'rb') as f:
            blob = f.read()
        print('[%d/%d] uploading %s  (%s)' % (n, len(ids), old, ANIMATIONS[old]))
        req = {
            'assetType': 'Animation',
            'displayName': ANIMATIONS[old][:50],
            'description': 'Quirk Battlegrounds (was %s)' % old,
            'creationContext': {'creator': creator},
        }
        xml = blob.startswith(b'<roblox ') or blob.startswith(b'<roblox>')
        body, ctype = multipart({'request': json.dumps(req)},
                                {'fileContent': ('%s.%s' % (old, 'rbxmx' if xml else 'rbxm'), 'model/x-rbxm', blob)})
        try:
            op = json.loads(request('POST', '%s/assets/v1/assets' % API, key, body, {'Content-Type': ctype}))
            res = op.get('response') if op.get('done') else None
            if res is None:
                res = wait_for(key, op.get('path') or op.get('operationId') or '')
            new = str(res.get('assetId') or str(res.get('path', '')).split('/')[-1])
            if not new.isdigit():
                raise ApiError(0, 'no asset id in the answer: ' + json.dumps(res)[:200])
            m[old] = new
            save_map(m)
            done += 1
            print('    -> %s' % new)
        except ApiError as e:
            failed[old] = hint(e, 'upload')
            print('    could not upload it: ' + failed[old])
            if e.status in (401, 403) and done == 0 and len(failed) >= 3:
                print('\nThe key is being refused every time - stopping here. Fix the key and run again.')
                break
        if todo and old != todo[-1]:
            time.sleep(UPLOAD_GAP)
    write_snippet(m)
    return done, failed


def write_snippet(m):
    lines = ['-- Quirk Battlegrounds: Mokou\'s and Remilia\'s animations, old id -> new id.',
             '-- Paste all of this into Studio\'s command bar (View > Command Bar) with the',
             '-- game open, press Enter, then save / publish.',
             'local MAP = {']
    for old in sorted(m, key=int):
        lines.append('\t[%s] = %s,' % (old, m[old]))
    lines += ['}',
              'local n = 0',
              'for _, d in game:GetDescendants() do',
              '\tif d:IsA("Animation") then',
              '\t\tlocal old = tonumber(string.match(d.AnimationId, "%d+$"))',
              '\t\tif old and MAP[old] then',
              '\t\t\td.AnimationId = "rbxassetid://" .. MAP[old]',
              '\t\t\tn += 1',
              '\t\tend',
              '\tend',
              'end',
              'print(n, "animations swapped to the new account\'s")']
    with open(SNIPPET, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')


# --- the run ----------------------------------------------------------------

def ask_key(who, what):
    env = os.environ.get('ROBLOX_%s_KEY' % who)
    if env:
        return env.strip()
    print('\nPaste the %s account\'s API key (%s). It won\'t show as you type or paste;' % (who.lower(), what))
    print('press Enter after.')
    while True:
        k = getpass.getpass('%s key: ' % who.title()).strip()
        if len(k) > 20:
            return k
        print('That looks too short for a key - try again.')


def ask_creator():
    env_user, env_group = os.environ.get('ROBLOX_NEW_USER_ID'), os.environ.get('ROBLOX_NEW_GROUP_ID')
    if env_group:
        return {'groupId': env_group.strip()}
    if env_user:
        return {'userId': env_user.strip()}
    print('\nWho owns Quirk Battlegrounds?')
    print('  1  my new account')
    print('  2  a group')
    while True:
        c = input('1 or 2: ').strip()
        if c in ('1', '2'):
            break
    label = 'Your new account\'s user id (the number in its profile link, roblox.com/users/<id>/profile)' if c == '1' \
        else 'The group\'s id (the number in its link, roblox.com/communities/<id>/...)'
    while True:
        v = input(label + ': ').strip()
        if v.isdigit():
            return {'userId': v} if c == '1' else {'groupId': v}
        print('Just the number, please.')


def main():
    ap = argparse.ArgumentParser(description='Re-upload Mokou\'s and Remilia\'s animations to a new account.')
    ap.add_argument('--download-only', action='store_true')
    ap.add_argument('--upload-only', action='store_true')
    a = ap.parse_args()
    ids = sorted(ANIMATIONS, key=int)
    print('%d animations to move. Files go in %s' % (len(ids), OUT))

    failed_dl, failed_up = {}, {}
    if not a.upload_only:
        key = ask_key('OLD', 'the account that made the animations; API system "legacy-asset", operation "manage"')
        got, failed_dl = download(key, ids)
        print('\nDownloaded %d of %d.' % (got, len(ids)))
    if not a.download_only:
        creator = ask_creator()
        key = ask_key('NEW', 'the account that owns Quirk Battlegrounds; API system "assets", Read and Write')
        done, failed_up = upload(key, creator, ids, only_present=a.upload_only)
        here = len([i for i in ids if os.path.exists(os.path.join(OUT, '%s.rbxm' % i))]) if a.upload_only else len(ids)
        print('\nUploaded %d of %d.' % (done, here))
        print('Old id -> new id: %s' % MAP)
        print('Paste into Studio\'s command bar: %s' % SNIPPET)
    bad = dict(failed_up)
    bad.update(failed_dl)  # (why it wasn't downloaded says more)
    if bad:
        print('\nThese didn\'t make it (run the script again to retry them):')
        for old, why in sorted(bad.items(), key=lambda kv: int(kv[0])):
            print('  %s  %s: %s' % (old, ANIMATIONS[old], why))
    else:
        print('\nAll done.')
    return 0 if not bad else 1


if __name__ == '__main__':
    try:
        code = main()
    except CertError:
        print('\n' + CERT_HINT)
        code = 1
    except KeyboardInterrupt:
        print('\nStopped. Run it again to carry on where it left off.')
        code = 1
    if sys.stdin.isatty() and os.name == 'nt' and not os.environ.get('PROMPT'):
        input('\nPress Enter to close.')
    sys.exit(code)
