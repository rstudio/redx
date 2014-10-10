local M = { }
M.redis_host = '127.0.0.1'
M.redis_port = '6379'
M.redis_password = ''
M.redis_timeout = 5000
M.redis_keepalive_pool_size = 0
M.redis_keepalive_max_idle_timeout = 10000
M.max_path_length = 1
M.stickiness = 0
M.balance_algorithm = 'least-connections'
return M
