-- name: Enemy Bouncing
-- description: Hold A when bouncing off of an enemy to get more vertical height.

local prevVelY = {}

--- @param m MarioState
local function before_mario_update(m)
    prevVelY[m.playerIndex] = m.vel.y
end

--- @param m MarioState
--- @param interactObj Object
--- @param interactType InteractionType
--- @param interactValue boolean
local function on_mario_interact(m, interactObj, interactType, interactValue)
    if interactType == INTERACT_BOUNCE_TOP then
        local oldVel = prevVelY[m.playerIndex] or 0
        local currentVel = m.vel.y

        if currentVel == 30.0 and currentVel > oldVel then
            if (m.input & INPUT_A_DOWN) ~= 0 then
                if m.action == ACT_LONG_JUMP then
                    m.vel.y = 39.6
                else
                    m.vel.y = 56.0
                end
            end
        end
    end
end

hook_event(HOOK_BEFORE_MARIO_UPDATE, before_mario_update)
hook_event(HOOK_ON_INTERACT, on_mario_interact)
