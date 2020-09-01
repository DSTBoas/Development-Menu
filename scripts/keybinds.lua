local DevelopmentScreen = require "screens/development_menu"
local PlayerNotifier = require "util/player_notifier"
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

local function GetTreadName(str)
    return str:gsub("_", " ")
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
    if ent and type(ent) == "table" and ent.prefab then
        PlayerNotifier(
            string.format(
                "Debug entity: %s",
                ent.prefab
            )
        )
    end
end)

function DumpReplicasComponents(t)
    print(string.rep("-", 15) .. "| Dumping ent |" .. string.rep("-", 15))

    print("Components:")
    if t.components then
        for i, v in pairs(t.components) do
            print("\t"..i, v)
        end
    end

    print("Replica:")
    if t.replica then
        for i, v in pairs(t.replica["_"]) do
            print("\t"..i, v)
        end
    end
end

KeybindService:AddGlobalKey("DUMP_SELECT", function()
    local ent = DeepSelect()
    if ent and type(ent) == "table" then
        if TheInput:IsKeyDown(KEY_CTRL) then
            for i,v in pairs(ent) do
                print(i,v)
            end
            if ent.prefab then
                PlayerNotifier(
                    string.format(
                        "%s's table dumped.",
                        ent.prefab
                    )
                )
            end
        else
            DumpReplicasComponents(ent)
            if ent.prefab then
                PlayerNotifier(
                    string.format(
                        "%s's components and replicas dumped.",
                        ent.prefab
                    )
                )
            end
        end
    end
end)

local function ValidateEntity(ent)
    return ent and ent:IsValid()
end

local InterceptEntity = {}

local function RemoveEventInterception()
    for _, ent in pairs(InterceptEntity) do
        if ValidateEntity(ent) then
            ent.PushEvent = EntityScript.PushEvent
        end
    end
end

local function GetFormattedOsClock()
    local seconds = os.clock()

    if seconds <= 0 then
        return "00:00:00"
    end

    local hours = string.format("%02.f", math.floor(seconds / 3600))
    local mins = string.format("%02.f", math.floor(seconds / 60 - (hours * 60)))
    local secs = string.format("%02.f", math.floor(seconds - hours * 3600 - mins * 60))

    return hours .. ":" .. mins .. ":" .. secs
end

local function EventInterceptor(inst, event, ...)
    print(
        string.format(
            "[%s] [EVENT] [%s] %s",
            GetFormattedOsClock(),
            inst.prefab,
            event
        )
    )
    EntityScript.PushEvent(inst, event, ...)
end

