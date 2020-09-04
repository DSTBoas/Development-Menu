local DevelopmentScreen = require "screens/development_menu"
local Notify = require "util/player_notifier"
local Threading = require "util/threading"
local KeybindService = MOD_DEVELOPMENT_MENU.KEYBINDSERVICE

local function ValidateFocusState()
    local activeScreen = TheFrontEnd:GetActiveScreen()
    local focusWidget = TheFrontEnd:GetFocusWidget()
    return not (activeScreen
           and activeScreen.name == "ModConfigurationScreen"
           and focusWidget
           and focusWidget.texture
           and (focusWidget.texture:find("spinner") or focusWidget.texture:find("arrow")))
end

local function ValidateScreenState()
    return not TheFrontEnd.forceProcessText
       and ValidateFocusState()
end

local function GetThreadName(str)
    return str:gsub("_", " ")
end

local StringFormat = string.format
local function Format(str, ...)
    return StringFormat(str, ...)
end

local function NotifyFormatted(str, ...)
    Notify(Format(str, ...))
end

local function PrintFormatted(str, ...)
    print(Format(str, ...))
end

KeybindService:AddGlobalKey("TOGGLE_DEVELOPMENT_MENU", function()
    local menu = TheFrontEnd:GetOpenScreenOfType("DevelopmentScreen")

    if menu == nil then
        if ValidateScreenState() then
            TheFrontEnd:PushScreen(DevelopmentScreen())
        end
    else
        TheFrontEnd:PopScreen(menu)
    end
end)

local function DeepSelect()
    local ent = TheInput:GetWorldEntityUnderMouse()

    if not ent and TheInput.hoverinst and TheInput.hoverinst.widget then
        local tile = TheInput.hoverinst.widget.parent
        if tile and tile.name and tile.name == "ItemTile" then
            ent = tile.item
        end
    end

    if not ent and TheWorld then
        ent = TheWorld
    end

    SetDebugEntity(ent)

    if ent and not TheSim:GetDebugRenderEnabled() then
        TheSim:SetDebugRenderEnabled(true)
    end

    return GetDebugEntity()
end

KeybindService:AddGlobalKey("SET_DEBUG_ENTITY", function()
    local ent = DeepSelect()
    if checkentity(ent) and ent.prefab then
        NotifyFormatted("Debug entity: %s", ent.prefab)
    end
end)

