local function ReadFile(path)
    local ret = ""

    local file = io.open(path, "r")
    if file ~= nil then
        ret = file:read("*all")
        file:close()
    end

    return ret
end

local RPCWithType = {}

local function ExtractRPCsWithType()
    local rpcHandlers = string.match(
                            ReadFile("scripts/networkclientrpc.lua"),
                            "local RPC_HANDLERS =%c*{(.*)%c*}"
                        )

    if not rpcHandlers then
        return {}
    end

    local RPCTypes =
    {
        "action",
        "recipe",
        "control"
    }

    local function GetRPCTypeFromArgs(funcArgs)
        for i = 1, #RPCTypes do
            if funcArgs:find(RPCTypes[i]) then
                return RPCTypes[i]
            end
        end

        return nil
    end

    for rpcName, rpcFuncArgs in rpcHandlers:gmatch "(%w+)%s*=%sfunction(%b())" do
        if rpcFuncArgs then
            local rpcType = GetRPCTypeFromArgs(rpcFuncArgs)
            if rpcType then
                RPCWithType[rpcName] = rpcType
            end
        end
    end
end
ExtractRPCsWithType()

local function GetRPCsType(rType)
    local ret = {}

    for rpcName, rpcType in pairs(RPCWithType) do
        if rpcType == rType then
            ret[RPC[rpcName]] = true
        end
    end

    return ret
end

local function GetControls()
    local ret = {}

    local file = ReadFile("scripts/constants.lua")
    for controlName, controlCode in file:gmatch "(CONTROL_[%w_]+)%s*=%s*([%w_]+)" do
        if controlCode then
            local num = tonumber(controlCode)
            if num then
                ret[num] = controlName
            end
        end
    end

    return ret
end

return
{
    GetRPCsType = GetRPCsType,
    GetControls = GetControls,
}
