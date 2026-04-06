-- name: Improved Controls
-- description: Based on "Improved Controls" from Super Mario 64 Plus by Mors.

------------------------------------------------------------------------
-- CONSTANTS & STATE
------------------------------------------------------------------------

local WITH_TURN_ACTIONS = {
    [ACT_BUTT_SLIDE_AIR] = true,
    [ACT_HOLD_BUTT_SLIDE_AIR] = true,
}

local WITHOUT_TURN_ACTIONS = {
    [ACT_RIDING_SHELL_FALL] = true,
    [ACT_DIVE] = true,
    [ACT_AIR_THROW] = true,
    [ACT_CRAZY_BOX_BOUNCE] = true,
    [ACT_FORWARD_ROLLOUT] = true,
    [ACT_BACKWARD_ROLLOUT] = true,
    [ACT_SLIDE_KICK] = true,
    [ACT_JUMP_KICK] = true,
    [ACT_FLYING_TRIPLE_JUMP] = true,
    [ACT_VERTICAL_WIND] = true,
    [ACT_SPECIAL_TRIPLE_JUMP] = true,

    [ACT_JUMP] = true,
    [ACT_DOUBLE_JUMP] = true,
    [ACT_TRIPLE_JUMP] = true,
    [ACT_BACKFLIP] = true,
    [ACT_FREEFALL] = true,
    [ACT_HOLD_JUMP] = true,
    [ACT_HOLD_FREEFALL] = true,
    [ACT_SIDE_FLIP] = true,
    [ACT_WALL_KICK_AIR] = true,
    [ACT_LONG_JUMP] = true,
    [ACT_TOP_OF_POLE_JUMP] = true,
}

local CAN_TURN_ACTIONS = {
    [ACT_JUMP] = true,
    [ACT_DOUBLE_JUMP] = true,
    [ACT_TRIPLE_JUMP] = true,
    [ACT_BACKFLIP] = true,
    [ACT_FREEFALL] = true,
    [ACT_HOLD_JUMP] = true,
    [ACT_HOLD_FREEFALL] = true,
    [ACT_SIDE_FLIP] = true,
    [ACT_WALL_KICK_AIR] = true,
    [ACT_LONG_JUMP] = true,
    [ACT_TOP_OF_POLE_JUMP] = true,

    [ACT_RIDING_SHELL_FALL] = true,
    [ACT_AIR_THROW] = true,
    [ACT_JUMP_KICK] = true,
    [ACT_FLYING_TRIPLE_JUMP] = true,
    [ACT_VERTICAL_WIND] = true,
    [ACT_SPECIAL_TRIPLE_JUMP] = true,
}

local ACT_MODERN_LEDGE_DROP = allocate_mario_action(ACT_GROUP_AIRBORNE | ACT_FLAG_AIR)

local savedVel = {}

------------------------------------------------------------------------
-- UTILITIES
------------------------------------------------------------------------

--- Helper to cast an angle/number to a signed 16-bit integer
--- @param val number
--- @return integer
local function s16(val)
    val = math.floor(val) & 0xFFFF
    if val >= 32768 then return val - 65536 end
    return val
end

local function update_saved_velocity(m)
    if WITH_TURN_ACTIONS[m.action] or WITHOUT_TURN_ACTIONS[m.action] then
        savedVel[m.playerIndex] = m.forwardVel
    else
        savedVel[m.playerIndex] = nil
    end
end

------------------------------------------------------------------------
-- FEATURES
------------------------------------------------------------------------

--- @param m MarioState
local function dive_jump_kick_intent(m, incomingAction, actionArg)
    if actionArg ~= 0 then return end
    if (m.input & INPUT_B_PRESSED) ~= 0 then
        if m.controller.stickMag > 48.0 then
            -- Force Dive if stick is held
            if incomingAction == ACT_DIVE then return end
            return ACT_DIVE
        else
            -- Force Kick if stick is neutral
            if incomingAction == ACT_JUMP_KICK then return end
            return ACT_JUMP_KICK
        end
    end
end

--- @param m MarioState
local function buffer_long_jump(m, incomingAction)
    -- Allow long jump on mistimed Z+A by 1 frame when running
    if m.action == ACT_JUMP and m.actionTimer <= 1 then
        if m.forwardVel > 10.0 then
            return ACT_LONG_JUMP
        end
    end
end

--- @param m MarioState
local function speedup_ground_pound(m)
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


