    -- if stepType == STEP_TYPE_GROUND then
    --     local turningSharply = (abs_angle_diff(m.intendedYaw, m.faceAngle.y) > 0x471C)

    --     if (m.input & INPUT_NONZERO_ANALOG) ~= 0
    --         and (m.action & (ACT_FLAG_BUTT_OR_STOMACH_SLIDE | ACT_FLAG_SHORT_HITBOX)) == 0
    --         and (m.pos.y <= m.floorHeight)
    --         and turningSharply
    --         and (mario_get_floor_class(m) ~= SURFACE_CLASS_VERY_SLIPPERY) then

    --         local nextX = m.pos.x + m.vel.x
    --         local nextZ = m.pos.z + m.vel.z
    --         local floorHeight = find_floor_height(nextX, m.pos.y, nextZ)

    --         if (m.pos.y > floorHeight + 100.0) then
    --             print("stopped")
    --             return GROUND_STEP_NONE
    --         end
    --     end
    -- end
