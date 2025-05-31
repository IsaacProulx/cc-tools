local JSON
if(not fs.exists(".:/serialize/json.lua")) then
    print("Could not find JSON module. Loading remotely...")
    
    local res, err = http.get("https://raw.githubusercontent.com/rxi/json.lua/refs/heads/master/json.lua")
    if(err) then
        printError(err)
        return 1
    end
    local content = res.readAll()
    res.close()
    fs.makeDir(".:/serialize")
    local f = fs.open(".:/serialize/json.lua", "w")
    f.write(content)
    f.close()
    JSON = loadstring(content)()
else
    -- require may not be defined yet
    JSON = loadfile(".:/serialize/json.lua")()
end

if(not fs.exists(".:/.clone")) then
    local f = fs.open(".:/.clone", "w")
    f.write('{"roots":["http://localhost:8080"]}')
    f.close()
end

local function readFile(url)
    local res, err = http.get(url)
    if(err == "File not found") then
        print(("Could not find \"%s\" - skiping ..."):format(url))
        return nil
    end
    local content = res.readAll()
    res.close()
    return content
end

local function getFile(repo, root, fileInfo, fs)
    local fileContent = readFile(fileInfo.remote or (repo.."/"..fileInfo.src))
    if(fileContent == nil) then return end
    if(fileInfo.run) then
        loadstring(fileContent)()
    end
    if(fileInfo.download == false) then return end

    local f = fs.open(fs.combine(root, fileInfo.dest or fileInfo.src),"w")
    f.write(fileContent)
    f.close()
end

local function checkRepo(clonercUrl)
    local f = fs.open(".:/.clone", "r")
    local userSettings = JSON.decode(f.readAll())
    f.close()
    local ok, config, res, err
    for _,root in pairs(userSettings.roots) do
        local url = root .. "/" .. clonercUrl
        err = nil
        res, err = http.get(url)
        if(err == nil) then
            ok, err, config = pcall(function() return nil, JSON.decode(res.readAll()) end)
            res.close()
        end

        if(not ok) then
            err = nil
            res, err = http.get(url .. "/" .. ".clonerc.json")
            if(err == nil) then
                ok, err, config = pcall(function() return nil, JSON.decode(res.readAll()) end)
                res.close()
            end
        end
        
        if(ok) then return config end
    end

    err = nil
    res, err = http.get(clonercUrl)
    if(err == nil) then
        ok, err, config = pcall(function() return nil, JSON.decode(res.readAll()) end)
        res.close()
    end

    if(not ok) then
        err = nil
        res, err = http.get(clonercUrl .. "/" .. ".clonerc.json")
        if(err == nil) then
            ok, err, config = pcall(function() return nil, JSON.decode(res.readAll()) end)
            res.close()
        end
    end
    
    if(ok) then return config end

    term.clear()
    term.setCursorPos(1,1)

    if(err=="Domain not permitted") then
        printError("The repository is blocked.")
        print(("You'll need to allow \"%s\" in your computercraft config."):format(clonercUrl))
        print("You can find your config file at: [world folder]>serverconfig>computercraft-server.toml")
    elseif(err=="Could not connect") then
        printError("Could not reach the repository.")
        print("Make sure you're connected to the internet")
    else
        printError("Not a Config")
        print("The provided URL does not point to a clonerc file")
    end

    return nil
end


local function clone(clonercUrl, fs)
    local time = os.clock()
    local config = checkRepo(clonercUrl)

    if(config == nil) then return 1 end

    print("Everything looks good, starting download...")
    for _,fileInfo in pairs(config.files) do repeat
        if(type(fileInfo) ~= "table") then break end
        getFile(config.sourceRoot, config.destinationRoot, fileInfo, fs)
        break
    until true end
    print("Done in:",os.clock()-time,"seconds")
    return 0
end

local tArgs = {...}
if #tArgs ~= 1 then
    print("Usage: clone <.clonerc.json url>")
    return 1
end

return clone(tArgs[1], fs)
