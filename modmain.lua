Assets =
{
    --Asset("ATLAS", "images/menu.xml"),
}

_G = GLOBAL
require = _G.require

local MOD_DEVELOPMENT_MENU = {}
MOD_DEVELOPMENT_MENU.MODNAME = modname
_G.MOD_DEVELOPMENT_MENU = MOD_DEVELOPMENT_MENU

require "keybinds"

local Commands =
{
   FREECRAFTING = "c_freecrafting()",
   GODMODE = "c_supergodmode()"
}

local function OnPlayerPostInit(inst)
    inst:DoTaskInTime(0, function()
        if inst == _G.ThePlayer then
            for config, command in pairs(Commands) do
                if GetModConfigData(config) then
                    _G.TheNet:SendRemoteExecute(command)
                end
            end
        end
    end)
end
AddPlayerPostInit(OnPlayerPostInit)
