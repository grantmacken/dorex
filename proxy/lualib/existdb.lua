local _M = {}

local util = require("grantmacken.util")

_M.version = '0.0.1'


local cfg  = {
  appsRoute = 'xmldb:exist:///db/apps/',
  restPath = '/exist/rest/db/apps/'
}
-- local util    = require('grantmacken.util')
-- https://github.com/pintsized/lua-resty-http
-- auth = 'Basic ' .. os.get env("EXIST_AUTH")

local http = require("resty.http").new()
local httpc = http.new()
local resolver = require("resty.dns.resolver")


local function connect()
  --- docker DNS resolver: 127.0.0.11
  local r, err, ans, ok
  r, err = resolver:new{nameservers = {'127.0.0.11'}}
  if not r then
    ngx.say("failed to instantiate resolver: ", err)
    return
  end
  ans, err = r:query("ex.", { qtype = r.TYPE_A })
  if not ans then
    ngx.say("failed to query: ", err)
    return
  end
  -- local ok, err = httpc:connect( '172.18.0.2',8080)
  local ok, err = httpc:connect(ans[1].address,8080)
  if not ok then
     ngx.say("ERR: Failed to connect ", err)
    -- ngx.exit()
  end
   return ' - connected to '  .. ans[1].address..  ' on port '  .. cfg['port']
end

-- local reqargsOptions = {
--   timeout          = 1000,
--   chunk_size       = 4096,
--   max_get_args     = 100,
--   mas_post_args    = 100,
--   max_line_size    = 512,
--   max_file_uploads = 10
-- }

local extensions = {
png = 'image/png',
jpg = 'image/jpeg',
jpeg = 'image/jpeg',
gif = 'image/gif'
}

-- local assetRoute = {
-- image  =   'resources/images',
-- scripts  = 'resources/styles',
-- styles  =  'resources/styles',
-- icons  =   'resources/icons'
-- }


-- ++++++++++++++++++++++++++++++++++++++++++
-- function acceptFormFields(fields , field)
--   --  the multpart form fields  this endpoint can handle
--   if not contains( fields, field )  then
--     return requestError(
--       ngx.HTTP_NOT_ACCEPTABLE,
--       'not accepted',
--       'endpoint only doesnt accept' .. field )
--   end
--  return method
-- end

local function getMimeType( filename )
  -- get file extension Only handle
  local ext, err = ngx.re.match(filename, "[^.]+$")
  if ext then
   return ext[0], extensions[ext[0]]
  else
    if err then
      ngx.log(ngx.ERR, "error: ", err)
      return
    end
    ngx.say("match not found")
  end
end

local function processGetDelete( method )
  ngx.log(ngx.INFO, "Process GET DELETE requests to eXist endpoint")
  ngx.log(ngx.INFO, ngx.var.uri)
  local response = {}
  local msg = ''
  local args = ngx.req.get_uri_args()
  if not args[1] then
    ngx.log(ngx.INFO, "Look for path")
    local sID = require('ngx.re').split(ngx.var.uri, '/')[3]
    if sID ~= nil then
      ngx.log(ngx.INFO, type(sID))
      local from, to, err = ngx.re.find(
      sID,
      "([rnap]{1})([0-9A-HJ-NP-Z_a-km-z]{3})([0-9A-HJ-NP-Z_a-km-z]{1})", 
      "jo")
      if from then
        -- ngx.say("from: ", from)
        -- ngx.say("to: ", to)
        local matched = string.sub(sID, from, to)
        ngx.log(ngx.INFO, "matched: ", matched )
        _M.proxyGetDelete( 'posts' , matched )
      else
        if err then
          msg =  "error: " .. err
          ngx.log(ngx.WARN, msg)
          util.requestError( ngx.HTTP_BAD_REQUEST,'bad request' , msg )
        end
        msg =  "error: not valid uid"
        ngx.log(ngx.WARN, msg)
        util.requestError( ngx.HTTP_BAD_REQUEST,'bad request' , msg )
      end
    else
      msg =  "error: no ID"
      ngx.log(ngx.WARN, msg)
      util.requestError( ngx.HTTP_BAD_REQUEST,'bad request' , msg )
    end


    -- if sID ~= '' then
    -- else
    -- msg =  "TODO! : " .. type(sID)
    -- ngx.log(ngx.WARN, msg)
    -- requestError( ngx.HTTP_BAD_REQUEST,'bad request' , msg )
    -- end
  end
  -- TODO!
  -- ngx.log(ngx.INFO, "Look for path")
  -- for key, val in pairs(args) do
  --   if type(val) == "table" then
  --     ngx.say(key, ": ", table.concat(val, ", "))
  --   else
  --     ngx.say(key, ": ", val)
  --   end
  -- end
