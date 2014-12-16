local M = { }
M.connect = function()
  local redis = require("resty.redis")
  local red = redis:new()
  red:set_timeout(config.redis_timeout)
  local ok, err = red:connect(config.redis_host, config.redis_port)
  if not (ok) then
    return {
      connection_error = "Error connecting to redis: " .. err
    }
  else
    if type(config.redis_password) == 'string' and #config.redis_password > 0 then
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
      return library.log_err("Failed to set keepalive: ", err)
    end
  end
end
M.boolean_response = function(red, err)
  if err then
    return {
      status = 500,
      msg = err,
      redis = red
    }
  else
    return {
      status = 200,
      redis = red
    }
  end
end
M.test = function()
  local red = M.connect()
  if red['connection_error'] then
    return {
      status = 500,
      msg = red['connection_error']
    }
  end
  local rand_value = tostring(math.random())
  local key = "healthcheck:" .. rand_value
  local ok, err = red:set(key, rand_value)
  if not (ok) then
    return {
      status = 500,
      msg = "Failed to write to redis",
      redis = red
    }
  end
  ok, err = red:get(key)
  if not (ok) then
    return {
      status = 500,
      msg = "Failed to read redis",
      redis = red
    }
  end
  if not (ok == rand_value) then
    return {
      status = 500,
      msg = "Healthcheck failed to write and read from redis",
      redis = red
    }
  end
  ok, err = red:del(key)
  if ok then
    return {
      status = 200,
      redis = red
    }
  else
    return {
      status = 500,
      msg = "Failed to delete key from redis",
      redis = red
    }
  end
end
M.commit = function(red, error_msg, data)
  if data == nil then
    data = nil
  end
  local results, err = red:commit_pipeline()
  if err then
    return {
      status = 500,
      msg = error_msg .. err,
      redis = red
    }
  else
    return {
      status = 200,
      redis = red
    }
  end
end
M.flush = function()
  local red = M.connect()
  if red['connection_error'] then
    return {
      status = 500,
      msg = red['connection_error']
    }
  end
  local ok, err = red:flushdb()
  return M.boolean_response(red, err)
end
M.get_config = function(asset_name, config)
  local red = M.connect()
  if red['connection_error'] then
    return {
      status = 500,
      msg = red['connection_error']
    }
  end
  local config_value, err = red:hget('backend:' .. asset_name, '_' .. config)
  if type(config_value) ~= 'string' then
    return {
      status = 404,
      redis = red
    }
  elseif err then
    return {
      status = 500,
      msg = err
    }
  else
    return {
      status = 200,
      data = config_value,
      redis = red
    }
  end
end
M.delete_config = function(asset_name, config)
  local red = M.connect()
  if red['connection_error'] then
    return {
      status = 500,
      msg = red['connection_error']
    }
  end
  local ok, err = red:hdel('backend:' .. asset_name, '_' .. config)
  return M.boolean_response(red, err)
end
M.set_config = function(asset_name, config, value)
  local red = M.connect()
  if red['connection_error'] then
    return {
      status = 500,
      msg = red['connection_error']
    }
  end
  local ok, err = red:hset('backend:' .. asset_name, '_' .. config, value)
  if ok >= 0 then
    return {
      status = 200,
      redis = red
    }
  else
    return {
      status = 500,
      msg = "Failed to save backend config: " .. err,
      redis = red
    }
  end
