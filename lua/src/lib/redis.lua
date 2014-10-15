local M = { }
M.connect = function(self)
  local redis = require("resty.redis")
  local red = redis:new()
  red:set_timeout(config.redis_timeout)
  local ok, err = red:connect(config.redis_host, config.redis_port)
  if not (ok) then
    library:log_err("Error connecting to redis: " .. err)
    self.msg = "error connectiong: " .. err
    self.status = 500
  else
    library.log("Connected to redis")
    if type(config.redis_password) == 'string' and #config.redis_password > 0 then
      library.log("Authenticated with redis")
      red:auth(config.redis_password)
    end
    return red
  end
end
M.finish = function(red)
  if config.redis_keepalive_pool_size == 0 then
    local ok, err = red:close()
  else
    local ok, err = red:set_keepalive(config.redis_keepalive_max_idle_timeout, config.redis_keepalive_pool_size)
    if not (ok) then
      library.log_err("failed to set keepalive: ", err)
      return 
    end
  end
end
M.test = function(self)
  local red = M.connect(self)
  local rand_value = tostring(math.random())
  local key = "healthcheck:" .. rand_value
  local ok, err = red:set(key, rand_value)
  if not (ok) then
    self.status = 500
    self.msg = "Failed to write to redis"
  end
  ok, err = red:get(key)
  if not (ok) then
    self.status = 500
    self.msg = "Failed to read redis"
  end
  if not (ok == rand_value) then
    self.status = 500
    self.msg = "Healthcheck failed to write and read from redis"
  end
  ok, err = red:del(key)
  if ok then
    self.status = 200
    self.msg = "OK"
  else
    self.status = 500
    self.msg = "Failed to delete key from redis"
  end
  return M.finish(red)
end
M.commit = function(self, red, error_msg)
  local results, err = red:commit_pipeline()
  if not results then
    library.log_err(error_msg .. err)
    self.msg = error_msg .. err
    self.status = 500
  else
    self.msg = "OK"
    self.status = 200
  end
end
M.flush = function(self)
  local red = M.connect(self)
  if red == nil then
    return nil
  end
  local ok, err = red:flushdb()
  if ok then
    self.status = 200
    self.msg = "OK"
  else
    self.status = 500
    self.msg = err
    library.log_err(err)
  end
  return M.finish(red)
end
M.get_config = function(self, asset_name, config)
  local red = M.connect(self)
  if red == nil then
    return nil
  end
  local config_value
  config_value, self.msg = red:zscore('backend:' .. asset_name, '_' .. config)
  if config_value == nil then
    self.resp = nil
  else
    self.resp = {
      [config] = config_value
    }
  end
  if self.resp then
    self.status = 200
    self.msg = "OK"
  end
  if self.resp == nil then
    self.status = 404
    self.msg = "Entry does not exist"
  else
    if not (self.status) then
      self.status = 500
    end
    if not (self.msg) then
      self.msg = 'Unknown failutre'
    end
    library.log(self.msg)
  end
  return M.finish(red)
end
M.set_config = function(self, asset_name, config, value)
  local red = M.connect(self)
  if red == nil then
    return nil
  end
  library.log(asset_name)
  library.log(config)
  library.log(value)
  local ok, err = red:zadd('backend:' .. asset_name, value, '_' .. config)
  library.log(ok)
  library.log(err)
  if ok >= 0 then
    self.status = 200
    self.msg = "OK"
  else
    self.status = 500
    if err == nil then
      err = "unknown"
    end
    self.msg = "Failed to save backend config: " .. err
    library.log_err(self.msg)
  end
  return M.finish(red)
