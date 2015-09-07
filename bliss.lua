#!/usr/bin/lua

function getopt(optstring, ...)
	local opts = { }
	local args = { ... }

	for optc, optv in optstring:gmatch"(%a)(:?)" do
		opts[optc] = { hasarg = optv == ":" }
	end

	return coroutine.wrap(function()
		local yield = coroutine.yield
		local i = 1

		while i <= #args do
			local arg = args[i]

			i = i + 1

			if arg == "--" then
				break
			elseif arg:sub(1, 1) == "-" then
				for j = 2, #arg do
					local opt = arg:sub(j, j)

					if opts[opt] then
						if opts[opt].hasarg then
							if j == #arg then
								if args[i] then
									yield(opt, args[i])
									i = i + 1
								elseif optstring:sub(1, 1) == ":" then
									yield(':', opt)
								else
									yield('?', opt)
								end
							else
								yield(opt, arg:sub(j + 1))
							end

							break
						else
							yield(opt, false)
						end
					else
						yield('?', opt)
					end
				end
			else
				yield(false, arg)
			end
		end

		for i = i, #args do
			yield(false, args[i])
		end
	end)
end

local bliss = require './libbliss'
local helpstr = [[
bliss - bliss language interpreter

options:
	h: display this help and quit
	v: display version info and quit
	i: evaluate the file specified by the argument and enter interactive mode
	e: execute a statement
	E: execute a statement and enter interactive mode]]

local verstr = [[
bliss version 1.0
Copyright © Matheus de Alcantara, 2015, under the MIT license.]]

for opt, arg in getopt('hvi:e:', ...) do
	if opt == 'h' then
		print(helpstr)
		os.exit(0)
	elseif opt == 'v' then
		print(verstr)
		os.exit(0)
	elseif opt == 'i' then
		bliss.evalf(arg)
	elseif opt == 'e' then
		bliss.eval(arg)
		os.exit(0)
	elseif opt == 'E' then
		bliss.eval(arg)
	elseif opt == false then
		bliss.evalf(arg)
		os.exit(0)
	end
end

bliss.repl()
