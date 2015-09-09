#!/usr/bin/env lua


function tokenize (exp)
	local sexpr, word, in_str, in_comment = {{}}, '', false, false

	for i = 1, #exp do
		local c = exp:sub(i, i)

		if (c == '(') and not in_str then
			table.insert(sexpr, {})
		elseif (c == ')') and not in_str then
			if #word > 0 then
				table.insert(sexpr[#sexpr], word)
				word = ''
			end

			local t = table.remove(sexpr)
			table.insert(sexpr[#sexpr], t)
		elseif (c == ' ' or c == '\t' or c == '\n') and not in_str then
			if in_comment then
				in_comment = (c ~= '\n')
			elseif #word > 0 then
				table.insert(sexpr[#sexpr], word)
				word = ''
			end
		elseif c == '"' then
			word = word .. '"'
			in_str = not in_str
		elseif c == ';' then
			in_comment = true
		else
			word = word .. c
		end
	end

	return sexpr[1]
end

function categorize(tokens)
	if tokens then
		local ret = {}

		for i = 1, #tokens do
			if type(tokens[i]) == 'table' then
				table.insert(ret, categorize(tokens[i]))
			elseif type(tokens[i]) == 'string' then
				if tonumber(tokens[i]) ~= nil then
					table.insert(ret, {
						type = 'literal',
						value = tonumber(tokens[i])
					})
				elseif tokens[i]:sub(1, 1) == '"' and tokens[i]:sub(#tokens[i], #tokens[i]) == '"' then
					table.insert(ret, {
						type = 'literal',
						value = tokens[i]:sub(2, #tokens[i] - 1)
					})
				elseif tokens[i]:sub(1, 1) == '\'' then
					table.insert(ret, {
						type = 'literal',
						value = tokens[i]:sub(2, #tokens[i])
					})
				elseif tokens[i]:lower() == 'true' or tokens[i] == 'false' then
					table.insert(ret, {
						type = 'literal',
						value = tokens[i]:lower() == 'true'
					})
				else
					table.insert(ret, {
						type = 'identifier',
						value = tokens[i]
					})
				end
			end
		end
		return ret
	end
end

local function cpt(t)
	local r = {}
	for k, v in pairs(t) do
		r[k] = v
	end
	return r
end

---

local maths = {
	['+'] = function(l, c)
		local acc = 0

		for i = 1, #l do
			acc = acc + interpret(l[i], c)
		end

		return acc
	end,
	['-'] = function(l, c)
		return interpret(l[1], c) - interpret(l[2], c)
	end,
	['*'] = function(l, c)
		local acc = interpret(l[1], c)

		for i = 2, #l do
			acc = acc * interpret(l[i], c)
		end

		return acc
	end,
	['/'] = function(l, c) return interpret(l[1], c) / interpret(l[2], c) end,
	['%'] = function(l, c) return interpret(l[1], c) % interpret(l[2], c) end,
	['**'] = function(l, c) return interpret(l[1], c) ^ interpret(l[2], c) end,
}

local tests = {
	['=='] = function(list, con) return interpret(list[1], con) == interpret(list[2], con) end,
	['!='] = function(list, con) return interpret(list[1], con) ~= interpret(list[2], con) end,
	['>='] = function(list, con) return interpret(list[1], con) >= interpret(list[2], con) end,
	['<='] = function(list, con) return interpret(list[1], con) <= interpret(list[2], con) end,
	['>']  = function(list, con) return interpret(list[1], con) > interpret(list[2], con)  end,
	['<']  = function(list, con) return interpret(list[1], con) < interpret(list[2], con)  end,
	['!']  = function(list, con) return not interpret(list[1], con)                        end
}

local keywords = {
	['def'] = function(list, con)
		(con.__parent and con.__parent or con)[list[1].value] = interpret(list[2], con)
	end,
	['if'] = function(list, con)
		if interpret(list[1], con) == true or type(interpret(list[1], con)) == 'table' then
			return interpret(list[2], con)
		else
			if list[3] then
				return interpret(list[3], con)
			end
		end
	end,
	['run'] = function(list, con)
		for i = 1, #list - 1 do
			interpret(list[i], con)
		end

		return interpret(list[#list], con)
	end,
	['lambda'] = function(list, con)
		return function(...)
			local args = {...}

			local scope = {}

			for i = 1, #list[1] do
				scope[list[1][i].value] = args[i]
			end

			if #list > 2 then
				for i = 2, #list do
					interpret(list[i], context(scope, con))
				end
			end
			return interpret(list[#list], context(scope, con))
		end
	end,
	['defun'] = function(list, con)
		con[list[1].value] = function(...)
			local args = {...}

			local scope = {}

			for i = 1, #list[2] do
				scope[list[2][i].value] = args[i]
			end

			for i = 3, #list do
				interpret(list[i], context(scope, con))
			end

			return interpret(list[#list], context(scope, con))
		end
	end,
	['pcall'] = function(list, con)
		local fun = interpret(list[1], con)
		if type(fun) ~= 'function' then
			return {false, 'Can not call element of type ' .. type(fun)}
		else
			return {pcall(fun, unpack(interpret(list[2], con)))}
		end
	end,
	['loop'] = function(list, con)
		while true do
			for i = 1, #list do
				interpret(list[i], con)
			end
		end
	end,
	['while'] = function(list, con)
		while interpret(list[1], con) == true do
			for i = 2, #list do
				interpret(list[2], con)
			end
		end
	end,
	['for'] = function(list, con)
		local label, start, stop = list[1].value,

		interpret(list[2], con), interpret(list[3], con)
		local forcontext = context(cpt(con), con)

		for i = start, stop do
			forcontext[label] = i
			for i = 3, #list do
				interpret(list[i], forcontext)
			end
		end
	end,

	['let'] = function(list, con)
		local letctx = context({}, con)
		letctx[list[1][1].value] = interpret(list[1][2], con)
		if #list > 2 then
			for i = 2, #list - 1 do
				interpret(list[2], letctx)
			end
		end
		return interpret(list[#list], letctx)
	end,

	['?:'] = function(list, con)
		if interpret(list[1], con) == true then
			return interpret(list[2], con)
		else
			return interpret(list[3], con)
		end
	end,
	['len'] = function(list, con)
		return #interpret(list[1], con)
	end,
	['ret'] = function(list, con)
		print(list[1].value .. ': ', interpret(list[1], con))
		return interpret(list[1], con)
	end,
	['throw'] = function(list, con)
		local r = {}

		for i = 1, #list do
			r[i] = interpret(list[i], con)
		end

		error(llispl.stringify(r))
	end
}


---

function context(scope, parent)
	return setmetatable({
		__parent = parent
	}, {
		['__index'] = function(_, k)
			if rawget(_, k) then return rawget(_, k)
			elseif scope and scope[k] then return scope[k]
			elseif parent and parent[k] then return parent[k] end
		end
	})
end

local special = (function(...)
	local ret = {}

	for k, v in pairs({...}) do
		for l, b in pairs(v) do
			ret[l] = b
		end
	end

	return ret
end)(maths, keywords, tests)

local function map(t, f)
	local x = {}
	for k, v in pairs(t) do x[k] = f(k, v) end
	return x
end

local function interpretList(ls, con)
	if #ls > 0 and special[ls[1].value] then
		return special[ls[1].value]({unpack(ls, 2)}, con)
	else
		local list = map(ls, function(k, v)
			if type(v) == 'table' then
				return interpret(v, con)
			end
		end)

		if type(list[1]) == 'function' then
			local l = {pcall(list[1], unpack(list, 2))}
			if not l[1] then
				return {false, l[2]}
			else
				return unpack(l, 2)
			end
		else
			return list
		end
	end
end

llispl = setmetatable({}, {__index = _ENV})

gctx = context(llispl)

function interpret(what, con)
	if con == nil then
		return interpret(what, gctx)
	elseif type(what) == 'table' and not what.type then
		return interpretList(what, con)
	elseif what.type and what.type == "identifier" then
		return con[what.value]
	else
		return what.value
	end
end

function parse(s)
	return categorize(tokenize(s))
end

---

function llispl.stringify(...)
	local ret = '('
	if #({...}) == 1 and type(({...})[1]) == 'table' then
		return llispl.stringify(unpack(({...})[1]))
	else
		local max = (function(x) local r = 0; for k, v in pairs(x) do r = r + 1 end; return r end)({...})
		for k, v in pairs({...}) do
			if type(v) == 'string' then
				ret = ret .. '"' .. v .. '"' .. (k == max and '' or ' ')
			elseif type(v) == 'table' then
				ret = ret .. llispl.stringify(unpack(v)) .. (k == max and '' or ' ')
			elseif type(v) == 'function' then
				ret = ret .. '\'<function>' .. (k == max and '' or ' ')
			elseif type(v) == 'thread' then
				ret = ret .. '\'<thread>' .. (k == max and '' or ' ')
			else
				ret = ret .. tostring(v) .. (k == max and '' or ' ')
			end
		end
	end

	return ret .. ')'
end

function llispl.treeify(list, depth, ig)
	if type(depth) ~= 'number' then depth = 0 end

	local s = ("%sList (%s):\n"):format(((depth and depth ~= 0) and (" "):rep(depth) or ''), (llispl.split(tostring(list), ' '))[2])
	local t = (" "):rep((depth or 0) + 1)
	local siz = (function(t) local s = 0; for k, v in pairs(t) do s = s + 1 end; return s end)(list)
	local i = 1
	local ig = {} or ig

	for k, v in pairs(list) do
		if type(v) == 'table' then
			if v == list and not ig[k] then
				s = s .. t .. llispl.stringify(k) .. ': ' .. '<Recursive Entry>' .. ((i == siz) and '' or '\n')
				ig[k] = true
			else
				s = s .. t .. llispl.stringify(k) .. ': ' .. llispl.treeify(v, (depth or 0) + 1, ig) .. ((i == siz) and '' or '\n')
			end
		else
			s = s .. t .. llispl.stringify(k) .. ': ' .. llispl.stringify(v) .. ((i == siz) and '' or '\n')
		end
		i = i + 1
	end

	return s
end

function llispl.print(...)
  print(llispl.stringify({...}))
  return true
end

function llispl.pprint(...)
	for k, v in pairs({...}) do
		io.write((type(v) == 'table' or type(v) == 'function') and llispl.stringify(v) or tostring(v) .. ' ')
	end
	print()
	return true
end

function llispl.split(str, sep)
  local sep, fields = sep or ":", {}
  local pattern = string.format("([^%s]+)", sep)
  str:gsub(pattern, function(c)
    fields[#fields+1] = c
  end)

  return fields
end

function llispl.exit(status)
  os.exit(status or 0)
end

function llispl.join(...)
  local ret = {}
  llispl.print(...)
  for k, v in pairs({...}) do
    if type(v) == 'table' then
      for l, b in pairs(v) do

        ret[#ret + 1] = b
      end
    else
      ret[#ret + 1] = v
    end
  end

  return ret
end

function llispl.getm(t, w)
  return t[w]
end

function llispl.setm(t, w, v)
  t[w] = v
  return t[w]
end

function llispl.getg(w)
  return _ENV[w]
end

function llispl.map(fn, tab)
  for i = 1, #tab do
    fn(tab[i])
  end
end

function llispl.head(tbl)
     return tbl[1]
end

function llispl.tail(tbl)
	if #tbl < 1 then
		return nil
	else
		local newtbl = {}
		local tblsize = #tbl
		local i = 2
		while (i <= tblsize) do
			table.insert(newtbl, i-1, tbl[i])
			i = i + 1
		end
		return newtbl
	end
end

function llispl.foldr(func, val, tbl)
	for i,v in pairs(tbl) do
		val = func(val, v)
	end
	return val
end

function llispl.foldr2(func, val, tbl)
	for i,v in pairs(tbl) do
		val = func(val, v) and val or v
	end
	return val
end

function llispl.reduce(func, tbl)
	return llispl.foldr2(func, llispl.head(tbl), llispl.tail(tbl))
end

function llispl.curry(f1, f2)
	return function(...)
		return f1(f2(...))
	end
end

function llispl.concat(...)
	local r = ''

	for k, v in pairs({...}) do
		r = r .. (type(v) == 'table' or type(v) == 'function') and llispl.stringify(v) or tostring(v) .. ' '
	end

	return r
end

llispl['operator#mod'] = math.mod;
llispl['operator#pow'] = math.pow;
llispl['operator#add'] = function(n,m) return n + m end;
llispl['operator#sub'] = function(n,m) return n - m end;
llispl['operator#mul'] = function(n,m) return n * m end;
llispl['operator#div'] = function(n,m) return n / m end;
llispl['operator#gt']  = function(n,m) return n > m end;
llispl['operator#lt']  = function(n,m) return n < m end;
llispl['operator#eq']  = function(n,m) return n == m end;
llispl['operator#le']  = function(n,m) return n <= m end;
llispl['operator#ge']  = function(n,m) return n >= m end;
llispl['operator#ne']  = function(n,m) return n ~= m end;


llispl['map!'] = function(fn, tab)
  for i = 1, #tab do
    tab[i] = fn(tab[i])
  end

  return tab
end

function llispl.load(str)
	local snip = parse(str)

	return function()
		return interpret(snip, gctx)
	end
end

function llispl.eval(str)
	return interpret(parse(str), gctx)
end

function llispl.read()
	return io.read()
end

function llispl.fopen(path, mode)
	return io.open(path, mode)
end

function llispl.fread(file, what)
	return not file.read and {false, 'not a file'} or file:read(what)
end

function llispl.fwrite(file, what)
	return not file.write and {false, 'not a file'} or file:write(what)
end

function llispl.loadf(file)
	local x = io.open(file, 'r')
	local what = x:read '*all'
	x:close()
	local snip = parse(what)

	return function()
		return interpret(snip, gctx)
	end
end

function llispl.evalf(file)
	return llispl.loadf(file)()
end

function llispl.write(...)
	for k, v in pairs({...}) do
		io.write((type(v) == 'table' or type(v) == 'function') and llispl.stringify(v) or tostring(v) .. ' ')
	end
end

function llispl.slice(w, s, t)
	local ret = {}
	for i = s, t or #w do
		ret[#ret + 1] = w[i]
	end

	return #ret == 1 and unpack(ret) or ret
end

function llispl.push(w, v)
	w[#w + 1] = v
end

function llispl.pop(w)
	return table.remove(w)
end

function _flatten(what, curr)
	curr = curr or {}
	for k, v in pairs(what) do
		if type(v) == 'table' then
			_flatten(v, curr)
		else
			curr[k] = v
		end
	end

	return curr
end

function llispl.flatten(...)
	return _flatten({...}, {})
end

function llispl.parallel(...)
	local routines, error_catching_fn = {}, print

	for k, v in pairs(llispl.flatten(...)) do
		routines[#routines + 1] = coroutine.create(v)
	end

	return function(op, ...)
		if op == 'update' then
			for i = 1, #routines do
				if coroutine.status(routines[i]) == 'dead' then
					routines[i] = nil
				else
					local ok, err = coroutine.resume(routines[i], ...)
					if not ok then
						if error_catching_fn(err) == 'delete' then
							routines[i] = nil
						end
					end
				end
			end
		elseif op == 'insert' then
			for k, v in pairs(llispl.flatten(...)) do
				routines[#routines + 1] = coroutine.create(v)
			end
		elseif op == 'gc' then
			for i = 1, #routines do
				if coroutine.status(routines[i]) == 'dead' then
					routines[i] = nil
				end
			end
		elseif op == 'count' then
			return #routines
		elseif op == 'set-error-function' then
			error_catching_fn = ...
		end
	end
end

function llispl.yield()
	return coroutine.yield()
end

function llispl.luasym(w)
	local x = llispl.split(w, '.')
	local ret = _ENV[x[1]]

	if #x >= 2 then
		for i = 2, #x do
			if ret[x[i]] then
				ret = ret[x[i]]
			end
		end
	end

	return ret
end

local ret = {}

function ret.repl()
	while true do
	  io.write('-> ')
	  local ok, s = pcall(io.read)
		if not ok then
			print()
			os.exit(1)
		end

		if s then
			pcall(function()
				local result = llispl.stringify(interpret(parse(s), gctx))

			  io.write('return: ')
			  print(result)
			end)
		else
			print()
			os.exit(1)
		end
	end
end

ret.load, ret.loadf, ret.eval, ret.evalf, ret.context = llispl.load,
	llispl.loadf, llispl.eval, llispl.evalf, gctx

return ret
