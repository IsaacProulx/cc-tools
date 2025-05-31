--[[
-- Don't use this module right now
--]]

JSON_WHITESPACE = " \t\n"
JSON_SYNTAX = '{,}":[]'
TRUE_LEN = 4
FALSE_LEN = 5
NULL_LEN = 4

local JSON = {}

local null_metatable = {
    __index = function(t,key,value)
        error("attempt to index a nil value")
    end,
    __newindex = function(t,key,value)
        error("attempt to index a nil value")
    end,
    __tostring = function(t)
        return 'null'
    end,
    __call = function(t)
        error("attempt to call a nil value")
    end
}

local function null()
    local n = {}
    setmetatable(n,null_metatable)
    return n
end

local function lex_str(str)
    json_str = ''
    --implement escape sequences later
    if str:sub(1,1) ~= '"' then
        return nil, str
    end

    str = str:sub(2)

    for char in str:gmatch(".") do
        if char == '"' then
            --print(char)
            return json_str, str:sub(#json_str+2)
        else
            json_str = json_str..char
        end
    end
    error('EOF while reading string')
end

local function lex_number(str)
    json_number = ''
    numbers = '0123456789e'
    
    for char in str:gmatch(".") do
        if char=="." or char=="-" then
            json_number = json_number..char
        elseif numbers:find(char) then
            json_number = json_number..char
        else
            break
        end
    end

    if #json_number == 0 then
        return nil, str
    end
    
    str = str:sub(#json_number+1)
    return tonumber(json_number), str
end

local function lex_bool(str)
    if #str < TRUE_LEN then return nil, str end
    
    if str:sub(0,TRUE_LEN) == 'true' then
        return true, str:sub(TRUE_LEN+1)
    end
    
    if str:sub(0,FALSE_LEN) == 'false' then
        return false, str:sub(FALSE_LEN+1)
    end

    return nil, str
end

local function lex_null(str)
    if #str >= NULL_LEN and str:sub(1,NULL_LEN) == 'null' then
        return true, str:sub(NULL_LEN+1)
    end
    return nil, str
end

local function lex(str)
    --position starts at 1 since lua is 1-indexed
    local pos = 1
    local tokens = {}
    local nil_tokens = {}
    local tokens_len = 0

    while #str>0 do
        repeat
            json_str, str = lex_str(str)
            if json_str ~= nil then
                table.insert(tokens,json_str)
                break
            end

            json_number, str = lex_number(str)
            if json_number ~= nil then
                table.insert(tokens,json_number)
                break
            end

            json_bool, str = lex_bool(str)
            if json_bool ~= nil then
                table.insert(tokens,json_bool)
                break
            end

            json_null, str = lex_null(str)
            if json_null ~= nil then
                table.insert(tokens,null())
                break
            end

            if JSON_WHITESPACE:find(str:sub(1,1)) then
                str = str:sub(2)
            elseif JSON_SYNTAX:find(str:sub(1,1)) then
                table.insert(tokens,str:sub(1,1))
                str = str:sub(2)
            else
                error("Unexpected token "..str:sub(1,1).." at position: "..tostring(pos))
            end
            break
        until true
        pos = pos + 1
    end
    return tokens
end

function slice(t,first,last)
    local sliced = {}

    for i=first or 1, last or #t, 1 do
        sliced[#sliced+1] = t[i]
    end

    return sliced
end

local function parse(tokens)
    local function parse_array(tokens)
        json_array = {}
    
        token = tokens[1]
        if token == ']' then
            return json_array, slice(tokens,2)
        end
    
        while #tokens > 0 do
            json, tokens = parse(tokens)
            table.insert(json_array,json)
    
            token = tokens[1]
            if token == ']' then
                return json_array,slice(tokens,2)
            end
            if token ~= ',' then
                error('Expected comma')
            else
                tokens = slice(tokens,2)
            end
        end
        error('EOF while reading array')
    end
    
    local function parse_object(tokens)
        json_object = {}
    
        token = tokens[1]
        if token == '}' then
            return json_object, slice(tokens,2)
        end
        while #tokens > 0 do
            json_key = tokens[1]
            if type(json_key) == "string" then
                tokens = slice(tokens,2)
            else
                error('Expected string')
            end
            if tokens[1] ~= ':' then
                error('Expected colon')
            end
    
            json_value, tokens = parse(slice(tokens,2))
            json_object[json_key] = json_value
    
            token = tokens[1]
            if token == '}' then
                return json_object,slice(tokens,2)
            end
            if token ~= ',' then
                error('Expected comma, got: '..tostring(token))
            else
                tokens = slice(tokens,2)
            end
        end
        error('EOF while reading object')
    end

    token = tokens[1]

    if token == '[' then
        return parse_array(slice(tokens,2))
    end
    if token == '{' then
        return parse_object(slice(tokens,2))
    end

    return token, slice(tokens,2)
    --return token, slice(tokens,2)
end

JSON.parse = function(str)
    return parse(lex(str))
end

JSON.isNull = function ( obj )
    if type(obj) == "table" and getmetatable( obj ) == null_metatable then
        return true
    end
    return false
end

JSON.null = null

return JSON
