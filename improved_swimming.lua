-- name: Improved Swimming
-- description: Based on "Improved Swimming" from Super Mario 64 Plus by Mors.

------------------------------------------------------------------------
-- CONSTANTS & STATE
------------------------------------------------------------------------

local savedPitch = {}

------------------------------------------------------------------------
-- UTILITIES
------------------------------------------------------------------------

local function approach_angle(current, target, inc, dec)
    local dist = (target - current) % 65536
    if dist > 32767 then dist = dist - 65536 end

    local result = approach_s32(current, current + dist, inc, dec)

    return result % 65536
end

------------------------------------------------------------------------
-- DISPATCHERS
------------------------------------------------------------------------

--- @param m MarioState
local function on_set_mario_action(m)
    if m.action == ACT_WATER_JUMP or m.action == ACT_HOLD_WATER_JUMP then
        m.vel.y = 48.0
    end
end

--- @param m MarioState
local function before_mario_update(m)
    savedPitch[m.playerIndex] = m.faceAngle.x

    if m.action == ACT_WATER_JUMP or m.action == ACT_HOLD_WATER_JUMP then
        if m.forwardVel < 18.0 then
            m.forwardVel = 18.0
        end
    end

    -- Swim buffs
    if m.action == ACT_BREASTSTROKE then
        local next_timer = m.actionTimer + 1
        if next_timer < 6 then
            m.forwardVel = m.forwardVel + 0.5
        elseif next_timer >= 9 then
            m.forwardVel = m.forwardVel + 1.5
        end
    end
end

--- @param m MarioState
local function on_mario_update(m)
    if m.playerIndex ~= 0 then return end

    if (m.action & ACT_GROUP_MASK) == ACT_GROUP_SUBMERGED then
        -- Alter buoyancy
        if (m.flags & MARIO_METAL_CAP) == 0 then
            local near_surface = ((m.waterLevel - 80) - m.pos.y) < 400.0
            if near_surface then
                m.vel.y = m.vel.y + 0.75
            elseif (m.action & ACT_FLAG_MOVING) == 0 then
                m.vel.y = m.vel.y + 1.5
            end
        end

        -- Smooth pitch
        local current_pitch = m.faceAngle.x
        local old_pitch = savedPitch[m.playerIndex] or current_pitch

        local diff = (current_pitch - old_pitch) % 65536
        if diff > 32767 then diff = diff - 65536 end
        if diff < -32768 then diff = diff + 65536 end

        if math.abs(diff) > 0x200 then
            m.faceAngle.x = approach_angle(old_pitch, current_pitch, 0x400, 0x400)
        end
    end
end

hook_event(HOOK_ON_SET_MARIO_ACTION, on_set_mario_action)
hook_event(HOOK_BEFORE_MARIO_UPDATE, before_mario_update)
hook_event(HOOK_MARIO_UPDATE, on_mario_update)
