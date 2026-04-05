-- name: Fix Bugs
-- description: WIP

--- @param m MarioState
function on_set_mario_action(m)
        if m.action == ACT_GROUND_POUND and m.prevAction == ACT_SIDE_FLIP then
        if m.actionTimer <= 1 then
            if m.intendedMag > 0 then
                m.faceAngle.y = m.intendedYaw
            else
                m.faceAngle.y = atan2s(m.vel.z, m.vel.x)
            end
            m.marioObj.header.gfx.angle.y = m.faceAngle.y
            vec3s_copy(m.marioObj.header.gfx.prevAngle, m.marioObj.header.gfx.angle)
        end
    end
end

hook_event(HOOK_ON_SET_MARIO_ACTION, on_set_mario_action)
