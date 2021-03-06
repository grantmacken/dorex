local _M = {}
local cjson = require("cjson")
local util = require('grantmacken.util')
local req = require("grantmacken.req")
local reqargs = require("resty.reqargs")
-- local re = require("ngx.re")
_M.version = '0.0.1'
--[[

webmention.lua
@see https://www.w3.org/TR/webmention

 - OPM depends ...
@see https://github.com/openresty/lua-nginx-module
@see https://github.com/pintsized/lua-resty-http
@see https://github.com/bungle/lua-resty-reqarg

 - My depends for this lib ...
@gf proxy/lualib/util.lua

 - Webmention Endpoint ...
@gF proxy/conf/server.conf:47

# establish if local or remote container
 - Set container *HOSTNAME* as nginx Environment Var ..
@gF proxy/conf/nginx.conf:8
 - set *container* as ngx var `nxg.var.container` ...
@gF proxy/conf/server.conf:23
NOTE:   orDev for local
        orProd for remote

# Receiving Webmentions

@see https://www.w3.org/TR/webmention/#receiving-webmentions


 - Receive POST Request

 - Request Verification
   - source and target valid URLs
   - source not same as target
   - target as valid resource
   - Webmention Verification
https://www.w3.org/TR/webmention/#h-webmention-verification
--]]



function _M.processRequest()
  ngx.log( ngx.INFO, '============================' )
  ngx.log( ngx.INFO, ' Process Webmention Request ' )
  ngx.log( ngx.INFO, '============================' )
  local method = util.acceptMethods({
      'POST'
    })
  local contentType = util.acceptContentTypes({
      'application/x-www-form-urlencoded'
    })
  processPostArgs()
end

function processPostArgs()
  ngx.log(ngx.INFO, ' - process POST arguments ' )
  local msg = ''
  local args = {}
  -- ngx.req.read_body()
  local get, post, files = reqargs()
  if not get then
    msg = "failed to get post args: " ..  err
    return util.requestError(
      ngx.HTTP_BAD_REQUEST,
      'bad request',
      msg)
  end

  local getItems = 0
  for k,v in pairs(get) do
    getItems = getItems + 1
  end

  local postItems = 0
  for k,v in pairs(post) do
    postItems = postItems + 1
  end

  if  getItems > 0 then
     ngx.log(ngx.INFO, ' - count post args ' .. getItems )
    args = get
  end

  if  postItems > 0 then
    ngx.log(ngx.INFO, ' - count post args ' .. postItems )
    args = post
  end

  ngx.log(ngx.INFO, 'SHOULD have 2 args "target" and "source"' )

  if util.tablelength( args ) ~= 2 then
    msg = "FAILURE: webmention SHOULD have 2 POST args 'source' and 'target'"
    ngx.log(ngx.INFO, msg )
    return util.requestError(
      ngx.HTTP_BAD_REQUEST,
      'bad request',
      msg)
  end

  ngx.log(ngx.INFO, 'receiver SHOULD verify the parameters' )
  util.acceptFormArgs( args , { 'source', 'target'})
  ngx.log(ngx.INFO, 'YEP! got 2 args' )
  ngx.log(ngx.INFO, 'source := ' .. args['source']   )
  ngx.log(ngx.INFO, 'target := ' .. args['target']   )
  -- Request Verification
  ngx.log(ngx.INFO, 'receiver MUST check that source and target are valid URLs' )
  if not isURL( args['source'] ) then
    msg = 'source "' .. args['source']  .. '" MUST be a valid url'
    ngx.log(ngx.INFO, msg)
    return util.requestError(
      ngx.HTTP_BAD_REQUEST,
      'bad request',
      msg)
  end
  if not isURL( args['target'] ) then
    msg = 'target "' .. args['target']  .. '" MUST be a valid url'
    ngx.log(ngx.INFO, msg)
    return util.requestError(
      ngx.HTTP_BAD_REQUEST,
      'bad request',
      msg)
  end
  ngx.log(ngx.INFO,  ' - YEP! "' .. args['source']  .. '" and "' ..  args['source'] .. '" look like a valid URLs'  )

  ngx.log(ngx.INFO,'receiver MUST reject the request if the source URL is the same as the target URL' )
  if  args['target']  ==  args['source'] then
    msg = 'the source URL is the same as the target URL'
    ngx.log(ngx.INFO, msg)
    return util.requestError(
      ngx.HTTP_BAD_REQUEST,
      'bad request',
      msg)
  else
    msg = ' - Goody Gumdrops: the source URL is NOT the same as the target URL'
    ngx.log(ngx.INFO, msg)
  end

  ngx.log(ngx.INFO,
    'receiver SHOULD check that target is a valid resource for which it can accept Webmention' )
  if isValidResource( args['target'] ) then
    msg = ' - Yippee Do Da: target is a valid resource on my site'
    ngx.log(ngx.INFO, msg)
  else
    msg = 'failure target is NOT a valid resource on my site'
    ngx.log(ngx.INFO, msg)
    return util.requestError(
      ngx.HTTP_BAD_REQUEST,
      'bad request',
      msg)
  end
  processWebmention( args['source'], args['target']  )
