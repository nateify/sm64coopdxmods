-- name: Improved Controls
-- description: Based on "Improved Controls" from Super Mario 64 Plus by Mors.

--- Helper to cast an angle/number to a signed 16-bit integer
--- @param val number
--- @return integer
local function s16(val)
    val = math.floor(val) & 0xFFFF
    if val >= 32768 then return val - 65536 end
    return val
end

-- Save velocity across hooks to modify air control
local savedVel = {}

-- Prevent recursion
local redirecting = false

--- @param m MarioState
local function on_set_mario_action(m)
    if m.action == ACT_WALL_KICK_AIR then
        if m.forwardVel < 28.0 then
            m.forwardVel = 28.0
        end
    elseif m.action == ACT_SLIDE_KICK then
        m.vel.y = 14.0
        if m.forwardVel < 36.0 then
            m.forwardVel = 36.0
        end
    end

    local actGroup = m.action & ACT_GROUP_MASK
    if actGroup ~= ACT_GROUP_AIRBORNE then
        savedVel[m.playerIndex] = nil
    end
end

--- @param m MarioState
--- @param incomingAction integer
local function before_set_mario_action(m, incomingAction, actionArg)
    if redirecting then return 0 end
    if incomingAction == ACT_DIVE or incomingAction == ACT_JUMP_KICK then
        if (m.input & INPUT_B_PRESSED) ~= 0 then
            if actionArg == 1 then return 0 end
            if m.controller.stickMag > 48.0 then
                -- Force a dive when the stick is held in a direction significantly
                if incomingAction == ACT_DIVE then return 0 end
                redirecting = true
                set_mario_action(m, ACT_DIVE, 1)
                redirecting = false
                return 1
            else
                -- Force a kick when the stick is not held
                if incomingAction == ACT_JUMP_KICK then return 0 end
                redirecting = true
                set_mario_action(m, ACT_JUMP_KICK, 0)
                redirecting = false
                return 1
            end
        end
    end

    -- Allow long jump on mistimed Z+A by 1 frame when running
    if incomingAction == ACT_GROUND_POUND then
        if m.action == ACT_JUMP and m.actionTimer <= 1 then
            if m.forwardVel > 10.0 then
                return ACT_LONG_JUMP
            end
        end
    end

    return 0
end


--- @param m MarioState
local function before_mario_update(m)
    local actGroup = m.action & ACT_GROUP_MASK
    if actGroup == ACT_GROUP_AIRBORNE and m.action ~= ACT_LONG_JUMP and m.action ~= ACT_FLYING then
        savedVel[m.playerIndex] = m.forwardVel
    end
end