end

local function processPost()
  ngx.log(ngx.INFO, "Process the content-types this endpoint can handle")
  -- mainly handle eXist rest endpoint
  local contentType = util.acceptContentTypes({
      'application/xquery',
      'application/xml',
      'application/json',
      'application/x-www-form-urlencoded',
      'multipart/form-data'
    })
--[[
POST  If the remainder of the URI (the part after /exist/rest) i
 references an XQuery program stored in the database, it will be executed.
]]--
  ngx.log(ngx.INFO, "Accepted Content Type [ " .. contentType  .. ' ]')
  --  ngx.say( contentType )
  if contentType  == 'application/x-www-form-urlencoded' then
    --processPostArgs()
  elseif contentType  == 'multipart/form-data' then
    --processMultiPartForm()
  elseif contentType  == 'application/json' then
    --processJsonBody()
  elseif contentType  == 'application/xml' then
    --processXqueryXML()
  elseif contentType  == 'application/xquery' then
    --processXqueryFile()
  end
end


local function doPut()
  ngx.log(ngx.INFO, "Process the content-types this endpoint can handle")
  ngx.log(ngx.INFO, "---------------------------------------------------")
  -- mainly handle eXist rest endpoint
  ngx.log(ngx.INFO, ngx.var.http_content_type )
  --
  local contentType = util.acceptContentTypes({
    'application/xml',
    'application/json'
  })
  ngx.log(ngx.INFO, "Accepted Content Type [ " .. contentType  .. ' ]')
  local sContainerName = 'ex'
  local sAddress, sMsg = require('grantmacken.resolve').getAddress( sContainerName )
  ngx.log( ngx.INFO, sMsg )
end


-- ++++++++++++++++++++++++++++++++++++++++++
--  MAIN endpoint for exist requests
--  https://<domain>//eXist/

function _M.processRequest()
  ngx.log(ngx.INFO, "Process Request" )
  local h, err = ngx.req.get_headers()
  if err == "truncated" then
    -- one can choose to ignore or reject the current request here
  end
 for k, v in pairs(h) do
    ngx.log(ngx.INFO,  k  .. " [ " .. v .. ' ]')
 end


   local method =  util.acceptMethods({"PUT", "POST","GET" , "DELETE"})
  ngx.log(ngx.INFO, "Accepted Method [ " .. method  .. ' ]')
  if ( method == "POST" ) then
    -- processPost()
  elseif (  method == "PUT" ) then
     doPut()
  else
    -- processGetDelete()
  end
end


function processXqueryXML()
  ngx.log(ngx.INFO, " Process xQuery ")
  ngx.log(ngx.INFO, "----------------")
  ngx.req.read_body()
  local data = ngx.req.get_body_data()
  ngx.log(ngx.INFO, ' - got sent body data' )
  -- ngx.log(ngx.INFO, data)
  local restPath =  '/exist/rest/db/apps/' ..  ngx.var.domain
  ngx.log(ngx.INFO, ' - restPath'  .. restPath)
  ngx.log(ngx.INFO, connect())
  local req = {
    version = 1.1,
    method = "POST",
    path = restPath,
    headers = {
      ["Content-Type"] =  ngx.header.content_type,
      ["Authorization"] = cfg['auth']
    },
    body = data
  }

  httpc:set_timeout(2000)
  httpc:proxy_response( httpc:request( req ) )
  httpc:set_keepalive()
end

return _M
