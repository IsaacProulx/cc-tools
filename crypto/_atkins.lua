--[[
    https://gist.github.com/nikswap/1788020
	Create a results list, filled with 2, 3, and 5.
    Create a sieve list with an entry for each positive integer; all entries of this list should initially be marked nonprime.
    For each entry number n in the sieve list, with modulo-sixty remainder r :
        If r is 1, 13, 17, 29, 37, 41, 49, or 53, flip the entry for each possible solution to 4x2 + y2 = n.
        If r is 7, 19, 31, or 43, flip the entry for each possible solution to 3x2 + y2 = n.
        If r is 11, 23, 47, or 59, flip the entry for each possible solution to 3x2 − y2 = n when x > y.
        If r is something else, ignore it completely.
    Start with the lowest number in the sieve list.
    Take the next number in the sieve list still marked prime.
    Include the number in the results list.
    Square the number and mark all multiples of that square as nonprime.
    Repeat steps five through eight.
]]--

local function element_in_list(element, list)
	for _,v in pairs(list) do
		if v == element then
			return true
		end
	end

	return false
end

local function atkins(start_prime, max_prime)
    local sieve_list = {}
    local res = {}
    if start_prime < 2 then
        res = {2,3,5}
    elseif start_prime < 4 then
        res = {3,5}
    elseif start_prime < 6 then
        res = {5}
    end

    for n=start_prime,max_prime,1 do
        sieve_list[n] = false
    end

    for n=start_prime,max_prime,1 do
        if element_in_list(n%60,{1,13,17,29,37,41,49,53}) then
            --4x^2+y^2 = n
            for x=1,math.sqrt(n),1 do
                for y=1,math.sqrt(n),1 do
                    if (4*x*x+y*y) == n then
                        sieve_list[n] = not sieve_list[n]
                    end
                end
            end
        elseif element_in_list(n%60,{7,19,31,43}) then
            --3x^2+y^2 = n
            for x=1,math.sqrt(n),1 do
                for y=1,math.sqrt(n),1 do
                    if (3*x*x+y*y) == n then
                        sieve_list[n] = not sieve_list[n]
                    end
                end
            end
        elseif element_in_list(n%60,{11,23,47,59}) then
            --3x^2-y^2 = n, x > y
            for y=1,math.sqrt(n),1 do
                for x=(y+1),math.sqrt(n),1 do
                    if (3*x*x-y*y) == n then
                        sieve_list[n] = not sieve_list[n]
                    end
                end
            end
        end
    end

    local max = start_prime
    while max < max_prime do
        for n=max,max_prime,1 do
            if sieve_list[n] then
                if not element_in_list(n,res) then
                    table.insert(res,n)
                end
                local step = n*n
                local counter = 1
                while step < max_prime do
                    step = step*counter
                    counter = counter+1
                    sieve_list[step] = false
                end
                break
            end
        end
        max = max + 1
    end

    return res
end

return atkins