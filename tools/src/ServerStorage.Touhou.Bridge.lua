-- (round 107) What the owner's Touhou place's move scripts reached for that
-- only that place had. QuirkServer (Kit.TH) fills it in:
--   GetLocalCharPosition:InvokeClient(player, body?) - there, the mover's own
--     machine said where he (or `body`) stood; here the server answers (that
--     root's CFrame).
--   GetMouseHit:InvokeClient(player) - there, where his mouse was; here,
--     where he was aiming when he pressed the key.
--   isEntity(part) - there, every body in a fight was under
--     workspace.Ignore.Entities; here, a part of anyone's body.
return {}
