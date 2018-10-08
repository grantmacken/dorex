local _M = {}

local ffi = require("ffi")
local c = ffi.load("libcmark")
ffi.cdef[[
  /*  Simple Interface */
  char *cmark_markdown_to_html(const char *text, size_t len, int options);

  /* Version information */
  int cmark_version(void);
  const char *cmark_version_string(void);
  ]]

local options = {
CMARK_OPT_DEFAULT  = 0,
CMARK_OPT_SOURCEPOS = 1,
CMARK_OPT_HARDBREAKS = 2,
CMARK_OPT_SAFE = 32,
CMARK_OPT_NOBREAKS = 4,
CMARK_OPT_VALIDATE_UTF8 = 16,
CMARK_OPT_SMART= 8
}

-- Simple Interface
function _M.markdownToHtml( text )
  local markdown_to_html  = c.cmark_markdown_to_html

  return
  ffi.string(markdown_to_html(text, string.len(text),0))
end

-- Version information
function _M.version( str )
  local ver =  c.cmark_version_string()
  --  ver is typeof CDATA
  return 
  ffi.string(ver, ffi.sizeof(ver))
end

print(_M.version())


return _M
