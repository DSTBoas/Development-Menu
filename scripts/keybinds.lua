local DevelopmentScreen = require "screens/development_menu"
local Say = require "util/say"
local Extractor = require "util/extractor"
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

local function SayFormatted(str, ...)
    Say(Format(str, ...))
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
        SayFormatted("Debug entity: %s", ent.prefab)
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
            SayFormatted("%s's table dumped", ent.prefab)
        else
            DumpReplicasComponents(ent)
            SayFormatted("%s's components & replicas dumped", ent.prefab)
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

-- @TODO Auto-filter these events in the future
-- Keeping it like this so devs can filter their own events
local FilteredEvents =
{
    -- MouseOver
    mouseover = true;
    mouseout = true;

    -- Sound
    sharksounddirty = true;

    -- Breather
    ["frostybreather.breathevent"] = true;

    -- PerformAction
    isperformactionsuccessdirty = true;
    performaction = true;

    -- Talking
    ontalk = true;
    donetalking = true;

    -- Ticks
    clocktick = true;
    temperaturetick = true;
    weathertick = true;
    overridecolourmodifier = true;

    -- Stats
    hungerdirty = true;
    hungerdelta = true;

    sanitydirty = true;
    sanitydelta = true;

    healthdirty = true;
    healthdelta = true;

    temperaturedirty = true;
    temperaturedelta = true;

    -- Prediction
    pausepredictionframesdirty = true;
    cancelmovementprediction = true;

}
local function FilteredEventInterceptor(inst, event, ...)
    if not FilteredEvents[event] then
        PrintFormatted(
            "[%s] [EVENT] [%s] %s",
            GetFormattedOsClock(),
            inst.prefab,
            event
        )
    end
    EntityScript.PushEvent(inst, event, ...)
end

