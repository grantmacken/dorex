local _M = {}

_M.version = '0.0.1'

-- local cjson = require("cjson")
local util = require("grantmacken.util")
local req = require("grantmacken.req")
local reqargs = require("resty.reqargs")


--[[
https://www.w3.org/TR/micropub/#update
https://www.w3.org/TR/micropub/#delete
each action should have an associate url
--]]

local tActions = {
 update = true,
 delete = true,
 undelete = true
}

--[[
https://www.w3.org/TR/micropub/#update
The request MUST also include a replace, add or delete property
--]]
local tUpdates = {
 replace = true,
 add = true,
 delete = true
}




 -- https://www.w3.org/TR/micropub/#create
 --  handle these microformat Object Types
 --  TODO!  mark true when can handle
 ---

local microformatObjectTypes = {
  entry = true,
  card = false,
  event = false,
  cite = false
}

local postedEntryProperties= {
  ['name'] = true,
  ['summary'] = true,
  ['category'] = true,
  ['rsvp'] = true,
  ['in-reply-to'] = true,
  ['syndicate-to'] = true,
  ['repost-of'] = true,
  ['like-of'] = true,
  ['video'] = true,
  ['photo'] = true,
  ['content'] = true,
  ['published'] = false,
  ['updated'] = false
}

local shortKindOfPost = {
 note = 'n',
 reply = 'r',
 article = 'a',
 photo = 'p',
 media = 'm'
}

local reqargsOptions = {
  timeout          = 1000,
  chunk_size       = 4096,
  max_get_args     = 100,
  mas_post_args    = 100,
  max_line_size    = 512,
  max_file_uploads = 10
}

local function getShortKindOfPost(kind)
  return shortKindOfPost[kind]
end

local function discoverPostType(props)
  -- https://www.w3.org/TR/post-type-discovery/
  local kindOfPost = 'note'
  if props['in-reply-to'] ~= nil then
    kindOfPost = 'reply'
  end
  -- for key, val in pairs(props) do
  --   ngx.log(ngx.INFO, "key: ", key)
  --   ngx.log(ngx.INFO, "key: ", type( key ))
  --   if key == "rsvp" then
  --     --TODO check valid value
  --     kindOfPost = 'RSVP'
  --   elseif key == 'in%-reply%-to' then
  --     --TODO check valid value
  --     kindOfPost = 'reply'
  --   elseif key == 'repost%-of' then
  --     --TODO check valid value
  --     kindOfPost = 'share'
  --   elseif key == 'like%-of' then
  --     --TODO check valid value
  --     kindOfPost = 'like'
  --   elseif key == "video" then
  --     --TODO check valid value
  --     kindOfPost = 'video'
  --   elseif key == "photo" then
  --     --TODO check valid value
  --     kindOfPost = 'photo'
  --     break
  --   elseif key == "name" then
  --     --TODO check valid value
  --     kindOfPost = 'article'
  --     break
  --   else
  --     kindOfPost = 'note'
  --   end
  -- end
 return kindOfPost
end

local function b60Encode(remaining)
  local chars = '0123456789ABCDEFGHJKLMNPQRSTUVWXYZ_abcdefghijkmnopqrstuvwxyz'
  local slug = ''
  --local remaining = tonumber(str)
  while (remaining > 0) do
    local d = (remaining % 60)
    local character = string.sub(chars, d + 1, d + 1)
    slug = character .. slug
    remaining = (remaining - d) / 60
  end
  return slug
end

local function encodeDate()
  local shortDate = os.date("%y") .. os.date("%j")
  local integer = tonumber( shortDate )
  return b60Encode(integer)
end

local function createID( k )
  local shortKindOfPost = getShortKindOfPost(k)
  ngx.log(ngx.INFO, 'shortKindOfPost: [ ' .. shortKindOfPost  .. ' ]')
  local slugDict = ngx.shared.slugDict
  local count = slugDict:get("count") or 0
  -- setup count and today
  if count  == 0 then
    slugDict:add("count", count)
    slugDict:add("today", encodeDate())
  end
  -- if the same day increment
  -- otherwise reset today and reset counter
  if slugDict:get("today") == encodeDate() then
    -- ngx.say('increment counter')
    slugDict:incr("count",1)
    --ngx.say(slugDict:get("count"))
    --ngx.say(slugDict:get("today"))
  else
    -- ngx.say('reset counter')
    slugDict:replace("today", encodeDate())
    slugDict:replace("count", 1)
  end
  -- TODO! comment out test
   -- ngx.log(ngx.INFO,  'comment out after test' )
   -- slugDict:replace("count", 1)
   -- ngx.log(ngx.INFO,  'COUNT: ' .. slugDict:get("count") )
  -- ngx.say(slugDict:get("count"))
  -- ngx.say(slugDict:get("today"))
  return shortKindOfPost .. slugDict:get("today") .. b60Encode(slugDict:get("count"))
end

function extractID( url )
  -- short urls https://gmack.nz/xxxxx
  local sID, err = require("ngx.re").split(url, "([na]{1}[0-9A-HJ-NP-Z_a-km-z]{4})")[2]
  if err then
    return requestError(
      ngx.HTTP_SERVICE_UNAVAILABLE,
      'HTTP service unavailable',
      'connection failure')
  end
  return sID
end