end
M.get_data = function(self, asset_type, asset_name)
  local red = M.connect(self)
  if red == nil then
    return nil
  end
  local _exp_0 = asset_type
  if 'frontends' == _exp_0 then
    self.resp, self.msg = red:get('frontend:' .. asset_name)
    if not (self.resp) then
      self.status = 500
    end
    if getmetatable(self.resp) == nil then
      self.resp = nil
    end
  elseif 'backends' == _exp_0 then
    local rawdata
    rawdata, self.msg = red:zrangebyscore('backend:' .. asset_name, '-inf', '+inf', 'withscores')
    local data = { }
    self.resp = { }
    do
      local _tbl_0 = { }
      for i, item in ipairs(rawdata) do
        if i % 2 > 0 then
          _tbl_0[item] = rawdata[i + 1]
        end
      end
      data = _tbl_0
    end
    do
      local _accum_0 = { }
      local _len_0 = 1
      for k, v in pairs(data) do
        if k:sub(1, 1) ~= "_" then
          _accum_0[_len_0] = k
          _len_0 = _len_0 + 1
        end
      end
      self.resp = _accum_0
    end
    if type(self.resp) == 'table' and table.getn(self.resp) == 0 then
      self.resp = nil
    end
  else
    self.status = 400
    self.msg = 'Bad asset type. Must be "frontends" or "backends"'
  end
  if self.resp then
    self.status = 200
    self.msg = "OK"
  end
  if self.resp == nil then
    self.status = 404
    self.msg = "Entry does not exist"
  else
    if not (self.status) then
      self.status = 500
    end
    if not (self.msg) then
      self.msg = 'Unknown failutre'
    end
    library.log(self.msg)
  end
  return M.finish(red)
end
M.save_data = function(self, asset_type, asset_name, asset_value, score, overwrite)
  if overwrite == nil then
    overwrite = false
  end
  local red = M.connect(self)
  if red == nil then
    return nil
  end
  local _exp_0 = asset_type
  if 'frontends' == _exp_0 then
    local ok, err = red:set('frontend:' .. asset_name, asset_value)
  elseif 'backends' == _exp_0 then
    if config.default_score == nil then
      config.default_score = 0
    end
    if score == nil then
      score = config.default_score
    end
    red = M.connect(self)
    if overwrite then
      red:init_pipeline()
    end
    if overwrite then
      red:del('backend:' .. asset_name)
    end
    local ok, err = red:zadd('backend:' .. asset_name, score, asset_value)
    if overwrite then
      M.commit(self, red, "Failed to save backend: ")
    end
  else
    local ok = false
    self.status = 400
    self.msg = 'Bad asset type. Must be "frontends" or "backends"'
  end
  if ok == nil then
    self.status = 200
    self.msg = "OK"
  else
    self.status = 500
    local err
    if err == nil then
      err = "unknown"
    end
    self.msg = "Failed to save backend: " .. err
    library.log_err(self.msg)
  end
  return M.finish(red)
end
M.delete_data = function(self, asset_type, asset_name, asset_value)
  if asset_value == nil then
    asset_value = nil
  end
  local red = M.connect(self)
  if red == nil then
    return nil
  end
  local _exp_0 = asset_type
  if 'frontends' == _exp_0 then
    local resp
    resp, self.msg = red:del('frontend:' .. asset_name)
    if not (self.resp) then
      self.status = 500
    end
  elseif 'backends' == _exp_0 then
    if asset_value == nil then
      local resp
      resp, self.msg = red:del('backend:' .. asset_name)
    else
      local resp
      resp, self.msg = red:zrem('backend:' .. asset_name, asset_value)
    end
  else
    self.status = 400
    self.msg = 'Bad asset type. Must be "frontends" or "backends"'
  end
  if resp == nil then
    if type(self.resp) == 'table' and table.getn(self.resp) == 0 then
      self.resp = nil
    end
    self.status = 200
    if not (self.msg) then
      self.msg = "OK"
    end
  else
    if not (self.status) then
      self.status = 500
    end
    if not (self.msg) then
      self.msg = 'Unknown failutre'
    end
    library.log_err(self.msg)
  end
  return M.finish(red)
end
M.save_batch_data = function(self, data, overwrite)
  if overwrite == nil then
    overwrite = false
  end
  local red = M.connect(self)
  if red == nil then
    return nil
  end
  red:init_pipeline()
  if data['frontends'] then
    local _list_0 = data['frontends']
    for _index_0 = 1, #_list_0 do
      local frontend = _list_0[_index_0]
      if overwrite then
        red:del('frontend:' .. frontend['url'])
      end
      if not (frontend['backend_name'] == nil) then
        library.log('adding frontend: ' .. frontend['url'] .. ' ' .. frontend['backend_name'])
        red:set('frontend:' .. frontend['url'], frontend['backend_name'])
      end
    end
  end
  if data["backends"] then
    local _list_0 = data['backends']
    for _index_0 = 1, #_list_0 do
      local backend = _list_0[_index_0]
      if overwrite then
        red:del('backend:' .. backend["name"])
      end
      if not (type(backend['servers']) == 'table') then
        backend['servers'] = {
          backend['servers']
        }
      end
      local _list_1 = backend['servers']
      for _index_1 = 1, #_list_1 do
        local server = _list_1[_index_1]
        if not (server == nil) then
          library.log('adding backend: ' .. backend["name"] .. ' ' .. server)
          if config.default_score == nil then
            config.default_score = 0
          end
          red:zadd('backend:' .. backend["name"], config.default_score, server)
        end
      end
    end
  end
  M.commit(self, red, "failed to save data: ")
  return M.finish(red)