end

  -- ngx.say( resID )

   -- -  source URL was malformed or is not a supported URL scheme (e.g. a mailto: link)
   -- -  source URL not found
   --
   -- does the source document mention the target 
   -- - source URL does not contain a link to the target URL
   -- then
   -- MAY publish content from the source page on the target page

  -- Webmention Verification
  -- Webmention verification SHOULD be handled asynchronously to prevent DoS (Denial of Service) attacks
  --  If the receiver is going to use the Webmention in some way ...
  --  -  MUST perform an HTTP GET request on source
  --  - SHOULD limit the number of redirects it follows
  --  - receiver SHOULD include an HTTP Accept header 
function processWebmention( source , target )
  ngx.log(ngx.INFO, ' Webmention Verification ' )
  ngx.log(ngx.INFO, '==========================' )
  ngx.log(ngx.INFO,'MUST perform an HTTP GET request on source' )
  local http = req.http
  local sURL =  source
  local sHost = http:parse_uri(sURL)[2]
  local iPort = http:parse_uri(sURL)[3]
  local sPath = http:parse_uri(sURL)[4]
  local sResolved
  if ( sHost == ngx.var.domain ) then
    sResolved = 'or'
  else
    sResolved = sHost
  end
  local sAddress, sMsg = req.getAddress( sResolved )
  local sConnect =  req.connect( sAddress, iPort )
  if ( iPort == 443 ) then
    req.handshake( sHost )
  end
  local tHeaders = {}
     tHeaders['Host'] = sHost
  local tRequest = {}
    tRequest['method'] = 'GET'
    tRequest['path'] = sPath
    tRequest['ssl_verify'] = false
    tRequest['headers'] = tHeaders

  http:set_timeout(2000)
  local response, err = http:request(tRequest )
  if not response then
    msg = "source URL not found - failed to complete request: ", err
    return requestError(ngx.HTTP_BAD_REQUEST,'bad request', msg )
  end
  if  response.reason ~= 'Not Found' then
    ngx.log(ngx.INFO, " - source response " .. response.reason)
  else
   msg = "source URL not found "
      return util.requestError(
        ngx.HTTP_BAD_REQUEST,
        'HTTP bad request',
        msg)
  end

  local body = ''
  if response.has_body then
    body, err = response:read_body()
    if not body then
      msg = "source URL not found - failed to read body: " ..  err
      return util.requestError(
        ngx.HTTP_BAD_REQUEST,
        'HTTP bad request',
        msg)
    end
  end
  ngx.log(ngx.INFO, " - source body available and read ")

  -- detirmine content-type from response header
  if response.headers['Content-Type']  ~= nil then
    ngx.log(ngx.INFO, "Request Response Content-Type: " .. response.headers['Content-Type'] )
  else
    local msg =  'source URL not found - can not determine content type'
    return util.requestError(
      ngx.HTTP_BAD_REQUEST,
      'bad request ' ,
      msg )
  end

  if response.headers['Content-Encoding'] ~= nil then
    ngx.log(ngx.INFO, "Request Response Content-Encoding: " .. response.headers['Content-Encoding'])
    ngx.log(ngx.INFO, "TODO!:  if gzip etc might need to decode" )
  end

  local contentTypeHeader = response.headers['Content-Type']
  -- TODO!  only handles text/html content
  -- The receiver SHOULD use per-media-type rules to determine whether the source document mentions the targe
  local from, to, err = ngx.re.find(contentTypeHeader ,"(text/html|text/plain)")
  if from then
    local contentType =  string.sub( contentTypeHeader, from, to )
      ngx.log(ngx.INFO, " - ok we can handle : " .. contentType)
    -- ngx.log(ngx.INFO, " - check if source content mentions target" )
    -- ngx.log(ngx.INFO, " - i.e.  somewhere in 'source content'  there is a mention of a resource ( target ) on my site" )
    -- ngx.log(ngx.INFO, " - note: target has already validated as a resource on my site" )
    -- the receiver should look for properties whose values are an exact match for the URL
    ---TODO!
    --The receiver SHOULD use per-media-type rules to determine whether the 
    -- source document mentions the target URL. For example, in an [ HTML5] document, 
    -- the receiver should look for <a href="*">, <img href="*">, <video src="*"> and 
    -- other similar links. In a JSON ([RFC7159]) document, the receiver should look 
    -- for properties whose values are an exact match for the URL. If the document is 
    -- plain text, the receiver should look for the URL by searching for the string.
    -- ngx.log(ngx.INFO, " - initial check is to see if target string is in source body text" )
    ngx.log(ngx.INFO, "source document MUST have an exact match of the target URL")
    if findTargetInSource( body , target ) then
       ngx.log(ngx.INFO, " - found target body text in source body text" )
       store(  source, target, body )
    else
      local msg =  'source URL does not contain a link to the target URL.'
      return util.requestError(
        ngx.HTTP_BAD_REQUEST,
        'bad request',
        msg )
    end
  else
    if err then
      local msg =  'source URL not found - ' .. err .. ' - can not proccess ' .. contentTypeHeader
      return util.requestError(
        ngx.HTTP_BAD_REQUEST,
        'bad request',
        msg )
    end
    local msg =  'source URL not found - can not proccess ' .. contentTypeHeader
    return util.equestError(
      ngx.HTTP_BAD_REQUEST,
      'bad request ' ,
      msg )
  end