local function AttachEventInterceptors(ent, interceptor)
    ent.PushEvent = interceptor
    EventInterceptorsEntities[#EventInterceptorsEntities + 1] = ent
    for _, v in pairs(ent) do
        if checkentity(v) and v.HasTag and v:HasTag("CLASSIFIED") then
            v.PushEvent = interceptor
            EventInterceptorsEntities[#EventInterceptorsEntities + 1] = v
        end
    end
    if ent.replica and ent.replica._ then
        for _, replica in pairs(ent.replica._) do
            if replica.classified then
                replica.classified.PushEvent = interceptor
                EventInterceptorsEntities[#EventInterceptorsEntities + 1] = replica.classified
            end
        end
    end
end

KeybindService:AddGlobalKey("EVENT_LISTEN_SELECT", function()
    if TheInput:IsKeyDown(KEY_CTRL) then
        DetachEventInterceptors()
        Say("Event Intercepting Stopped")
        return
    end

    local ent = DeepSelect()
    if ValidateEntity(ent) then
        local interceptor = EventInterceptor
        local mode = "Default"
        if TheInput:IsKeyDown(KEY_SHIFT) then
            interceptor = FilteredEventInterceptor
            mode = "Filtered"
        end
        DetachEventInterceptors()
        AttachEventInterceptors(ent, interceptor)
        SayFormatted("Event Intercepting: %s | Mode: %s", ent.prefab, mode)
    end
end)

KeybindService:AddGlobalKey("CLEAR_CONSOLE", function()
    if not TheInput:IsKeyDown(KEY_CTRL) and not TheFrontEnd.forceProcessText then
        for _ = 1, 19 do
            nolineprint("")
        end
        nolineprint(string.rep("-", 15) .. "| Console Cleared |" .. string.rep("-", 15))
        Say("Console Log Cleared")
    end
end)

KeybindService:AddKey("TOGGLE_GODMODE", function()
    TheNet:SendRemoteExecute("c_supergodmode()")
end)

KeybindService:AddKey("SIM_STEP", function()
    if TheInput:IsKeyDown(KEY_CTRL) then
        TheNet:SendRemoteExecute([[if TheSim:IsDebugPaused() then TheSim:ToggleDebugPause() end]])
        return
    end
    TheNet:SendRemoteExecute([[if not TheSim:IsDebugPaused() then TheSim:ToggleDebugPause() end TheSim:Step()]])
end)

KeybindService:AddKey("RESET_WORLD", function()
    if TheInput:IsKeyDown(KEY_CTRL) and TheInput:IsKeyDown(KEY_SHIFT) then
        TheNet:SendRemoteExecute("c_reset()")
    end
end)

KeybindService:AddKey("SAVE_WORLD", function()
    if TheInput:IsKeyDown(KEY_CTRL) then
        TheNet:SendRemoteExecute("c_save()")
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
    SayFormatted("Time scale: %s", TimeScale)
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
    "Day",
    "Dusk",
    "Night",
}

local function GetNextPhase()
    local phase = TheWorld and TheWorld.state and TheWorld.state.phase

    if phase then
        for i = 1, #PHASE_NAMES do
            if PHASE_NAMES[i]:lower() == phase then
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
    SayFormatted("Phase change: %s", GetNextPhase())
end)

local function IsRaining()
    return TheWorld
       and TheWorld.state
       and TheWorld.state.israining
end

KeybindService:AddKey("TOGGLE_RAIN", function()
    if IsRaining() then
        TheNet:SendRemoteExecute([[TheWorld:PushEvent("ms_deltamoisture", -TheWorld.state.moistureceil)]])
    else
        TheNet:SendRemoteExecute([[TheWorld:PushEvent("ms_deltamoisture", TheWorld.state.moistureceil)]])
    end

    SayFormatted(
        "Rain: %s",
        IsRaining() and "Stopped"
        or "Started"
    )
end)

KeybindService:AddKey("CHANGE_DAMAGE_MULTIPLIER", function()
    local dmgMult = TheInput:IsKeyDown(KEY_CTRL) and 999
                    or 1

    TheNet:SendRemoteExecute("ThePlayer.components.combat.damagemultiplier = " .. dmgMult)

    SayFormatted("Damage multiplier: %s", dmgMult)
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
    SayFormatted(
        "%s: %s %s",
        GetThreadName(thread),
        ent.prefab,
        status
    )
end

local TagsThread =
{
    ID = "Tags_Tracker",
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
            DefaultThreadToggle(ent, TagsThread.ID, "Stopped")
        end)

        DefaultThreadToggle(ent, TagsThread.ID, "")
    end
end)

local function GetAnimation(ent)
    return string.match(ent:GetDebugString(), "AnimState:.*anim:%s+(%S+)") -- Credit for the regex goes to @Victor | Steam handle: DemonBlink
end

local function GetAnimationLengthInFrames(ent)
    return math.floor(ent.AnimState:GetCurrentAnimationLength() * 30)
end

local function GetAnimationTimeInFrames(ent)
    return math.floor(ent.AnimState:GetCurrentAnimationTime() * 30)
end

local function PrintAnimationDebug(ent)
    local animation = GetAnimation(ent)
    local animationTimeInFrames = GetAnimationTimeInFrames(ent)
    local animationLengthInFrames = GetAnimationLengthInFrames(ent)
    local animationLoops = math.floor(animationTimeInFrames / animationLengthInFrames)
    animationTimeInFrames = animationTimeInFrames % animationLengthInFrames

    PrintFormatted(
        "[%s] Animation: (%s) Frame: (%s/%s) Loops: (%s)",
        ent.prefab,
        animation,
        animationTimeInFrames,
        animationLengthInFrames,
        animationLoops
    )
end

local AnimationThread =
{
    ID = "Animation_Tracker",
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

        if TheInput:IsKeyDown(KEY_SHIFT) then
            local oldAnim = GetAnimation(ent)
            local currentAnim
            AnimationThread.Thread = Threading:StartThread(AnimationThread.ID, function()
                currentAnim = GetAnimation(ent)
                if currentAnim ~= oldAnim then
                    PrintFormatted(
                        "[%s] Animation Delta: (%s)",
                         ent.prefab,
                         currentAnim
                    )
                    oldAnim = currentAnim
                end
                Sleep(FRAMES)
            end,
            function()
                return ent:IsValid() and AnimationThread.Thread
            end,
            function()
                DefaultThreadToggle(ent, AnimationThread.ID, "Stopped")
            end)

            DefaultThreadToggle(ent, AnimationThread.ID, "| Mode: Delta")
        else
            AnimationThread.Thread = Threading:StartThread(AnimationThread.ID, function()
                PrintAnimationDebug(ent)
                Sleep(FRAMES)
            end,
            function()
                return ent:IsValid() and AnimationThread.Thread
            end,
            function()
                DefaultThreadToggle(ent, AnimationThread.ID, "Stopped")
            end)

            DefaultThreadToggle(ent, AnimationThread.ID, "| Mode: Default")
        end
    end
end)

local TRANSLATE_RPC = GetModConfigData("TRANSLATE_RPC", MOD_DEVELOPMENT_MENU.MODNAME)
local function GetRPCNameFromCode(code)
    if TRANSLATE_RPC then
        for rpcName, rpcCode in pairs(RPC) do
            if code == rpcCode then
                return "RPC." .. rpcName
            end
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

local Controls = Extractor.GetControls()

local function GetControlFromCode(code)
    return Controls[code] or code
end

local ControlRPCs = Extractor.GetRPCsType("control")

local function IsControlRPC(code)
    return ControlRPCs[code]
end

local ActionRPCs = Extractor.GetRPCsType("action")

local function IsActionRPC(code)
    return ActionRPCs[code]
end

local RecipeRPCs = Extractor.GetRPCsType("recipe")

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
    SendRPCToServer = SendRPCToServer ~= RPCServerInterceptor and RPCServerInterceptor
                      or OldSendRPCToServer
    SayFormatted(
        "RPC monitor: %s",
        SendRPCToServer == RPCServerInterceptor and "Enabled"
        or "Disabled"
    )
end)

KeybindService:AddKey("STOP_DEBUGGING", function()
    SendRPCToServer = OldSendRPCToServer
    DetachEventInterceptors()

    if AnimationThread.Thread then
        Threading:StopThread(AnimationThread.ID)
        AnimationThread.Thread = nil
    end

    if TagsThread.Thread then
        Threading:StopThread(TagsThread.ID)
        TagsThread.Thread = nil
    end

    Say("Stop debugging")
end)