--- @param m MarioState
local function mario_update(m)
    if m.playerIndex ~= 0 then return end
    if m.action == ACT_GROUND_POUND and m.actionState == 0 then
        local animInfo = m.marioObj.header.gfx.animInfo
        -- Apply faster flip velocities
        if m.actionTimer < 10 then
            m.vel.y = -24.0
        else
            m.vel.y = -54.0
        end

        -- Cut the animation lag time from +4 to +2
        if animInfo.curAnim ~= nil then
            if m.actionTimer >= animInfo.curAnim.loopEnd + 2 and m.actionTimer < animInfo.curAnim.loopEnd + 4 then
                play_sound(SOUND_MARIO_GROUND_POUND_WAH, m.marioObj.header.gfx.cameraToObject)
                m.actionState = 1
            end
        end
    end

    ---------------------------------------
    --  WALKING & BRAKING
    ---------------------------------------
    if m.action == ACT_WALKING then
        -- Improved Turn-around responsiveness
        if analog_stick_held_back(m) ~= 0 then
            if m.forwardVel >= 12.0 and m.forwardVel < 16.0 then
                set_mario_action(m, ACT_TURNING_AROUND, 0)
            elseif m.forwardVel < 10.0 and m.forwardVel > 0.0 then
                m.faceAngle.y = m.intendedYaw
                set_mario_action(m, ACT_TURNING_AROUND, 0)
            end
        end
    end

    if m.action == ACT_WALKING or m.action == ACT_DECELERATING or m.action == ACT_HOLD_WALKING or m.action == ACT_HOLD_DECELERATING then
        if m.forwardVel < -8.0 then
            m.forwardVel = -8.0
        end

        -- Faster Turning (0x1000 instead of 0x800)
        if (m.input & INPUT_NONZERO_ANALOG) ~= 0 then
            local diff = s16(m.intendedYaw - m.faceAngle.y)
            m.faceAngle.y = m.intendedYaw - approach_s32(diff, 0, 0x800, 0x800)
        end
    end
    -- Increase deceleration (2.0 to 2.5)
    if m.action == ACT_BRAKING then
        m.forwardVel = m.forwardVel - 0.5
        if m.forwardVel < 0 then m.forwardVel = 0 end
    end

    -- Faster crouch
    if m.action == ACT_START_CROUCHING or m.action == ACT_STOP_CROUCHING then
        local animID = m.marioObj.header.gfx.animInfo.animID
        set_mario_anim_with_accel(m, animID, 0x26000)
    end

    ---------------------------------------
    --  AIR CONTROL
    ---------------------------------------
    local actGroup = m.action & ACT_GROUP_MASK
    if actGroup == ACT_GROUP_AIRBORNE and m.action ~= ACT_LONG_JUMP and m.action ~= ACT_FLYING then
        if savedVel[m.playerIndex] == nil then return end

        local intendedDYaw = s16(m.intendedYaw - m.faceAngle.y)
        local intendedMag = m.intendedMag / 32.0
        local cosDYaw = coss(intendedDYaw)
        local sinDYaw = sins(intendedDYaw)

        local movingForward = (m.forwardVel > 0 and intendedMag * cosDYaw > 0) or
            (m.forwardVel < 0 and intendedMag * cosDYaw < 0)

        local prev = savedVel[m.playerIndex]
        local dragThreshold = 32.0
        local sidewaysSpeed = 0

        m.forwardVel = prev

        if (m.input & INPUT_NONZERO_ANALOG) ~= 0 then
            m.forwardVel = approach_f32(m.forwardVel, 0.0, 0.35, 0.35)

            if movingForward then
                if m.action ~= ACT_WALL_KICK_AIR then
                    m.forwardVel = m.forwardVel + (intendedMag * cosDYaw * 1.5)
                end
            else
                m.forwardVel = m.forwardVel + (intendedMag * cosDYaw * 3.5)
            end

            sidewaysSpeed = intendedMag * sinDYaw * 15.0
        else
            m.forwardVel = approach_f32(m.forwardVel, 0.0, 0.35, 0.35)
        end

        -- reapply drag thresholds
        if m.forwardVel > dragThreshold then
            m.forwardVel = m.forwardVel - 1.0
        end
        if m.forwardVel < -16.0 then
            m.forwardVel = m.forwardVel + 2.0
        end

        m.vel.x = m.forwardVel * sins(m.faceAngle.y) + sidewaysSpeed * sins(m.faceAngle.y + 0x4000)
        m.vel.z = m.forwardVel * coss(m.faceAngle.y) + sidewaysSpeed * coss(m.faceAngle.y + 0x4000)

        savedVel[m.playerIndex] = nil
    end

    -- Increment action timer on jump to account for long jump buffer fix
    if m.action == ACT_JUMP then
        m.actionTimer = m.actionTimer + 1
    end
end

hook_event(HOOK_ON_SET_MARIO_ACTION, on_set_mario_action)
hook_event(HOOK_BEFORE_SET_MARIO_ACTION, before_set_mario_action)
hook_event(HOOK_BEFORE_MARIO_UPDATE, before_mario_update)
hook_event(HOOK_MARIO_UPDATE, mario_update)
