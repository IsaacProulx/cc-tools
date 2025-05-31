local rnttp = require("rnttp")
local Promise = require("async/promise")

local function sum(operands)
    local s = 0
    local i = 1
    repeat
        if(type(operands[i]) ~= "number") then break end
        s = s+operands[i]
        i = i+1
    until i > #operands
    if(i ~= #operands+1) then return nil, i end
    return s
end

local function multiply(operands)
    local m = 1
    local i = 1
    repeat
        if(type(operands[i]) ~= "number") then break end
        m = m*operands[i]
        i = i+1
    until i > #operands
    if(i ~= #operands+1) then return nil, i end
    return m
end

local function badRequest(id, error)
    rnttp.send(id, {status=400, body={error=error}})
end

local function main() while true do repeat
    local id, req = rnttp.receive()
    if(req == nil) then badRequest(id, "Empty request"); break end
    if(req.body == nil) then badRequest(id, "Missing body"); break end
    if(req.body.operation == nil) then badRequest(id, "Missing operation"); break end
    if(req.body.operands == nil) then badRequest(id, "Missing operands"); break end
    if(#req.body.operands == 0) then badRequest(id, "Missing operand"); break end
    local operation = req.body.operation
    local ans, i
    if(operation == "+") then
        ans, i = sum(req.body.operands)
    elseif(operation == "*") then
        ans, i = multiply(req.body.operands)
    end
    if(ans == nil) then badRequest(id, "operand "..i.." is not a number"); break end
    rnttp.send(id, {status=200, body={ans=ans}})
until false end end

parallel.waitForAny(
    Promise.loop,
    main
)
