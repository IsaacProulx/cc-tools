local generatePrimes = require("/crypto/_atkins")

local function generatePrime(min, max)
    local primes = generatePrimes(min, max)
    math.randomseed(os.clock())
    return primes[math.random(#primes)]
end

-- https://github.com/TheAlgorithms/Lua/blob/main/src/math/greatest_common_divisor.lua
-- Euclidean algorithm
local function extended_gcd(
	a, -- number
	b -- number
)
	a, b = math.abs(a), math.abs(b)
	if a == 0 then
		return math.max(b, 1)
	elseif b == 0 then
		return math.max(a, 1)
	end
	-- Bezout's identity
	local x_prev, x = 1, 0
	local y_prev, y = 0, 1
	while b > 0 do
		local quotient = math.floor(a / b)
		a, b = b, a % b
		x_prev, x = x, x_prev - quotient * x
		y_prev, y = y, y_prev - quotient * y
	end
	-- Greatest common divisor & Bezout's identity: x, y with a * x + b * y = GCD
	return a, x_prev, y_prev
end

-- Computes the inverse of `a` modulo `m`, i.e.
-- finds a number `x` such that
-- (a * x) % m == 1 and 0 < x < m
local function mod_inverse(
	a, -- number
	m -- modulus
)
	assert(m > 0, "modulus must be positive")
	if m == 1 then
		return nil
	end
	local gcd, x, _ = extended_gcd(a % m, m)
	if gcd == 1 then
		-- Ensure that result is in (0, m)
		return x % m
	end
	return nil
end

--https://emrehangorgec.medium.com/implementing-rsa-for-digital-signature-from-scratch-f6f416d9878f
local function generateKey()
    local p = generatePrime(3, 5000)
    local q = generatePrime(3, 5000)
    while p == q do
        q = generatePrime(3, 5000)
    end

    local n = p * q
    local totient_n = (p - 1) * (q - 1)

    math.randomseed(os.clock())

    local e = math.random(3, totient_n - 1)

    while extended_gcd(e, totient_n) ~= 1 do
        e = math.random(3, totient_n - 1)
    end

    local d = mod_inverse(e, totient_n)

    return {
        public = {e, n},
        private = {d, n}
    }

end

local function splitBlocks(message, block_size)
    return message:gmatch((".?"):rep(block_size))
end

local function bytesToInt(input)
    local num = 0
    for c in input:gmatch"." do
        num = bit.bor(bit.blshift(num, 8), c:byte())
    end

    return num
end

local function bytesToString(input)
    local str = ""
    --print(input)
    while(input>0) do
        local byte = bit.band(input, 0xFF)
        str = string.char(byte)..str
        input = bit.brshift(input, 8)
    end
    return str
end

--https://en.wikipedia.org/wiki/Modular_exponentiation#Pseudocode
local function modPow(b, e, m)
    local result = 1
    b = b % m
    while(e > 0) do
        if(e % 2 == 1) then
            result = (result * b) % m
        end
        e = bit.brshift(e, 1)
        b = (b*b) % m
    end
    return result
end

local function encryptBlock(block, d, n)
    local block_int = bytesToInt(block)
    --print(block_int)
    --print(("encrypt_block: %d"):format(block_int))
    --print(modPow(block_int, d,n))
    return modPow(block_int, d, n)
end

local function sign(message, d, n)
    local block_size = math.floor(math.ceil(math.log(n, 2))/8)
    if #message <= block_size then
        return message, encryptBlock(message, d, n)
    end

    local blocks = splitBlocks(message, block_size)
    local originalBlocks = {}
    local signedBlocks = {}
    for block in blocks do
        table.insert(signedBlocks, encryptBlock(block, d, n))
        table.insert(originalBlocks, block)
    end
    return originalBlocks, signedBlocks
end

local function decryptBlock(encryptedBlockInt, e, n)
    local decryptedBlockInt = modPow(encryptedBlockInt, e, n)
    --print(decryptedBlockInt)
    --print(bytesToString(decryptedBlockInt))
    return bytesToString(decryptedBlockInt)
end

local function verify(signedBlocks, e, n, originalMessage)
    local decryptedMessage = ""
    --print(signedBlocks)
    for _,block in ipairs(signedBlocks) do
        --print(type(block))
        decryptedMessage = decryptedMessage .. decryptBlock(block, e, n)
    end

    --print(decryptedMessage)
    return decryptedMessage == originalMessage
end

local RSA = {}
RSA.generatePrimes = generatePrimes
RSA.generateKey = generateKey
RSA.sign = sign
RSA.verify = verify
RSA.encrypt = encryptBlock
RSA.decrypt = decryptBlock
return RSA
