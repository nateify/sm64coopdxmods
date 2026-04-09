-- name: No Lives
-- description: Applies infinite lives and hides the HUD icon.

local function infinite_lives_update(m)
    if m.playerIndex == 0 then
        m.numLives = 99
    end
end

local function hide_lives_hud()
    local currentFlags = hud_get_value(HUD_DISPLAY_FLAGS)
    hud_set_value(HUD_DISPLAY_FLAGS, currentFlags & ~HUD_DISPLAY_FLAG_LIVES)
end

hook_event(HOOK_MARIO_UPDATE, infinite_lives_update)
hook_event(HOOK_ON_HUD_RENDER, hide_lives_hud)