--- @param m MarioState
local function movement_tweaks(m)
    -- Improved Turn-around responsiveness
    if m.action == ACT_WALKING then
        if analog_stick_held_back(m) ~= 0 then
            if m.forwardVel >= 12.0 and m.forwardVel < 16.0 then
                set_mario_action(m, ACT_TURNING_AROUND, 0)
            elseif m.forwardVel < 10.0 and m.forwardVel > 0.0 then
                m.faceAngle.y = m.intendedYaw
                set_mario_action(m, ACT_TURNING_AROUND, 0)
            end
        end
    end

    -- Faster turning
    if m.action == ACT_WALKING or m.action == ACT_DECELERATING or m.action == ACT_HOLD_WALKING or m.action == ACT_HOLD_DECELERATING then
        if m.forwardVel < -8.0 then
            m.forwardVel = -8.0
        end

        if (m.input & INPUT_NONZERO_ANALOG) ~= 0 then
            local diff = s16(m.intendedYaw - m.faceAngle.y)
            m.faceAngle.y = m.intendedYaw - approach_s32(diff, 0, 0x800, 0x800)
        end
    end

    if m.action == ACT_BURNING_GROUND then
        local diff = s16(m.intendedYaw - m.faceAngle.y)
        m.faceAngle.y = m.intendedYaw - approach_s32(diff, 0, 0x200, 0x200)
    end

    -- Increase deceleration
    if m.action == ACT_BRAKING then
        m.forwardVel = m.forwardVel - 0.5
        if m.forwardVel < 0 then m.forwardVel = 0 end
    end

    -- Faster crouch
    if m.action == ACT_START_CROUCHING or m.action == ACT_STOP_CROUCHING then
        local animID = m.marioObj.header.gfx.animInfo.animID
        set_mario_anim_with_accel(m, animID, 0x26000)
    end

    -- Ledge protection
    if m.action == ACT_DECELERATING then
        check_ledge_climb_down(m)
    end
end

--- @param m MarioState
local function act_modern_ledge_drop(m)
    set_mario_animation(m, MARIO_ANIM_GENERAL_FALL)

    m.vel.y = math.max(m.vel.y - 4.0, -75.0)

    local step = perform_air_step(m, 0)

    if step == AIR_STEP_LANDED then
        set_mario_action(m, ACT_FREEFALL_LAND, 0)
        return true
    end

    if m.actionTimer > 8 then
        set_mario_action(m, ACT_FREEFALL, 0)
    end

    m.actionTimer = m.actionTimer + 1
    return false
end

--- @param m MarioState
local function improved_ledge_drop(m)
    local stick_down = m.controller.stickY < -60
    local z_pressed = (m.controller.buttonPressed & Z_TRIG) ~= 0
    if z_pressed or stick_down then
        set_mario_action(m, ACT_MODERN_LEDGE_DROP, 0)
        m.pos.y = m.pos.y - 160
        m.pos.x = m.pos.x - 30 * sins(m.faceAngle.y)
        m.pos.z = m.pos.z - 30 * coss(m.faceAngle.y)

        vec3f_copy(m.marioObj.header.gfx.pos, m.pos)
        vec3f_copy(m.marioObj.header.gfx.prevPos, m.pos)

        m.forwardVel = 0
        m.vel.y = 0.0

        m.controller.buttonPressed = m.controller.buttonPressed & ~Z_TRIG

        play_sound(SOUND_ACTION_TERRAIN_JUMP, m.marioObj.header.gfx.cameraToObject)
    end
end

--- @param m MarioState
local function air_tweaks(m)
    if savedVel[m.playerIndex] == nil then return end

    local isWithTurn = WITH_TURN_ACTIONS[m.action]
    local isWithoutTurn = WITHOUT_TURN_ACTIONS[m.action]
    local canTurn = CAN_TURN_ACTIONS[m.action]

    if m.action == ACT_LONG_JUMP then return end
    if not isWithTurn and not isWithoutTurn then return end

    -- Revert forwardVel to what it was at the very start of the frame
    m.forwardVel = savedVel[m.playerIndex]

    local dragThreshold = 32.0
    local sidewaysSpeed = 0

    if (m.input & INPUT_NONZERO_ANALOG) ~= 0 then
        m.forwardVel = approach_f32(m.forwardVel, 0.0, 0.35, 0.35)

        local intendedDYaw = s16(m.intendedYaw - m.faceAngle.y)
        local intendedMag = m.intendedMag / 32.0
        local cosDYaw = coss(intendedDYaw)
        local sinDYaw = sins(intendedDYaw)

        local movingForward = (m.forwardVel > 0 and intendedMag * cosDYaw > 0) or
            (m.forwardVel < 0 and intendedMag * cosDYaw < 0)

        if movingForward then
            if m.action ~= ACT_WALL_KICK_AIR then
                m.forwardVel = m.forwardVel + (intendedMag * cosDYaw * 1.5)
            end
        else
            m.forwardVel = m.forwardVel + (intendedMag * cosDYaw * 3.5)
        end

        if isWithTurn then
            m.faceAngle.y = m.faceAngle.y + s16(1024.0 * sinDYaw * intendedMag)
        elseif canTurn then
            sidewaysSpeed = intendedMag * sinDYaw * 15.0
            m.faceAngle.y = m.faceAngle.y + s16(320.0 * sinDYaw * intendedMag)
        else
            sidewaysSpeed = intendedMag * sinDYaw * 15.0
            m.faceAngle.y = m.faceAngle.y + s16(64.0 * sinDYaw * intendedMag)
        end
    else
        m.forwardVel = approach_f32(m.forwardVel, 0.0, 0.35, 0.35)
    end

    if m.forwardVel > dragThreshold then
        m.forwardVel = m.forwardVel - 1.0
    end
    if m.forwardVel < -16.0 then
        m.forwardVel = m.forwardVel + 2.0
    end

    m.slideVelX = m.forwardVel * sins(m.faceAngle.y)
    m.slideVelZ = m.forwardVel * coss(m.faceAngle.y)

    if isWithoutTurn then
        -- Add sideways speed vector
        m.slideVelX = m.slideVelX + sidewaysSpeed * sins(m.faceAngle.y + 0x4000)
        m.slideVelZ = m.slideVelZ + sidewaysSpeed * coss(m.faceAngle.y + 0x4000)
    end

    m.vel.x = m.slideVelX
    m.vel.z = m.slideVelZ

    savedVel[m.playerIndex] = nil
