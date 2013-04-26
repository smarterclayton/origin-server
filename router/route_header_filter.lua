local frontend = ngx.var.frontend
if #frontend == 0 then
    return
end

-- Record a hit against a frontend
local hits = ngx.shared.hits
if hits:get(frontend) == nil then
    hits:set(frontend, 0)
end
hits:incr(frontend, 1)

local code = ngx.status
-- Mark the backend as dead only for 5xx errors
if not (ngx.status >= 501 and ngx.status ~= 503) then
    return
end

-- Put the dead backends in a shared dict (we cannot call Redis from here)
local deads = ngx.shared.deads
local line = frontend .. ";" .. ngx.var.backend .. ";" .. ngx.var.backend_id .. ";" .. ngx.var.backends_len
deads:set(ngx.var.frontend .. ngx.var.backend_id, line)
