local url = require('socket.url')
local base64 = require('base64')
local M = { }
M.get_cookie = function(request, settings)
  local cookie = request.cookies[settings.COOKIE]
  if cookie ~= nil then
    return base64.decode(cookie)
  else
    return nil
  end
end
M.set_cookie = function(request, server, frontend, settings)
  local name = settings.COOKIE
  local value = base64.encode(server)
  local path = M.extract_path(frontend)
  local cookie = tostring(url.escape(value)) .. "; Path=" .. tostring(path) .. "; HttpOnly"
  ngx.log(ngx.DEBUG, "Setting sticky server: " .. tostring(server) .. " (Path=" .. tostring(path) .. ")")
  request.cookies[settings.COOKIE] = cookie
end
M.clear_cookie = function(request, settings)
  request.cookies[settings.COOKIE] = nil
end
M.balance = function(request, session, settings)
  local sticky_server = M.get_cookie(request, settings)
  if sticky_server ~= nil then
    local _list_0 = session.servers
    for _index_0 = 1, #_list_0 do
      local server = _list_0[_index_0]
      if sticky_server == M.extract_domain(server.address) then
        return server
      end
    end
    ngx.log(ngx.WARN, "Server not found matching address: " .. tostring(sticky_server))
    M.clear_cookie(request, settings)
  end
  return session['servers']
end
M.post = function(request, session, settings)
  local sticky_server = M.get_cookie(request, settings)
  if session.server ~= nil then
    local current_server = M.extract_domain(session.server)
    if sticky_server ~= current_server then
      return M.set_cookie(request, current_server, session.frontend, settings)
    end
  end
end
M.extract_domain = function(url)
  if not string.match(url, '/') then
    return url
  else
    local location_index = string.find(url, '/')
    local domain = string.sub(url, 1, (location_index - 1))
    return domain
  end
end
M.extract_path = function(url)
  local i = string.find(url, '/')
  if i ~= nil then
    return string.sub(url, i)
  else
    return '/'
  end
end
return M
