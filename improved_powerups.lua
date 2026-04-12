-- name: Improved Powerups
-- description: Based on "Improved Powerups" from Super Mario 64 Plus by Mors.

------------------------------------------------------------------------
-- CONSTANTS & STATE
------------------------------------------------------------------------

local customShellTimers = {}

------------------------------------------------------------------------
-- FEATURES
------------------------------------------------------------------------

--- @param m MarioState
local function custom_metal_water_gravity(m)
    m.vel.y = m.vel.y - 2.0

    if m.vel.y < -24.0 then
        m.vel.y = -24.0
    end
end

------------------------------------------------------------------------
-- DISPATCHERS
------------------------------------------------------------------------

--- @param m MarioState
local function before_phys_step(m)
    local isMetalFalling = (m.action == ACT_METAL_WATER_FALLING or m.action == ACT_HOLD_METAL_WATER_FALLING)
    local isMetalPlunge = (m.action == ACT_WATER_PLUNGE and (m.flags & MARIO_METAL_CAP) ~= 0)

    if isMetalFalling or isMetalPlunge then
        m.vel.y = approach_f32(m.vel.y, -24.0, 2.0, 4.0)
    end
end

--- @param m MarioState
local function before_mario_update(m)
    if m.action == ACT_WATER_SHELL_SWIMMING then
        -- Extend the timer by 2x
        if m.actionTimer > 0 and (m.area.localAreaTimer % 2 == 0) then
            m.actionTimer = m.actionTimer - 1
        end
    end
end

hook_mario_action(ACT_METAL_WATER_FALLING, { gravity = custom_metal_water_gravity })
hook_mario_action(ACT_METAL_WATER_JUMP, { gravity = custom_metal_water_gravity })
hook_mario_action(ACT_HOLD_METAL_WATER_FALLING, { gravity = custom_metal_water_gravity })
hook_mario_action(ACT_HOLD_METAL_WATER_JUMP, { gravity = custom_metal_water_gravity })
hook_event(HOOK_BEFORE_PHYS_STEP, before_phys_step)
hook_event(HOOK_BEFORE_MARIO_UPDATE, before_mario_update)
