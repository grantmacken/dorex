local _M = {}

_M.version = '0.0.1'

--[[
 TESTS
 docker exec or prove -v t/proxy/lualib/access.t
delegation of endpoints for authentication

#
 - [authorization-endpoint]( https://indieweb.org/authorization-endpoint )
   identify user OR obtain athorization code
 use an existing authorization service such as indieauth.com

# VERIFICATION
 [token-endpoint] (https://indieweb.org/token-endpoint)

  1. grant an access token
  2. verify an access token

 Micropub endpoint interested in -- 2

  Requests with tokens
  so we need to verify token validity

 is token valid?

  make a request to the token endpoint to verify that an incoming access token is valid
 server - `verifyAccessToken`
 https://tokens.indieauth.com/

  returns
  Content-Type: application/x-www-form-urlencoded

  inspect these values and determine whether to proceed with the request
  `
 1. client creates post and send to micropub endpoint
 2. sent token will be in the Authorization header or in the post args

 - extractToken
 - verifyToken


lua modules used

@see https://github.com/pintsized/lua-resty-http
@see http://doc.lubyk.org/xml.html

 https://github.com/openresty/lua-nginx-module#tcpsocksslhandshake
 https://github.com/openresty/lua-nginx-module#ssl_certificate_by_lua_block
 https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/ssl.md#readme
 https://github.com/openresty/lua-resty-core/blob/master/lib/ngx/ocsp.md#readme
 http://lua-users.org/lists/lua-l/2016-01/msg00129.html
 https://github.com/aptise/peter_sslers

@see  https://indieweb.org/token-endpoint
@see  https://www.w3.org/TR/micropub/

 - MUST support both header and form parameter methods of authentication
 - MUST support creating posts with the [h-entry] vocabulary

3.8 Error Response
https://www.w3.org/TR/micropub/#error-response
--]]

local cjson = require("cjson")
local httpc = require("resty.http").new()
local jwt = require("resty.jwt")

local function contains(tab, val)
  for index, value in ipairs (tab) do
    if value == val then
      return true
    end
  end
  return false
end


local function requestError( status, msg ,description)
  ngx.status = status
  ngx.header.content_type = 'application/json'
  local json = cjson.encode({
      error  = msg,
      error_description = description
    })
  ngx.log(ngx.WARN, ' - ' .. msg .. ' [ ' .. description  .. ' ]' )
  ngx.print(json)
  ngx.exit(status)
end

local function extractDomain( url )
  local sDomain, err = require("ngx.re").split(url, "([/]{1,2})")[3]
  if err then
    return requestError(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'connection failure')
  end
  return sDomain
end

local function extractToken()
   ngx.log(ngx.INFO, "Extract Token")
  --TODO! token in post args
  --access_token - the OAuth Bearer token authenticating the request
  --(the access token may be sent in an HTTP Authorization header or
  --this form parameter)
  -- ngx.log(ngx.INFO, ngx.var.http_authorization )
  local token
  if ngx.var.http_authorization == nil then
    ngx.req.read_body()
    token = ngx.req.get_post_args()['access_token']
    if token  ~=  nil then
      return token
    else
      return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', 'read body but no token')
    end
  else
    token, err = require("ngx.re").split(ngx.var.http_authorization,' ')[2]
    if err then
      return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', 'no token')
    end
     -- ngx.log(ngx.INFO, token)
     return token
   -- ngx.log(ngx.INFO, ngx.var.http_authorization)
  end
end

--[[
-- verifyToken
--  Main Entry Point
--
--]]--

local function isTokenValid( jwtObj )
  ngx.log(ngx.INFO, "Check The Tokens Validity")
  if not jwtObj.valid then
    return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'not a jwt token')
  end
  --ngx.log(ngx.INFO, 'YEP! looks like a JWT token ')
  local me = jwtObj.payload.me
  if me == nil then
    return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'missing me')
  end

  local clientID = jwtObj.payload.client_id
  if clientID == nil then
    return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'missing client id')
  end
  -- ngx.log(ngx.INFO, 'YEP! has a client id  [ ' .. clientID  .. ' ] ')

  local scope = jwtObj.payload.scope
  if scope == nil then
    return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'missing scope')
  end
  ngx.log(ngx.INFO, 'YEP! has a scope [ ' .. scope  .. ' ] ')

  local issuedAt = jwtObj.payload.issued_at
  if  issuedAt == nil then
    return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'missing issued_at')
  end
  -- ngx.log(ngx.INFO, 'YEP! has a issued at date [ ' .. issuedAt  .. ' ] ')

  local issuedBy = jwtObj.payload.issued_by
  if  issuedBy == nil then
    return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'missing issued by')
  end
  -- ngx.log(ngx.INFO, 'YEP! has a issued by domain [ ' .. issuedBy  .. ' ] ')
  -- ngx.log(ngx.INFO, 'Token Me Domain!:  [ ' .. extractDomain( me ) .. ' ] ')
  -- ngx.log(ngx.INFO, 'Request Doamain:  [ ' .. ngx.var.domain  .. ' ] ')
  if ( ngx.var.domain ~=  extractDomain( me ) )  then
    return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'you are not me')
  end
  --ngx.log(ngx.INFO, 'YEP! I am the one who authorized the use of this token')
  --ngx.log(ngx.INFO, 'Check! I have the appropiate CREATE UPDATE scope')
  -- local tScope, err = require("ngx.re").split(scope,' ')
  -- if err then
  --   return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', 'insufficient_scope')
  -- end

  -- if contains(tScope,'create' ) then
  --   return  requestError(
  --     ngx.HTTP_UNAUTHORIZED,
  --     'insufficient_scope',
  --     ' do not have the appropiate CREATE scope')
  -- end
  --  ngx.log(ngx.INFO, 'YEP! I have the appropiate scope: ' .. scope )

  -- I have the appropiate post scope
  -- TODO! scope is a list
  --  ngx.say(clientID)

  -- I accept posts only from the following clients
  -- TODO!
  --
  -- I accept tokens no older than
  -- -- TODO!
  return true
end

--local function indieLoginVerifyAuthorizationCode( )
--  -- user redirected back to my site
--  ngx.log(ngx.INFO, " - verify the authorization code with IndieLogin.com ")
--  local reqargs = require("resty.reqargs")
--  local req = require("grantmacken.req")
--  local get, post, files = reqargs()
--  if not get then
--    local msg = " failed to get response args"
--    return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg )
--  end
--  -- two parameters in the query string, state and code
--  if ( type(get['scope']) ~= 'string' ) or ( type(get['code']) ~= 'string' ) then
--    local msg = " failed to get scope or code params"
--    return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg )
--  end
--  local sURL =  'https://indielogin.com/auth'
--  local sHost = http:parse_uri(sURL)[2]
--  local iPort = http:parse_uri(sURL)[3]
--  local sPath = http:parse_uri(sURL)[4]
--  local sAddress, sMsg = req.getDomainAddress( sHost )
--  local sConnect =       req.connect( sAddress, iPort )
--  local sHandshake =     req.handshake( sHost )
--  local tHeaders = {}
--    tHeaders['Host'] = sHost
--    tHeaders['Content-Type'] = 'application/x-www-form-urlencoded'
--    tHeaders['Accept'] = 'application/json'
--  local tRequest = {}
--    tRequest['version'] = 1.1
--    tRequest['method'] = 'POST'
--    tRequest['path'] = sPath
--    tHeaders['query'] = {
--      ['code'] = get['state'],
--      ['redirect_uri'] = 'https://' .. ngx.var.domain .. '/_login',
--      ['client_id'] = ngx.var.domain
--    }
--    tRequest['ssl_verify'] = false
--    tRequest['headers'] = tHeaders
--  local response, err = http:request( tRequest )
--  if not response then
--     msg = "failed to complete request: ", err
--     return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg )
--  end
--  ngx.log(ngx.INFO, " indielogin request response status: " .. response.status)
--  ngx.log(ngx.INFO, " indielogin request response eason: " .. response.reason)

--   if response.has_body then
--     body, err = response:read_body()
--     if not body then
--       msg = "failed to read body: " ..  err
--       return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg )
--     end
--     --ngx.log(ngx.INFO, " - response body received and read ")
--     local args = cjson.decode(body)
--     if not args then
--       msg = "failed to decode json " ..  err
--       return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg )
--     end
--     ngx.log(ngx.INFO, " - verify body decoded ")
--     local myDomain = extractDomain( args['me'] )
--     -- local clientDomain = extractDomain( args['client_id'] )
--     --ngx.log(ngx.INFO, "Am I the one who authorized the use of this token?")
--     if ngx.var.domain  ~=  myDomain  then
--       return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'you are not me')
--     end
--     ngx.log(ngx.INFO, 'Yep! ' .. ngx.var.domain .. ' same domain as '  .. myDomain   )
--   else
--     msg = " - failed response has no body "
--     return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg )
--   end
--end

local function verifyAtTokenEndpoint( )
  ngx.log(ngx.INFO, " Verify At Token Endpoint ")
  --ngx.log(ngx.INFO, "==========================")
  local scheme, host, port, path = unpack(httpc:parse_uri('https://tokens.indieauth.com'))
  httpc:set_timeout(6000) -- one min timeout
  local ok, err = httpc:connect(host, port)
  if not ok then
    local msg = "FAILED to connect to " .. host .. " on port "  .. port .. ' - ERR: ' ..  err
    return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg )
  end
  --ngx.log(ngx.INFO, ' - connected to '  .. host ..  ' on port '  .. port)
   -- 4 sslhandshake opts
   local reusedSession = nil -- defaults to nil
   local serverName = host    -- for SNI name resolution
   local sslVerify = false  -- boolean if true make sure the directives set
   -- for lua_ssl_trusted_certificate and lua_ssl_verify_depth
   local sendStatusReq = '' -- boolean OCSP status request

   local shake, err = httpc:ssl_handshake( reusedSession, serverName, sslVerify)
   if not shake then
     msg = "failed to do SSL handshake: ", err
     return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg )
   end
    --ngx.log(ngx.INFO, " - SSL Handshake Completed: "  .. type(shake) )
    -- --ngx.log(ngx.INFO, " - ngx.var.http_authorization : "  .. ngx.var.http_authorization )
   --ngx.var.http_authorization

   httpc:set_timeout(6000)
   local response, err = httpc:request({
       version = 1.1,
       method = "GET",
       path = "/token",
       headers = {
         ["Authorization"] =  ngx.var.http_authorization
       },
       ssl_verify = sslVerify
     })

   if not response then
     msg = "failed to complete request: ", err
     return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg )
   end

   -- --ngx.log(ngx.INFO, "Request Response Status: " .. response.status)
   -- --ngx.log(ngx.INFO, "Request Response Reason: " .. response.reason)

   if response.has_body then
     body, err = response:read_body()
     if not body then
       msg = "failed to read post args: " ..  err
       return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg )
     end
     --ngx.log(ngx.INFO, " - response body received and read ")
     local args = ngx.decode_args(body, 0)
     if not args then
       msg = "failed to decode post args: " ..  err
       return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg )
     end
     --ngx.log(ngx.INFO, " - verify body decoded ")
     local myDomain = extractDomain( args['me'] )
     -- local clientDomain = extractDomain( args['client_id'] )
     --ngx.log(ngx.INFO, "Am I the one who authorized the use of this token?")
     if ngx.var.domain  ~=  myDomain  then
       return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'you are not me')
     end
     --ngx.log(ngx.INFO, 'Yep! ' .. ngx.var.domain .. ' same domain as '  .. myDomain   )
     --ngx.log(ngx.INFO, "Do I have the appropiate CREATE UPDATE scope? ")
     if args['scope'] ~= 'create update'  then
       return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', ' do not have the appropiate post scope')
     end
      --ngx.log(ngx.INFO, "Yep! post scope  equals: " ..  args['scope'])
     return true
   else
     return false
   end
 end

_M.extractDomain =  extractDomain
_M.extractToken =  extractToken
_M.isTokenValid =  isTokenValid
-- _M.indieLoginVerifyAuthorizationCode = indieLoginVerifyAuthorizationCode

function _M.verifytoken()
  ngx.log(ngx.INFO, "Verify Token")
  local msg = ''
  local tokens = ngx.shared.dTokens
  local token = extractToken()
  -- ngx.say( 'token: ' .. token )
  local jwtObj = jwt:load_jwt(token)
  if isTokenValid( jwtObj ) then
    --ngx.log(ngx.INFO, " Token is valid jwt object ")
    --ngx.log(ngx.INFO, "===========================")
    --ngx.log(ngx.INFO, "if a token has been verified the in will be stores in shared dic")
    --ngx.log(ngx.INFO, "shared dic only survives during runnung nginx instance")
    local thisDomain =  extractDomain( jwtObj.payload.me )
    --ngx.log(ngx.INFO, " - who am I := " .. thisDomain )
    local clientDomain =  extractDomain( jwtObj.payload.client_id )
    --ngx.log(ngx.INFO, " - client domain := " .. clientDomain )
    local domainHash = ngx.encode_base64( thisDomain .. clientDomain , true)
    local value, flags = tokens:get( domainHash )
    if not value then
      --ngx.log(ngx.INFO, 'Token has not been verified at token endpoint')
      if verifyAtTokenEndpoint( 'token' ) then
        --ngx.log(ngx.INFO, 'Token verified at token endpoint')
        tokens:set(domainHash, true)
        --ngx.log(ngx.INFO, 'token set for running nginx instance')
        return true
      else
        msg = "failed to verfify token at token endpoint: "
        return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg )
      end
    else
      --ngx.log(ngx.INFO, 'Token has already been verified at token endpoint ')
      --TODO! for testing only
      --  tokens:set(domainHash, nil)
      return true
    end
  else
    ngx.log(ngx.Warn, 'Token not Veriified')
    -- oh NO! should not end up here
    msg = "failed to validate token "
    return requestError(ngx.HTTP_UNAUTHORIZED,'unauthorized', msg )
  end
end

-- function _M.verifyHubSignature()
--   ngx.log(ngx.INFO, "Verify X Hub Signature")
--   local msg = ''
-- end

function _M.verifyMyToken()
  ngx.log(ngx.INFO, "Verify my token")
  local token = extractToken()
  ngx.say( 'token: ' .. token)
  local jwtObj = jwt:load_jwt(token)
  ngx.log(ngx.INFO, "Check The Tokens Validity")
  if not jwtObj.valid then
    return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'not a jwt token')
  end
 ngx.log(ngx.INFO, 'YEP! looks like a JWT token ')
  local common_name = jwtObj.payload.common_name
  if common_name == nil then
    return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'common_name')
  end
  local exist_auth_hash = jwtObj.payload.exist_auth_hash
  if exist_auth_hash == nil then
    return  requestError(ngx.HTTP_UNAUTHORIZED,'insufficient_scope', 'exist_auth_hash')
  end

  if  jwtObj.payload.exist_auth_hash == ngx.md5(ngx.var.exAuth) then
    ngx.say( ' OK ')
  else
    ngx.say ('not OK')
    return  requestError(ngx.HTTP_UNAUTHORIZED,'has check failed', 'exist_auth_hash')
  end

end

return _M
