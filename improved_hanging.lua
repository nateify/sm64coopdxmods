-- name: Improved Hanging
-- description: Based on "Improved Hanging" from Super Mario 64 Plus by Mors.

------------------------------------------------------------------------
-- FEATURES
------------------------------------------------------------------------

--- @param m MarioState
local function improved_update_hang_moving(m)
    local maxSpeed = 8.0

    m.forwardVel = m.forwardVel + 1.0
    if m.forwardVel > maxSpeed then
        m.forwardVel = maxSpeed
    end

    local yawDiff = m.intendedYaw - m.faceAngle.y
    if yawDiff > 32767 then yawDiff = yawDiff - 65536 end
    if yawDiff < -32768 then yawDiff = yawDiff + 65536 end

    m.faceAngle.y = m.intendedYaw - approach_s32(yawDiff, 0, 0x800, 0x800)

    m.slideYaw = m.faceAngle.y
    m.slideVelX = m.forwardVel * sins(m.faceAngle.y)
    m.slideVelZ = m.forwardVel * coss(m.faceAngle.y)

    m.vel.x = m.slideVelX
    m.vel.y = 0.0
    m.vel.z = m.slideVelZ

    local nextPos = {
        x = m.pos.x - m.ceil.normal.y * m.vel.x,
        y = m.pos.y,
        z = m.pos.z - m.ceil.normal.y * m.vel.z
    }

    local stepResult = perform_hanging_step(m, nextPos)

    vec3f_copy(m.marioObj.header.gfx.pos, m.pos)
    m.marioObj.header.gfx.angle.y = m.faceAngle.y

    return stepResult
end

--- @param m MarioState
local function act_improved_start_hanging(m)
    m.actionTimer = m.actionTimer + 1

    if (m.input & INPUT_NONZERO_ANALOG) ~= 0 and m.actionTimer >= 31 then
        return set_mario_action(m, ACT_HANGING, 0)
    end

    -- Toggle instead of hold
    if (m.input & INPUT_A_PRESSED) ~= 0 then
        return set_mario_action(m, ACT_FREEFALL, 0)
    end

    if (m.input & INPUT_Z_PRESSED) ~= 0 then
        return set_mario_action(m, ACT_GROUND_POUND, 0)
    end

    if m.ceil == nil or m.ceil.type ~= SURFACE_HANGABLE then
        return set_mario_action(m, ACT_FREEFALL, 0)
    end

    set_mario_animation(m, MARIO_ANIM_HANG_ON_CEILING)
    play_sound_if_no_flag(m, SOUND_ACTION_HANGING_STEP, MARIO_ACTION_SOUND_PLAYED)

    update_hang_stationary(m)

    if is_anim_at_end(m) ~= 0 then
        set_mario_action(m, ACT_HANGING, 0)
    end

    return false
end

--- @param m MarioState
local function act_improved_hanging(m)
    if (m.input & INPUT_NONZERO_ANALOG) ~= 0 then
        return set_mario_action(m, ACT_HANG_MOVING, m.actionArg)
    end

    if (m.input & INPUT_A_PRESSED) ~= 0 then
        return set_mario_action(m, ACT_FREEFALL, 0)
    end

    if (m.input & INPUT_Z_PRESSED) ~= 0 then
        return set_mario_action(m, ACT_GROUND_POUND, 0)
    end

    if m.ceil == nil or m.ceil.type ~= SURFACE_HANGABLE then
        return set_mario_action(m, ACT_FREEFALL, 0)
    end

    if (m.actionArg & 1) ~= 0 then
        set_mario_animation(m, MARIO_ANIM_HANDSTAND_LEFT)
    else
        set_mario_animation(m, MARIO_ANIM_HANDSTAND_RIGHT)
    end

    update_hang_stationary(m)

    return false
end

--- @param m MarioState
local function act_improved_hang_moving(m)
    if (m.input & INPUT_A_PRESSED) ~= 0 then
        return set_mario_action(m, ACT_FREEFALL, 0)
    end

    if (m.input & INPUT_Z_PRESSED) ~= 0 then
        return set_mario_action(m, ACT_GROUND_POUND, 0)
    end

    if m.ceil == nil or m.ceil.type ~= SURFACE_HANGABLE then
        return set_mario_action(m, ACT_FREEFALL, 0)
    end

    if (m.actionArg & 1) ~= 0 then
        set_mario_animation(m, MARIO_ANIM_MOVE_ON_WIRE_NET_RIGHT)
    else
        set_mario_animation(m, MARIO_ANIM_MOVE_ON_WIRE_NET_LEFT)
    end

    if m.marioObj.header.gfx.animInfo.animFrame == 12 then
        play_sound(SOUND_ACTION_HANGING_STEP, m.marioObj.header.gfx.cameraToObject)
    end

    if is_anim_past_end(m) ~= 0 then
        m.actionArg = m.actionArg ~ 1

        if (m.input & INPUT_NONZERO_ANALOG) == 0 then
            return set_mario_action(m, ACT_HANGING, m.actionArg)
        end
    end

    improved_update_hang_moving(m)

    return false
end

------------------------------------------------------------------------
-- DISPATCHERS
------------------------------------------------------------------------

--- @param m MarioState
local function before_mario_update(m)
    -- Grab ceilings more easily
    if (m.action & ACT_FLAG_AIR) ~= 0 and m.vel.y >= 0 then
        if m.ceil ~= nil and m.ceil.type == SURFACE_HANGABLE then
            local distToCeil = m.ceilHeight - m.pos.y
            if distToCeil < 160 then
                m.vel.y = 0
                set_mario_action(m, ACT_START_HANGING, 0)
            end
        end
    end
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, before_mario_update)
hook_mario_action(ACT_START_HANGING, { every_frame = act_improved_start_hanging })
hook_mario_action(ACT_HANGING, { every_frame = act_improved_hanging })
hook_mario_action(ACT_HANG_MOVING, { every_frame = act_improved_hang_moving })