end

function store( source, target, body )
  local domain  = ngx.var.domain
  ngx.log(ngx.INFO, "STORE source as a wellformed document" )
  local srcID = createResourceID( source )
  ngx.log(ngx.INFO, " - sourceID is hash of the source URL: " .. srcID )
  local srcCol = 'pages'
  ngx.log(ngx.INFO, " - source will be catched page in the collection: " ..srcCol )
  local http = req.http
  local scheme, host, port, path = unpack(http:parse_uri(source))
  local base = scheme .. '://' .. host
  ngx.log(ngx.INFO, " - source base : " .. base)
  local data =  sanitizeStoreSource( ngx.encode_base64( body ), base , domain , srcCol, srcID )
  ngx.log( ngx.INFO, ' - stored source in '  .. srcCol .. ' collection' )
  local targetID = util.extractID( target )
  if not targetID then
    return false
  end
  ngx.log(ngx.INFO, " - targetID is the doc mentioned on my site: " .. targetID )
  local insResponse = insertMention( source, srcID, targetID, domain )
  ngx.log(ngx.INFO, " - mention insert done: " .. targetID )
end

function insertMention( source, srcID, targetID, myDomain )
  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    import module namespace mf2="http://markup.nz/#mf2" at "xmldb:exist:///db/apps/]] .. myDomain .. [[/modules/lib/mf2.xqm";
    let $source := "]] .. source .. [["
    let $srcPath := "xmldb:exist:///db/data/]] .. myDomain  .. '/docs/pages/' ..  srcID .. [["
    let $srcDoc := doc( $srcPath )
    let $mf2Parsed := mf2:dispatch( $srcDoc/node() )
    let $mention := if ( $srcDoc instance of document-node() ) then (
    <mention><source>{$source}</source>{$mf2Parsed}</mention>
    )
    else (
    <mention><source>{$source}</source></mention>
    )
    let $collection := "xmldb:exist:///db/data/]] .. myDomain  .. '/docs/mentions/' .. [["
    let $resource := "]] .. targetID .. [["
    let $targPath := concat( $collection , $resource )
    return
    try {
     if ( doc-available( $targPath ) ) then (
      if ( doc( $targPath )//source[ . = $source ] ) then (
        'mention source already exists for this page',
        xmldb:store( $collection, $resource, <mentions>{$mention}</mentions>, 'application/xml'  )
      )
      else (
        update insert $mention into doc( $targPath )/*, 'new mention inserted'
      )
     ) else (
       xmldb:store( $collection, $resource, <mentions>{$mention}</mentions>, 'application/xml'  )
     )
     }
    catch *{()}
     ]] ..']]>' .. [[
    </text>
  </query>
]]

  local responseBody = postQuery( txt )
  ngx.log(ngx.INFO, "body: ", responseBody)
end

-- return mf2:dispatch($sanDoc)
function sanitizeStoreSource( srcBinary, srcBase, myDomain, srcCol, srcID )
  local restPath  = '/exist/rest/db'
  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    import module namespace muSan="http://markup.nz/#muSan" at "xmldb:exist:///db/apps/]] .. myDomain .. [[/modules/lib/muSan.xqm";
    try {
    let $srcDoc := util:parse-html(util:base64-decode("]] .. srcBinary .. [["))
    let $base := "]] .. srcBase .. [["
    let $sanDoc := muSan:sanitizer( $srcDoc/* , $base )
    let $collection := "xmldb:exist:///db/data/]] .. myDomain  .. '/docs/' .. srcCol .. [["
    let $resource := "]] .. srcID .. [["
    return xmldb:store( $collection, $resource, $sanDoc, 'application.xml' )
    }
    catch *{()}
     ]] ..']]>' .. [[
    </text>
  </query>
]]
  --  ngx.log(ngx.INFO, 'constructed txt')
  --  ngx.say(txt)
  local responseBody = postQuery( txt )
  ngx.log(ngx.INFO, "body: ", responseBody)
  ngx.log(ngx.INFO, "body: ", type( responseBody))
  return responseBody
end

function findTargetInSource( srcBody, target )
  ngx.log(ngx.INFO, "In source text look for string [ " .. target  .. ' ] ' )
  ngx.log(ngx.INFO, 'NOTE have not parsed source str' )
  local isFound = false
  local regEx = '(' .. target .. ')'
  local from, to, err = ngx.re.find( srcBody ,regEx )
  if from then
    local link =  string.sub( srcBody, from, to )
    ngx.log(ngx.INFO, ' - OK target link found: ' .. link )
    isFound = true
  else
    if err then
      ngx.log(ngx.INFO, "error: ", err)
    end
    ngx.log(ngx.INFO, "not matched!")
  end
  return isFound
end


function isValidResource( url )
  local dbID = util.extractID( url )
  -- ngx.log(ngx.INFO, type(dbID) )
  if not dbID then
    return false
  end
   ngx.log(ngx.INFO, 'extracted ID: ' .. dbID )
   ngx.log(ngx.INFO, url)
   local txt  =   [[
<query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
  <text>
  <![CDATA[
  xquery version "3.1";
  try { doc-available( "xmldb:exist:///db/data/]] .. ngx.var.domain  .. '/docs/posts/' .. dbID .. [[") }
  catch *{()}
    ]] ..']]>' .. [[
  </text>
</query>
]]

  local exResult = postQuery( txt )
  -- expect boolean
  if exResult == 'true' then
    return true
  else
    return false
  end
end

function createResourceID( str )
  local domain  = ngx.var.domain
  local restPath  = '/exist/rest/db'
  local txt  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    import module namespace muURL="http://markup.nz/#muURL" at "xmldb:exist:///db/apps/]] .. domain  .. [[/modules/lib/muURL.xqm";
    try { muURL:urlHash( "]] .. str.. [[") }
    catch *{()}
    ]] ..']]>' .. [[
    </text>
  </query>
]]
  --  ngx.log(ngx.INFO, 'constructed txt')
  --  ngx.say(txt)
  -- ngx.log(ngx.INFO, "body: ", responseBody)
  --ngx.log(ngx.INFO, "body: ", type( responseBody))
  --
  -- expect string
  return postQuery( txt )
  -- if exResult == 'true' then
  --   return true
  -- else
  --   return false
  -- end

end

function isURL( url )
  ngx.log(ngx.INFO, url)
  local domain  = ngx.var.domain
  local txt =  [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    import module namespace muURL="http://markup.nz/#muURL" at "xmldb:exist:///db/apps/]] .. domain  .. [[/modules/lib/muURL.xqm";
    try { muURL:meetsAcceptableCriteria(  "]] .. url .. [[" ) }
    catch *{()}
     ]] ..']]>' .. [[
    </text>
  </query>

]]

  local exResult = postQuery( txt )
  -- expect boolean
  if exResult == 'true' then
    return true
  else
    return false
  end
end


function postQuery( xmlBody  )
  local sPath  = '/exist/rest/db'
  local sAddress, sMsg = req.getAddress( 'ex' )
  ngx.log(ngx.INFO,  sMsg )
  local sConnect = req.connect( sAddress, 8080 )
  ngx.log(ngx.INFO,  sConnect )
  ngx.log(ngx.INFO, sPath )
  ngx.log(ngx.INFO, xmlBody )
  local sAuth = 'Basic ' .. ngx.var.exAuth
  -- ngx.log(ngx.INFO, auth )
  local tHeaders = {}
  tHeaders["Content-Type"] =  'application/xml'
  tHeaders["Authorization"] =  sAuth
  local tRequest = {
    method = 'POST',
    path = sPath,
    headers = tHeaders,
    ssl_verify = false,
    body = xmlBody
  }
  req.http:set_timeout(6000)
  local response, err = req.http:request( tRequest )
  if not response then
    ngx.say(' - ERR: failed to get response: ' .. err)
    ngx.say(' - exiting ... '  )
    ngx.exit()
  end
  ngx.log(ngx.INFO, 'Response status: ' .. response.status )
  local rBody
  if response.has_body then
    rBody, err = response:read_body()
    if not rBody then
      ngx.say("ERR: failed to read_body: ", err)
      ngx.exit()
    end
  end
  local closed, err = req.http:close()
  if not closed then
    ngx.say("ERR: failed to close connection: ", err)
    ngx.exit()
  end
  return rBody
end

return _M
