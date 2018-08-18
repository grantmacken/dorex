local _M = {}

--- DNS Resolution
-- @usage  Given container name Resolve IP address of container
-- @return address
-- @return message
-- @parm   sContainerName The name of the docker container
function _M.getAddress( sContainerName )
  local resolver = require("resty.dns.resolver")
  --- docker DNS resolver: 127.0.0.11
  local r, err, answers
  r, err = resolver:new{nameservers = {'127.0.0.11'}}
  if not r then
    ngx.log(ngx.ERR, ' - failed to instantiate resolver:' .. err)
    return nil
  end
  -- ngx.log(ngx.INFO, ' - instantiated DNS resolver:')
  answers , err = r:tcp_query(sContainerName, { qtype = r.TYPE_A })
  if not answers then
    ngx.log(ngx.ERR, ' - FAILED to get answer from DNS query:' .. err)
    return nil
  end
  -- ngx.log(ngx.INFO, ' - query answered by DNS server')
  if answers.errcode then
    ngx.log(ngx.ERR,
    " - FAILED DNS server returned error code: " ..
    answers.errcode ..
    ": " ..
    answers.errstr)
    return nil
  end
  -- for i, ans in ipairs(answers) do
  --   ngx.log(ngx.INFO , 'NAME: ' .. ans.name )
  --   ngx.log(ngx.INFO , 'ADDRESS: ' .. ans.address )
  -- end
  local sAddress = answers[1].address
  local sMsg = 'container ip address resolved: ' .. sAddress
  return sAddress, sMsg
end

return _M
