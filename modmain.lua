Assets =
{
    --Asset("ATLAS", "images/menu.xml"),
}

_G = GLOBAL
require = _G.require

local MOD_DEVELOPMENT_MENU = {}
MOD_DEVELOPMENT_MENU.MODNAME = modname
MOD_DEVELOPMENT_MENU.KEYBINDSERVICE = require "util/keybindservice"(modname)
_G.MOD_DEVELOPMENT_MENU = MOD_DEVELOPMENT_MENU

require "keybinds"

local function OnPlayerActivated(_, player)
    if player ~= _G.ThePlayer then
        return
    end

    local commands =
    {
       FREECRAFTING = "c_freecrafting()",
       GODMODE = "c_supergodmode()"
    }

    for config, command in pairs(commands) do
        if GetModConfigData(config) then
            _G.TheNet:SendRemoteExecute(command)
        end
    end
end

local function OnWorldPostInit(inst)
    if _G.TheWorld == nil then
        return
    end

    _G.TheWorld:ListenForEvent("playeractivated", OnPlayerActivated, _G.TheWorld)
end
AddPrefabPostInit("world", OnWorldPostInit)
