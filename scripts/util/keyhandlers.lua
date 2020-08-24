local KeyHandlers = {}
local KeyDebounce = {}

local function DoKey(key, down)
    if KeyHandlers[key] then
        if down and not KeyDebounce[key] then
            for i = 1, #KeyHandlers[key] do
                KeyHandlers[key][i]()
            end
        end
        KeyDebounce[key] = down
    end
end

local OldOnRawKey = FrontEnd.OnRawKey

function FrontEnd:OnRawKey(key, down)
    DoKey(key, down)
    OldOnRawKey(self, key, down)
end

local function GetConfigByte(config)
    return rawget(_G, GetModConfigData(config, MOD_DEVELOPMENT_MENU.MODNAME))
end

function AddGlobalKey(config, fn)
    config = GetConfigByte(config)
    if config then
        KeyHandlers[config] = KeyHandlers[config] or {}
        KeyHandlers[config][#KeyHandlers[config] + 1] = fn
    end
end

local function GetActiveScreenName()
    local activeScreen = TheFrontEnd:GetActiveScreen()
    return activeScreen and activeScreen.name or ""
end

local function ValidateKeybind()
    return GetActiveScreenName() == "HUD"
end

function AddGameKey(config, fn)
    AddGlobalKey(config, function()
        if ValidateKeybind() then
            fn()
        end
    end)
end
