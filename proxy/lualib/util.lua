local _M = {}

local cjson = require("cjson")
-- local re = require("ngx.re")

_M.version = '0.0.1'

local function tableLength(T)
  local count = 0
  for _ in pairs(T) do
    count = count + 1
  end
  return count
end

local function contains(tab, val)
  for index, value in ipairs (tab) do
    if value == val then
      return true
    end
  end
  return false
end

function _M.requestError( status, msg, description )
  ngx.status = status
  ngx.header.content_type = 'application/json'
  local json = cjson.encode({
      error  = msg,
      error_description = description
    })
  ngx.print(json)
  ngx.exit(status)
end

function _M.acceptMethods( methods )
  ngx.log( ngx.INFO, 'the methods this endpoint can handle' )
  local method = ngx.req.get_method()
  if not contains( methods, method )  then
    return _M.requestError(
      ngx.HTTP_METHOD_NOT_IMPLEMENTED,
      method .. ' method not implemented',
      'this endpoint does not accept ' .. method .. ' method')
  end
 return method
end

function _M.acceptContentTypes( contentTypes )
  ngx.log( ngx.INFO, 'the content types this endpoint can handle' )
  local contentType = ngx.var.http_content_type
  if not contentType then
    local msg = 'should have a content type'
    return _M.requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted ',
      msg )
  end
  local from, to, err = ngx.re.find(contentType ,"(multipart/form-data|application/x-www-form-urlencoded|multipart/form-data)")
  if from then
    contentType =  string.sub( contentType, from, to )
  end
  if not contains( contentTypes, contentType )  then
    local msg = 'endpoint does not accept' .. contentType
    return _M.requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted ',
      msg )
  end
  return contentType
end

function _M.acceptFormArgs(args, acceptArgs)
  for key, value in pairs(args) do
    ngx.log(ngx.INFO, key)
    if not contains(acceptArgs, key) then
      return _M.requestError(
        ngx.HTTP_NOT_ACCEPTABLE,
        "not accepted",
        "endpoint only does not accept " .. key
      )
    end
  end
  return true
end

function _M.extractID(url)
  -- short urls https://gmack.nz/xxxxx
  local sID, err =
    require("ngx.re").split(url, "([nar]{1}[0-9A-HJ-NP-Z_a-km-z]{4})")[2]
  if err then
    local msg = "could not extract id from URL"
    return _M.requestError(ngx.HTTP_BAD_REQUEST, "bad request", msg)
  end
  return sID
end

-- utility REQUEST functions
--
--[[
-- a simple GET request wrapper for resty-http
-- @see https://github.com/pintsized/lua-resty-http
-- @param URL
-- @returns  response table , err
--]] 
function _M.fetch(
  url)
  ngx.log(ngx.INFO, " FETCH simple GET ")
  ngx.log(ngx.INFO, " - fetch: " .. url)
  local msg = ""
  local httpc = require("resty.http").new()
  local scheme, host, port, path = unpack(httpc:parse_uri(url))
  ngx.log(ngx.INFO, " - scheme: " .. scheme)
  httpc:set_timeout(2000) -- 2 sec timeoutlog( ngx.INFO, " - fetch: "  .. url )
  local ok, err = httpc:connect(host, port)

  if not ok then
    msg = "FAILED to connect to " .. host .. " on port " .. port
    ngx.log(ngx.INFO, msg)
    return {}, msg
  else
    ngx.log(ngx.INFO, " - connected to " .. host .. " on port " .. port)
  end

  if scheme == "https" then
    -- 4 sslhandshake opts
    local reusedSession = nil -- defaults to nil
    local serverName = host -- for SNI name resolution
    local sslVerify = false -- boolean if true make sure the directives set
    -- for lua_ssl_trusted_certificate and lua_ssl_verify_depth
    local sendStatusReq = "" -- boolean OCSP status request
    local shake, err = httpc:ssl_handshake(reusedSession, serverName, sslVerify)
    if not shake then
      ngx.log(
        ngx.INFO,
        "FAILED SSL handshake with  " .. serverName .. " on port " .. port
      )
      return {}, msg
    else
      ngx.log(ngx.INFO, " - SSL Handshake Completed: " .. type(shake))
    end
  end

  -- local DEFAULT_PARAMS
  --   method = "GET",
  --   path = "/",
  --   version = 1.1,
  --  also defaults to
  --  headers["User-Agent"] = _M._USER_AGENT
  --  if SSL headers["Host"] = self.host .. ":" .. self.port
  --  else headers["Host"] = self.host
  --  headers["Connection"] = "Keep-Alive"
  --  if body will also add
  --  headers["Content-Length"] = #body

  httpc:set_timeout(2000)
  local response, err =
    httpc:request(
    {
      ["path"] = path
    }
  )

  if not response then
    msg = "failed to complete request: ", err
    ngx.log(ngx.INFO, msg)
    return {}, msg
  end
  return response, err
end

_M.contains = contains
_M.tablelength = tableLength
_M.tableLength = tableLength

function _M.doPutXML( sPath , xBody )
  local sAddress, sMsg = req.getAddress( 'ex' )
  local sConnect = req.connect( sAddress, 8080 )
  local tHeaders = {}
  tHeaders["Content-Type"] =  'application/xml'
  tHeaders["Authorization"] = 'Basic ' .. sAuth
  local tRequest = {
    method = 'PUT',
    path = sPath,
    headers = tHeaders,
    ssl_verify = false,
    body =  xBody
   }
  req.http:set_timeout(3000)
  local response, err = req.http:request( tRequest )
  ngx.say( " - response status: " .. response.status)
  ngx.say( " - response reason: " .. response.reason)
end

function _M.doGetXML( sPath )
  local sAddress, sMsg = req.getAddress( 'ex' )
  local sConnect = req.connect( sAddress, 8080 )
  local tHeaders = {}
  tHeaders["Content-Type"] =  'application/xml'
  tHeaders["Authorization"] = 'Basic ' .. sAuth
  local tRequest = {
    method = 'GET',
    path = sPath,
    headers = tHeaders,
    ssl_verify = false,
   }
  req.http:set_timeout(3000)
  local response, err = req.http:request( tRequest )
  return response:read_body()
end



return _M
