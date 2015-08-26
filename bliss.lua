#!/usr/bin/env lua

function tokenize (exp)
  local sexpr, word, in_str = {{}}, '', false

  for i = 1, #exp do
    local c = exp:sub(i, i)

    if c == '(' and not in_str then
      table.insert(sexpr, {})
    elseif c == ')' and not in_str then
      if #word > 0 then
        table.insert(sexpr[#sexpr], word)
        word = ''
      end

      local t = table.remove(sexpr)
      table.insert(sexpr[#sexpr], t)
    elseif c == ' ' or c == '\t' or c == '\n' and not in_str then
      if #word > 0 then
        table.insert(sexpr[#sexpr], word)
        word = ''
      end
    elseif c == '"' then
      word = word .. '"'
      in_str = not in_str
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
    local acc = interpret(l[1], c)

    for i = 2, #l do
      acc = acc - interpret(l[i], c)
    end

    return acc
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
  ['def'] = function(list, con) con[list[1].value] = interpret(list[2], con) end,
  ['if'] = function(list, con)
    if interpret(list[1], con) == true or type(interpret(list[1], con)) == 'table' then
      return interpret(list[2], con)
    else
      if list[3] then
        return interpret(list[3])
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

      return interpret(list[2], context(scope, con))
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
  end
}


---

function context(scope, parent)
  return setmetatable({}, {
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
    local max = (function(x)
      local r = 0; for k, v in pairs(x) do r = r + 1 end; return r
    end)({...})
    for k, v in pairs({...}) do
      if type(v) == 'string' then
        ret = ret .. '"' .. v .. '"' .. (k == max and '' or ' ')
      elseif type(v) == 'table' then
        ret = ret .. llispl.stringify(unpack(v)) .. (k == max and '' or ' ')
      elseif type(v) == 'function' then
        ret = ret .. '\'<function>' .. (k == max and '' or ' ')
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
  for k, v in pairs({...}) do
    io.write(llispl.stringify(v) .. ' ')
  end
  print('')
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

llispl['map!'] = function(fn, tab)
  for i = 1, #tab do
    tab[i] = fn(tab[i])
  end

  return tab
end
while true do
  io.write('-> ')
  local s = io.read()
  io.write('return: ')
  print(llispl.stringify(interpret(parse(s), gctx)))
end