local function DumpReplicasComponents(ent)
    local t = {}

    t[#t + 1] = string.rep("-", 10) .. "| Components & Replica (" .. ent.prefab ..  ") |" .. string.rep("-", 10)

    t[#t + 1] = "Components:"
    if ent.components then
        for component in pairs(ent.components) do
            t[#t + 1] = "\t" .. component
        end
    end

    t[#t + 1] = "Replica:"
    if ent.replica then
        for replica in pairs(ent.replica._) do
            t[#t + 1] = "\t" .. replica
        end
    end

    print(table.concat(t, "\n"))
end

KeybindService:AddGlobalKey("DUMP_SELECT", function()
    local ent = DeepSelect()
    if checkentity(ent) then
        if TheInput:IsKeyDown(KEY_CTRL) then
            print("Table dump " .. ent.prefab)
            for i,v in pairs(ent) do
                print(i,v)
            end
            NotifyFormatted("%s's table dumped", ent.prefab)
        else
            DumpReplicasComponents(ent)
            NotifyFormatted("%s's components & replicas dumped", ent.prefab)
        end
    end
end)

local function ValidateEntity(ent)
    return checkentity(ent) and ent:IsValid()
end

local EventInterceptorsEntities = {}
local function DetachEventInterceptors()
    for i = 1, #EventInterceptorsEntities do
        local ent = EventInterceptorsEntities[i]

        if ValidateEntity(ent) then
            ent.PushEvent = EntityScript.PushEvent
        end

        EventInterceptorsEntities[i] = nil
    end
end

local function GetFormattedOsClock()
    local seconds = os.clock()

    if seconds <= 0 then
        return "00:00:00"
    end

    local hours = Format("%02.f", math.floor(seconds / 3600))
    local mins = Format("%02.f", math.floor(seconds / 60 - (hours * 60)))
    local secs = Format("%02.f", math.floor(seconds - hours * 3600 - mins * 60))

    return hours .. ":" .. mins .. ":" .. secs
end

local function EventInterceptor(inst, event, ...)
    PrintFormatted(
        "[%s] [EVENT] [%s] %s",
        GetFormattedOsClock(),
        inst.prefab,
        event
    )
    EntityScript.PushEvent(inst, event, ...)
end

local function AttachEventInterceptors(ent)
    ent.PushEvent = EventInterceptor
    EventInterceptorsEntities[#EventInterceptorsEntities + 1] = ent
    for _, v in pairs(ent) do
        if checkentity(ent) and v.HasTag and v:HasTag("CLASSIFIED") then
            v.PushEvent = EventInterceptor
            EventInterceptorsEntities[#EventInterceptorsEntities + 1] = v
        end
    end
    if ent.replica and ent.replica._ then
        for _, replica in pairs(ent.replica._) do
            if replica.classified then
                replica.classified.PushEvent = EventInterceptor
                EventInterceptorsEntities[#EventInterceptorsEntities + 1] = replica.classified
            end
        end
    end
end

KeybindService:AddKey("EVENT_LISTEN_SELECT", function()
    if TheInput:IsKeyDown(KEY_CTRL) then
        DetachEventInterceptors()
        Notify("Stopped listening to events")
        return
    end

    local ent = DeepSelect()
    if ValidateEntity(ent) then
        DetachEventInterceptors()
        AttachEventInterceptors(ent)
        NotifyFormatted("Now listening to events from %s", ent.prefab)
    end
end)

KeybindService:AddGlobalKey("CLEAR_CONSOLE", function()
    if TheInput:IsKeyDown(KEY_SHIFT) then
        -- local consoleOutputList = GetConsoleOutputList()

        -- for i = 1, #consoleOutputList do
        --     consoleOutputList[i] = nil
        -- end
        for _ = 1, 19 do
            nolineprint("")
        end
        nolineprint(string.rep("-", 15) .. "| Console Cleared |" .. string.rep("-", 15))

        Notify("Console log cleared")
    end
end)

KeybindService:AddKey("TOGGLE_GODMODE", function()
    TheNet:SendRemoteExecute("c_supergodmode()")
end)

KeybindService:AddKey("RESET_WORLD", function()
    if TheInput:IsKeyDown(KEY_CTRL) and TheInput:IsKeyDown(KEY_SHIFT) then
        TheNet:SendRemoteExecute("c_reset()")
    end
end)

local TimeScale = 1
local function ManipulateTimeScale(newTimeScale)
    TimeScale = math.clamp(newTimeScale, 0, 4)
    TheNet:SendRemoteExecute(
        Format(
            "TheSim:SetTimeScale(%s)",
            TimeScale
        )
    )
    NotifyFormatted("Time scale set to %s", TimeScale)
end

KeybindService:AddKey("DECREASE_TIME_SCALE", function()
    if TheInput:IsKeyDown(KEY_CTRL) then
        ManipulateTimeScale(1)
    elseif TheInput:IsKeyDown(KEY_SHIFT) then
        ManipulateTimeScale(0)
    else
        ManipulateTimeScale(TimeScale - .25)
    end
end)

KeybindService:AddKey("INCREASE_TIME_SCALE", function()
    if TheInput:IsKeyDown(KEY_CTRL) then
        ManipulateTimeScale(1)
    elseif TheInput:IsKeyDown(KEY_SHIFT) then
        ManipulateTimeScale(4)
    else
        ManipulateTimeScale(TimeScale + .25)
    end
end)

local PHASE_NAMES =
{
    "day",
    "dusk",
    "night",
}

local function GetNextPhase()
    local phase = TheWorld and TheWorld.state and TheWorld.state.phase

    if phase then
        for i = 1, #PHASE_NAMES do
            if PHASE_NAMES[i] == phase then
                if i == #PHASE_NAMES then
                    phase = PHASE_NAMES[1]
                else
                    phase = PHASE_NAMES[i + 1]
                end
                break
            end
        end
    else
        phase = PHASE_NAMES[1]
    end

    return phase
end

KeybindService:AddKey("NEXT_PHASE", function()
    TheNet:SendRemoteExecute([[TheWorld:PushEvent("ms_nextphase")]])
    NotifyFormatted("Phase has changed to %s", GetNextPhase())
end)

KeybindService:AddKey("FORCE_RAIN", function()
    local state = "stopped"

    if TheInput:IsKeyDown(KEY_CTRL) then
        TheNet:SendRemoteExecute([[TheWorld:PushEvent("ms_deltamoisture", TheWorld.state.moistureceil)]])
        state = "started"
    else
        TheNet:SendRemoteExecute([[TheWorld:PushEvent("ms_deltamoisture", -TheWorld.state.moistureceil)]])
    end

    NotifyFormatted("Rain %s", state)
end)

KeybindService:AddKey("CHANGE_DAMAGE_MULTIPLIER", function()
    local dmgMult = TheInput:IsKeyDown(KEY_CTRL) and 999
                 or 1

    TheNet:SendRemoteExecute("ThePlayer.components.combat.damagemultiplier=" .. dmgMult)

    NotifyFormatted("Damage multiplier set to %s", dmgMult)
end)

local function GetTags(ent)
    local tags = {}

    local tagsStr = ent:GetDebugString():match("Tags: ([%w_%s]+)Prefab:")
    for tag in tagsStr:gmatch("[%w_]+") do
        if tag ~= "FROMNUM" then
            tags[#tags + 1] = tag
        end
    end

    return tags
end

local function GetTagDeltas(tab, deltaTab, str)
    local t = {}

    for i = 1, #deltaTab do
        if not table.contains(tab, deltaTab[i]) then
            t[#t + 1] = str .. deltaTab[i] 
        end
    end

    return t
end

local function PrintTagDeltas(ent, oldEntityTags)
    local currentEntityTags = GetTags(ent)
    local deltaTags = JoinArrays(
                        GetTagDeltas(oldEntityTags, currentEntityTags, "++"),
                        GetTagDeltas(currentEntityTags, oldEntityTags, "--")
                      )

    if #deltaTags > 0 then
        PrintFormatted(
            "[%s] [TAG] [%s] (%s)",
            GetFormattedOsClock(),
            ent.prefab,
            table.concat(deltaTags, ", ")
        )
    end

    return currentEntityTags
end

local function DefaultThreadToggle(ent, thread, status)
    NotifyFormatted(
        "%s's %s %s",
        ent.prefab,
        GetThreadName(thread),
        status
    )
end

local TagsThread =
{
    ID = "tags_thread",
    Thread = nil
}
KeybindService:AddKey("TAG_DELTAS_TRACKER", function()
    if TheInput:IsKeyDown(KEY_CTRL) then
        TagsThread.Thread = nil
        return
    end

    local ent = DeepSelect()
    if ValidateEntity(ent) and ent.AnimState then

        if TagsThread.Thread then
            Threading:StopThread(TagsThread.ID)
        end

        local SavedEntityTags = GetTags(ent)
        TagsThread.Thread = Threading:StartThread(TagsThread.ID, function()
            SavedEntityTags = PrintTagDeltas(ent, SavedEntityTags)
            Sleep(FRAMES)
        end,
        function()
            return ent:IsValid() and TagsThread.Thread
        end,
        function()
            DefaultThreadToggle(ent, TagsThread.ID, "stopped")
        end)

        DefaultThreadToggle(ent, TagsThread.ID, "started")
    end
end)

local function PrintAnimationDebug(ent)
    local debugString = ent:GetDebugString()

    -- Credit for the regex goes to @Victor | Steam handle: DemonBlink
    local anim = string.match(debugString, "AnimState:.*anim:%s+(%S+)")
    local animTotalFrames = math.floor(ent.AnimState:GetCurrentAnimationLength() * 30)
    local animFrame = math.floor(ent.AnimState:GetCurrentAnimationTime() * 30) 
    local loopCount = math.floor(animFrame / animTotalFrames)
    animFrame = animFrame % animTotalFrames

    PrintFormatted(
        "[%s] Animation: (%s) Frame: (%s/%s) Loops: (%s)",
        ent.prefab,
        anim,
        animFrame,
        animTotalFrames,
        loopCount
    )
end

local AnimationThread =
{
    ID = "animation_thread",
    Thread = nil
}

KeybindService:AddKey("ANIMATION_DELTAS_TRACKER", function()
    if TheInput:IsKeyDown(KEY_CTRL) then
        AnimationThread.Thread = nil
        return
    end

    local ent = DeepSelect()
    if ValidateEntity(ent) and ent.AnimState then

        if AnimationThread.Thread then
            Threading:StopThread(AnimationThread.ID)
        end

        AnimationThread.Thread = Threading:StartThread(AnimationThread.ID, function()
            PrintAnimationDebug(ent)
            Sleep(FRAMES)
        end,
        function()
            return ent:IsValid() and AnimationThread.Thread
        end,
        function()
            DefaultThreadToggle(ent, AnimationThread.ID, "stopped")
        end)

        DefaultThreadToggle(ent, AnimationThread.ID, "started")
    end
end)

local function GetRPCNameFromCode(code)
    for rpcName, rpcCode in pairs(RPC) do
        if code == rpcCode then
            return "RPC." .. rpcName
        end
    end

    return code
end

local function GetActionNameFromCode(code)
    for actionName, action in pairs(ACTIONS) do
        if action.code == code then
            return "ACTIONS." .. actionName .. ".code"
        end
    end

    return code
end

local function GetRecipeNameFromCode(code)
    for recipe, recipeData in pairs(AllRecipes) do
        if recipeData.rpc_id == code then
            return code .. " - " .. recipe
        end
    end

    return code
end

local CONTROLS = {}
local function GetControlFromCode(code)
    return CONTROLS[code] or code
end

for name, val in pairs(_G) do
    if type(name) == "string" and name:sub(1,8) == "CONTROL_" then
        CONTROLS[val] = name
    end
end

local ControlRPCs =
{
    [RPC.StopControl] = true;
}

local function IsControlRPC(code)
    return ControlRPCs[code]
end

local ActionRPCs =
{
    [RPC.ControllerUseItemOnSelfFromInvTile] = true;
    [RPC.ControllerUseItemOnSceneFromInvTile] = true;
    [RPC.ControllerActionButton] = true;
    [RPC.ControllerActionButtonPoint] = true;
    [RPC.ControllerAltActionButton] = true;
    [RPC.DoWidgetButtonAction] = true;
    [RPC.UseItemFromInvTile] = true;
    [RPC.ActionButton] = true;
    [RPC.LeftClick] = true;
    [RPC.RightClick] = true;
}

-- @TODO Find a better way to detect RPC type
local function IsActionRPC(code)
    return ActionRPCs[code]
end

local RecipeRPCs =
{
    [RPC.MakeRecipeFromMenu] = true;
    [RPC.MakeRecipeAtPoint] = true;
    [RPC.BufferBuild] = true;
}

local function IsRecipeRPC(code)
    return RecipeRPCs[code]
end

local RPCTranslators = {}

if GetModConfigData("TRANSLATE_ACTION", MOD_DEVELOPMENT_MENU.MODNAME) then
    RPCTranslators[IsActionRPC] = GetActionNameFromCode 
end

if GetModConfigData("TRANSLATE_RECIPE", MOD_DEVELOPMENT_MENU.MODNAME) then
    RPCTranslators[IsRecipeRPC] = GetRecipeNameFromCode 
end

if GetModConfigData("TRANSLATE_CONTROL", MOD_DEVELOPMENT_MENU.MODNAME) then
    RPCTranslators[IsControlRPC] = GetControlFromCode 
end

local function TranslateCode(arg1, arg2)
    for trigger, getName in pairs(RPCTranslators) do
        if trigger(arg1) then
            return getName(arg2)
        end
    end

    return nil
end

local OldSendRPCToServer = SendRPCToServer
local function RPCServerInterceptor(...)
    local t = {}

    local arg = {...}
    for i = 1, #arg do
        if i == 1 then
            t[#t + 1] = GetRPCNameFromCode(arg[1])
        elseif i == 2 and TranslateCode(arg[1], arg[i])then
            t[#t + 1] = TranslateCode(arg[1], arg[i])
        else
            t[#t + 1] = tostring(arg[i])
        end
    end

    if #t > 0 then
        PrintFormatted(
            "SendRPCToServer(%s)",
            table.concat(t, ", ")
        )
    end

    OldSendRPCToServer(...)
end

KeybindService:AddKey("RPC_SERVER_LISTENER", function()
    SendRPCToServer = SendRPCToServer == OldSendRPCToServer and RPCServerInterceptor
                      or OldSendRPCToServer
    NotifyFormatted(
        "RPC monitor: %s",
        SendRPCToServer == RPCServerInterceptor and "Enabled"
        or "Disabled"
    )
end)

KeybindService:AddKey("STOP_THREADS", function()
    SendRPCToServer = OldSendRPCToServer
    DetachEventInterceptors()
    AnimationThread.Thread = nil
    TagsThread.Thread = nil
    Notify("Stopped all threads")
end)
