local M = {}

M.redis_host = '127.0.0.1'
M.redis_port = '6379'

-- the max number of path parts to look up
-- examples 
-- 1 = host.com/contact
-- 2 = host.com/contact/us
-- 3 = host.com/contact/us/now
M.max_path_length = 1

return M
