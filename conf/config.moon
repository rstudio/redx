M = {}

-- redis host
M.redis_host = '127.0.0.1'
-- redis port
M.redis_port = '6379'
-- redis password
M.redis_password = ''

-- redis timeout
-- number of milliseconds for redis timeout
M.redis_timeout = 5000

-- keepalive
-- When == 0, don't use keepalive, and close the connection
-- When > 0, is the number of keepalive connection to maintain per nginx worker
M.redis_keepalive_pool_size = 0
-- max idle timeout for keepalive connection, in milliseconds
M.redis_keepalive_max_idle_timeout = 10000

-- the max number of path parts to look up
-- examples
-- 1 = host.com/contact
-- 2 = host.com/contact/us
-- 3 = host.com/contact/us/now
M.max_path_length = 1

return M