end
M.delete_batch_data = function(self, data)
  local red = M.connect(self)
  if red == nil then
    return nil
  end
  red:init_pipeline()
  if data['frontends'] then
    local _list_0 = data['frontends']
    for _index_0 = 1, #_list_0 do
      local frontend = _list_0[_index_0]
      library.log('deleting frontend: ' .. frontend['url'])
      red:del('frontend:' .. frontend['url'])
    end
  end
  if data["backends"] then
    local _list_0 = data['backends']
    for _index_0 = 1, #_list_0 do
      local backend = _list_0[_index_0]
      if backend['servers'] == nil then
        red:del('backend:' .. backend["name"])
      end
      if backend['servers'] then
        if not (type(backend['servers']) == 'table') then
          backend['servers'] = {
            backend['servers']
          }
        end
        local _list_1 = backend['servers']
        for _index_1 = 1, #_list_1 do
          local server = _list_1[_index_1]
          if not (server == nil) then
            library.log('deleting backend: ' .. backend["name"] .. ' ' .. server)
            red:zrem('backend:' .. backend["name"], server)
          end
        end
      end
    end
  end
  M.commit(self, red, "failed to save data: ")
  return M.finish(red)
end
M.fetch_frontend = function(self, max_path_length)
  if max_path_length == nil then
    max_path_length = 3
  end
  local path = self.req.parsed_url['path']
  local path_parts = library.split(path, '/')
  local keys = { }
  local p = ''
  local count = 0
  for k, v in pairs(path_parts) do
    if not (v == nil or v == '') then
      if count < (max_path_length) then
        count = count + 1
        p = p .. "/" .. tostring(v)
        table.insert(keys, 1, self.req.parsed_url['host'] .. p)
      end
    end
  end
  local red = M.connect(self)
  if red == nil then
    return nil
  end
  for _index_0 = 1, #keys do
    local key = keys[_index_0]
    local resp, err = red:get('frontend:' .. key)
    if type(resp) == 'string' then
      M.finish(red)
      return {
        frontend_key = key,
        backend_key = resp
      }
    end
  end
  M.finish(red)
  library.log_err("Frontend Cache miss")
  return nil
