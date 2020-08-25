local DevelopmentScreen = require "screens/development_menu"
local PlayerNotifier = require "util/player_notifier"
require "util/keyhandlers"

local function ValidateFocusState()
    local activeScreen = TheFrontEnd:GetActiveScreen()
    local focusWidget = TheFrontEnd:GetFocusWidget()
    return not (activeScreen
           and activeScreen.name == "ModConfigurationScreen"
           and focusWidget
           and focusWidget.texture
           and (focusWidget.texture:find("spinner"))
                or focusWidget.texture:find("arrow"))
end

local function ValidateScreenState()
    return not TheFrontEnd.forceProcessText
       and ValidateFocusState()
end

AddGlobalKey("TOGGLE_DEVELOPMENT_MENU", function()
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

    return GetDebugEntity()
end

AddGlobalKey("SET_DEBUG_ENTITY", function()
    local ent = DeepSelect()
    if ent and type(ent) == "table" and ent.prefab then
        PlayerNotifier(
            string.format(
                "Debug entity is %s.",
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

AddGlobalKey("DUMP_SELECT", function()
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
    return ent and type(ent) == "table" and ent.PushEvent
end

local InterceptEntity = {}

local function RemoveEventInterception()
    for _, ent in pairs(InterceptEntity) do
        if ValidateEntity(ent) then
            ent.PushEvent = EntityScript.PushEvent
        end
    end
end

local function GetFormattedTime()
    local seconds = os.clock()
    local hours = string.format("%02.f", math.floor(seconds / 3600))
    local mins = string.format("%02.f", math.floor(seconds / 60 - (hours * 60)))
    local secs = string.format("%02.f", math.floor(seconds - hours * 3600 - mins * 60))

    if seconds <= 0 then
        return "00:00:00"
    end

    return hours..":"..mins..":"..secs
end

local function EventIntercepter(inst, event, ...)
    print(
        string.format(
            "[%s] [EVENT] [%s] %s",
            GetFormattedTime(),
            inst.prefab,
            event
        )
    )
    EntityScript.PushEvent(inst, event, ...)
end

local function AddEventInterception(ent)
    ent.PushEvent = EventIntercepter
    InterceptEntity[#InterceptEntity + 1] = ent
    for _, v in pairs(ent) do
        if type(v) == "table" and v.HasTag and v:HasTag("CLASSIFIED") then
            v.PushEvent = EventIntercepter
            InterceptEntity[#InterceptEntity + 1] = v
        end
    end
    if ent.replica and ent.replica._ then
        for _, replica in pairs(ent.replica._) do
            if replica.classified then
                replica.classified.PushEvent = EventIntercepter
                InterceptEntity[#InterceptEntity + 1] = replica.classified
            end
        end
    end
end

AddGameKey("EVENT_LISTEN_SELECT", function()
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

AddGlobalKey("CLEAR_CONSOLE", function()
    for _ = 1, 19 do
        nolineprint("")
    end
    nolineprint(string.rep("-", 15) .. "| Console Cleared |" .. string.rep("-", 15))
    PlayerNotifier("Console log cleared.")
end)

AddGameKey("TOGGLE_GODMODE", function()
    TheNet:SendRemoteExecute("c_supergodmode()")
end)

AddGameKey("RESET_WORLD", function()
    if TheInput:IsKeyDown(KEY_CTRL) and TheInput:IsKeyDown(KEY_SHIFT) then
        TheNet:SendRemoteExecute("c_reset()")
    end
end)

local TimeScale = 1

local function ManipulateTimeScale(newTimeScale)
    TimeScale = newTimeScale
    if TimeScale < 0 then
        TimeScale = 0
        return
    elseif TimeScale > 4 then
        TimeScale = 4
        return
    end
end

AddGameKey("DECREASE_TIME_SCALE", function()
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

AddGameKey("INCREASE_TIME_SCALE", function()
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

AddGameKey("NEXT_PHASE", function()
    TheNet:SendRemoteExecute([[TheWorld:PushEvent("ms_nextphase")]])
    PlayerNotifier(
        string.format(
            "Phase has changed to %s.",
            GetNextPhase()
        )
    )
end)

AddGameKey("FORCE_RAIN", function()
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

AddGameKey("CHANGE_DAMAGE_MULTIPLIER", function()
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
        local debugStr = ent:GetDebugString()
        local tagsStr = debugStr:match("Tags: ([%l%C%S]+%f[%s])")

        for tag in tagsStr:gmatch("[%w_]+") do
            if tag ~= "FROMNUM" then
                tags[#tags + 1] = tag
            end
        end
    end

    return tags
end

local TagTrackerTags = {}
local TagTrackerPrefab = "MISSING"
local TagTrackerTask
local TagTrackerEnt

local function TableContains(tab, tag)
    for i = 1, #tab do
        if tab[i] == tag then
            return true
        end
    end

    return false
end

local function PrintDeltaTags(tab, deltaTab, str)
    for i = 1, #deltaTab do
        if TableContains(tab, deltaTab[i]) == false then
            print(
                string.format(
                    str,
                    TagTrackerPrefab,
                    deltaTab[i]
                )
            )
        end
    end
end

local function GetTagDeltas(tab, deltaTab, str)
    local t = {}

    for i = 1, #deltaTab do
        if TableContains(tab, deltaTab[i]) == false then
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

local function PrintTagDelta(tags)
    local newTags = GetTags(TagTrackerEnt)

    local addedTags = GetTagDeltas(tags, newTags, "++")
    local removedTags = GetTagDeltas(newTags, tags, "--")
    local deltaTags = MergeTables(addedTags, removedTags)

    if #deltaTags > 0 then
        print(
            string.format(
                "[%s] [TAG] [%s] (%s)",
                GetFormattedTime(),
                TagTrackerPrefab,
                table.concat(deltaTags, ", ")
            )
        )
    end

    --PrintDeltaTags(tags, newTags, "[TAG] [%s] (%s) added.")
    --PrintDeltaTags(newTags, tags, "[TAG] [%s] (%s) removed.")

    TagTrackerTags = newTags
end

local function EndTagThread(silent)
    TagTrackerEnt = nil
    TagTrackerTags = {}
    if TagTrackerTask then
        scheduler:KillTask(TagTrackerTask)
    end
    TagTrackerTask = nil
    if not silent then
        PlayerNotifier(
            string.format(
                "%s's tag tracking stopped.",
                TagTrackerPrefab
            )
        )
    end
    TagTrackerPrefab = "MISSING"
end

local function StartTagThread()
    while TagTrackerEnt:IsValid() do
        PrintTagDelta(TagTrackerTags)
        Sleep(0)
    end

    TagTrackerTask = nil
    EndTagThread()
end

AddGameKey("TAG_DELTAS_TRACKER", function()
    if TheInput:IsKeyDown(KEY_CTRL) then
        return TagTrackerTask and EndTagThread()
    end

    local ent = DeepSelect()
    if ValidateEntity(ent) and ent.prefab then
        EndTagThread(true)
        TagTrackerEnt = ent
        TagTrackerPrefab = ent.prefab
        TagTrackerTags = GetTags(ent)
        TagTrackerTask = ThePlayer:StartThread(StartTagThread)
        PlayerNotifier(
            string.format(
                "%s started tracking tag deltas.",
                TagTrackerPrefab
            )
        )
        -- print("local tags = {" .. table.concat(TagTrackerTags,", ") .. "}")
    end
end)

local AnimationEntityPrefab = "MISSING"
local AnimationEntity
local AnimationTask

local function GetAnimationDebugString(ent)
    local debugString = ent:GetDebugString()

    -- Credit for the regex goes to @Victor | Steam handle: DemonBlink
    local anim = string.match(debugString, "AnimState:.*anim:%s+(%S+)")
    local animTotalFrames = math.floor(ent.AnimState:GetCurrentAnimationLength() * 30)
    local animFrame = math.floor(ent.AnimState:GetCurrentAnimationTime() * 30) 
    local loopCount = math.floor(animFrame / animTotalFrames)
    animFrame = animFrame % animTotalFrames

    local str = string.format(
                    "[%s] Animation: (%s) Frame: (%s/%s) Loops: (%s)",
                    AnimationEntityPrefab,
                    anim,
                    animFrame,
                    animTotalFrames,
                    loopCount
                )
    return str
end

local function EndAnimationThread(silent)
    AnimationEntity = nil
    if AnimationTask then
        scheduler:KillTask(AnimationTask)
    end
    AnimationTask = nil
    if not silent then
        PlayerNotifier(
            string.format(
                "%s's animation tracking stopped.",
                AnimationEntityPrefab
            )
        )
    end
    AnimationEntityPrefab = "MISSING"
end

local function StartAnimationThread()
    while AnimationEntity and AnimationEntity:IsValid() and AnimationEntity.AnimState do
        print(GetAnimationDebugString(AnimationEntity))
        Sleep(0)
    end
    if AnimationEntity then
        EndAnimationThread()
    end
end

AddGameKey("ANIMATION_DELTAS_TRACKER", function()
    if TheInput:IsKeyDown(KEY_CTRL) then
        return AnimationTask and EndAnimationThread()
    end

    local ent = DeepSelect()
    if ValidateEntity(ent) and ent.prefab and ent.AnimState then
        EndAnimationThread(true)
        AnimationEntity = ent
        AnimationEntityPrefab = ent.prefab
        AnimationTask = ThePlayer:StartThread(StartAnimationThread)
        PlayerNotifier(
            string.format(
                "%s started animation tracking.",
                AnimationEntityPrefab
            )
        )
    end
end)

local OldSendRPCToServer = SendRPCToServer

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

local function IsActionRPC(code)
    return code == 57
        or code == 1
end

local function RPCServerIntercepter(...)
    local t = {}

    local arg = {...}
    for i = 1, #arg do
        if i == 1 then
            t[#t + 1] = TranslateRPC(arg[1])
        elseif i == 2 and (#arg == 11 or IsActionRPC(arg[1])) then
            t[#t + 1] = TranslateAction(arg[2])
        else
            t[#t + 1] = tostring(arg[i])
        end
    end

    print(
        string.format(
            "SendRPCToServer(%s)",
            table.concat(t, ", ")
        )
    )

    OldSendRPCToServer(...)
end

AddGameKey("RPC_SERVER_LISTENER", function()
    local str = "started"

    if SendRPCToServer ~= RPCServerIntercepter then
        SendRPCToServer = RPCServerIntercepter
    else
        str = "stopped"
        SendRPCToServer = OldSendRPCToServer
    end

    PlayerNotifier(
        string.format(
            "RPC server %s listening.",
            str
        )
    )
end)
