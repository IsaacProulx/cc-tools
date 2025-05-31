local rnttp = require("rnttp")
local Promise = require("async/promise")

local function sum(operands)
    print(operands[1])
    print(type(operands[1]))
    local s = 0
    local i = 1
    repeat
        if(type(operands[i]) ~= "number") then break end
        s = s+operands[i]
        i = i+1
    until i > #operands
    print(i)
    if(i ~= #operands+1) then return nil, i end
    return s
end

local function badRequest(id, error)
    rnttp.send(id, {status=400, body={error=error}})
end

local function main() while true do repeat
    local id, req = rnttp.receive()
    if(req.body == nil) then badRequest(id, "Missing body"); break end
    if(req.body.operands == nil) then badRequest(id, "Missing operands"); break end
    if(#req.body.operands == 0) then badRequest(id, "Missing operand"); break end
    local ans, i = sum(req.body.operands)
    if(ans == nil) then badRequest(id, "operand "..i.." is not a number"); break end
    rnttp.send(id, {status=200, body={ans=ans}})
until false end end

parallel.waitForAny(
    Promise.loop,
    main
)
