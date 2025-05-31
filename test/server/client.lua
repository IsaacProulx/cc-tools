local rnttp = require("rnttp")
local Promise = require("async/promise")

local tArgs = {...}
local operation = tArgs[1]
local operands = {}
for i=2,select("#", ...) do
    table.insert(operands, tonumber(tArgs[i]))
end

local function main()
    local res = rnttp.fetch("test.com",{
        method="GET",
        body={
            operation=operation,
            operands=operands
        }
    }):await()
    if(res.status == 200) then
        local s = ""
        for _,op in pairs(operands) do
            s = s .. op .. "+"
        end
        s = s:sub(0,-2) .. "=" .. res.body.ans
        print(s)
        return
    end
    if(res.status == 400) then
        print(res.body.error)
        return
    end
    print(res.status)
end

parallel.waitForAny(
    Promise.loop,
    main
)
