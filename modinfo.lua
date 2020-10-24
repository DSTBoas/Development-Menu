name = "Development Menu"
description = "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\tMade with 󰀍"

icon_atlas = "modicon.xml"
icon = "modicon.tex"

author = "Boas"
version = "0.56"
forumthread = ""

dont_starve_compatible = false
reign_of_giants_compatible = false
dst_compatible = true

all_clients_require_mod = false
client_only_mod = true

api_version = 10

folder_name = folder_name or name
if not folder_name:find("workshop-") then
    name = name .. " (dev)"
end

local function AddConfigOption(desc, data, hover)
    return {description = desc, data = data, hover = hover}
end

local function AddConfig(label, name, options, default, hover)
    return {
                label = label,
                name = name,
                options = options,
                default = default,
                hover = hover
           }
end

local function AddSectionTitle(title)
    return AddConfig(title, "", {{description = "", data = 0}}, 0)
end

local function GetKeyboardOptions()
    local keys = {}
    local nameKeys =
    {
        "Tab",
        "-",
        "=",
        "Space",
        "Enter",
        "Esc",
        "Insert",
        "Delete",
        "End",
        "Scroll lock",
        "Print Screen",
        "Capslock",
        "Scrollock",
        "Right Shift",
        "Left Shift",
        "Shift",
        "Right Ctrl",
        "Left Ctrl",
        "Ctrl",
        "Right Alt",
        "Left Alt",
        "Alt",
        "Backspace",
        ".",
        "/",
        ";",
        "}",
        "{",
        "\\",
        "~",
        "↑",
        "↓",
        "→",
        "←",
        "Page up",
        "Page down"
    }
    local specialKeys =
    {
        "TAB",
        "MINUS",
        "EQUALS",
        "SPACE",
        "ENTER",
        "ESCAPE",
        "INSERT",
        "DELETE",
        "END",
        "PAUSE",
        "PRINT",
        "CAPSLOCK",
        "SCROLLOCK",
        "RSHIFT",
        "LSHIFT",
        "SHIFT",
        "RCTRL",
        "LCTRL",
        "CTRL",
        "RALT",
        "LALT",
        "ALT",
        "BACKSPACE",
        "PERIOD",
        "SLASH",
        "SEMICOLON",
        "LEFTBRACKET",
        "RIGHTBRACKET",
        "BACKSLASH",
        "TILDE",
        "UP",
        "DOWN",
        "RIGHT",
        "LEFT",
        "PAGEUP",
        "PAGEDOWN",
    }

    local function AddConfigKey(t, key)
        t[#t + 1] = AddConfigOption(key, "KEY_" .. key)
    end

    local function AddConfigSpecialKey(t, name, key)
        t[#t + 1] = AddConfigOption(name, "KEY_" .. key)
    end

    local function AddDisabledConfigOption(t)
        t[#t + 1] = AddConfigOption("Disabled", false)
    end

    AddDisabledConfigOption(keys)

    local string = ""
    for i = 1, 26 do
        AddConfigKey(keys, string.char(64 + i))
    end

    for i = 1, 10 do
        AddConfigKey(keys, i % 10 .. "")
    end

    for i = 1, 12 do
        AddConfigKey(keys, "F" .. i)
    end

    for i = 1, #specialKeys do
        AddConfigSpecialKey(keys, nameKeys[i], specialKeys[i])
    end
    
    AddDisabledConfigOption(keys)

    return keys
end

local function GetDefaultOptions(hover)
    local function AddDefaultOption(t, desc, data, hover)
        t[#t + 1] = AddConfigOption(desc, data, hover)
    end

    local options = {}

    AddDefaultOption(options, "Disabled", false)
    AddDefaultOption(options, "Enabled", true, hover)

    return options
end

local KeyboardOptions = GetKeyboardOptions()
local SettingOptions = GetDefaultOptions()
local AssignKeyMessage = "Assign a key"
local AssignLanguageMessage = "Select your language"
local SettingMessage = "Set to your liking"

configuration_options =
{
    AddSectionTitle("Keybinds"),
    AddConfig(
        "Toggle menu",
        "TOGGLE_DEVELOPMENT_MENU",
        KeyboardOptions,
        false,
        AssignKeyMessage
    ),
    AddConfig(
        "Toggle godmode",
        "TOGGLE_GODMODE",
        KeyboardOptions,
        "KEY_G",
        AssignKeyMessage
    ),
    AddConfig(
        "Reset world",
        "RESET_WORLD",
        KeyboardOptions,
        "KEY_R",
        AssignKeyMessage
    ),
    AddConfig(
        "Save world",
        "SAVE_WORLD",
        KeyboardOptions,
        "KEY_S",
        AssignKeyMessage
    ),
    AddConfig(
        "Change damage multiplier",
        "CHANGE_DAMAGE_MULTIPLIER",
        KeyboardOptions,
        "KEY_K",
        AssignKeyMessage
    ),
    AddConfig(
        "Increase time scale",
        "INCREASE_TIME_SCALE",
        KeyboardOptions,
        "KEY_EQUALS",
        AssignKeyMessage
    ),
    AddConfig(
        "Decrease time scale",
        "DECREASE_TIME_SCALE",
        KeyboardOptions,
        "KEY_MINUS",
        AssignKeyMessage
    ),
    AddConfig(
        "Set debug entity",
        "SET_DEBUG_ENTITY",
        KeyboardOptions,
        "KEY_F1",
        AssignKeyMessage
    ),
    AddConfig(
        "Dump entity components/replicas",
        "DUMP_SELECT",
        KeyboardOptions,
        "KEY_F2",
        AssignKeyMessage
    ),
    AddConfig(
        "Entity event interceptor",
        "EVENT_LISTEN_SELECT",
        KeyboardOptions,
        "KEY_F3",
        AssignKeyMessage
    ),
    AddConfig(
        "Entity tags tracker",
        "TAG_DELTAS_TRACKER",
        KeyboardOptions,
        "KEY_F4",
        AssignKeyMessage
    ),
    AddConfig(
        "Entity animation tracker",
        "ANIMATION_DELTAS_TRACKER",
        KeyboardOptions,
        "KEY_F5",
        AssignKeyMessage
    ),
    AddConfig(
        "RPC traffic monitor",
        "RPC_SERVER_LISTENER",
        KeyboardOptions,
        "KEY_F6",
        AssignKeyMessage
    ),
    AddConfig(
        "Stop debugging",
        "STOP_DEBUGGING",
        KeyboardOptions,
        "KEY_F8",
        AssignKeyMessage
    ),
    AddConfig(
        "Clear console",
        "CLEAR_CONSOLE",
        KeyboardOptions,
        "KEY_L",
        AssignKeyMessage
    ),

    -- World
    AddConfig(
        "Next phase",
        "NEXT_PHASE",
        KeyboardOptions,
        "KEY_F9",
        AssignKeyMessage
    ),
    AddConfig(
        "Toggle rain",
        "TOGGLE_RAIN",
        KeyboardOptions,
        "KEY_F10",
        AssignKeyMessage
    ),
    AddConfig(
        "Simulation step",
        "SIM_STEP",
        KeyboardOptions,
        false,
        AssignKeyMessage
    ),


    AddSectionTitle("RPC Translations"),
    AddConfig(
        "Translate rpc codes",
        "TRANSLATE_RPC",
        SettingOptions,
        true,
        SettingMessage
    ),
    AddConfig(
        "Translate action codes",
        "TRANSLATE_ACTION",
        SettingOptions,
        true,
        SettingMessage
    ),
    AddConfig(
        "Translate control codes",
        "TRANSLATE_CONTROL",
        SettingOptions,
        true,
        SettingMessage
    ),
    AddConfig(
        "Translate recipe codes",
        "TRANSLATE_RECIPE",
        SettingOptions,
        false,
        SettingMessage
    ),


    AddSectionTitle("Defaults"),
    AddConfig(
        "Freecrafting",
        "FREECRAFTING",
        SettingOptions,
        true,
        SettingMessage
    ),
    AddConfig(
        "Godmode",
        "GODMODE",
        SettingOptions,
        true,
        SettingMessage
    ),
}