end
M.get_data = function(asset_type, asset_name)
  local red = M.connect()
  if red['connection_error'] then
    return {
      status = 500,
      msg = red['connection_error']
    }
  end
  local data = { }
  local _exp_0 = asset_type
  if 'frontends' == _exp_0 then
    if asset_name == nil then
      local keys, err = red:keys('frontend:*')
      if err then
        return {
          status = 500,
          msg = err,
          redis = red
        }
      else
        for _index_0 = 1, #keys do
          local key = keys[_index_0]
          local url = library.split(key, ':')
          url = url[#url]
          local backend_name = red:get(key)
          table.insert(data, 1, {
            url = url,
            backend_name = backend_name
          })
        end
        return {
          status = 200,
          data = data,
          redis = red
        }
      end
    else
      local err
      data, err = red:get('frontend:' .. asset_name)
      if err then
        return {
          status = 500,
          msg = err,
          redis = red
        }
      else
        if getmetatable(data) == nil then
          return {
            status = 404,
            redis = red
          }
        else
          return {
            status = 200,
            data = data,
            redis = red
          }
        end
      end
    end
  elseif 'backends' == _exp_0 then
    if asset_name == nil then
      local keys, err = red:keys('backend:*')
      if err then
        return {
          status = 500,
          msg = err,
          redis = red
        }
      else
        for _index_0 = 1, #keys do
          local key = keys[_index_0]
          local name = library.split(key, ':')
          name = name[#name]
          local rawdata = red:hgetall(key)
          local servers
          do
            local _accum_0 = { }
            local _len_0 = 1
            for i, item in ipairs(rawdata) do
              if i % 2 > 0 and item:sub(1, 1) ~= '_' then
                _accum_0[_len_0] = item
                _len_0 = _len_0 + 1
              end
            end
            servers = _accum_0
          end
          local configs
          do
            local _tbl_0 = { }
            for i, item in ipairs(rawdata) do
              if i % 2 > 0 and item:sub(1, 1) == '_' then
                _tbl_0[string.sub(item, 2, -1)] = rawdata[i + 1]
              end
            end
            configs = _tbl_0
          end
          table.insert(data, 1, {
            name = name,
            servers = servers,
            config = configs
          })
        end
        return {
          status = 200,
          data = data,
          redis = red
        }
      end
    else
      local rawdata, err = red:hgetall('backend:' .. asset_name)
      if err then
        return {
          status = 500,
          msg = err,
          redis = red
        }
      else
        local servers
        do
          local _accum_0 = { }
          local _len_0 = 1
          for i, item in ipairs(rawdata) do
            if i % 2 > 0 and item:sub(1, 1) ~= '_' then
              _accum_0[_len_0] = item
              _len_0 = _len_0 + 1
            end
          end
          servers = _accum_0
        end
        local configs
        do
          local _tbl_0 = { }
          for i, item in ipairs(rawdata) do
            if i % 2 > 0 and item:sub(1, 1) == '_' then
              _tbl_0[string.sub(item, 2, -1)] = rawdata[i + 1]
            end
          end
          configs = _tbl_0
        end
        if #rawdata == 0 then
          return {
            status = 404,
            redis = red
          }
        else
          return {
            status = 200,
            data = {
              servers = servers,
              config = configs
            },
            redis = red
          }
        end
      end
    end
  else
    return {
      status = 400,
      msg = 'Bad asset type. Must be "frontends" or "backends"',
      redis = red
    }
  end
end
M.save_data = function(asset_type, asset_name, asset_value, score, overwrite)
  if overwrite == nil then
    overwrite = false
  end
  local red = M.connect()
  if red['connection_error'] then
    return {
      status = 500,
      msg = red['connection_error']
    }
  end
  local _exp_0 = asset_type
  if 'frontends' == _exp_0 then
    local ok, err = red:set('frontend:' .. asset_name, asset_value)
    return M.boolean_response(red, err)
  elseif 'backends' == _exp_0 then
    if config.default_score == nil then
      config.default_score = 0
    end
    if score == nil then
      score = config.default_score
    end
    if overwrite then
      red:init_pipeline()
    end
    if overwrite then
      red:del('backend:' .. asset_name)
    end
    local ok, err = red:hset('backend:' .. asset_name, asset_value, score)
    if overwrite then
      return M.commit(red, "Failed to save backend: ")
    end
    return M.boolean_response(red, err)
  else
    return {
      status = 400,
      msg = 'Bad asset type. Must be "frontends" or "backends"',
      redis = red
    }
  end
end
M.delete_data = function(asset_type, asset_name, asset_value)
  if asset_value == nil then
    asset_value = nil
  end
  local red = M.connect()
  if red['connection_error'] then
    return {
      status = 500,
      msg = red['connection_error']
    }
  end
  local _exp_0 = asset_type
  if 'frontends' == _exp_0 then
    local resp, err = red:del('frontend:' .. asset_name)
    return M.boolean_response(red, err)
  elseif 'backends' == _exp_0 then
    if asset_value == nil then
      local resp, err = red:del('backend:' .. asset_name)
    else
      local resp, err = red:hdel('backend:' .. asset_name, asset_value)
    end
    return M.boolean_response(red, err)
  else
    return {
      status = 400,
      msg = 'Bad asset type. Must be "frontends" or "backends"',
      redis = red
    }
  end
end
M.save_batch_data = function(data, overwrite)
  if overwrite == nil then
    overwrite = false
  end
  local red = M.connect()
  if red['connection_error'] then
    return {
      status = 500,
      msg = red['connection_error']
    }
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
            if type(server) == 'string' then
              if config.default_score == nil then
                config.default_score = 0
              end
              red:hset('backend:' .. backend["name"], server, config.default_score)
            else
              red:hset('backend:' .. backend["name"], server[1], server[2])
            end
          end
        end
      end
      if backend['config'] then
        for k, v in pairs(backend['config']) do
          red:hset('backend:' .. backend["name"], "_" .. k, v)
        end
      end
    end
  end
  return M.commit(red, "Failed to batch save data: ")
end
M.delete_batch_data = function(data)
  local red = M.connect()
  if red['connection_error'] then
    return {
      status = 500,
      msg = red['connection_error']
    }
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
      if backend['servers'] == nil and backend['config'] == nil then
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
            red:hdel('backend:' .. backend["name"], server)
          end
        end
      end
      if backend['config'] then
        for k, v in ipairs(backend['config']) do
          library.log('deleting backend config: ' .. backend["name"] .. ' ' .. k)
          red:hdel('backend:' .. backend["name"], k)
        end
      end
    end
  end
  return M.commit(red, "Failed to batch delete data: ")
end
M.fetch_frontend = function(self, max_path_length)
  if max_path_length == nil then
    max_path_length = 3
  end
  local path = self.req.parsed_url['path']
  local host = self.req.parsed_url['host']
  local keys, frontends = {
    'frontend:' .. host
  }, {
    host
  }
  local p, count = '', 0
  for k, v in pairs(library.split(path, '/')) do
    if not (v == nil or v == '') then
      if count < (max_path_length) then
        count = count + 1
        p = p .. "/" .. tostring(v)
        table.insert(keys, 1, 'frontend:' .. host .. p)
        table.insert(frontends, 1, host .. p)
      end
    end
  end
  local red = M.connect()
  if red['connection_error'] then
    return nil
  end
  local resp, err = red:mget(unpack(keys))
  M.finish(red)
  if err then
    return nil
  end
  for i, item in pairs(resp) do
    if type(item) == 'string' then
      return {
        frontend = frontends[i],
        backend = tostring(item)
      }
    end
  end
  library.log_err("Frontend Cache miss")
  return nil
end
M.fetch_backend = function(backend)
  local red = M.connect()
  if red['connection_error'] then
    return {
      nil,
      nil
    }
  end
  local rawdata, err = red:hgetall('backend:' .. backend)
  M.finish(red)
  if err then
    return {
      status = 500,
      msg = err
    }
  end
  local servers, configs = { }, { }
  for i, item in ipairs(rawdata) do
    if i % 2 > 0 then
      if item:sub(1, 1) == '_' then
        local config_name = string.sub(item, 2, -1)
        configs[config_name] = rawdata[i + 1]
      else
        table.insert(servers, {
          address = item,
          score = tonumber(rawdata[i + 1])
        })
      end
    end
  end
  return {
    servers,
    configs
  }
end
M.orphans = function()
  local red = M.connect()
  if red['connection_error'] then
    return {
      status = 500,
      msg = red['connection_error']
    }
  end
  local orphans = {
    frontends = { },
    backends = { }
  }
  local frontends, err = red:keys('frontend:*')
  if err then
    return {
      status = 500,
      msg = err,
      redis = red
    }
  end
  local backends
  backends, err = red:keys('backend:*')
  if err then
    return {
      status = 500,
      msg = err,
      redis = red
    }
  end
  local rawdata
  rawdata, err = red:mget(unpack(frontends))
  if err then
    return {
      status = 500,
      msg = err,
      redis = red
    }
  end
  local used_backends = { }
  for i, backend_name in pairs(rawdata) do
    local frontend_url = library.split(frontends[i], 'frontend:')[2]
    if type(backend_name) == 'string' then
      local match = false
      for _index_0 = 1, #backends do
        local backend = backends[_index_0]
        if backend == 'backend:' .. backend_name then
          table.insert(used_backends, backend_name)
          match = true
          break
        end
      end
      if not (match) then
        table.insert(orphans['frontends'], {
          url = frontend_url
        })
      end
    else
      table.insert(orphans['frontends'], {
        url = frontend_url
      })
    end
  end
  used_backends = library.set(used_backends)
  for _index_0 = 1, #backends do
    local backend = backends[_index_0]
    local backend_name = library.split(backend, 'backend:')[2]
    if not (used_backends[backend_name]) then
      table.insert(orphans['backends'], {
        name = backend_name
      })
    end
  end
  return {
    status = 200,
    data = orphans,
    redis = red
  }
end
return M
