-- name: Odyssey Ground Pound Dive
-- description: Press B out of ground pound to perform a dive with slight upward boost.

--- @param m MarioState
local function odyssey_dive_update(m)
    if m.action ~= ACT_GROUND_POUND then return end
    if (m.input & INPUT_B_PRESSED) == 0 then return end

    set_mario_action(m, ACT_DIVE, 1)
    mario_set_forward_vel(m, 40.0)
    m.vel.y = 28.0
end

hook_event(HOOK_MARIO_UPDATE, odyssey_dive_update)