local function AddEventInterception(ent)
    ent.PushEvent = EventInterceptor
    InterceptEntity[#InterceptEntity + 1] = ent
    for _, v in pairs(ent) do
        if type(v) == "table" and v.HasTag and v:HasTag("CLASSIFIED") then
            v.PushEvent = EventInterceptor
            InterceptEntity[#InterceptEntity + 1] = v
        end
    end
    if ent.replica and ent.replica._ then
        for _, replica in pairs(ent.replica._) do
            if replica.classified then
                replica.classified.PushEvent = EventInterceptor
                InterceptEntity[#InterceptEntity + 1] = replica.classified
            end
        end
    end
end

KeybindService:AddKey("EVENT_LISTEN_SELECT", function()
    if not TheInput:IsKeyDown(KEY_CTRL) then
        local ent = DeepSelect()
        if ValidateEntity(ent) then
            RemoveEventInterception()
            AddEventInterception(ent)
            PlayerNotifier(
                string.format(
                    "Now listening to events from %s.",
                    ent.prefab
                )
            )
        end
    else
        RemoveEventInterception()
        PlayerNotifier("Stopped listening to events.")
    end
end)

KeybindService:AddGlobalKey("CLEAR_CONSOLE", function()
    if TheInput:IsKeyDown(KEY_SHIFT) then
        for _ = 1, 19 do
            nolineprint("")
        end
        nolineprint(string.rep("-", 15) .. "| Console Cleared |" .. string.rep("-", 15))
        PlayerNotifier("Console log cleared.")
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
    TimeScale = newTimeScale
    if TimeScale < 0 then
        TimeScale = 0
    elseif TimeScale > 4 then
        TimeScale = 4
    end
end

KeybindService:AddKey("DECREASE_TIME_SCALE", function()
    if TheInput:IsKeyDown(KEY_CTRL) then
        TheNet:SendRemoteExecute("TheSim:SetTimeScale(1)")
        ManipulateTimeScale(1)
    elseif TheInput:IsKeyDown(KEY_SHIFT) then
        TheNet:SendRemoteExecute("TheSim:SetTimeScale(0)")
        ManipulateTimeScale(0)
    else
        TheNet:SendRemoteExecute("TheSim:SetTimeScale(TheSim:GetTimeScale() - .25)")
        ManipulateTimeScale(TimeScale - .25)
    end
    PlayerNotifier(
        string.format(
            "Time scale is now %s.",
            TimeScale
        )
    )
end)

KeybindService:AddKey("INCREASE_TIME_SCALE", function()
    if TheInput:IsKeyDown(KEY_CTRL) then
        TheNet:SendRemoteExecute("TheSim:SetTimeScale(1)")
        ManipulateTimeScale(1)
    elseif TheInput:IsKeyDown(KEY_SHIFT) then
        TheNet:SendRemoteExecute("TheSim:SetTimeScale(4)")
        ManipulateTimeScale(4)
    else
        TheNet:SendRemoteExecute("TheSim:SetTimeScale(TheSim:GetTimeScale() + .25)")
        ManipulateTimeScale(TimeScale + .25)
    end
    PlayerNotifier(
        string.format(
            "Time scale is now %s.",
            TimeScale
        )
    )
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
    PlayerNotifier(
        string.format(
            "Phase has changed to %s.",
            GetNextPhase()
        )
    )
end)

KeybindService:AddKey("FORCE_RAIN", function()
    local state = "stopped"

    if TheInput:IsKeyDown(KEY_CTRL) then
        TheNet:SendRemoteExecute([[TheWorld:PushEvent("ms_deltamoisture", TheWorld.state.moistureceil)]])
        state = "started"
    else
        TheNet:SendRemoteExecute([[TheWorld:PushEvent("ms_deltamoisture", -TheWorld.state.moistureceil)]])
    end

    PlayerNotifier(
        string.format(
            "Rain %s.",
            state
        )
    )
end)

KeybindService:AddKey("CHANGE_DAMAGE_MULTIPLIER", function()
    local mult = 1

    if TheInput:IsKeyDown(KEY_CTRL) then
        mult = 9999
        TheNet:SendRemoteExecute("ThePlayer.components.combat.damagemultiplier="..mult)
    else
        TheNet:SendRemoteExecute("ThePlayer.components.combat.damagemultiplier="..mult)
    end

    PlayerNotifier(
        string.format(
            "Damage multiplier is now %s.",
            mult
        )
    )
end)

local function GetTags(ent)
    local tags = {}

    if ent and ent.GetDebugString then
        local tagsStr = ent:GetDebugString():match("Tags: ([%w_%s]+)Prefab:") or ""

        for tag in tagsStr:gmatch("[%w_]+") do
            if tag ~= "FROMNUM" then
                tags[#tags + 1] = tag
            end
        end
    end

    return tags
end

local function TableContains(tab, tag)
    for i = 1, #tab do
        if tab[i] == tag then
            return true
        end
    end

    return false
end

-- local function PrintDeltaTags(tab, deltaTab, str)
--     for i = 1, #deltaTab do
--         if TableContains(tab, deltaTab[i]) == false then
--             print(
--                 string.format(
--                     str,
--                     TagTrackerPrefab,
--                     deltaTab[i]
--                 )
--             )
--         end
--     end
-- end

local function GetTagDeltas(tab, deltaTab, str)
    local t = {}

    for i = 1, #deltaTab do
        if not TableContains(tab, deltaTab[i]) then
            t[#t + 1] = str .. deltaTab[i] 
        end
    end

    return t
end

local function MergeTables(...)
    local t = {}

    local tabs = {...}
    for _ = 1, #tabs do
        for i = 1, #tabs[_] do
            t[#t + 1] = tabs[_][i]
        end
    end

    return t
end

local TagTrackerTags = {}
local function PrintTagDelta(ent, tags)
    local newTags = GetTags(ent)

    local addedTags = GetTagDeltas(tags, newTags, "++")
    local removedTags = GetTagDeltas(newTags, tags, "--")
    local deltaTags = MergeTables(addedTags, removedTags)

    if #deltaTags > 0 then
        print(
            string.format(
                "[%s] [TAG] [%s] (%s)",
                GetFormattedOsClock(),
                ent.prefab,
                table.concat(deltaTags, ", ")
            )
        )
    end

    --PrintDeltaTags(tags, newTags, "[TAG] [%s] (%s) added.")
    --PrintDeltaTags(newTags, tags, "[TAG] [%s] (%s) removed.")

    TagTrackerTags = newTags
end

local function DefaultThreadToggle(ent, thread, status)
    PlayerNotifier(
        string.format(
            "%s's %s %s.",
            ent.prefab,
            GetTreadName(thread),
            status
        )
    )
end

local TagsThread =
{
    ID = "tags_thread",
    Thread = nil
}

KeybindService:AddKey("TAG_DELTAS_TRACKER", function()
    if TheInput:IsKeyDown(KEY_CTRL) and TagsThread.Thread then
        TagsThread.Thread = nil
        return
    end

    local ent = DeepSelect()
    if ValidateEntity(ent) and ent.AnimState then

        if TagsThread.Thread then
            Threading:StopThread(TagsThread.ID)
        end

        TagTrackerTags = GetTags(ent)
        TagsThread.Thread = Threading:StartThread(TagsThread.ID, function()
            PrintTagDelta(ent, TagTrackerTags)
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

    print(
        string.format(
            "[%s] Animation: (%s) Frame: (%s/%s) Loops: (%s)",
            ent.prefab,
            anim,
            animFrame,
            animTotalFrames,
            loopCount
        )
    )
end

local AnimationThread =
{
    ID = "animation_thread",
    Thread = nil
}

KeybindService:AddKey("ANIMATION_DELTAS_TRACKER", function()
    if TheInput:IsKeyDown(KEY_CTRL) and AnimationThread.Thread then
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

local function TranslateRPC(code)
    for name, rpcCode in pairs(RPC) do
        if code == rpcCode then
            return string.format(
                        "RPC.%s",
                        name
                   )
        end
    end

    return code
end

local function TranslateAction(code)
    for name, action in pairs(ACTIONS) do
        if action.code == code then
            return string.format(
                        "ACTIONS.%s.code",
                        name
                   )
        end
    end

    return code
end

-- local function IsActionRPC(code)
--     return code == RPC.UseItemFromInvTile
--         or code == RPC.ActionButton
--         or code == RPC.LeftClick
--         or code == RPC.RightClick
-- end

local function IsValidEnt(ent)
    return ent
       and type(ent) == "table"
       and ent.IsValid
       and ent:IsValid()
end

local OldSendRPCToServer = SendRPCToServer
local function RPCServerInterceptor(...)
    local t = {}

    local arg = {...}
    for i = 1, #arg do
        if i == 1 then
            t[#t + 1] = TranslateRPC(arg[1])
        elseif i == 2 and (#arg >= 11 or IsValidEnt(arg[3])) then -- or IsActionRPC(arg[1])) then
            t[#t + 1] = TranslateAction(arg[2])
        else
            t[#t + 1] = tostring(arg[i])
        end
    end

    if #t > 0 then
        print(
            string.format(
                "SendRPCToServer(%s)",
                table.concat(t, ", ")
            )
        )
    end

    OldSendRPCToServer(...)
end

KeybindService:AddKey("RPC_SERVER_LISTENER", function()
    local str = "Started"

    if SendRPCToServer ~= RPCServerInterceptor then
        SendRPCToServer = RPCServerInterceptor
    else
        str = "Stopped"
        SendRPCToServer = OldSendRPCToServer
    end

    PlayerNotifier(
        string.format(
            "%s listening to RPC requests.",
            str
        )
    )
end)

KeybindService:AddKey("STOP_THREADS", function()
    SendRPCToServer = OldSendRPCToServer
    RemoveEventInterception()
    AnimationThread.Thread = nil
    TagsThread.Thread = nil
    PlayerNotifier("Stopped all threads.")
end)