end

--- @param m MarioState
local function ledge_protection(m)
    if (m.input & INPUT_NONZERO_ANALOG) ~= 0
        and (m.action & (ACT_FLAG_BUTT_OR_STOMACH_SLIDE | ACT_FLAG_SHORT_HITBOX)) == 0
        and (m.pos.y <= m.floorHeight)
        and (mario_get_floor_class(m) ~= SURFACE_CLASS_VERY_SLIPPERY) then
        local floorNormalY = m.floor ~= nil and m.floor.normal.y or 1.0
        local qStepX = floorNormalY * (m.vel.x / 4.0)
        local qStepZ = floorNormalY * (m.vel.z / 4.0)

        local testX = m.pos.x
        local testZ = m.pos.z

        for i = 1, 4 do
            testX = testX + qStepX
            testZ = testZ + qStepZ

            local predictedFloorHeight = find_floor_height(testX, m.pos.y, testZ)
            if (m.pos.y > predictedFloorHeight + 100.0) then
                local movementAngle = atan2s(m.vel.z, m.vel.x)
                local intentDifference = abs_angle_diff(m.intendedYaw, movementAngle)

                -- 0x3000 is 67.5 degrees
                if intentDifference > 0x3000 then
                    m.forwardVel = 0
                    m.vel.x = 0
                    m.vel.z = 0
                    return GROUND_STEP_NONE
                end
                break
            end
        end
    end
end

------------------------------------------------------------------------
-- DISPATCHERS
------------------------------------------------------------------------

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

    update_saved_velocity(m)
end

--- @param m MarioState
local function before_set_mario_action(m, incomingAction, actionArg)
    if incomingAction == ACT_DIVE or incomingAction == ACT_JUMP_KICK then
        local diveKickResult = dive_jump_kick_intent(m, incomingAction, actionArg)
        if diveKickResult ~= nil then return diveKickResult end
    end

    if incomingAction == ACT_GROUND_POUND then
        local longJumpResult = buffer_long_jump(m, incomingAction)
        if longJumpResult ~= nil then return longJumpResult end
    end
end

--- @param m MarioState
local function before_mario_update(m)
    update_saved_velocity(m)

    if m.action == ACT_LEDGE_GRAB then
        improved_ledge_drop(m)
    end
end

--- @param m MarioState
local function on_mario_update(m)
    if m.playerIndex ~= 0 then return end

    if m.action == ACT_GROUND_POUND and m.actionState == 0 then
        speedup_ground_pound(m)
    end

    movement_tweaks(m)

    -- Increment action timer on jump for buffer_long_jump
    if m.action == ACT_JUMP then
        m.actionTimer = m.actionTimer + 1
    end
end

--- @param m MarioState
--- @param stepType integer
local function before_phys_step(m, stepType)
    if stepType == STEP_TYPE_AIR then
        air_tweaks(m)
    end

    if stepType == STEP_TYPE_GROUND then
        ledge_protection(m)
    end
end

hook_event(HOOK_BEFORE_PHYS_STEP, before_phys_step)
hook_event(HOOK_BEFORE_SET_MARIO_ACTION, before_set_mario_action)
hook_event(HOOK_ON_SET_MARIO_ACTION, on_set_mario_action)
hook_event(HOOK_BEFORE_MARIO_UPDATE, before_mario_update)
hook_event(HOOK_MARIO_UPDATE, on_mario_update)
hook_mario_action(ACT_MODERN_LEDGE_DROP, act_modern_ledge_drop)
