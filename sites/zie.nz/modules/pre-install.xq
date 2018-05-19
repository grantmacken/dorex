xquery version "3.1";
import module namespace xdb="http://exist-db.org/xquery/xmldb";
declare variable $home external;
declare variable $dir external;
declare variable $target external;
declare variable $domain   := substring-after( string($target), '/apps/');
declare variable $pages    := 'data/' || $domain || '/docs/pages';
declare variable $posts    := 'data/' || $domain || '/docs/posts';
declare variable $recycle  := 'data/' || $domain || '/docs/recycle';
declare variable $uploads  := 'data/' || $domain || '/docs/uploads';
declare variable $mentions := 'data/' || $domain || '/docs/mentions';
declare variable $media    := 'data/' || $domain || '/media';

declare function local:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xdb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
      ()
};

declare function local:mkcol($collection, $path) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
};

local:mkcol("/db/system/config", $target),
local:mkcol("/db", $pages),
local:mkcol("/db", $posts),
local:mkcol("/db", $recycle),
local:mkcol("/db", $uploads),
local:mkcol("/db", $mentions),
local:mkcol("/db", $media),
xdb:store-files-from-pattern(concat("/db/system/config", $target), $dir, "*.xconf")