local function createMf2Properties( post )
   ngx.log(ngx.INFO,  'Convert post data into a mf2 JSON Serialization Format' )
  --[[
    convert post data into a mf2 JSON  Serialization Formati

    NOTE: could use simplified
    JF2 Post Serialization Format  ref:  https://www.w3.org/TR/jf2/
    instead

  -- Post Properties
  -- https://www.w3.org/TR/jf2/#post-properties
  --
  server added microformat properties
  * published
  * url
  * uid

   uid and url  https://indieweb.org/u-uid

   uid an id to be used when deleting and undeleting posts
   http://microformats.org/wiki/uid-brainstorming
   A UID SHOULD be a URL rather than MUST
   The UID microformat will ordinarily be a URL,
   but it should be flexible enough to allow it to contain non-network resolvable URI

   my uid is resolvable by base domain
   https://{DOMAIN}/{UID}
   https://gmack.nz/n

  --  TODO! make url the expanded (human readable ) url
  --  e.g. /2017/01/01/title

  --]]

  ngx.log(ngx.INFO, ' - from the sent properties - discover the kind of post ')
  local kindOfPost = discoverPostType( post )
  ngx.log(ngx.INFO, 'kindOfPost: [ ' .. kindOfPost  .. ' ]')

  local properties = {}
  local sID = createID( kindOfPost )
  local sURL = 'https://' .. ngx.var.domain .. '/' .. sID
  local sPub, n, err =  ngx.re.sub(ngx.localtime(), " ", "T")

  properties['published'] =  { sPub }
  properties['uid'] =  { sID  }
  properties['url'] = { sURL }

  ngx.log(ngx.INFO, 'property: published [ ' .. sPub .. ' ]' )
  ngx.log(ngx.INFO, 'property: uid  [ ' .. sID .. ' ]' )
  ngx.log(ngx.INFO, 'property: url  [ ' .. sURL .. ' ]' )

  for key, val in pairs( post ) do
    -- ngx.log(ngx.INFO,  'post key: '  .. key  )
    -- ngx.log(ngx.INFO,   type( val ) )
    if key == 'content' then
      if type(post['content'][1]) == "table" then
        for k, v in pairs(post['content'][1]) do
          ngx.say('TODO!')
          --table.insert(data,1,{ xml = 'content',['type'] = k, v })
        end
      elseif type(post['content'][1]) == "string" then
        ngx.say('TODO!')
      elseif type(post['content']) == "string" then
        local content = {{
            ['value'] = post['content']
        }}
        properties['content'] = content
      end
    elseif key == 'content[html]' then
      if type(post['content[html]']) == "string" then
        local content = {{
            ['html'] = post['content[html]']
        }}
        properties['content'] = content
      end
    elseif key == 'content[value]' then
      if type(post['content[value]']) == "string" then
        local content = {{
            ['value'] = post['content[value]']
        }}
        properties['content'] = content
      end
    elseif  type(val) == "string" then
      -- ngx.log(ngx.INFO,  'post key: '  .. key  )
      -- ngx.log(ngx.INFO,   type( val ) )
      -- categories are array like
      local m, err = ngx.re.match(key, "\\[\\]")
      -- ngx.log(ngx.INFO,   type( m ) )
      if m then
        local pKey, n, err = ngx.re.sub(key, "\\[\\]", "")
        if pKey then
          if postedEntryProperties[pKey] ~=  nil then
            if properties[ pKey ] ~= nil then
              ngx.log(ngx.INFO,  'pKey : '  .. pKey )
              table.insert(properties[ pKey ],val)
            else
              properties[ pKey ] = { val }
            end
          end
        end
      else
        if err then
          ngx.log(ngx.ERR, "error: ", err)
          return
        end
        -- ngx.log(ngx.INFO,   'match not found' )
        if postedEntryProperties[key] ~=  nil then
          -- ngx.log(ngx.INFO,  'non array key: '  .. key  )
          -- ngx.log(ngx.INFO,   val  )
          properties[ key ] = { val }
        end
      end
    elseif type(val) == "table" then
      for k, v in pairs( val ) do
        local pKey, n, err = ngx.re.sub(key, "\\[\\]", "")
        if pKey then
          if postedEntryProperties[pKey] ~=  nil then
            if properties[ pKey ] ~= nil then
              -- ngx.say('key', ": ", pKey)
              table.insert(properties[ pKey ],v)
            else
              properties[ pKey ] = { v }
            end
          end
        end
      end
    end
  end
 return properties, kindOfPost
 end

local function createXmlEntry( jData )
   ngx.log(ngx.INFO,  'create XML entry from jData' )
   local root = ngx.re.match( jData.type, "[^-]+$")[0]
   local xmlNode = ''
   -- ngx.log(ngx.INFO,  'root documentElement: ' .. root   )
   local properties = {}
   local contents = {}
   for property, val in pairs( jData.properties ) do
     -- ngx.log(ngx.INFO, 'property', ": ", property)
     -- ngx.log(ngx.INFO, 'value type: ' ..  type(val))
     for i, item in pairs( val ) do
       if type(item) == "table" then
         -- ngx.log(ngx.INFO, cjson.encode(item) )
         --table.insert( xData,1,{ xml = key })
         for key, item2 in pairs( item ) do
           -- ngx.log(ngx.INFO,'key', ": ", key)
           -- ngx.log(ngx.INFO,'item2 type: ' ..  type(item2))
           if type(item2) == "string" then
             xmlNode =  '<' .. key .. '>' .. item2 .. '</' .. key .. '>'
             table.insert(contents,xmlNode)
           end
         end
         xmlNode =  '<' .. property .. '>' .. table.concat(contents) .. '</' .. property .. '>'
        table.insert(properties,xmlNode)
      else
         xmlNode =  '<' .. property .. '>' .. item .. '</' .. property .. '>'
        table.insert(properties,xmlNode)
      end
    end
  end
 local xmlDoc =  '<' .. root .. '>' .. table.concat(properties) .. '</' .. root .. '>'
 return xmlDoc
