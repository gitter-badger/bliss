#!/usr/bin/env lua

local function strtrim(str)
  return (str:gsub("^%s*(.-)%s*$", "%1"))
end

local function strsplit(str, sep)
  local sep, fields = sep or ":", {}
  local pattern = string.format("([^%s]+)", sep)
  str:gsub(pattern, function(c)
    fields[#fields+1] = c
  end)
  return fields
end

local function tokenize(inp)
  return strsplit(strtrim(inp:gsub('%(', ' ( ')
  :gsub('%)', ' ) ')), ' ')
end

local function arrconcat(one, two)
  table.insert(one, two)
  return one
end

local function categorize(inp)
  if inp and tonumber(inp) ~= nil then
    return {type = "literal", value = tonumber(inp)}
  elseif inp and inp:sub(1, 1) == '"' and inp:sub(#inp, #inp) == '"' then
    return {type = "literal", value = inp:sub(2, #inp - 1)}
  elseif inp and inp:lower() == "false" or inp:lower() == "true" then
    return {type = "literal", value = (inp:lower() == 'true')}
  elseif inp and inp:lower() == 'null' then
    return {type = "literal", value = nil}
  else
    return {type = "identifier", value = inp}
  end
end


local function paren(inp, ls)
  if ls == nil then
    return paren(inp, {})
  else
    local tok = table.remove(inp, 1)
    if tok == nil then
      return table.remove(ls)
    elseif tok == '(' then
      arrconcat(ls, paren(inp, {}))
      return paren(inp, ls)
    elseif tok == ')' then
      return ls
    else
      return paren(inp, arrconcat(ls, categorize(tok)))
    end
  end
end

local function parse(input)
  return paren(tokenize(input))
end

local function cont(scop, paren)
  return setmetatable({}, {
    ['__index'] = function(_, k)
      if scop then
        if rawget(scop, k) then
          return rawget(scop, k)
        elseif paren then
          return paren[k]
        end
      elseif k == 'add' then
        return function(k, v)
          _[k] = v
        end
      end
    end
  })
end


local function map(t, f)
  local ret = {}

  for k, v in pairs(t) do
    ret[k] = f(k, v)
  end

  return ret
end

local special = {
  lambda = function(list, con)
    return function(...)
      local args = {...}

      local scope = {}

      for i = 1, #list[1] do
        scope[list[1][i].value] = args[i]
      end

      return interpret(list[2], cont(scope, con))
    end
  end,
  defun = function(list, con)
    gctx[list[1].value] = function(...)
      local args = {...}

      local scope = {}

      for i = 1, #list[2] do
        scope[list[2][i].value] = args[i]
      end

      for i = 3, #list do
        interpret(list[i], cont(scope, con))
      end
      return interpret(list[#list], cont(scope, con))
    end
  end,

  ['+'] = function(list, con)
    local a, b = interpret(list[1], con), interpret(list[2], con)
    if a and b then
      return (interpret(list[1], con) + interpret(list[2], con))
    elseif not a and b then
      return "No (a) value."
    elseif a and not b then
      return "No (b) value."
    elseif not a and not b then
      return "No (a) and no (b) values."
    end
  end,
  ['-'] = function(list, con)
    local a, b = interpret(list[1], con), interpret(list[2], con)
    if a and b then
      return (interpret(list[1], con) - interpret(list[2], con))
    elseif not a and b then
      return "No (a) value."
    elseif a and not b then
      return "No (b) value."
    elseif not a and not b then
      return "No (a) and no (b) values."
    end
  end,
  ['*'] = function(list, con)
    local a, b = interpret(list[1], con), interpret(list[2], con)
    if a and b then
      return (interpret(list[1], con) * interpret(list[2], con))
    elseif not a and b then
      return "No (a) value."
    elseif a and not b then
      return "No (b) value."
    elseif not a and not b then
      return "No (a) and no (b) values."
    end
  end,
  ['/'] = function(list, con)
    local a, b = interpret(list[1], con), interpret(list[2], con)
    if a and b then
      return (interpret(list[1], con) / interpret(list[2], con))
    elseif not a and b then
      return "No (a) value."
    elseif a and not b then
      return "No (b) value."
    elseif not a and not b then
      return "No (a) and no (b) values."
    end
  end,
  ['%'] = function(list, con)
    local a, b = interpret(list[1], con), interpret(list[2], con)
    if a and b then
      return (interpret(list[1], con) % interpret(list[2], con))
    elseif not a and b then
      return "No (a) value."
    elseif a and not b then
      return "No (b) value."
    elseif not a and not b then
      return "No (a) and no (b) values."
    end
  end,
  ['pow'] = function(list, con)
    local a, b = interpret(list[1], con), interpret(list[2], con)
    if a and b then
      return (interpret(list[1], con) ^ interpret(list[2], con))
    elseif not a and b then
      return "No (a) value."
    elseif a and not b then
      return "No (b) value."
    elseif not a and not b then
      return "No (a) and no (b) values."
    end
  end,
  ['def'] = function(list, con)
    gctx[list[1].value] = interpret(list[2], con)
  end,
  ['=='] = function(list, con)
    return interpret(list[1], con) == interpret(list[2], con)
  end,
  ['!='] = function(list, con)
    return interpret(list[1], con) ~= interpret(list[2], con)
  end,
  ['>='] = function(list, con)
    return interpret(list[1], con) >= interpret(list[2], con)
  end,
  ['<='] = function(list, con)
    return interpret(list[1], con) <= interpret(list[2], con)
  end,
  ['>'] = function(list, con)
    return interpret(list[1], con) > interpret(list[2], con)
  end,
  ['<'] = function(list, con)
    return interpret(list[1], con) < interpret(list[2], con)
  end,
  ['pcall'] = function(list, con)
    local fun = interpret(list[1], con)
    if type(fun) ~= 'function' then
      return {false, 'Can not call element of type ' .. type(fun)}
    else
      return {pcall(fun, unpack(interpret(list[2], con)))}
    end
  end,
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
  ['!'] = function(list, con)
    return not interpret(list[1], con)
  end,
  ['repeat'] = function(list, con)
    while true do
      for i = 1, #list do
        interpret(list[i], con)
      end
    end
  end,
  ['str'] = function(list, con)
    local r = ''
    for i = 1, #list do
      r = r .. list[i].value .. ' '
    end

    return r
  end
}

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
      return list[1](unpack(list, 2))
    else
      return list
    end
  end
end

local llispl = setmetatable({}, {__index = _ENV})

_ENV.gctx = cont(llispl)

function _ENV.interpret(what, con)
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

function llispl.stringify(w)
  if type(w) == 'function' then
    return ('<Function (%s)>'):format((strsplit(tostring(w), ' '))[2])
  elseif type(w) == 'table' then
    local r = ('<List (%s) ['):format((strsplit(tostring(w), ' '))[2])
    for k, v in pairs(w) do
      r = r .. ("{%s = %s}"):format(llispl.stringify(k), llispl.stringify(v))
    end
    return r .. ']>'
  elseif type(w) == 'string' then
    return w
  else
    return tostring(w)
  end
end

function llispl.treeify(list, depth, ig)
  if type(depth) ~= 'number' then depth = 0 end

  local s = ("%sList (%s):\n"):format(((depth and depth ~= 0) and (" "):rep(depth) or ''), (strsplit(tostring(list), ' '))[2])
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

function llispl.tabl(...)
  return {...}
end

function llispl.prinl(s)
  print(s)
end

function llispl.exit(num)
  if package and package.cpath then
    if package.cpath:match("%p[\\|/]?%p(%a+)") == 'so' or package.cpath:match("%p[\\|/]?%p(%a+)") == 'dylib' then
      print(string.char(27) .. '[1;31mTerminated.' .. string.char(27) .. '[0m')
    else
      print('Terminated.')
    end
  else
    print('Terminated.')
  end
  os.exit(num)
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

function llispl.map(t, f)
  local rt = {}
  for k, v in pairs(t) do
    rt[k] = f(k, v)
  end
  return rt
end

function llispl.exec(p, a)
  if os.run then -- CC, I hate you.
    return os.run({}, p, unpack(a))
  elseif os.execute then
    return os.execute(p .. table.concat(a or {},  ' '))
  end
end

function llispl.lua (...)
  local s = 'return '
  for k, v in pairs({...}) do
    if type(v) == 'string' then
      s = s .. v
    end
  end

  return load(s)
end

function llispl.read()
  return io.read()
end

function llispl.eval(s)
  return interpret(parse(s), gctx)
end

llispl._env = llispl

local file = ...

if package and package.cpath then
  if package.cpath:match("%p[\\|/]?%p(%a+)") == 'so' or package.cpath:match("%p[\\|/]?%p(%a+)") == 'dylib' then
    wrt = function(x)
      return io.write(string.char(27) .. '[1;32m'.. x .. string.char(27) .. '[0m')
    end
  else
    wrt = io.write
  end
else
  wrt = io.write
end

local args = {...}
if args[1] == 'file' and args[2] then
  local f = io.open(args[2], 'r')
  gctx['arg'] = {unpack(args, 3)}
  interpret(parse (f:read("*all")), gctx)
  f:close()

  os.exit(0)
end

gctx['arg'] = args

while true do
  wrt('-> ')
  local ret = interpret(parse (io.read()), gctx)
  if ret then
    llispl.print(ret)
  else
    llispl.print '<no return value>'
  end
end
