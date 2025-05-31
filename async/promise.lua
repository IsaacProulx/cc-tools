-- Promise Module for CC-Tweaked
-- Implements Promises using standard Lua OOP practices

-- Promise States
local STATES = {
    PENDING = "pending",
    FULFILLED = "fulfilled", 
    REJECTED = "rejected"
}

-- Promise Class
local Promise = {}
Promise.__index = Promise

-- Private Promise Manager
local PromiseManager = {
    _promises = {},
    _nextId = 0
}

-- Generate a unique ID for promises
function PromiseManager:_generateId()
    self._nextId = self._nextId + 1
    return self._nextId
end

-- Remove a promise from the manager
function PromiseManager:_remove(id)
    for i = 1, #self._promises do
        if self._promises[i].id == id then
            table.remove(self._promises, i)
            return
        end
    end
end

-- Constructor
function Promise.new(executor)
    -- Validate executor
    if type(executor) ~= "function" then
        error("Promise executor must be a function", 2)
    end

    -- Create promise instance
    local self = setmetatable({}, Promise)
    
    -- Promise state
    self._id = PromiseManager:_generateId()
    self._state = STATES.PENDING
    self._value = nil
    self._reason = nil
    
    -- Handlers
    self._handlers = {
        onFulfilled = nil,
        onRejected = nil,
        onFinally = nil
    }

    -- Resolve method
    local function resolve(value)
        if self._state ~= STATES.PENDING then return end
        
        PromiseManager:_remove(self._id)
        self._state = STATES.FULFILLED
        self._value = value
        
        if self._handlers.onFulfilled then
            self._handlers.onFulfilled(value)
        end
        
        if self._handlers.onFinally then
            self._handlers.onFinally()
        end
    end

    -- Reject method
    local function reject(reason)
        if self._state ~= STATES.PENDING then return end
        
        PromiseManager:_remove(self._id)
        self._state = STATES.REJECTED
        self._reason = reason
        
        if self._handlers.onRejected then
            self._handlers.onRejected(reason)
        end
        
        if self._handlers.onFinally then
            self._handlers.onFinally()
        end
    end

    -- Add to promise manager
    local promiseEntry = {
        id = self._id,
        fn = function()
            local ok, err = pcall(executor, resolve, reject)
            if not ok then
                reject(err)
            end
        end
    }
    table.insert(PromiseManager._promises, promiseEntry)

    return self
end

-- Done method
function Promise:done(onFulfilled)
    self._handlers.onFulfilled = onFulfilled
    
    if self._state == STATES.FULFILLED then
        onFulfilled(self._value)
    end
    
    return self
end

-- Catch method
function Promise:catch(onRejected)
    self._handlers.onRejected = onRejected
    
    if self._state == STATES.REJECTED then
        onRejected(self._reason)
    end
    
    return self
end

-- Finally method
function Promise:finally(onFinally)
    self._handlers.onFinally = onFinally
    
    if self._state ~= STATES.PENDING then
        onFinally()
    end
    
    return self
end

-- Await method
function Promise:await()
    -- Create a local state to track promise resolution
    --local status = self._state
    local result = nil
    local error_occurred = false

    -- Set up handlers to update local state
    self:done(function(value)
        --status = STATES.FULFILLED
        result = value
    end):catch(function(err)
        --status = STATES.REJECTED
        result = err
        error_occurred = true
    end)

    -- Wait until promise is resolved
    while self._state == STATES.PENDING do
        os.sleep(0)  -- Yield to other processes
    end

    -- If an error occurred during promise resolution, throw it
    if error_occurred then
        error(result, 2)
    end

    -- Return the resolved value
    return result
end

-- Static method: Resolve
function Promise.resolve(value)
    return Promise.new(function(resolve) resolve(value) end)
end

-- Static method: Reject
function Promise.reject(reason)
    return Promise.new(function(_, reject) reject(reason) end)
end

-- Static method: All
function Promise.all(promises)
    return Promise.new(function(resolve, reject)
        local results = {}
        local completed = 0
        local total = #promises

        if total == 0 then
            resolve(results)
            return
        end

        for i, p in ipairs(promises) do
            p:done(function(value)
                results[i] = value
                completed = completed + 1
                if completed == total then
                    resolve(results)
                end
            end):catch(reject)
        end
    end)
end

-- Static method: Async wrapper for functions that return promises
function Promise.async(fn)
    return function(...)
        local args = {...}
        return Promise.new(function(resolve, reject)
            local ok, result = pcall(function()
                return fn(table.unpack(args))
            end)
            
            if ok then
                if type(result) == "table" and result.await then
                    resolve(result:await())
                else
                    resolve(result)
                end
            else
                reject(result)
            end
        end)
    end
end

-- Async Loop
local function loop()
    while true do
        local executors = {}
        for i = 1, #PromiseManager._promises do
            table.insert(executors, PromiseManager._promises[i].fn)
        end
        
        if #executors > 0 then
            parallel.waitForAll(table.unpack(executors))
        end
        
        os.sleep(0)
    end
end

-- Metatable to allow calling Promise as a function
setmetatable(Promise, {
    __call = function(_, executor)
        return Promise.new(executor)
    end
})

-- Global exposure
_G["Promise"] = Promise

-- Module export
return {
    Promise = Promise,
    loop = loop
}