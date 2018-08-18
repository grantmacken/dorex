local _M = {}

local cjson = require("cjson")
-- local re = require("ngx.re")

_M.version = '0.0.1'

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

_M.contains = contains

return _M