end

function doPut( sID, sPath, xmlBody )
  local sAddress, sMsg = req.getAddress( 'ex' )
  ngx.log(ngx.INFO,  sMsg )
  local sConnect = req.connect( sAddress, 8080 )
  ngx.log(ngx.INFO,  sConnect )
  ngx.log(ngx.INFO, sPath )
  -- ngx.log(ngx.INFO, xmlBody )
  local sAuth = 'Basic ' .. ngx.var.exAuth
  -- ngx.log(ngx.INFO, auth )
  local tHeaders = {}
  tHeaders["Content-Type"] =  'application/xml'
  tHeaders["Authorization"] =  sAuth
  local tRequest = {
    method = 'PUT',
    path = sPath,
    headers = tHeaders,
    ssl_verify = false,
    body = xmlBody
  }
  req.http:set_timeout(6000)
  local response, err = req.http:request( tRequest )
  ngx.log(ngx.INFO, " - response status: " .. response.status)
  ngx.log(ngx.INFO, " - response reason: " .. response.reason)
  if response.reason == 'Created' then
    ngx.log(ngx.INFO, ' created entry: ' .. 'https://' .. sID  )
    ngx.log(ngx.INFO, '# EXIT ...... # ' )
    ngx.header['Location'] = 'https://' .. sID
    ngx.exit(ngx.HTTP_CREATED)
   end
  --[[
  ngx.header.location = 'https://' .. sID
  if response.reason == 'Created' then
    ngx.log(ngx.INFO, ' created entry: ' .. 'https://' .. sID  )
    ngx.log(ngx.INFO, '# EXIT ...... # ' )
    ngx.exit(ngx.HTTP_CREATED)
   end
   --]]
end

function sendMicropubRequest( xmlBody  )
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
    ngx.log(ngx.ERR, ' - FAILED to get response: ' .. err)
    return requestError(
    ngx.HTTP_SERVICE_UNAVAILABLE,
    'HTTP service unavailable',
    'connection failure')
  end
  return response
end

--[[
deleting and undeleting posts
moves posts to and from a recycle collection ( like a trash/recycle bin )
on windows
--]]

function deletePost( uri )
  local contentType = 'application/xml'
  local resource    = extractID( uri)
  ngx.log(ngx.INFO, "resource: ", resource)
  local sourceCollection = '/db/data/' .. ngx.var.domain .. '/docs/posts'
  local targetCollection = '/db/data/' .. ngx.var.domain .. '/docs/recycle'
  ngx.log(ngx.INFO, "resource: ", resource)
  ngx.log(ngx.INFO, "target collection: ", targetCollection)
  ngx.log(ngx.INFO, "source collection: ", sourceCollection)
  local xmlBody  =  [[
<query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    let $sourceCollection := "]] .. sourceCollection .. [["
    let $targetCollection := "]] .. targetCollection .. [["
    let $resource         := "]] .. resource .. [["
    let $docPath          := $sourceCollection || '/' || $resource
    return
    if (exists($docPath)) then (
     xmldb:move( $sourceCollection, $targetCollection, $resource)
    )
    else ( )
    ]] ..']]>' .. [[
    </text>
</query>
]]
return sendMicropubRequest( xmlBody )
end

function undeletePost( uri )
  local resource    = extractID( uri)
  local sourceCollection = '/db/data/' .. ngx.var.domain .. '/docs/recycle'
  local targetCollection = '/db/data/' .. ngx.var.domain .. '/docs/posts'
  ngx.log(ngx.INFO, "resource: ", resource)
  ngx.log(ngx.INFO, "target collection: ", targetCollection)
  ngx.log(ngx.INFO, "source collection: ", sourceCollection)
  local xmlBody  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    let $sourceCollection := "]] .. sourceCollection .. [["
    let $targetCollection := "]] .. targetCollection .. [["
    let $resource         := "]] .. resource .. [["
    let $docPath          := $sourceCollection || '/' || $resource
    return
    if (exists($docPath)) then (
     xmldb:move( $sourceCollection, $targetCollection, $resource)
    )
    else ( )

    ]] ..']]>' .. [[
    </text>
  </query>
]]
  return sendMicropubRequest( xmlBody )
end

--[[
UPDATING POSTS
 update actions
 - add
 - delete
 - replace
--]]

function addProperty( uri, property, item )
  local resource    = extractID( uri )
  -- TODO only allow certain properties
  local xmlNode =  '<' .. property .. '>' .. item .. '</' .. property .. '>'
  local docPath   = '/db/data/' .. ngx.var.domain .. '/docs/posts/' .. resource
  local xmlBody  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    let $path := "]] .. docPath .. [["
    let $document := doc($path)
    let $node := ]] .. xmlNode .. [[
    let $item := ']] .. item .. [['
    return
    if ($document/entry/]] .. property .. [[  = $node ) then (
      update replace $document/entry/]] .. property .. [[[./string() eq $item]  with $node )
    else (
      update insert $node into $document/entry
    )
    ]] ..']]>' .. [[
    </text>
  </query>
]]
  return sendMicropubRequest( xmlBody )
