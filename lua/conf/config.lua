local M = { }
M.redis_host = 'redis'
M.redis_port = '6379'
M.redis_password = ''
M.redis_timeout = 5000
M.redis_keepalive_pool_size = 5
M.redis_keepalive_max_idle_timeout = 10000
M.max_path_length = 1
M.session_length = 900
M.plugins = {
  'random'
}
M.default_score = 0
return M