end
M.fetch_server = function(self, backend_key)
  if config.stickiness > 0 then
    backend_cookie = self.session.backend
  end
  upstream = nil
  local red = M.connect(self)
  if red == nil then
    return nil
  end
  if config.stickiness > 0 and backend_cookie ~= nil and backend_cookie ~= '' then
    local resp, err = red:zscore('backend:' .. backend_key, backend_cookie)
    if resp == nil then
      self.session.backend = nil
      upstream = nil
    else
      upstream = backend_cookie
    end
  end
  if upstream == nil then
    local rawdata, err = red:zrangebyscore('backend:' .. backend_key, '-inf', '+inf', 'withscores')
    local data = { }
    do
      local _tbl_0 = { }
      for i, item in ipairs(rawdata) do
        if i % 2 > 0 then
          _tbl_0[item] = rawdata[i + 1]
        end
      end
      data = _tbl_0
    end
    local upstreams = { }
    do
      local _accum_0 = { }
      local _len_0 = 1
      for k, v in pairs(data) do
        if k:sub(1, 1) ~= "_" then
          _accum_0[_len_0] = {
            backend = k,
            score = tonumber(v)
          }
          _len_0 = _len_0 + 1
        end
      end
      upstreams = _accum_0
    end
    local backend_config = { }
    do
      local _tbl_0 = { }
      for k, v in pairs(data) do
        if k:sub(1, 1) == "_" then
          _tbl_0[k] = v
        end
      end
      backend_config = _tbl_0
    end
    if #upstreams == 1 then
      library.log_err('Only one backend, choosing it')
      upstream = upstreams[1]['backend']
    else
      if config.balance_algorithm == 'least-score' or config.balance_algorithm == 'most-score' then
        if #upstreams == 2 then
          local max_score = tonumber(backend_config['_max_score'])
          if not (max_score == nil) then
            local available_score = 0
            for _index_0 = 1, #upstreams do
              local x = upstreams[_index_0]
              if config.balance_algorithm == 'least-score' then
                available_score = available_score + (max_score - x['score'])
              else
                available_score = available_score + x['score']
              end
            end
            local rand = math.random(1, available_score)
            if config.balance_algorithm == 'least-score' then
              if rand <= (max_score - upstreams[1]['score']) then
                upstream = upstreams[1]['backend']
              else
                upstream = upstreams[2]['backend']
              end
            else
              if rand <= (upstreams[1]['score']) then
                upstream = upstreams[1]['backend']
              else
                upstream = upstreams[2]['backend']
              end
            end
          end
        else
          local most_score = nil
          local least_score = nil
          for _index_0 = 1, #upstreams do
            local up = upstreams[_index_0]
            if most_score == nil or up['score'] > most_score then
              most_score = up['score']
            end
            if least_score == nil or up['score'] < least_score then
              least_score = up['score']
            end
          end
          if config.balance_algorithm == 'least-score' then
            do
              local _accum_0 = { }
              local _len_0 = 1
              for _index_0 = 1, #upstreams do
                local up = upstreams[_index_0]
                if up['score'] < most_score then
                  _accum_0[_len_0] = up
                  _len_0 = _len_0 + 1
                end
              end
              available_upstreams = _accum_0
            end
          else
            do
              local _accum_0 = { }
              local _len_0 = 1
              for _index_0 = 1, #upstreams do
                local up = upstreams[_index_0]
                if up['score'] > least_score then
                  _accum_0[_len_0] = up
                  _len_0 = _len_0 + 1
                end
              end
              available_upstreams = _accum_0
            end
          end
          if #available_upstreams > 0 then
            local available_score = 0
            local _list_0 = available_upstreams
            for _index_0 = 1, #_list_0 do
              local x = _list_0[_index_0]
              if config.balance_algorithm == 'least-score' then
                available_score = available_score + (most_score - x['score'])
              else
                available_score = available_score + x['score']
              end
            end
            local rand = math.random(available_score)
            local offset = 0
            local _list_1 = available_upstreams
            for _index_0 = 1, #_list_1 do
              local up = _list_1[_index_0]
              local value = 0
              if config.balance_algorithm == 'least-score' then
                value = (most_score - up['score'])
              else
                value = up['score']
              end
              if rand <= (value + offset) then
                upstream = up['backend']
                break
              end
              offset = offset + value
            end
          end
        end
        if upstream == nil and #upstreams > 0 then
          upstream = upstreams[math.random(#upstreams)]['backend']
        end
      else
        upstream = upstreams[math.random(#upstreams)]['backend']
      end
    end
  end
  M.finish(red)
  if type(upstream) == 'string' then
    if config.stickiness > 0 then
      self.session.backend = upstream
    end
    return upstream
  else
    library.log_err("Backend Cache miss: " .. backend_key)
    return nil
  end
end
M.orphans = function(self)
  local red = M.connect(self)
  if red == nil then
    return nil
  end
  local orphans = {
    frontends = { },
    backends = { }
  }
  local frontends, err = red:keys('frontend:*')
  local backends
  backends, err = red:keys('backend:*')
  local used_backends = { }
  for _index_0 = 1, #frontends do
    local frontend = frontends[_index_0]
    local backend_name
    backend_name, err = red:get(frontend)
    local frontend_url = library.split(frontend, 'frontend:')[2]
    if type(backend_name) == 'string' then
      local resp
      resp, err = red:exists('backend:' .. backend_name)
      if resp == 0 then
        table.insert(orphans['frontends'], {
          url = frontend_url
        })
      else
        table.insert(used_backends, backend_name)
      end
    else
      table.insert(orphans['frontends'], {
        url = frontend_url
      })
    end
  end
  used_backends = library.Set(used_backends)
  for _index_0 = 1, #backends do
    local backend = backends[_index_0]
    local backend_name = library.split(backend, 'backend:')[2]
    if not (used_backends[backend_name]) then
      table.insert(orphans['backends'], {
        name = backend_name
      })
    end
  end
  self.resp = orphans
  self.status = 200
  return orphans
end
return M
