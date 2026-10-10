# Mokou and Remilia: the ids to upload again (round 107)

Made by `tools/touhou/ids107.py` from the built place. 185 animations, 275 sounds, 0 ids written in its scripts.

Roblox plays an animation only in a game owned by the account (or group) that owns the animation,
so every animation here has to be uploaded again from the account that owns Quirk Battlegrounds.
A sound you uploaded yourself plays in a game it is shared with: either give Quirk Battlegrounds
permission to use it from the old account (Creator Dashboard, the sound, Permissions) or upload it again.
Sounds from Roblox's own library play anywhere and need nothing.

## The quick way: `reupload_anims.py`

It moves all of them with Roblox's own Open Cloud API: it downloads each one with the old account's
key and uploads it with the new account's, then writes the Studio snippet that swaps the ids.

1. Make two API keys at create.roblox.com/dashboard/credentials (Creator Dashboard, API Keys):
   - signed in to the **old** account: add the API system **legacy-asset**, operation **manage**;
   - signed in to the **new** account (or under the group, if a group owns the game): add the API
     system **assets**, operations **Read** and **Write**.
   Both: leave **Restrict IP addresses** off (Roblox's default), and an expiry date if you like.
   The script asks Roblox about each key before using it and says what's wrong, if anything
   (pasted in part, switched off, expired, missing a permission).
2. Put `reupload_anims.py` in a folder and run it there with Python 3:
   - Mac: open Terminal, `cd` to the folder, `python3 reupload_anims.py` (if Python isn't there, macOS
     offers to install it; with Python from python.org, run its "Install Certificates.command" once first);
   - Windows: install Python from python.org (tick "Add Python to PATH"), then `py reupload_anims.py`.
3. Paste each key when it asks (it won't show; it's never saved), and the new account's user id
   (or the group's id).
4. When it's done, open `reupload107/swap_animations.lua`, paste all of it into Studio's command bar
   with Quirk Battlegrounds open, press Enter, and publish. (Or send `reupload107/map.json` - it has no
   keys in it - and `tools/touhou/swap107.py` puts the new ids into the place file.)

Stopped part-way, or some failed? Run it again: what's already done is skipped.

## By hand in Studio (if the script can't)

1. In Studio signed in to the **old** account, open the Touhou place and paste this into the command bar.
   It fetches every animation as a KeyframeSequence into `ServerStorage.Reupload107`, named by its old id:

```lua
local ids = {15695297816, 15695395145, 15930242639, 15930243864, 17029138699, 17029142737, 17312856852, 17370044273, 17373812220, 17373814145, 17409311963, 17409403714, 17551095296, 17573216998, 17812390527, 18145472727, 18145475842, 18145477841, 18145480060, 18149433144, 18283767231, 18352920455, 18429859590, 18429861347, 18445733559, 18511195410, 18596488404, 18612081451, 18612375563, 18612383886, 18658792595, 18658797810, 18661538385, 18677782250, 18677788193, 18677792869, 18677798018, 18810371910, 18899476416, 70374968022434, 71464565385340, 71532812870582, 72323173649922, 72980469747201, 73287521538162, 73712744544567, 73746123899436, 73755645375655, 77776207323955, 78332699411211, 78481800158366, 78489585784552, 79071329180694, 81165337623816, 81251122896633, 81340248017777, 81935136729809, 82871872174505, 84664466945559, 84978033686757, 85337556992087, 85401870749911, 85675893869792, 85755598829892, 86208985982958, 87273756597526, 88128088729866, 88554512282085, 88734040000550, 88799907085956, 89186898022356, 89450561243568, 89951073993390, 90572488446664, 91696202815496, 92360162228187, 93301883197633, 94311448312548, 95005368970029, 95478203831208, 95546273858325, 95589433738932, 95601120048515, 95954856512475, 96049252470351, 96621879258942, 97264893487499, 98639356796203, 98841667934972, 98939326579670, 99010286305154, 99058026163893, 99415271075232, 100156864186007, 100830467870612, 101867295338279, 102560249007590, 102818347988488, 103437648238860, 103901385332562, 104021859653778, 105167650055806, 105290718623603, 105347340587524, 106025773955713, 106205693845137, 106284116960538, 106595932906570, 108217279087207, 109175025011855, 109368316634074, 109739299132189, 109794938761166, 110475242863679, 110485203042029, 111972266386532, 112049695372365, 112214037939666, 112285075775053, 112405239051544, 112685577131623, 112820707497987, 113153033751095, 113503086858505, 113715472766145, 113818101455706, 114527304087612, 114680013127948, 114694958626815, 115152468957804, 115741366398216, 115916590606773, 116528496998535, 116677254193558, 116694727194817, 117322473499719, 117759742720341, 117826107919894, 117926942626963, 118580204277633, 118826387368191, 118941982890586, 119019934070297, 119770714667862, 119788919749366, 120674619121800, 121396696849223, 121954213907376, 122222337018536, 122278729092408, 122942537936440, 123471770763857, 123548284046255, 123638711644021, 124402989349373, 125013873256822, 126650249505888, 126659012932837, 126666515307802, 126770669106638, 128147647540876, 128675044478123, 128854900592291, 128875824406345, 129581595461291, 129760642655211, 130187509617447, 130196013814350, 130198022684545, 131184751372079, 132060711277270, 132231122450051, 132464988285463, 133097663801152, 133250196272173, 133312172613881, 133800367771260, 133851040563942, 134413792479820, 136545287121629, 136919141396902, 137680639825079, 137701041431404, 138941292691749, 139557574586154}
local KSP = game:GetService("KeyframeSequenceProvider")
local out = Instance.new("Folder"); out.Name = "Reupload107"; out.Parent = game.ServerStorage
for _, id in ids do
	local ok, ks = pcall(function() return KSP:GetKeyframeSequenceAsync("rbxassetid://" .. id) end)
	if ok and ks then ks.Name = tostring(id); ks.Parent = out else warn("couldn't fetch", id, ks) end
end
print(#out:GetChildren(), "of", #ids)
```

2. Right-click `Reupload107`, Save to File. In Studio signed in to the **new** account, open Quirk
   Battlegrounds, insert that file, and publish each KeyframeSequence (right-click, Save to Roblox).
   Keep a note of new id against old id (the KeyframeSequence's name is the old id).
3. Swap the ids everywhere with one command-bar paste (fill `MAP` as `[old] = new`):

```lua
local MAP = { --[[ [16941283510] = 123456789, ... ]] }
local n = 0
for _, d in game:GetDescendants() do
	local prop = d:IsA("Animation") and "AnimationId" or d:IsA("Sound") and "SoundId" or nil
	local old = prop and tonumber(string.match(d[prop], "%d+$"))
	if old and MAP[old] then d[prop] = "rbxassetid://" .. MAP[old]; n += 1 end
end
print(n, "ids swapped")
```

Anything left on an old id just doesn't play (the move still works).

The two awakening songs are also set in `QuirkConfig` (`UltMusic.Tracks.Mokou` / `.Remilia`): change their `Id` there
too. Until then each falls back to a Roblox-library track (its `Fallback`) when the song won't load.

## Animations (185)

| id | for | where (first of n) | n |
|---|---|---|---|
| 116528496998535 | Mokou | `Animations.Characters.Immortal Blaze.Awakening.AwakenAnim` | 1 |
| 136545287121629 | Mokou | `Animations.Characters.Immortal Blaze.Awakening.DeathAnim` | 1 |
| 86208985982958 | Mokou | `Animations.Characters.Immortal Blaze.Awakening.Skill1.Release` | 2 |
| 103437648238860 | Mokou | `Animations.Characters.Immortal Blaze.Awakening.Skill1.Success` | 2 |
| 70374968022434 | Mokou | `Animations.Characters.Immortal Blaze.Awakening.Skill1.Victim` | 2 |
| 95589433738932 | Mokou | `Animations.Characters.Immortal Blaze.Awakening.Skill2.Release` | 1 |
| 123548284046255 | Mokou | `Animations.Characters.Immortal Blaze.Awakening.Skill2.Success` | 1 |
| 95601120048515 | Mokou | `Animations.Characters.Immortal Blaze.Awakening.Skill2.Victim` | 1 |
| 85675893869792 | Mokou | `Animations.Characters.Immortal Blaze.Awakening.Skill3.Release` | 1 |
| 99058026163893 | Mokou | `Animations.Characters.Immortal Blaze.Awakening.Skill3.Success` | 1 |
| 90572488446664 | Mokou | `Animations.Characters.Immortal Blaze.Awakening.Skill3.Victim` | 1 |
| 100156864186007 | Mokou | `Animations.Characters.Immortal Blaze.Awakening.Skill4.Release` | 1 |
| 112685577131623 | Mokou | `Animations.Characters.Immortal Blaze.Awakening.Skill4.Success` | 1 |
| 137680639825079 | Mokou | `Animations.Characters.Immortal Blaze.Awakening.Skill4.Victim` | 1 |
| 101867295338279 | Mokou | `Animations.Characters.Immortal Blaze.RankedSpawnAnimation` | 1 |
| 18810371910 | Mokou | `Animations.Characters.Immortal Blaze.Skill1.Miss` | 1 |
| 98639356796203 | Mokou | `Animations.Characters.Immortal Blaze.Skill1.Startup` | 1 |
| 114527304087612 | Mokou | `Animations.Characters.Immortal Blaze.Skill1.Startup1` | 1 |
| 88554512282085 | Mokou | `Animations.Characters.Immortal Blaze.Skill1.StartupGrab` | 1 |
| 18899476416 | Mokou | `Animations.Characters.Immortal Blaze.Skill1.Startupold` | 1 |
| 81340248017777 | Mokou | `Animations.Characters.Immortal Blaze.Skill1.Success` | 1 |
| 105167650055806 | Mokou | `Animations.Characters.Immortal Blaze.Skill1.Victim` | 1 |
| 113818101455706 | Mokou | `Animations.Characters.Immortal Blaze.Skill1.Victim2` | 1 |
| 95954856512475 | Mokou | `Animations.Characters.Immortal Blaze.Skill2OLD.Release` | 1 |
| 95546273858325 | Mokou | `Animations.Characters.Immortal Blaze.Skill2OLD.Success` | 1 |
| 117826107919894 | Mokou | `Animations.Characters.Immortal Blaze.Skill2OLD.Victim` | 1 |
| 116677254193558 | Mokou | `Animations.Characters.Immortal Blaze.Skill3.Release` | 1 |
| 126770669106638 | Mokou | `Animations.Characters.Immortal Blaze.Skill3.Success` | 1 |
| 113503086858505 | Mokou | `Animations.Characters.Immortal Blaze.Skill3.Victim` | 1 |
| 128147647540876 | Mokou | `Animations.Characters.Immortal Blaze.Skill3Old.Release` | 1 |
| 18511195410 | Mokou | `Animations.Characters.Immortal Blaze.Skill3Old.Success` | 1 |
| 112405239051544 | Mokou | `Animations.Characters.Immortal Blaze.Skill3Old.Victim` | 1 |
| 105290718623603 | Mokou | `Animations.Characters.Immortal Blaze.Skill4.Release` | 1 |
| 124402989349373 | Mokou | `Animations.Characters.Immortal Blaze.Skill4.ReleaseOLD` | 1 |
| 120674619121800 | Mokou | `Animations.Characters.Immortal Blaze.Skill4.Releaseoldspin` | 1 |
| 128875824406345 | Mokou | `Animations.Characters.Immortal Blaze.Skill4.Success` | 1 |
| 15930242639 | Mokou | `Animations.Characters.Immortal Blaze.Skill4.SuccessFinisher` | 1 |
| 114680013127948 | Mokou | `Animations.Characters.Immortal Blaze.Skill4.Victim` | 1 |
| 15930243864 | Mokou | `Animations.Characters.Immortal Blaze.Skill4.VictimFinisher` | 1 |
| 91696202815496 | Mokou | `Animations.Characters.Immortal Blaze.Special.Release` | 1 |
| 110485203042029 | Mokou | `Animations.Characters.Immortal Blaze.Specialnew.Release` | 1 |
| 98939326579670 | Mokou | `Animations.Characters.Immortal Blaze.Specialnew.Release2` | 1 |
| 73755645375655 | Mokou | `Animations.Characters.Immortal Blaze.Specialnew.ReleaseTa` | 1 |
| 110475242863679 | Mokou | `Animations.Combats.Immortal Blaze.Block` | 1 |
| 18429861347 | Mokou | `Animations.Combats.Immortal Blaze.BlockFlinch1` | 2 |
| 18429859590 | Mokou | `Animations.Combats.Immortal Blaze.BlockFlinch2` | 1 |
| 81251122896633 | Mokou | `Animations.Combats.Immortal Blaze.DashM1` | 1 |
| 133250196272173 | Mokou | `Animations.Combats.Immortal Blaze.Downslam` | 1 |
| 92360162228187 | Mokou | `Animations.Combats.Immortal Blaze.FrontDash` | 1 |
| 136919141396902 | Mokou | `Animations.Combats.Immortal Blaze.Hit1` | 1 |
| 84664466945559 | Mokou | `Animations.Combats.Immortal Blaze.Hit2` | 1 |
| 106284116960538 | Mokou | `Animations.Combats.Immortal Blaze.Hit3` | 1 |
| 79071329180694 | Mokou | `Animations.Combats.Immortal Blaze.Hit4` | 1 |
| 99415271075232 | Mokou | `Animations.Combats.Immortal Blaze.Uppercut` | 1 |
| 108217279087207 | Mokou | `Animations.Combats.Immortal Blaze.UppercutOld` | 1 |
| 89186898022356 | Mokou | `RS.Touhou.Combats.Immortal Blaze.Blitz.cam` | 1 |
| 88128088729866 | Mokou | `RS.Touhou.Combats.Immortal Blaze.BlitzKick.cam` | 1 |
| 121954213907376 | Mokou | `RS.Touhou.Combats.Immortal Blaze.BlitzKick2.cam` | 1 |
| 85337556992087 | Mokou | `SS.ModelStorage.MokouWings.Script.Animation` | 1 |
| 134413792479820 | Remilia | `Animations.Characters.Scarlet Empress.Awakening.AwakenAnim` | 1 |
| 81935136729809 | Remilia | `Animations.Characters.Scarlet Empress.Awakening.Skill1.MISSNEW` | 1 |
| 96049252470351 | Remilia | `Animations.Characters.Scarlet Empress.Awakening.Skill1.STARTNEW` | 1 |
| 112049695372365 | Remilia | `Animations.Characters.Scarlet Empress.Awakening.Skill1.SUCCESSNEW` | 1 |
| 102818347988488 | Remilia | `Animations.Characters.Scarlet Empress.Awakening.Skill1.Startup` | 1 |
| 121396696849223 | Remilia | `Animations.Characters.Scarlet Empress.Awakening.Skill1.VICTIMNEW` | 1 |
| 103901385332562 | Remilia | `Animations.Characters.Scarlet Empress.Awakening.Skill2.Cast` | 1 |
| 73287521538162 | Remilia | `Animations.Characters.Scarlet Empress.Awakening.Skill2.Startup` | 1 |
| 122942537936440 | Remilia | `Animations.Characters.Scarlet Empress.Awakening.Skill2.Success` | 1 |
| 102560249007590 | Remilia | `Animations.Characters.Scarlet Empress.Awakening.Skill2.Victim` | 1 |
| 130196013814350 | Remilia | `Animations.Characters.Scarlet Empress.Awakening.Skill3.Release` | 1 |
| 118826387368191 | Remilia | `Animations.Characters.Scarlet Empress.Awakening.Skill3.Release2` | 1 |
| 118941982890586 | Remilia | `Animations.Characters.Scarlet Empress.Awakening.Skill3.Success` | 1 |
| 96621879258942 | Remilia | `Animations.Characters.Scarlet Empress.Awakening.Skill3.Victim` | 1 |
| 104021859653778 | Remilia | `Animations.Characters.Scarlet Empress.Awakening.Skill4.Release` | 1 |
| 119019934070297 | Remilia | `Animations.Characters.Scarlet Empress.RankedSpawnAnimation` | 1 |
| 116694727194817 | Remilia | `Animations.Characters.Scarlet Empress.Skill1.Release` | 1 |
| 95005368970029 | Remilia | `Animations.Characters.Scarlet Empress.Skill1.Release2New` | 1 |
| 129581595461291 | Remilia | `Animations.Characters.Scarlet Empress.Skill1.ReleaseNew` | 1 |
| 139557574586154 | Remilia | `Animations.Characters.Scarlet Empress.Skill1.Success` | 1 |
| 118580204277633 | Remilia | `Animations.Characters.Scarlet Empress.Skill1.SuccessNew` | 1 |
| 88799907085956 | Remilia | `Animations.Characters.Scarlet Empress.Skill1.SuccessNewFinisher` | 1 |
| 117926942626963 | Remilia | `Animations.Characters.Scarlet Empress.Skill1.Victim` | 1 |
| 105347340587524 | Remilia | `Animations.Characters.Scarlet Empress.Skill1.VictimNew` | 1 |
| 72323173649922 | Remilia | `Animations.Characters.Scarlet Empress.Skill1.VictimNewFinisher` | 1 |
| 18661538385 | Remilia | `Animations.Characters.Scarlet Empress.Skill1Fists.Release` | 1 |
| 18658792595 | Remilia | `Animations.Characters.Scarlet Empress.Skill1Fists.Success` | 1 |
| 18658797810 | Remilia | `Animations.Characters.Scarlet Empress.Skill1Fists.Victim` | 1 |
| 71532812870582 | Remilia | `Animations.Characters.Scarlet Empress.Skill2.CloseVariant` | 1 |
| 17573216998 | Remilia | `Animations.Characters.Scarlet Empress.Skill2.Finisher` | 1 |
| 18352920455 | Remilia | `Animations.Characters.Scarlet Empress.Skill2.GrabAttacker` | 1 |
| 18283767231 | Remilia | `Animations.Characters.Scarlet Empress.Skill2.GrabVictim` | 1 |
| 18596488404 | Remilia | `Animations.Characters.Scarlet Empress.Skill2.GroundPull` | 1 |
| 109175025011855 | Remilia | `Animations.Characters.Scarlet Empress.Skill2.Hold` | 1 |
| 78481800158366 | Remilia | `Animations.Characters.Scarlet Empress.Skill2.HoldClose` | 1 |
| 78332699411211 | Remilia | `Animations.Characters.Scarlet Empress.Skill2.NewRelease` | 1 |
| 109368316634074 | Remilia | `Animations.Characters.Scarlet Empress.Skill2.Release` | 2 |
| 115916590606773 | Remilia | `Animations.Characters.Scarlet Empress.Skill2.ReleaseClose` | 1 |
| 17812390527 | Remilia | `Animations.Characters.Scarlet Empress.Skill2.Startup` | 1 |
| 113153033751095 | Remilia | `Animations.Characters.Scarlet Empress.Skill2.Success` | 1 |
| 99010286305154 | Remilia | `Animations.Characters.Scarlet Empress.Skill2.Victim` | 1 |
| 123638711644021 | Remilia | `Animations.Characters.Scarlet Empress.Skill2Fists.BeingPulled` | 1 |
| 84978033686757 | Remilia | `Animations.Characters.Scarlet Empress.Skill2Fists.Release` | 1 |
| 128854900592291 | Remilia | `Animations.Characters.Scarlet Empress.Skill2Fists.Success` | 1 |
| 111972266386532 | Remilia | `Animations.Characters.Scarlet Empress.Skill2Fists.Victim` | 1 |
| 130187509617447 | Remilia | `Animations.Characters.Scarlet Empress.Skill3.NEWAIRVARIANTSLAM` | 1 |
| 72980469747201 | Remilia | `Animations.Characters.Scarlet Empress.Skill3.NEWAIRVARIANTSTARTUP` | 1 |
| 131184751372079 | Remilia | `Animations.Characters.Scarlet Empress.Skill3.NEWHIT` | 1 |
| 125013873256822 | Remilia | `Animations.Characters.Scarlet Empress.Skill3.NEWMISS` | 1 |
| 114694958626815 | Remilia | `Animations.Characters.Scarlet Empress.Skill3.NEWSTAB` | 1 |
| 119788919749366 | Remilia | `Animations.Characters.Scarlet Empress.Skill3.NEWVICTIM` | 1 |
| 73712744544567 | Remilia | `Animations.Characters.Scarlet Empress.Skill3.Release` | 1 |
| 117759742720341 | Remilia | `Animations.Characters.Scarlet Empress.Skill3.Success` | 1 |
| 109794938761166 | Remilia | `Animations.Characters.Scarlet Empress.Skill3.SuccessENDLAG` | 1 |
| 132231122450051 | Remilia | `Animations.Characters.Scarlet Empress.Skill3.Victim` | 1 |
| 17551095296 | Remilia | `Animations.Characters.Scarlet Empress.Skill4.Miss` | 1 |
| 78489585784552 | Remilia | `Animations.Characters.Scarlet Empress.Skill4.Startup` | 1 |
| 82871872174505 | Remilia | `Animations.Characters.Scarlet Empress.Skill4.StartupNew` | 1 |
| 85755598829892 | Remilia | `Animations.Characters.Scarlet Empress.Skill4.Success` | 1 |
| 71464565385340 | Remilia | `Animations.Characters.Scarlet Empress.Skill4.Victim` | 1 |
| 109739299132189 | Remilia | `Animations.Characters.Scarlet Empress.Special.Hit` | 1 |
| 97264893487499 | Remilia | `Animations.Characters.Scarlet Empress.Special.Release` | 1 |
| 117322473499719 | Remilia | `Animations.Characters.Scarlet Empress.Special.ReleaseNew` | 1 |
| 129760642655211 | Remilia | `Animations.Combats.Scarlet Empress.Block` | 1 |
| 73746123899436 | Remilia | `Animations.Combats.Scarlet Empress.Block2` | 1 |
| 18445733559 | Remilia | `Animations.Combats.Scarlet Empress.BlockFlinch1` | 3 |
| 89951073993390 | Remilia | `Animations.Combats.Scarlet Empress.DashM1` | 1 |
| 133851040563942 | Remilia | `Animations.Combats.Scarlet Empress.DashM1Mode` | 1 |
| 133800367771260 | Remilia | `Animations.Combats.Scarlet Empress.DashM1Second` | 1 |
| 132060711277270 | Remilia | `Animations.Combats.Scarlet Empress.Downslam` | 1 |
| 81165337623816 | Remilia | `Animations.Combats.Scarlet Empress.DownslamSecond` | 1 |
| 112285075775053 | Remilia | `Animations.Combats.Scarlet Empress.FrontDash` | 2 |
| 115152468957804 | Remilia | `Animations.Combats.Scarlet Empress.FrontDashMode` | 1 |
| 94311448312548 | Remilia | `Animations.Combats.Scarlet Empress.Hit1` | 1 |
| 95478203831208 | Remilia | `Animations.Combats.Scarlet Empress.Hit2` | 1 |
| 98841667934972 | Remilia | `Animations.Combats.Scarlet Empress.Hit3` | 1 |
| 132464988285463 | Remilia | `Animations.Combats.Scarlet Empress.Hit4` | 1 |
| 137701041431404 | Remilia | `Animations.Combats.Scarlet Empress.HitSecond1` | 1 |
| 85401870749911 | Remilia | `Animations.Combats.Scarlet Empress.HitSecond2` | 1 |
| 128675044478123 | Remilia | `Animations.Combats.Scarlet Empress.HitSecond3` | 1 |
| 138941292691749 | Remilia | `Animations.Combats.Scarlet Empress.HitSecond4` | 1 |
| 123471770763857 | Remilia | `Animations.Combats.Scarlet Empress.Uppercut` | 1 |
| 133097663801152 | Remilia | `VFX.Scarlet Empress.SpinningRemiliaSpear.MainAnimation` | 7 |
| 115741366398216 | Remilia | `RS.Touhou.Combats.Scarlet Empress.Blitz.cam` | 1 |
| 112820707497987 | Remilia | `RS.Touhou.Combats.Scarlet Empress.BlitzKick2.cam` | 1 |
| 130198022684545 | Remilia | `RS.Touhou.Combats.Scarlet Empress.Blitzo.cam` | 1 |
| 93301883197633 | Remilia | `SS.ModelStorage.RemiliaWings.Script.Animation` | 1 |
| 122278729092408 | Remilia | `SS.ModelStorage.RemiliaWingsUlt.Script.Animation` | 1 |
| 106595932906570 | both | `Animations.BLSRAFTERIMAGES.BLSR 1` | 1 |
| 112214037939666 | both | `Animations.BLSRAFTERIMAGES.BLSR 2` | 1 |
| 119770714667862 | both | `Animations.BLSRAFTERIMAGES.BLSR 3` | 1 |
| 126650249505888 | both | `Animations.BLSRAFTERIMAGES.BLSR 4` | 1 |
| 15695297816 | both | `Animations.Characters.Immortal Blaze.Awakening.FantasySeal.Camera` | 2 |
| 17409311963 | both | `Animations.Characters.Immortal Blaze.Awakening.FantasySeal.User` | 2 |
| 17409403714 | both | `Animations.Characters.Immortal Blaze.Awakening.Skill2OLD.Hold` | 2 |
| 18149433144 | both | `Animations.Characters.Immortal Blaze.Awakening.Skill2OLD.Startup` | 2 |
| 17373814145 | both | `Animations.Characters.Immortal Blaze.Skill2OLD.InAir.Cast` | 3 |
| 17373812220 | both | `Animations.Characters.Immortal Blaze.Skill2OLD.InAir.Smash` | 3 |
| 17029138699 | both | `Animations.Characters.Immortal Blaze.Skill3Fists.Hold` | 6 |
| 18612081451 | both | `Animations.Characters.Immortal Blaze.Skill3Fists.Release` | 2 |
| 17029142737 | both | `Animations.Characters.Immortal Blaze.Skill3Fists.ReleaseAir` | 6 |
| 18612375563 | both | `Animations.Characters.Immortal Blaze.Skill3Fists.Success` | 2 |
| 18612383886 | both | `Animations.Characters.Immortal Blaze.Skill3Fists.Victim` | 2 |
| 18677792869 | both | `Animations.Combats.Hit1` | 1 |
| 18677788193 | both | `Animations.Combats.Hit2` | 1 |
| 18677782250 | both | `Animations.Combats.Hit3` | 1 |
| 18677798018 | both | `Animations.Combats.Hit4` | 1 |
| 122222337018536 | both | `Animations.Combats.Immortal Blaze.BackDash` | 2 |
| 15695395145 | both | `Animations.Combats.Immortal Blaze.Idle` | 2 |
| 133312172613881 | both | `Animations.Combats.Immortal Blaze.LeftDash` | 2 |
| 100830467870612 | both | `Animations.Combats.Immortal Blaze.RightDash` | 2 |
| 17312856852 | both | `Animations.Combats.Immortal Blaze.Run` | 2 |
| 126659012932837 | both | `Animations.Reactions.DashM1Reaction` | 1 |
| 126666515307802 | both | `Animations.Reactions.Reaction1` | 2 |
| 89450561243568 | both | `Animations.Reactions.Reaction2` | 2 |
| 88734040000550 | both | `Animations.Reactions.Reaction3` | 2 |
| 87273756597526 | both | `Animations.Reactions.Reaction4` | 2 |
| 17370044273 | both | `Animations.ReactionsCrazy.DashM1Reaction` | 3 |
| 77776207323955 | both | `Animations.ReactionsCrazy.Reaction1` | 1 |
| 106205693845137 | both | `Animations.ReactionsCrazy.Reaction2` | 1 |
| 113715472766145 | both | `Animations.ReactionsCrazy.Reaction3` | 1 |
| 106025773955713 | both | `Animations.ReactionsCrazy.Reaction4` | 1 |
| 18145472727 | both | `Animations.ReactionsFlyingREAL.Reaction1` | 1 |
| 18145475842 | both | `Animations.ReactionsFlyingREAL.Reaction2` | 1 |
| 18145477841 | both | `Animations.ReactionsFlyingREAL.Reaction3` | 1 |
| 18145480060 | both | `Animations.ReactionsFlyingREAL.Reaction4` | 1 |

## Sounds (275)

| id | for | where (first of n) | n |
|---|---|---|---|
| 7757156301 | Mokou | `VFX.Immortal Blaze.BambooBomb.fuse` | 1 |
| 4474833664 | Mokou | `VFX.Immortal Blaze.BambooBomb.sfx` | 1 |
| 262562442 | Mokou | `VFX.Immortal Blaze.BambooBomb.sfx2` | 1 |
| 2051450166 | Mokou | `VFX.Immortal Blaze.BambooBomb.sfx3` | 1 |
| 4898894127 | Mokou | `VFX.Immortal Blaze.BlockSound1` | 1 |
| 4898893138 | Mokou | `VFX.Immortal Blaze.BlockSound2` | 1 |
| 4898902438 | Mokou | `VFX.Immortal Blaze.BlockSound3` | 1 |
| 4898901387 | Mokou | `VFX.Immortal Blaze.BlockSound4` | 1 |
| 8701825353 | Mokou | `VFX.Immortal Blaze.Combat.BarrageHit1` | 2 |
| 3518146972 | Mokou | `VFX.Immortal Blaze.Combat.DashTrail.sfx` | 2 |
| 7211875405 | Mokou | `VFX.Immortal Blaze.Combat.FingerSnap` | 1 |
| 5560680723 | Mokou | `VFX.Immortal Blaze.Combat.FingerSnap2` | 1 |
| 5868574236 | Mokou | `VFX.Immortal Blaze.Combat.FingerSnap3` | 1 |
| 3518168170 | Mokou | `VFX.Immortal Blaze.Combat.FirstUltAttack1` | 1 |
| 3518167306 | Mokou | `VFX.Immortal Blaze.Combat.FirstUltStart` | 1 |
| 18904107800 | Mokou | `VFX.Immortal Blaze.Combat.GroundHit.ROCKIMPACT1` | 9 |
| 83208864085323 | Mokou | `VFX.Immortal Blaze.Combat.GroundHit2.ROCKIMPACT1` | 1 |
| 84788145657633 | Mokou | `VFX.Immortal Blaze.Combat.GroundHit2.ROCKIMPACT2` | 1 |
| 18708158894 | Mokou | `VFX.Immortal Blaze.Combat.Hit.VFX.h1` | 3 |
| 18708159984 | Mokou | `VFX.Immortal Blaze.Combat.Hit.VFX.h2` | 3 |
| 18708161597 | Mokou | `VFX.Immortal Blaze.Combat.Hit.VFX.h3` | 3 |
| 18708163148 | Mokou | `VFX.Immortal Blaze.Combat.Hit.VFX.h4` | 3 |
| 131861167964896 | Mokou | `VFX.Immortal Blaze.Combat.MokouSpinKickHit` | 1 |
| 71337810603971 | Mokou | `VFX.Immortal Blaze.Combat.MokouSpinSFX` | 1 |
| 120293120466328 | Mokou | `VFX.Immortal Blaze.Combat.MokouSpinStart` | 1 |
| 133568880103936 | Mokou | `VFX.Immortal Blaze.Combat.MokouSpinStop` | 1 |
| 98300619649690 | Mokou | `VFX.Immortal Blaze.Combat.ROCKIMPACT155` | 1 |
| 18708288317 | Mokou | `VFX.Immortal Blaze.Combat.Sfx.Swings.s1` | 1 |
| 18708289627 | Mokou | `VFX.Immortal Blaze.Combat.Sfx.Swings.s2` | 1 |
| 18708289230 | Mokou | `VFX.Immortal Blaze.Combat.Sfx.Swings.s3` | 1 |
| 18708288881 | Mokou | `VFX.Immortal Blaze.Combat.Sfx.Swings.s4` | 1 |
| 16898133698 | Mokou | `VFX.Immortal Blaze.Combat.SlashFire2` | 1 |
| 8186570431 | Mokou | `VFX.Immortal Blaze.Combat.ThrowBambooGrenade1` | 1 |
| 9105104700 | Mokou | `VFX.Immortal Blaze.Combat.ThrowBambooGrenade2` | 1 |
| 92250017598166 | Mokou | `VFX.Immortal Blaze.Combat.TornadoSFX` | 1 |
| 18904140422 | Mokou | `VFX.Immortal Blaze.Combat.Wind15` | 1 |
| 18904139414 | Mokou | `VFX.Immortal Blaze.Combat.Wind152` | 1 |
| 18921186069 | Mokou | `VFX.Immortal Blaze.Combat.Wind16` | 3 |
| 18921185746 | Mokou | `VFX.Immortal Blaze.Combat.Wind162` | 1 |
| 8128407082 | Mokou | `VFX.Immortal Blaze.Combat.abysscswing` | 1 |
| 103580204062268 | Mokou | `VFX.Immortal Blaze.Combat.airbeatdownsfx` | 1 |
| 89849119321803 | Mokou | `VFX.Immortal Blaze.Combat.althit` | 1 |
| 91210276253427 | Mokou | `VFX.Immortal Blaze.Combat.dessertsfx` | 2 |
| 85008523996659 | Mokou | `VFX.Immortal Blaze.Combat.dessertsfx2` | 1 |
| 131250987457635 | Mokou | `VFX.Immortal Blaze.Combat.diablesfx` | 1 |
| 120371006058971 | Mokou | `VFX.Immortal Blaze.Combat.dropkicksfx` | 1 |
| 79592637822825 | Mokou | `VFX.Immortal Blaze.Combat.fireburn` | 1 |
| 140016356294499 | Mokou | `VFX.Immortal Blaze.Combat.fireconter` | 1 |
| 127655618901083 | Mokou | `VFX.Immortal Blaze.Combat.firecounterslide` | 1 |
| 89021987158224 | Mokou | `VFX.Immortal Blaze.Combat.fireguy` | 1 |
| 81161906830054 | Mokou | `VFX.Immortal Blaze.Combat.fireguyscrape` | 1 |
| 131369317438838 | Mokou | `VFX.Immortal Blaze.Combat.fireguystartup` | 1 |
| 74450598327801 | Mokou | `VFX.Immortal Blaze.Combat.fireguystartup2` | 1 |
| 126329746083493 | Mokou | `VFX.Immortal Blaze.Combat.fireguystartup3` | 1 |
| 84288357070246 | Mokou | `VFX.Immortal Blaze.Combat.firekickexpl` | 1 |
| 100893262250084 | Mokou | `VFX.Immortal Blaze.Combat.firekickhit` | 1 |
| 83726469416071 | Mokou | `VFX.Immortal Blaze.Combat.firekickloop` | 1 |
| 99049609146781 | Mokou | `VFX.Immortal Blaze.Combat.firekickmiss` | 1 |
| 126693181803958 | Mokou | `VFX.Immortal Blaze.Combat.firethrow` | 1 |
| 8573521980 | Mokou | `VFX.Immortal Blaze.Combat.kick33swing` | 1 |
| 119119632450745 | Mokou | `VFX.Immortal Blaze.Combat.mokousfx` | 1 |
| 6177203860 | Mokou | `VFX.Immortal Blaze.Combat.mudamuda` | 1 |
| 8128429188 | Mokou | `VFX.Immortal Blaze.Combat.runespeed` | 1 |
| 17853845325 | Mokou | `VFX.Immortal Blaze.Combat.stab1` | 1 |
| 17853854020 | Mokou | `VFX.Immortal Blaze.Combat.stab2` | 1 |
| 92859054691403 | Mokou | `VFX.Immortal Blaze.Combat.wallcombosfx` | 1 |
| 87518608742739 | Mokou | `VFX.Immortal Blaze.Combat.windsfx1` | 1 |
| 109729509207586 | Mokou | `VFX.Immortal Blaze.feather.Sound` | 1 |
| 9085333927 | Mokou | `VFX.Immortal Blaze.jump2` | 1 |
| 137378160319690 | Mokou | `VFX.Immortal Blaze.mokoubeatdown2` | 1 |
| 7699333859 | Mokou | `VFX.Immortal Blaze.mokoujump1` | 1 |
| 114899115974479 | Mokou | `Attacks.Immortal Blaze.Awakening.Awaken.AwakeningScarySong` | 1 |
| 6128977275 | Remilia | `VFX.Combat.DashMiss.sfx` | 4 |
| 91303824150663 | Remilia | `VFX.Scarlet Empress.AWAKENVFX.aheartk.Sound` | 11 |
| 6861697328 | Remilia | `VFX.Scarlet Empress.BlockSound1` | 1 |
| 6861697427 | Remilia | `VFX.Scarlet Empress.BlockSound2` | 1 |
| 6861697362 | Remilia | `VFX.Scarlet Empress.BlockSound3` | 1 |
| 6861697390 | Remilia | `VFX.Scarlet Empress.BlockSound4` | 1 |
| 121762248225725 | Remilia | `VFX.Scarlet Empress.Combat.AURALOOPSFX` | 2 |
| 115019419243828 | Remilia | `VFX.Scarlet Empress.Combat.AURALOOPSFXGEBURA` | 1 |
| 17256141274 | Remilia | `VFX.Scarlet Empress.Combat.BigThrust2` | 1 |
| 18509588973 | Remilia | `VFX.Scarlet Empress.Combat.BloodDash` | 3 |
| 8128437441 | Remilia | `VFX.Scarlet Empress.Combat.DashTrail.sfx2` | 3 |
| 632919727 | Remilia | `VFX.Scarlet Empress.Combat.DashTrail2.sfx3` | 2 |
| 747238556 | Remilia | `VFX.Scarlet Empress.Combat.DashTrail2.sfx4` | 2 |
| 7441141577 | Remilia | `VFX.Scarlet Empress.Combat.Hit.VFX.h1` | 1 |
| 7441097182 | Remilia | `VFX.Scarlet Empress.Combat.Hit.VFX.h2` | 1 |
| 7441128032 | Remilia | `VFX.Scarlet Empress.Combat.Hit.VFX.h3` | 1 |
| 7441140898 | Remilia | `VFX.Scarlet Empress.Combat.Hit.VFX.h4` | 6 |
| 7837535984 | Remilia | `VFX.Scarlet Empress.Combat.HitHeartBreak.VFX.b1` | 2 |
| 7837536401 | Remilia | `VFX.Scarlet Empress.Combat.HitHeartBreak.VFX.b2` | 2 |
| 7837536770 | Remilia | `VFX.Scarlet Empress.Combat.HitHeartBreak.VFX.b3` | 2 |
| 7837537174 | Remilia | `VFX.Scarlet Empress.Combat.HitHeartBreak.VFX.b4` | 2 |
| 15836952587 | Remilia | `VFX.Scarlet Empress.Combat.HitHeartBreak.VFX.bloodhit` | 1 |
| 3743744465 | Remilia | `VFX.Scarlet Empress.Combat.HitHeartBreak.VFX.h1` | 5 |
| 689589276 | Remilia | `VFX.Scarlet Empress.Combat.HitHeartBreak.h1` | 17 |
| 8573523345 | Remilia | `VFX.Scarlet Empress.Combat.LegMovement` | 1 |
| 70544025865622 | Remilia | `VFX.Scarlet Empress.Combat.MMSFX` | 1 |
| 121433451659503 | Remilia | `VFX.Scarlet Empress.Combat.SKILL2FINISHEREXPL1SFX` | 1 |
| 102960997922295 | Remilia | `VFX.Scarlet Empress.Combat.SKILL2FINISHEREXPL2SFX` | 1 |
| 89090943302785 | Remilia | `VFX.Scarlet Empress.Combat.SKILL2FINISHERSFX` | 1 |
| 8176492141 | Remilia | `VFX.Scarlet Empress.Combat.Sfx.Swings.s1` | 4 |
| 9114890978 | Remilia | `VFX.Scarlet Empress.Combat.Updash1.sfx` | 1 |
| 8128405702 | Remilia | `VFX.Scarlet Empress.Combat.abysscswing` | 1 |
| 7441133345 | Remilia | `VFX.Scarlet Empress.Combat.bash1` | 1 |
| 7441132956 | Remilia | `VFX.Scarlet Empress.Combat.bash2` | 1 |
| 7441133912 | Remilia | `VFX.Scarlet Empress.Combat.bash3` | 1 |
| 137235867611784 | Remilia | `VFX.Scarlet Empress.Combat.beatdownsfx` | 1 |
| 9113464190 | Remilia | `VFX.Scarlet Empress.Combat.blooddrip` | 4 |
| 1753171776 | Remilia | `VFX.Scarlet Empress.Combat.bounce1` | 1 |
| 180204586 | Remilia | `VFX.Scarlet Empress.Combat.bounce2` | 1 |
| 166047765 | Remilia | `VFX.Scarlet Empress.Combat.bounce3` | 1 |
| 7374246665 | Remilia | `VFX.Scarlet Empress.Combat.chainBreak` | 5 |
| 7374234221 | Remilia | `VFX.Scarlet Empress.Combat.chainStart` | 2 |
| 9113823993 | Remilia | `VFX.Scarlet Empress.Combat.clothsfx12` | 1 |
| 9113823264 | Remilia | `VFX.Scarlet Empress.Combat.clothsfx14` | 1 |
| 6636232274 | Remilia | `VFX.Scarlet Empress.Combat.clothsfx15` | 1 |
| 9113534108 | Remilia | `VFX.Scarlet Empress.Combat.clothsfx16` | 1 |
| 2239424601 | Remilia | `VFX.Scarlet Empress.Combat.clothsfx17` | 1 |
| 123263862021547 | Remilia | `VFX.Scarlet Empress.Combat.counterstartupsfx` | 1 |
| 7441130752 | Remilia | `VFX.Scarlet Empress.Combat.crush1` | 1 |
| 7441129853 | Remilia | `VFX.Scarlet Empress.Combat.crush2` | 1 |
| 7441129469 | Remilia | `VFX.Scarlet Empress.Combat.crush3` | 1 |
| 120618932365957 | Remilia | `VFX.Scarlet Empress.Combat.enragedSFX` | 1 |
| 128352362625582 | Remilia | `VFX.Scarlet Empress.Combat.geburaSFX` | 1 |
| 181004943 | Remilia | `VFX.Scarlet Empress.Combat.gungnirsound` | 1 |
| 181004957 | Remilia | `VFX.Scarlet Empress.Combat.gungnirsound2` | 1 |
| 82833529557806 | Remilia | `VFX.Scarlet Empress.Combat.heartbreakstartupsfx` | 1 |
| 118841091348065 | Remilia | `VFX.Scarlet Empress.Combat.heartbreakstartupsfx2` | 1 |
| 134328973073184 | Remilia | `VFX.Scarlet Empress.Combat.heartbreakstartupsfx2end` | 1 |
| 100069473257998 | Remilia | `VFX.Scarlet Empress.Combat.heartbreakthrowsound` | 1 |
| 9063842075 | Remilia | `VFX.Scarlet Empress.Combat.jumpsfx` | 1 |
| 8956218288 | Remilia | `VFX.Scarlet Empress.Combat.madokajump` | 1 |
| 1657154945 | Remilia | `VFX.Scarlet Empress.Combat.movesound` | 1 |
| 2974753896 | Remilia | `VFX.Scarlet Empress.Combat.movesound5` | 16 |
| 123161037833102 | Remilia | `VFX.Scarlet Empress.Combat.movesound51` | 1 |
| 126868982350911 | Remilia | `VFX.Scarlet Empress.Combat.ncrsfx` | 1 |
| 124363255229259 | Remilia | `VFX.Scarlet Empress.Combat.ncrsfxexpl` | 1 |
| 5132612497 | Remilia | `VFX.Scarlet Empress.Combat.neco` | 1 |
| 131228548 | Remilia | `VFX.Scarlet Empress.Combat.overhere` | 1 |
| 104115141569517 | Remilia | `VFX.Scarlet Empress.Combat.remiliasfx` | 1 |
| 126121671708832 | Remilia | `VFX.Scarlet Empress.Combat.remiliavoiceline` | 1 |
| 99439377262478 | Remilia | `VFX.Scarlet Empress.Combat.remimovespin` | 1 |
| 116333745883592 | Remilia | `VFX.Scarlet Empress.Combat.remimoveuppercut` | 1 |
| 6903182307 | Remilia | `VFX.Scarlet Empress.Combat.spear152` | 1 |
| 17524153633 | Remilia | `VFX.Scarlet Empress.Combat.spear25` | 2 |
| 139878534297844 | Remilia | `VFX.Scarlet Empress.Combat.spear35` | 1 |
| 103172876264934 | Remilia | `VFX.Scarlet Empress.Combat.stab1` | 1 |
| 78713247191018 | Remilia | `VFX.Scarlet Empress.Combat.stab2` | 1 |
| 79009688458315 | Remilia | `VFX.Scarlet Empress.Combat.stab3` | 1 |
| 100323235846349 | Remilia | `VFX.Scarlet Empress.Combat.stingerAIRSTARTSFX` | 1 |
| 88026161225909 | Remilia | `VFX.Scarlet Empress.Combat.stingerEXPLSFX` | 1 |
| 96007461406628 | Remilia | `VFX.Scarlet Empress.Combat.stingerGRABSFX` | 1 |
| 72368579924299 | Remilia | `VFX.Scarlet Empress.Combat.stingerSTARTSFX` | 1 |
| 119516089698238 | Remilia | `VFX.Scarlet Empress.Combat.ultcountersfx` | 1 |
| 102806323024644 | Remilia | `VFX.Scarlet Empress.Combat.ultfrontdashsfx` | 1 |
| 129241641151674 | Remilia | `VFX.Scarlet Empress.Combat.vampirekissENDSFX` | 1 |
| 83441284464591 | Remilia | `VFX.Scarlet Empress.Combat.vampirekissFINISHERSFX` | 1 |
| 129882093232326 | Remilia | `VFX.Scarlet Empress.Combat.vampirekissSFX` | 1 |
| 139731475547429 | Remilia | `VFX.Scarlet Empress.Combat.vampirekissSTARTSFX` | 1 |
| 140661198604140 | Remilia | `VFX.Scarlet Empress.Combat.wallcombosfx` | 1 |
| 77264810342177 | Remilia | `VFX.Scarlet Empress.Combat.wingloopsfx` | 1 |
| 6476902954 | Remilia | `VFX.Scarlet Empress.HeadFX.Attachment.s1` | 4 |
| 8227931265 | Remilia | `VFX.Scarlet Empress.HeadFX.Attachment.s55` | 1 |
| 743521549 | Remilia | `VFX.Scarlet Empress.Heart Break.Emit.sfx` | 1 |
| 608494468 | Remilia | `VFX.Scarlet Empress.Heart Break.Emit.sfx2` | 1 |
| 608600954 | Remilia | `VFX.Scarlet Empress.Heart Break.Emit.sfx3` | 1 |
| 7441098525 | Remilia | `VFX.Scarlet Empress.Heart Break.Explode.sfx` | 1 |
| 7714910991 | Remilia | `VFX.Scarlet Empress.Heart Break.Explode.sfx2` | 7 |
| 1388740053 | Remilia | `VFX.Scarlet Empress.Heart Break.Explode.sfx3` | 3 |
| 8588542238 | Remilia | `VFX.Scarlet Empress.Smash.Smash.sfx` | 1 |
| 7128851174 | Remilia | `VFX.Scarlet Empress.Smash.Smash.sfx2` | 2 |
| 9067471663 | Remilia | `VFX.Scarlet Empress.Smash.SmashBigger.sfx1` | 2 |
| 9048843988 | Remilia | `VFX.Scarlet Empress.Smash.SmashBigger.sfx2` | 2 |
| 926264402 | Remilia | `VFX.Scarlet Empress.Snatch.Downslam.FinalHit.sfx` | 1 |
| 9113463638 | Remilia | `VFX.Scarlet Empress.Snatch.bloodsmash.2` | 3 |
| 9119294320 | Remilia | `VFX.Scarlet Empress.Snatch.bloodsmash.3` | 3 |
| 2227416952 | Remilia | `VFX.Scarlet Empress.Snatch.bloodsuckattach.bloodsuck.gor1` | 1 |
| 2227417121 | Remilia | `VFX.Scarlet Empress.Snatch.bloodsuckattach.bloodsuck.gor3` | 1 |
| 105522324133528 | Remilia | `VFX.Scarlet Empress.SpinningRemiliaSpear.remiliaspear.spinloop` | 7 |
| 9125386730 | Remilia | `VFX.Scarlet Empress.StabBarrage.BigSlash.bat1` | 3 |
| 9125386815 | Remilia | `VFX.Scarlet Empress.StabBarrage.BigSlash.bat2` | 3 |
| 9125386714 | Remilia | `VFX.Scarlet Empress.StabBarrage.BigSlash.bat3` | 3 |
| 138402299613793 | Remilia | `VFX.Scarlet Empress.StabBarrage.BigSlash.sfx1` | 1 |
| 7545764969 | Remilia | `VFX.Scarlet Empress.StabBarrage.Left.sfx1` | 2 |
| 17733489642 | Remilia | `VFX.Scarlet Empress.asukascream` | 1 |
| 18399714161 | Remilia | `VFX.Scarlet Empress.heartbreak.Attachm122ent.spinbladebycrokuran` | 30 |
| 85264084292514 | Remilia | `VFX.Scarlet Empress.heartbreak.HeartbreakExplosionSFX` | 8 |
| 18511857150 | Remilia | `VFX.Scarlet Empress.heartbreak.gunganir1` | 15 |
| 8128398192 | Remilia | `VFX.Scarlet Empress.heartbreak.gungnir` | 15 |
| 5334567730 | Remilia | `VFX.Scarlet Empress.heartbreaknew.gungnirloop` | 1 |
| 5754300955 | Remilia | `RS.Assets.crashremiliaspear.Impale` | 5 |
| 5754301788 | Remilia | `RS.Assets.crashremiliaspear.Impale2` | 5 |
| 7441143109 | Remilia | `RS.Assets.crashremiliaspear.slash2` | 5 |
| 77583881434727 | Remilia | `RS.Assets.crashremiliaspear.spinloop` | 1 |
| 6155969862 | Remilia | `RS.Assets.crashremiliaspear.spinny` | 5 |
| 17839662770 | Remilia | `RS.Assets.crashremiliaspear.swing1` | 5 |
| 17837850125 | Remilia | `RS.Assets.crashremiliaspear.swing12` | 5 |
| 129095297809850 | Remilia | `RS.Assets.crashremiliaspear.swing2` | 5 |
| 139502179573489 | Remilia | `RS.Assets.remiliaspear.spinloop` | 4 |
| 127881542100169 | Remilia | `RS.Modules.RemiliaSpearsThrowable.heartbreakFish.gunganir1` | 1 |
| 129252516034384 | Remilia | `RS.Modules.RemiliaSpearsThrowable.heartbreakStormbreaker.HeartbreakExplosionSFX` | 1 |
| 75152639792585 | Remilia | `RS.Voicelines.Scarlet Empress.Giggle.Giggle1` | 1 |
| 115166880441831 | Remilia | `RS.Voicelines.Scarlet Empress.Giggle.Giggle2` | 1 |
| 136140219198977 | Remilia | `RS.Voicelines.Scarlet Empress.SentenceFirstTake.Ahh... The summer sun is so annoying.` | 1 |
| 137688761941343 | Remilia | `RS.Voicelines.Scarlet Empress.SentenceFirstTake.Fairies are really useless.` | 1 |
| 115828545374625 | Remilia | `RS.Voicelines.Scarlet Empress.SentenceFirstTake.Hmm, I have no one to kill time with...` | 1 |
| 74621068711436 | Remilia | `RS.Voicelines.Scarlet Empress.SentenceFirstTake.I don't like the sun...` | 1 |
| 121349843717051 | Remilia | `RS.Voicelines.Scarlet Empress.SentenceFirstTake.I heard a rumor that ghost-based air conditioning is a trend...` | 1 |
| 96990589479767 | Remilia | `RS.Voicelines.Scarlet Empress.SentenceFirstTake.Vampires don't show up in mirrors, so this is just an afterimage.` | 1 |
| 95306801492087 | Remilia | `RS.Voicelines.Scarlet Empress.SentenceSecondTake.Ah, the summer sun is terrible.` | 1 |
| 130717891740391 | Remilia | `RS.Voicelines.Scarlet Empress.SentenceSecondTake.Fairies are really useless.` | 1 |
| 97498723009409 | Remilia | `RS.Voicelines.Scarlet Empress.SentenceSecondTake.Hmm, I have no one to kill time with...` | 1 |
| 70843721652818 | Remilia | `RS.Voicelines.Scarlet Empress.SentenceSecondTake.I don't like the sun...` | 1 |
| 90411865428269 | Remilia | `RS.Voicelines.Scarlet Empress.SentenceSecondTake.I heard a rumor that ghost-based air conditioning is a trend...` | 1 |
| 107296179467135 | Remilia | `RS.Voicelines.Scarlet Empress.SentenceSecondTake.So this is just an afterimage!` | 1 |
| 74318698139584 | Remilia | `RS.Voicelines.Scarlet Empress.SentenceSecondTake.Vampires don't show up in mirrors, so this is just an afterimage.` | 1 |
| 70878271270129 | Remilia | `RS.Voicelines.Scarlet Empress.Sound.(¬_¬")` | 1 |
| 110344618511757 | Remilia | `RS.Voicelines.Scarlet Empress.Sound.Owchies` | 1 |
| 100668643508929 | Remilia | `Attacks.Scarlet Empress.Awakening.Awaken.AwakeningScarySong` | 1 |
| 17538001669 | Remilia | `Attacks.Scarlet Empress.Awakening.Awaken.AwakeningScarySong1` | 1 |
| 119963367394670 | Remilia | `Attacks.Scarlet Empress.Awakening.Awaken.AwakeningScarySong2` | 1 |
| 6653554097 | both | `VFX.1up` | 1 |
| 5989939664 | both | `VFX.Combat.DashTrail.sfx` | 1 |
| 9117969717 | both | `VFX.Combat.hitupper` | 1 |
| 621557962 | both | `VFX.Combat.kick22` | 1 |
| 7119100776 | both | `VFX.Combat.kickdoor` | 1 |
| 9113822618 | both | `VFX.Immortal Blaze.Combat.ClothAwakening` | 4 |
| 443980606 | both | `VFX.Immortal Blaze.Combat.DashTrail.sfxburn` | 3 |
| 7119101332 | both | `VFX.Immortal Blaze.Combat.DownCut.sfx` | 4 |
| 8804201356 | both | `VFX.Immortal Blaze.Combat.FrontDashHit.VFX.h1` | 2 |
| 6150718109 | both | `VFX.Immortal Blaze.Combat.InstantChainThrow` | 2 |
| 7119101555 | both | `VFX.Immortal Blaze.Combat.Kick2` | 4 |
| 8348697790 | both | `VFX.Immortal Blaze.Combat.Sfx.Hits.s1` | 4 |
| 8348700441 | both | `VFX.Immortal Blaze.Combat.Sfx.Hits.s3` | 4 |
| 8379366672 | both | `VFX.Immortal Blaze.Combat.SpiritBuff` | 3 |
| 2227417262 | both | `VFX.Immortal Blaze.Combat.StretchHit.VFX.h3` | 3 |
| 2227416792 | both | `VFX.Immortal Blaze.Combat.StretchHit.VFX.h4` | 2 |
| 2275292812 | both | `VFX.Immortal Blaze.Combat.StretchHit.VFX.h5` | 2 |
| 8595975458 | both | `VFX.Immortal Blaze.Combat.Throw` | 2 |
| 175024455 | both | `VFX.Immortal Blaze.Combat.UpperCut.sfx2` | 2 |
| 220025741 | both | `VFX.Immortal Blaze.Combat.UpperCut.sfx3` | 2 |
| 17853814781 | both | `VFX.Immortal Blaze.Combat.bladespin1` | 8 |
| 17853829958 | both | `VFX.Immortal Blaze.Combat.bladespin2` | 2 |
| 17853839467 | both | `VFX.Immortal Blaze.Combat.bladespin3` | 2 |
| 9113759193 | both | `VFX.Immortal Blaze.Combat.chainmail` | 2 |
| 9105467029 | both | `VFX.Immortal Blaze.Combat.grab` | 2 |
| 6313897471 | both | `VFX.Immortal Blaze.Combat.gungnirsound` | 5 |
| 9118613187 | both | `VFX.Immortal Blaze.Combat.skill3fistsgrabslam.1` | 5 |
| 9118612324 | both | `VFX.Immortal Blaze.Combat.skill3fistsgrabslam.2` | 5 |
| 9118612306 | both | `VFX.Immortal Blaze.Combat.skill3fistsgrabslam.3` | 5 |
| 7441099960 | both | `VFX.Immortal Blaze.Combat.skill3fistsgrabslam.bloodmedium` | 3 |
| 3802269741 | both | `VFX.Immortal Blaze.Combat.skill3fistsgrabslam.smash` | 19 |
| 5507830073 | both | `VFX.Immortal Blaze.Combat.skill3grabslam.bloodmedium` | 4 |
| 125186329151865 | both | `VFX.Immortal Blaze.Hitfisttd.VFX.BlackFlash` | 4 |
| 1358454187 | both | `VFX.Immortal Blaze.Hitfisttd.VFX.BlackFlash1` | 4 |
| 7171591581 | both | `VFX.Immortal Blaze.swing` | 2 |
| 7655466603 | both | `VFX.Immortal Blaze.swing2` | 2 |
| 7714911066 | both | `VFX.Immortal Blaze.swing3` | 2 |
| 120157240722066 | both | `VFX.backdashsound` | 1 |
| 3929467229 | both | `VFX.dashsound` | 1 |
| 138169148 | both | `VFX.deathsound` | 1 |
| 4747078972 | both | `VFX.parrysound` | 1 |
| 6706981173 | both | `VFX.uppercutswing` | 1 |
| 9118617342 | both | `RS.Modules.Util.baseassets.Part1.sfx2` | 2 |
| 15335365157 | both | `RS.Modules.Util.baseassets.Part2.sfx2` | 3 |
| 15335364631 | both | `RS.Modules.Util.baseassets.Part2.sfx3` | 3 |
| 7214216646 | both | `RS.Modules.Util.baseassets.PartTree.sfx2` | 1 |
| 7214256592 | both | `RS.Modules.Util.baseassets.PartTree.sfx3` | 1 |
| 9120965080 | both | `RS.Modules.Util.baseassets.bamboopart.sfx2` | 1 |
| 9120802168 | both | `RS.Modules.Util.baseassets.bamboopart.sfx3` | 1 |
| 14119477497 | both | `RS.Modules.Util.baseassets.down.sfx` | 1 |
| 9117203557 | both | `RS.Modules.Util.baseassets.fabricpart.sfx2` | 2 |
| 543280386 | both | `RS.Modules.Util.baseassets.vasepart.sfx2` | 4 |
| 18628144419 | both | `Attacks.Immortal Blaze.Awakening.Awaken.remiliasfx` | 1 |