end

function removeProperty( uri, property)
  local resource    = extractID( uri )
  local docPath   = '/db/data/' .. ngx.var.domain .. '/docs/posts/' .. resource
  local xmlBody  = [[
<query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
<text>
<![CDATA[
xquery version "3.1";
let $path := "]] .. docPath .. [["
let $document := doc($path)
return
if ( exists($document//]] .. property .. [[ ))
  then ( update delete $document//]] .. property .. [[ )
  else ( )
]] ..']]>' .. [[
</text>
</query>
]]
return sendMicropubRequest( xmlBody )
end

function removePropertyItem( uri, property, item )
  local resource    = extractID( uri)
  local xmlNode =  '<' .. property .. '>' .. item .. '</' .. property .. '>'
  local docPath   = '/db/data/' .. ngx.var.domain .. '/docs/posts/' .. resource
  local xmlBody  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    let $path := "]] .. docPath .. [["
    let $document := doc($path)
    let $item := ']] .. item .. [['
    return
    if ( $document/entry/]] .. property .. '[ . = "' .. item .. '" ]' ..  [[ ) then (
    update delete  $document/entry/]] .. property .. '[ . = "' .. item .. '" ]' ..  [[
    )
    else ( )
    ]] ..']]>' .. [[
    </text>
  </query>
]]
return sendMicropubRequest( xmlBody )
end

function replaceProperty( uri, property, item )
  local resource    = extractID( uri)
  local docPath   = '/db/data/' .. ngx.var.domain .. '/docs/posts/' .. resource
  local xmlNode = ''
  -- TODO only allow certain properties
  if property == 'content' then
    xmlNode = '<value>' .. item .. '</value>'
  else
   -- xmlNode = { xml = property, item }
  end

  local xmlBody  =   [[
  <query xmlns="http://exist.sourceforge.net/NS/exist" wrap="no">
    <text>
    <![CDATA[
    xquery version "3.1";
    let $path := "]] .. docPath .. [["
    let $document := doc($path)
    let $node := ]] .. xmlNode .. [[
    let $item := ']] .. item .. [['
    return
    if ( exists( $document/entry/]] .. property .. [[/value)) then (
      update replace $document/entry/]] .. property .. [[/value with $node )
    else (
      update insert $node into $document/entry
    )

    ]] ..']]>' .. [[
    </text>
  </query>
]]
  return sendMicropubRequest( xmlBody )
end

function fetchPostsDoc( uri )
  local resource    = extractID( uri)
  local sPath = '/exist/rest/db/data/' .. ngx.var.domain .. '/docs/posts/' .. resource
  local sAddress, sMsg = req.getAddress( 'ex' )
  -- ngx.log(ngx.INFO,  sMsg )
  local sConnect = req.connect( sAddress, 8080 )
  ngx.log(ngx.INFO,  sConnect )
  -- ngx.log(ngx.INFO, auth )
  local sAuth = 'Basic ' .. ngx.var.exAuth
  local tHeaders = {}
  tHeaders["Content-Type"] =  'application/xml'
  tHeaders["Authorization"] =  sAuth
  local sPath = '/exist/rest/db/data/' .. ngx.var.domain .. '/docs/posts/' .. resource
  local tRequest = {
    method = 'GET',
    path = sPath,
    headers = tHeaders,
    ssl_verify = false
  }
  req.http:set_timeout(6000)
  local response, err = req.http:request( tRequest )
  if not response then
    ngx.log(ngx.ERR, ' - FAILED to get response: ' .. err)
  end
  ngx.log(ngx.INFO, " - Response Status: " .. response.status)
  ngx.log(ngx.INFO, " - Response Reason: " .. response.reason)
  req.http:proxy_response(response)

  -- ngx.log(ngx.INFO, sPath )
  -- -- ngx.log(ngx.INFO, auth )
  -- local tHeaders = {}
  -- tHeaders["Content-Type"] =  'application/xml'
  -- tHeaders["Authorization"] =  sAuth
  -- local tRequest = {
  --   method = 'GET',
  --   path = sPath,
  --   headers = tHeaders,
  --   ssl_verify = false
  -- }
  -- req.http:set_timeout(6000)
  -- req.http:proxy_response(req.http:proxy_request(tRequest))
  -- req.http:set_keepalive()
  -- ngx.log(ngx.INFO, ' - path :' .. sPath )
  -- local tRequest = {
  --   method = 'GET',
  --   path = sPath,
  --   headers = tHeaders,
  --   ssl_verify = false
  -- }
  -- req.http:set_timeout(6000)
  -- local response, err = req.http:request( tRequest )
  -- if not response then
  --   ngx.log(ngx.ERR, ' - FAILED to get response: ' .. err)
  -- end
  -- ngx.log(ngx.INFO, " - Response Status: " .. response.status)
  -- ngx.log(ngx.INFO, " - Response Reason: " .. response.reason)
end

local function processGet()
  ngx.log(ngx.INFO, 'process GET query to micropub endpoint' )
  ngx.header.content_type = 'application/json'
  local response = {}
  local msg = ''

  local args = ngx.req.get_uri_args()
  local mediaEndpoint = 'https://' .. ngx.var.domain .. '/micropub'
  if args['q'] then
    ngx.log(ngx.INFO, ' query the endpoint ' )
    local q = args['q']
    if q  == 'config' then
      -- 'https://www.w3.org/TR/micropub/#h-configuration'
      -- TODO!
      local status = ngx.HTTP_OK
      -- response = { 'media-endpoint' =  mediaEndpoint}
      local json = cjson.encode({
         [ 'media-endpoint' ]  = mediaEndpoint
        })
      ngx.print(json)
      ngx.exit(status)
    elseif q  == 'source' then
      ngx.log(ngx.INFO, '- source query' )
      -- TODO!
      -- ngx.say('https://www.w3.org/TR/micropub/#h-source-content')
      if args['url'] then
        local sURL = args['url']
        ngx.log(ngx.INFO,  'has url: ' , sURL  )
         fetchPostsDoc( sURL )
      else
      msg = 'source must have associated url'
      return util.requestError(
        ngx.HTTP_NOT_ACCEPTABLE,
        'not accepted',
        msg )
      end
      ngx.exit(ngx.OK)
    elseif q  == 'syndicate-to' then
      ngx.status = ngx.HTTP_OK
      -- https://github.com/bungle/lua-resty-libcjson
      -- https://github.com/bungle/lua-resty-libcjson/issues/1
      --  ngx.print(cjson.encode(json.decode('{"syndicate-to":[]}')))
     local json = '{"syndicate-to":[]}'
     ngx.print(json)
      ngx.exit(ngx.OK)
    end
  end
  -- local status = ngx.HTTP_OK
  -- -- response = { 'media-endpoint' =  mediaEndpoint}
  -- local json = cjson.encode({
  --     [ 'media-endpoint' ]  = mediaEndpoint
  --   })
  -- ngx.print(json)
  -- ngx.exit(status)

  return util.requestError(
  ngx.HTTP_BAD_REQUEST,
  'bad request',
  'invalid_request - query the endpoint using q pararm' )
end

-- ACTIONS
-- processing form actions
-- processing json actions

function processActions( postType, args )
  --[[
  --postType form or json
    To update an entry, send "action": "update" and specify the URL of the entry that is being updated using the "url"
    property. The request MUST also include a replace, add or delete property (or any combination of these) containing
      the updates to make.
    --]]
  ngx.log(ngx.INFO, ' - process actions ', postType )
  -- ngx.log(ngx.INFO, args['action'] )
  -- for key, item in pairs( args ) do
  --    ngx.log(ngx.INFO,'key', ": ", key)
  --    ngx.log(ngx.INFO,'value', ": ", item)
  -- end

  local sAction = args['action']
  local sURL = args['url']

  if type( sAction ) ~= 'string' then
    msg = " micropub should have an action item' "
    return util.requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
      msg)
  end

  if type( sURL ) ~= 'string' then
    msg = " micropub 'action' should have an associated 'url' "
    return util.requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
      msg)
  end
  --  arg['action'] should be either 'update' or 'delete' or 'undelete'
  local from, to, err = ngx.re.find(sAction ,"(update|delete|undelete)")
  if not from then
    local msg = " micropub 'action' should be either 'update' or 'delete' or 'undelete' "
    return util.requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
      msg)
  end
  ngx.log(ngx.INFO, 'ACTION: ', sAction )
  if sAction == 'update' then
    ngx.log(ngx.INFO, 'start of ACTION UPDATEs')
    -- do any combination
    --[[
          The values of each property inside the replace, add or delete keys MUST be an array, even if there is only a
          single value.
          --]]
    -- ACTION UPDATE REPLACE
    if args['replace'] then
      ngx.log(ngx.INFO, " do replace")
      -- TODO! replace other properties
      if type(args['replace'] ) == 'table' then
        if type(args['replace']['content']) == 'table' then
          ngx.log(ngx.INFO, "do replace content")
          local sProperty = 'content'
          local sItem = table.concat(args['replace']['content'], " ")
          -- TODO! for each item
          -- ngx.log(ngx.INFO, "url: " .. sURL )
          -- ngx.log(ngx.INFO, "property: " .. sProperty)
          -- ngx.log(ngx.INFO, "item: " .. sItem)
          local response = replaceProperty(sURL,sProperty,sItem)
          ngx.log(ngx.INFO, "status: ", response.status)
          ngx.log(ngx.INFO,"reason: ", response.reason)
          if reason == 'OK' then
            ngx.status = ngx.HTTP_OK
            ngx.exit( ngx.HTTP_OK )
          end
        else
          return util.requestError(
            ngx.HTTP_BAD_REQUEST,
            'HTTP BAD REQUEST',
            'content value should be in an array')
        end
      else
        return util.requestError(
          ngx.HTTP_BAD_REQUEST,
          'HTTP BAD REQUEST',
          'replace value should be in an array')
      end
    end
    -- ACTION UPDATE DELETE
    if args['delete'] then
      ngx.log(ngx.INFO, 'do action update DELETE')
      ngx.log(ngx.INFO, type(args['delete']) )
      local reason = nil
      -- -- TODO! replace other properties
      -- --local n = #args['delete']
      for key, property in pairs(args['delete']) do
        ngx.log(ngx.INFO, 'keyType:' .. type(key) )
        ngx.log(ngx.INFO, 'propType:' .. type(property) )
        if type(key) == 'number' then
          -- ngx.log(ngx.INFO, 'keyType:' .. key )
          -- ngx.log(ngx.INFO, 'property:' .. property )
          if type(property) == 'string' then
            local response = removeProperty( sURL, property)
            ngx.log(ngx.INFO, "status: ", response.status)
            ngx.log(ngx.INFO,"reason: ", response.reason)
            reason = response.reason
          end
        elseif type(key) == 'string' then
          if type(property) == 'table' then
            for index, item in ipairs (property) do
              ngx.log(ngx.INFO, "url: " .. sURL)
              ngx.log(ngx.INFO, "key: " .. key)
              ngx.log(ngx.INFO, "item: " .. item)
              local response =  removePropertyItem( url, key , item )
              ngx.log(ngx.INFO, "status: ", response.status)
              ngx.log(ngx.INFO,"reason: ", response.reason)
              reason = response.reason
            end
            -- after we have removes properties
          elseif type(property) == 'string' then
            ngx.log(ngx.INFO, "url: " .. sURL)
            ngx.log(ngx.INFO, "key: " .. key)
            -- local reason =  require('grantmacken.eXist').removeProperty( url, property )
            -- if reason == 'OK' then
            --   require('grantmacken.eXist').fetchPostsDoc( url )
            -- end
          end
        end
      end
      ngx.log(ngx.INFO, 'end action update DELETE')
      if reason == 'OK' then
        ngx.status = ngx.HTTP_OK
        ngx.exit( ngx.HTTP_OK )
      end
    end
    -- ACTION UPDATE ADD
    if args['add'] then
      ngx.log(ngx.INFO, 'do action update ADD')
     local reason = nil
     --  ngx.log(ngx.INFO, type(args['add']) )
      for key, property in pairs(args['add']) do
        -- ngx.log(ngx.INFO, 'keyType: '  .. type(key) )
        -- ngx.log(ngx.INFO, 'propType: ' .. type(property) )
        if type(key) == 'number' then
          ngx.log(ngx.INFO, 'TODO! key:' .. key )
        elseif type(key) == 'string' then
          --  ngx.log(ngx.INFO, 'key: ' .. key )
          if type(property) == 'table' then
            for index, item in ipairs (property) do
              ngx.log(ngx.INFO, "url: " .. sURL)
              ngx.log(ngx.INFO, "key: " .. key)
              ngx.log(ngx.INFO, "item: " .. item)
              -- TODO  what if it fails
              local response =  addProperty( sURL, key, item )
              ngx.log(ngx.INFO, "status: ", response.status)
              ngx.log(ngx.INFO,"reason: ", response.reason)
              reason = response.reason
            end
          end
        end
      end
      ngx.log(ngx.INFO, 'end action update ADD')
      if reason == 'OK' then
        ngx.status = ngx.HTTP_OK
        ngx.exit( ngx.HTTP_OK )
      end
    end
    -- end of ACTION UPDATEs
  elseif sAction == 'delete' then
    -- start of ACTION DELETE
    ngx.log(ngx.INFO, "start of ACTION DELETE")
    ngx.log(ngx.INFO, "URL: " .. sURL )
    local response = deletePost( sURL )
    ngx.log(ngx.INFO, "status: ", response.status)
    ngx.log(ngx.INFO,"reason: ", response.reason)
    reason = response.reason
    if reason == 'OK' then
      ngx.status = ngx.HTTP_NO_CONTENT
      ngx.exit( ngx.HTTP_NO_CONTENT )
    end
  elseif sAction == 'undelete' then
    ngx.log(ngx.INFO, "start of ACTION UNDELETE")
    local response =  undeletePost( sURL )
    ngx.log(ngx.INFO, "status: ", response.status)
    ngx.log(ngx.INFO,"reason: ", response.reason)
    reason = response.reason
    if reason == 'OK' then
      ngx.status = ngx.HTTP_OK
      ngx.exit( ngx.HTTP_OK )
    end
  end
end

function createEntryFromJson( hType , props)
  ngx.log(ngx.INFO,  'create XML entry from jData' )
   local root = hType
   local xmlNode = ''
   -- Post Properties
  -- https://www.w3.org/TR/jf2/#post-properties
  local kindOfPost = discoverPostType( props )
  -- in addition to posted properties create following metadata
  local sID = createID( kindOfPost )
  local sURL = 'https://' .. ngx.var.domain .. '/' .. sID
  local sPub, n, err =  ngx.re.sub(ngx.localtime(), " ", "T")

  props['published'] =  { sPub }
  props['uid'] =  { sID  }
  props['url'] = { sURL }

  -- ngx.log(ngx.INFO, 'property: published [ ' .. sPub .. ' ]' )
  -- ngx.log(ngx.INFO, 'property: uid  [ ' .. sID .. ' ]' )
  -- ngx.log(ngx.INFO, 'property: url  [ ' .. sURL .. ' ]' )

   local properties = {}
   local contents = {}
   for property, val in pairs( props ) do
     -- ngx.log(ngx.INFO, 'property', ": ", property)
    -- ngx.log(ngx.INFO, 'value type: ' ..  type(val))
     for i, item in pairs( val ) do
       if type(item) == "table" then
        -- ngx.log(ngx.INFO, ' - every prop value should be a table ' )
         for key, item2 in pairs( item ) do
            -- ngx.log(ngx.INFO,'key', ": ", key)
            -- ngx.log(ngx.INFO,'item2 type: ' ..  type(item2))
           if type(item2) == "string" then
             xmlNode =  '<' .. key .. '>' .. item2 .. '</' .. key .. '>'
             table.insert(contents,xmlNode)
           end
         end
         xmlNode =  '<' .. property .. '>' .. table.concat(contents) .. '</' .. property .. '>'
        table.insert(properties,xmlNode)
      else
         xmlNode =  '<' .. property .. '>' .. item .. '</' .. property .. '>'
        table.insert(properties,xmlNode)
      end
    end
  end
 local xmlDoc =  '<' .. root .. '>' .. table.concat(properties) .. '</' .. root .. '>'
 return sID, xmlDoc
end

function processJsonTypes(args)
  -- ngx.log(ngx.INFO, ' assume we are creating a post item' )
  if type(args['type']) == 'table' then
    local jType = table.concat(args['type'], ", ")
    local hType, n, err = ngx.re.sub(jType, "h-", "")
    ngx.log(ngx.INFO, ' hType: [ ' .. hType .. ' ]' )
    if hType then
      if not microformatObjectTypes[hType] then
        msg = 'can not handle microformat  object type": ' .. hType
        return util.requestError(
          ngx.HTTP_NOT_ACCEPTABLE,
          'not accepted',
          msg )
      end
      -- TYPE ENTRY
      if hType == 'entry' then
        if type(args['properties']) == 'table' then
          ngx.log(ngx.INFO, ' - CREATE ' ..  hType)
          local sID, xmlBody = createEntryFromJson( hType , args['properties'] )
          local sPath = '/exist/rest/db/data/' .. ngx.var.domain .. '/docs/posts/' .. sID
          local response = doPut( sID, sPath, xmlBody)
          ngx.log(ngx.INFO, " - Response Status: " .. response.status)
          ngx.log(ngx.INFO, " - Response Reason: " .. response.reason)
          end
        end
      end
  end
end

function processJsonBody( )
  ngx.log(ngx.INFO, ' ======================' )
  ngx.log(ngx.INFO, ' process Json Body ' )
  ngx.log(ngx.INFO, ' ======================' )
  -- ngx.req.read_body()
  local get, post, files = reqargs()
  if not post then
    msg = " - failed to get post body: " ..  err
    return util.requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
      msg)
  end
  if not ( next(post)  ) then
    msg = " - failed (json body should not be empty)"
    return util.requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
      msg)
  end
  -- either 'ACTION' to modify post or 'TYPE' to create type of post
  if post['action'] then
     processActions( 'json' , post )
  elseif post['type'] then
     processJsonTypes(post)
  else
    msg = "sent json body should contain either 'action' or 'type' as keys"
    return util.requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
      msg)
  end
