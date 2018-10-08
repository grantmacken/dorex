local _M = {}
local http = require("resty.http").new()
local util = require("grantmacken.util")


--- Domain DNS Resolution
-- @usage  Given DOMAIN Resolve IP address
-- @return address
-- @return message
-- @parm   sContainerName The name of the docker container
local function getDomainAddress( sDomain )
  local resolver = require("resty.dns.resolver")
  local msg
  local r, err, answers
  r, err = resolver:new{nameservers = {'8.8.8.8'}}
  if not r then
    msg = '- failed to instantiate resolver:' .. err
    return util.requestError( ngx.HTTP_BAD_REQUEST,'bad request',msg )
  end
  -- ngx.log(ngx.INFO, ' - instantiated DNS resolver:')
  answers , err = r:tcp_query(sDomain, { qtype = r.TYPE_A })
  if not answers then
    msg = ' - FAILED to get answer from DNS query:' .. err
    return util.requestError( ngx.HTTP_BAD_REQUEST,'bad request',msg )
  end
  -- ngx.log(ngx.INFO, ' - query answered by DNS server')
  if answers.errcode then
    msg =  " - FAILED DNS server returned error code: " ..
    answers.errcode ..
    ": " ..
    answers.errstr
    return util.requestError( ngx.HTTP_BAD_REQUEST,'bad request',msg )
  end
  -- for i, ans in ipairs(answers) do
  --   ngx.log(ngx.INFO , 'NAME: ' .. ans.name )
  --   ngx.log(ngx.INFO , 'ADDRESS: ' .. ans.address )
  -- end
  if answers[1] == nil then
    msg = 'domain ip NOT address resolved'
    return util.requestError( ngx.HTTP_BAD_REQUEST,'bad request',msg )
   else
    msg = 'domain ip address resolved: ' .. answers[1].address
    return answers[1].address , msg
  end
end

--- Container DNS Resolution
-- @usage  Given container name Resolve IP address of container
-- @return address
-- @return message
-- @parm   sContainerName The name of the docker container
local function getAddress( sContainerName )
  local resolver = require("resty.dns.resolver")
  --- docker DNS resolver: 127.0.0.11
  local msg
  local r, err, answers
  r, err = resolver:new{nameservers = {'127.0.0.11'}}
  if not r then
    msg = '- failed to instantiate resolver:' .. err
    return util.requestError( ngx.HTTP_BAD_REQUEST,'bad request',msg )
  end
  -- ngx.log(ngx.INFO, ' - instantiated DNS resolver:')
  answers , err = r:tcp_query(sContainerName, { qtype = r.TYPE_A })
  if not answers then
    msg = ' - FAILED to get answer from DNS query:' .. err
    return util.requestError( ngx.HTTP_BAD_REQUEST,'bad request',msg )
  end
  -- ngx.log(ngx.INFO, ' - query answered by DNS server')
  if answers.errcode then
    msg =  " - FAILED DNS server returned error code: " ..
    answers.errcode ..
    ": " ..
    answers.errstr
    return util.requestError( ngx.HTTP_BAD_REQUEST,'bad request',msg )
  end
  -- for i, ans in ipairs(answers) do
  --   ngx.log(ngx.INFO , 'NAME: ' .. ans.name )
  --   ngx.log(ngx.INFO , 'ADDRESS: ' .. ans.address )
  -- end
  if answers[1] == nil then
    msg = 'container ip NOT address resolved'
    return util.requestError( ngx.HTTP_BAD_REQUEST,'bad request',msg )
   else
    msg = 'container ip address resolved: ' .. answers[1].address
    return answers[1].address , msg
  end
end

---  HTTP connection
local function connect( sAddress, iPort )
  local ok, err = http:connect( sAddress, iPort )
  if not ok then
    ngx.log(ngx.ERR, err)
    return util.requestError( ngx.HTTP_BAD_REQUEST,'bad request',err)
  end
  return 'connected to '  .. sAddress ..  ' on port '  .. iPort
end

---  SSL handshake
local function handshake( sHost )
   -- 4 sslhandshake opts
    local reusedSession = nil   -- defaults to nil
    local serverName = sHost    -- for SNI name resolution
    local sslVerify = false     -- boolean if true make sure the directives set
    -- for lua_ssl_trusted_certificate and lua_ssl_verify_depth
    local sendStatusReq = '' -- boolean OCSP status request
    -- SSL HANDSHAKE
    local shake, err = http:ssl_handshake( reusedSession, serverName, sslVerify)
    if not shake then
      ngx.log(ngx.ERR, 'FAILED to complete SSL handshake' .. err)
    return util.requestError( ngx.HTTP_BAD_REQUEST,'bad request',err)
    end
    return "SSL Handshake Completed: " .. type(shake)
end

local function reqObj( request )
  local sURL =  request['sURL']
  local sHost = http:parse_uri(sURL)[2]
  local iPort = http:parse_uri(sURL)[3]
  local sPath = http:parse_uri(sURL)[4]
  local sContainerName = request['sContainerName']
  local sAddress, sMsg = getAddress( sContainerName )
  local sConnect =       connect( sAddress, iPort )
  local sHandshake =     handshake( sHost )
  local tHeaders = {}
    -- tHeaders['version'] = 1.1
    tHeaders['Authorization'] =  'Bearer ' .. request['sToken']
    tHeaders['Host'] = sHost
    tHeaders['Content-Type'] = request['sContentType']
  local tRequest = {}
    tRequest['method'] = request['sMethod']
    tRequest['path'] = sPath
    tRequest['ssl_verify'] = false
    tRequest['headers'] = tHeaders
  if ( request['sMethod'] == "POST" or request['sMethod'] == "PUT" )  then
    tRequest['body'] = request['sData']
  end
  return tRequest
end

_M.http = http
_M.getAddress = getAddress
_M.getDomainAddress = getDomainAddress
_M.connect = connect
_M.handshake = handshake
_M.reqObj = reqObj

return _M
