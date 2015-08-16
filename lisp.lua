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
      if rawget(scop, k) then
        return rawget(scop, k)
      elseif paren then
        return paren[k]
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
      local scope = (function (a)
        local x = {}

        for i = 1, #a[1] do
          x[a[i].value] = args[i]
        end
        return x
      end)(list)


      return interpret(list[2], cont(scop, con))
    end
  end
}

local function interpretList(ls, con)
  if #ls > 0 and special[ls[1].value] then
    return special[ls[1].value](ls, con)
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

local llispl = setmetatable({}, {__index = _G})


function _G.interpret(what, con)
  if con == nil then
    return interpret(what, cont(llispl))
  elseif type(what) == 'table' and not what.type then
    return interpretList(what, con)
  elseif what.type and what.type == "identifier" then
    return con[what.value]
  else
    return what.value
  end
end

function llispl.write(...)
  for k, v in pairs({...}) do
    if type(v) == 'function' then
      io.write('<Function>')
    else
      io.write(tostring(v))
    end
    io.write(' ')
  end
end

function llispl.print(...)
  for k, v in pairs({...}) do
    if type(v) == 'table' then
      llispl.write(unpack(v))
    elseif type(v) == 'function' then
      io.write('<Function>')
    else
      io.write(tostring(v))
    end

    io.write(' ')
  end
  print('')
end

function llispl.tabl(...)
  return {...}
end

function llispl.exit(num)
  if package.cpath:match("%p[\\|/]?%p(%a+)") == 'so' or package.cpath:match("%p[\\|/]?%p(%a+)") == 'dylib' then
    print(string.char(27) .. '[1;31mTerminated.' .. string.char(27) .. '[0m')
  else
    print('Terminated.')
  end
  os.exit(num)
end

while true do
  io.write('-> ')
  local ret = interpret(parse (io.read()))
  if ret then
    print(ret)
  else
    print '<no return value>'
  end
end