end

local function processPostArgs()
  ngx.log(ngx.INFO, ' ======================' )
  ngx.log(ngx.INFO, ' process POST arguments ' )
  ngx.log(ngx.INFO, ' ======================' )
  local msg = ''
  local args = {}
  ngx.req.read_body()
  local get, post, files = reqargs(  )
  if not get then
    msg = "failed to get post args: " ..  err
    return util.requestError(
    ngx.HTTP_NOT_ACCEPTABLE,
    'not accepted',
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
    --ngx.log(ngx.INFO, ' - count post args ' .. getItems )
    args = get
  end

  if  postItems > 0 then
    --ngx.log(ngx.INFO, ' - count post args ' .. postItems )
    args = post
  end

  -- ngx.log(ngx.INFO, 'args')
  -- for key, val in pairs(args) do
  --   if type(val) == "table" then
  --     ngx.log(ngx.INFO,'key', ": ", key)
  --     ngx.log(ngx.INFO, 'value type: ' ..  type(val))
  --     for k, v in pairs( val ) do
  --       ngx.log(ngx.INFO,'key', ": ", k)
  --       ngx.log(ngx.INFO, 'value type: ' ..  v)
  --     end
  --   else
  --     ngx.log(ngx.INFO,'key', ": ", key)
  --     ngx.log(ngx.INFO, 'value: ' ..  val)
  --   end
  -- end

  if args['h'] then
    local hType = args['h']
    if microformatObjectTypes[hType] then
      ngx.log(ngx.INFO,  ' - assume we are creating a post item'  )
    else
      msg = 'can not handle microformat  object type": ' .. hType
      return util.requestError(
      ngx.HTTP_NOT_ACCEPTABLE,
      'not accepted',
      msg )
    end
    ngx.log(ngx.INFO,  'Microformat Object Type: ' .. args['h'] )
    -- --  Post object ref: http://microformats.org/wiki/microformats-2#v2_vocabularies
    -- --  TODO if no type is specified, the default type [h-entry] SHOULD be used.
    if hType == 'entry' then
      ngx.log(ngx.INFO, ' - create entry' )
         -- ngx.log(ngx.INFO, ' - from the sent properties - discover the kind of post ')
         -- local kindOfPost = discoverPostType( post )
         -- ngx.log(ngx.INFO, 'kindOfPost: [ ' .. kindOfPost  .. ' ]')
         local properties, kindOfPost = createMf2Properties( args )
         local jData = {
           ['type']  =  'h-' ..  hType,
           ['properties'] = properties
         }

         ngx.log(ngx.INFO,  ' - post args serialised as mf2' )
         ngx.log(ngx.INFO,   jData['type'] )
         ngx.log(ngx.INFO,  ' - serialize jData as XML nodes and store in eXist db' )
      --    local uID = jData.properties.uid[1]
      --    -- tasks depends on type of post
      local xmlEntry = createXmlEntry(jData)
      local uID = jData.properties.uid[1]
      ngx.log(ngx.INFO,  xmlEntry )
      ngx.log(ngx.INFO,  uID )
      local sAddress, sMsg = req.getAddress( 'ex' )
      -- ngx.log(ngx.INFO,  sMsg )
      local sConnect = req.connect( sAddress, 8080 )
      -- ngx.log(ngx.INFO,  sConnect )
      -- ngx.log(ngx.INFO, sPath )
      local sAuth = 'Basic ' .. ngx.var.exAuth
      -- ngx.log(ngx.INFO, auth )
      local tHeaders = {}
      tHeaders["Content-Type"] =  'application/xml'
      tHeaders["Authorization"] =  sAuth
      local sPath = '/exist/rest/db/data/' .. ngx.var.domain .. '/docs/posts/' .. uID

      local tRequest = {
        method = 'PUT',
        path = sPath,
        headers = tHeaders,
        ssl_verify = false,
        body = xmlEntry
      }
      req.http:set_timeout(6000)
      local response, err = req.http:request( tRequest )
      if not response then
        ngx.log(ngx.ERR, ' - FAILED to get response: ' .. err)
      end
      ngx.log(ngx.INFO, " - Response Status: " .. response.status)
      ngx.log(ngx.INFO, " - Response Reason: " .. response.reason)
      -- for k,v in pairs(response.headers) do
      --   ngx.log( ngx.INFO,  k " " .. v )
      -- end
      -- if response.has_body then
      --   body, err = response:read_body()
      --   if not body then
      --     ngx.log(ngx.ERR, 'FAILED to get read body: ' .. err)
      --   else
      --     ngx.log( body )
      --   end
      -- end
      if kindOfPost == 'reply' then
        ngx.log(ngx.INFO,  kindOfPost  ..  ' additional tasks ' )
        -- my page
        local source = jData.properties.url[1]
        -- TODO may have more than one in-reply-to
        local target = jData.properties['in-reply-to'][1]
        local endpoint = require('grantmacken.endpoint').discoverWebmentionEndpoint( target )
        if endpoint ~= nil then
          ngx.log(ngx.INFO, 'source: [ '  .. source .. ' ]' )
          ngx.log(ngx.INFO, 'target: [ '  .. target .. ' ]' )
          ngx.log(ngx.INFO, 'endpoint: [ '  .. endpoint .. ' ]' )
          local mention = sendWebMention( endpoint, source, target )
        else
          ngx.log(ngx.INFO, 'could NOT discover endpoint' )
        end
      end
      --  POSSE Post Own Site Syndicate Elsewhere
      --  mp-syndicate-to ( comma separated list)
      --  this property is giving a command to the Micropub endpoint,
      --  rather than just creating data, so it uses the mp-prefix
      if ( args['mp-syndicate-to'] ~= nil  ) then
        local elsewhere = args['mp-syndicate-to']
        -- TODO! split on comma
        if ( elsewhere == 'https://twitter.com' ) then
          ngx.log(ngx.INFO, 'Syndicate Elsewhere ' .. elsewhere )
          ngx.log(ngx.INFO, ' content ' ..  args['content'] )
          require('grantmacken.syndicate').syndicateToTwitter( args['content'] )
          -- jData.properties['in-reply-to'][1]

          -- require('grantmacken.syndicate').syndicateToTwitter( post[] )
          --local tweet = require('grantmacken.syndicate').syndicateToTwitter( jData )
        end
      end
      -- Finally
      if response.reason == 'Created' then
        ngx.log(ngx.INFO, ' created entry: ' .. jData.properties.url[1] )
        ngx.log(ngx.INFO, '# EXIT ...... # ' )
        ngx.header['Location'] = jData.properties.url[1]
        ngx.exit(ngx.HTTP_CREATED)
      end
    end
  elseif args['action'] then
    ngx.log(ngx.INFO,  ' assume we are modifying a post item in some way'  )
     processActions( 'form' , args )
  else
    ngx.log(ngx.INFO, ' - create entry' )
    msg = "failed to get actionable POST argument, h or action required"
    return util.requestError(
    ngx.HTTP_NOT_ACCEPTABLE,
    'not accepted',
    msg )
  end
end


function _M.processRequest()
  ngx.log( ngx.INFO, 'Process Request for '  .. ngx.var.domain )
  local method =  util.acceptMethods({"POST","GET"})
  ngx.log( ngx.INFO, 'Accept Method: ' .. method )
  if method == "POST" then
      local contentType = util.acceptContentTypes({
      'application/json',
      'application/xml',
      'application/x-www-form-urlencoded',
      'multipart/form-data'
    })
    ngx.log( ngx.INFO, 'Accept Content Type: ' .. contentType )
    if contentType  == 'application/x-www-form-urlencoded' then
      processPostArgs()
    elseif contentType  == 'multipart/form-data' then
      -- processMultPartForm()
    elseif contentType  == 'application/json' then
      processJsonBody()
    elseif contentType  == 'application/xml' then
        ngx.log( ngx.INFO, 'Process: ' .. contentType )

        ngx.req.read_body()
        local data = ngx.req.get_body_data()
        ngx.say(type(data))
    end
  else
    processGet()
  end
end


return _M
