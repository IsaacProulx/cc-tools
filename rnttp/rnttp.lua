local RSA = require("/crypto/RSA")
local JSON = require("/serialize/json")
require("/async/promise")

local keyPair
if(not fs.exists(".rnttp")) then
    fs.makeDir(".rnttp")
end
if(not fs.exists(".rnttp/key")) then
    keyPair = RSA.generateKey()
    local f = fs.open(".rnttp/key", "w")
    f.write(JSON.encode(keyPair))
    f.close()
else
    local f = fs.open(".rnttp/key", "r")
    keyPair = JSON.decode(f.readAll())
    f.close()
end

local function receive()
    rednet.open("back")
    local id, message = rednet.receive()
    rednet.close("back")
    local parsedMessage
    if(pcall(function()
        parsedMessage = JSON.decode(message)
    end)) then
        return id, parsedMessage
    end
    return id, nil
end

local function send(id, jsonData, unsigned)
    rednet.open("back")
    if(not unsigned) then
        local _, signature = RSA.sign(JSON.encode(jsonData), table.unpack(keyPair.private))
        jsonData.signature = signature
    end

    local success = rednet.send(id, JSON.encode(jsonData))
    rednet.close("back")
    return success
end

local function waitForValidResponse(id, key)
    while true do repeat
        local responseId, response = receive()
        if(responseId ~= id) then break end
        local signature = response.signature
        response.signature = nil
        if(not RSA.verify(signature, key[1], key[2], JSON.encode(response))) then break end

        return response
    until true end
end

local function resolveAddress(address)
    -- TODO: address list caching
    local dnsList do
        local f = fs.open(".rnttp/dns-config.json","r")
        dnsList = JSON.decode(f.readAll())
        f.close()
    end

    return Promise(function(resolve, reject)
        for _,dns in ipairs(dnsList) do
            send(dns.id, {
                method = "GET",
                body = {
                    address = address
                }
            })

            local response = waitForValidResponse(dns.id, dns.key)
            if(response.status == 200) then
                resolve(table.pack(response.body.id, response.body.key))
                return
            end
        end
    end)
end

local function fetch(address, request) return Promise(
    function(resolve, reject)
        resolveAddress(address):done(function(dnsResponse)
            local serverId, serverKey = table.unpack(dnsResponse)
            send(serverId, request)
            resolve(waitForValidResponse(serverId, serverKey))
        end)
    end
) end

local rnttp = {}
rnttp.fetch = fetch
rnttp.receive = receive
rnttp.send = send
return rnttp
