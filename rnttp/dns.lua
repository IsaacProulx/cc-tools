local JSON = require("/serialize/json")
local rnttp = require("/rnttp")

local keyPair, addressTable do
    local f = fs.open(".rnttp/key","r")
    keyPair = JSON.decode(f.readAll())
    f.close()
    f = fs.open(".rnttp/address-table.json", "r")
    addressTable = JSON.decode(f.readAll())
    f.close()
end

local function get(id, request)
    local resolvedHost = addressTable[request.body.address]
    if(resolvedHost == nil) then
        return rnttp.send(id, {
            status = 404,
            body = {
                error = "Address not found"
            }
        })
    end
    return rnttp.send(id, {
        status = 200,
        body = resolvedHost
    })
end

local function post(id, request)
    if(addressTable[request.body.address]) then
        return rnttp.send(id, {
            status = 409,
            body = {
                error = "This domain is already registered"
            }
        })
    end

    addressTable[request.body.address] = {
        id=request.body.id,
        key=request.body.key
    }

    local addressTableFile = fs.open(".rnttp/address-table.json", "w")
    addressTableFile.write(JSON.encode(addressTable))
    addressTableFile.close()

    return rnttp.send(id, {
        status = 201,
        body = {
            message = ("Successfully registered domain %s"):format(request.body.address)
        }
    })

end

--os.clearScreen{"black"}
term.clear()
term.setCursorPos(1,1)
print("Domain Name Server running...")
print(("ID = %d"):format(os.getComputerID()))
print("Public Key =")
print(("  e = %d"):format(keyPair.public[1]))
print(("  n = %d"):format(keyPair.public[2]))
while true do repeat
    local id, request = rnttp.receive()

    if(request.method == "GET") then
        get(id, request)
        break
    end

    if(request.method == "POST") then
        post(id, request)
        break
    end

    rnttp.send(id, {status=400, body={error="Unsupported METHOD"}})
until true end
