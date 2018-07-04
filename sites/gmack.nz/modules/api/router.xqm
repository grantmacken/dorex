xquery version "3.1";
(:~      main app routes
@author  Grant MacKenzie
@version 0.1

this app is proxied behind openresty/nginx 

-------------------------------------------

GET routes deliver a hyperlinked website

website:
 - render docs in named collections -  pages
 - render docs in date archive      -  posts
 - 

 pages/home/index.html - home-page
 pages/about/index.html  about-page
 pages/tags/index.html   list named tags
 pages/tags/{tag-name}   list entries tagged as

 posts/{ID}.html         a dated entry
 posts/latest            latest dated entries
 posts/2016/10/01        this days entries
 posts/2016/10           this months entries
 posts/2016              this years entries
 posts/                  all posts

-------------------------------------------
:)

module namespace router = "http://gmack.nz/#router";

import module namespace templates="http://exist-db.org/xquery/templates";
(: import module namespace req="http://exquery.org/ns/request"; :)

(: include my modules here  vim-note: `gf` to go to at files below :)
import module namespace archive="http://gmack.nz/#archive" at "../lib/archive.xqm"; 
import module namespace note="http://gmack.nz/#note" at "../lib/note.xqm";
import module namespace site="http://gmack.nz/#site" at "../render/site.xqm";
import module namespace feed="http://gmack.nz/#feed" at "../render/feed.xqm"; 
import module namespace entry="http://gmack.nz/#entry" at "../render/entry.xqm";
import module namespace muURL="http://markup.nz/#muURL" at "../lib/muURL.xqm";
import module namespace muUtility="http://markup.nz/#muUtility" at "../lib/muUtility.xqm";
(:############################################################################:)

declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace pkg="http://expath.org/ns/pkg";

declare namespace rest="http://exquery.org/ns/restxq";
declare namespace http="http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
(: declare option output:method "html5"; :)
(: declare option output:html-version "5"; :)
(: declare option output:media-type "text/html"; :)
(: declare option output:indent "yes"; :)

(:Determine the application base from the current module load path :)
declare variable $router:base := 
   substring-before( replace(
 system:get-module-load-path(),
 '^(xmldb:exist://)?(embedded-eXist-server)?(.+)$',
 '$3'), '/modules')
;

declare variable $router:domain :=
  substring-after( $router:base, 'apps/')
;

declare variable $router:root := substring-before( $router:base,'/apps/');
declare variable $router:dPath  := $router:root    || '/data/' || $router:domain;
declare variable $router:dDocs  := $router:dPath   || '/docs';
declare variable $router:dRecyle  := $router:dPath || '/docs/recycle';
declare variable $router:dPosts := $router:dPath   || '/docs/posts';
declare variable $router:dPages := $router:dPath   || '/docs/pages';
declare variable $router:dUploads := $router:dPath || '/docs/uploads';
declare variable $router:dMentions := $router:dPath || '/docs/mentions';
declare variable $router:dMedia := $router:dPath   || '/media';

declare variable $router:repo  := doc($router:base ||  "/repo.xml");
declare variable $router:pkg   := doc($router:base ||  "/expath-pkg.xml");
(: templates :)
declare variable $router:tPosts := $router:base ||  "/templates/posts";
declare variable $router:tPages := $router:base ||  "/templates/pages";
declare variable $router:tTags  := $router:base ||  "/templates/tags";
declare variable $router:nl := "&#10;";

declare variable $router:map := map {
  'domain'  := $router:domain,
  'author'  := $router:repo//repo:author/string(),
  'website' := $router:repo//repo:website/string(),
  'gravatar'    :=  'http://0.gravatar.com/avatar/0650d3fbdb61ed5d8709eda6b80c3e47',
  'description' := $router:repo//repo:description/string(),
  'version' :=  $router:pkg/pkg:package/@version/string(),
  'title' :=  $router:pkg//pkg:title/string(),
  'data-posts'  := $router:dPosts,
  'data-pages'  := $router:dPages,
  'data-mentions'  := $router:dMentions,
  'data-media'  := $router:dMedia
};

declare variable $router:config := map {
  $templates:CONFIG_APP_ROOT := $router:base,
  $templates:CONFIG_STOP_ON_ERROR := true(),
  $templates:CONFIG_PARAM_RESOLVER := function($param as xs:string) as xs:string* {req:parameter($param)}
};

declare variable $router:error := map {
'notFound' := QName( 'http://gmack.nz/#router','documentNotAvailable'),
'wmError'  : QName( 'http://gmack.nz/#router','webmentionError')
};

declare variable $router:lookup :=function($functionName as xs:string, $arity as xs:int) {
  try {
    function-lookup(xs:QName($functionName), $arity)
  } catch * {()}
};

declare
    %rest:GET
    %rest:path( "/gmack.nz/pages/home.html")
    %output:media-type("text/html")
    %output:method("html")
function router:home() {
  try {
  let $templatePath := $router:tPages || "/" || "home.html"
  let $template :=
      if (doc-available($templatePath)) then (doc($templatePath)) else (
        fn:error(
        $router:error('notFound'),
        'template not available on path: ' || substring-after( $templatePath , $router:base || '/')
        )
       )
 return
  templates:apply($template, $router:lookup, $router:map, $router:config )
 }
  catch * {(
  <rest:response>
    <http:response status="200" message="OK">
     <http:header name="Link" value="&lt;https://gmack.nz/webmention&gt; rel='webmention'"/>
    </http:response>
  </rest:response>,
  <div>
    <h1> TODO! </h1>
    <p>error code - {$err:code}</p>
    <p>error description - {$err:description}</p>
    <p>error line number- {$err:line-number}</p>
    <p>error module - {$err:module}</p>
  </div>
    )}
};

(:
posts templates
---------------
html template based on 'kind of post' 
- postType:  entry/@kind/string()

gf: templates/posts/note.html
:)

declare
    %rest:GET
    %rest:path( "/gmack.nz/posts/{$id}")
    %output:media-type("text/html")
    %output:method("html5")
function router:posts($id as xs:string) {
  try {
  let $uid := substring-before($id,'.')
  let $kindOfPost :=
   switch( substring( $id,1,1) )
      case 'n' return 'note'
      case 'r' return 'reply'
      case 'a' return 'article'
      case 'p' return 'photo'
      default return 'note'

  let $docsPath := $router:dPosts || '/' || $uid
  let $data :=
      if (doc-available($docsPath)) then (doc($docsPath)) else (
        fn:error($router:error('notFound'), $docsPath || ' :  data doc not available on path' )
       )

  let $templatePath := $router:tPosts || "/" || $kindOfPost || ".html"
  let $template :=
      if (doc-available($templatePath)) then (doc($templatePath)) else (
        fn:error($router:error('notFound'),'template doc not available on path' )
       )
  (:
  create an new map  by combining router:map ( site-wide stuff )
  :)
  let $dataMap := map {
    'kind' := $kindOfPost,
    'id' := $data/entry/uid/string(),
    'url' := $data/entry/url/string(),
    'published' :=  $data/entry/published/string(),
    'category' :=  if( $data/entry/category/text()) then ($data/entry/category/string()) else(),
    'in-reply-to' :=  if( $data/entry/in-reply-to/text()) then ($data/entry/in-reply-to/string()) else(),
    'syndicate-to' :=  if( $data/entry/syndicate-to/text()) then ($data/entry/syndicate-to/string()) else(),
    'photo' :=  if( $data/entry/photo/text()) then ($data/entry/photo/string()) else(),
    'content' :=  if( $data/entry/content ) then ($data/entry/content) else ()
    }
(:  content is a node everything else a string or a sequence:)

  let $map := map:new(( $router:map, $dataMap ))
  return (
      <rest:response>
        <http:response status="200" message="OK">
          <http:header name="Link" value="&lt;https://gmack.nz/webmention&gt; rel='webmention'"/>
        </http:response>
      </rest:response>,
    templates:apply($template, $router:lookup, $map, $router:config )
    )
    }
  catch * {
    if ( xs:string($err:code) eq 'router:documentNotAvailable' ) then (
        <rest:response>
        <http:response status="404"/>
        </rest:response>,
        templates:apply(
        doc($router:tPages || '/not-found.html'),
        $router:lookup, 
        map:new(( $router:map, map {
            'id' := substring-before($id, '.html'),
            'module' := $err:module,
            'code' := $err:code,
            'line-number' := $err:line-number,
            'description' := $err:description
            } )),
        $router:config
        ))
    else
    (
     <rest:response>
     <http:response status="404"/>
     </rest:response>,
     <div>
     <h1> TODO! </h1>
     <p>{$id}</p>
     <p>error code - {$err:code}</p>
     <p>error description - {$err:description}</p>
     <p>error line number- {$err:line-number}</p>
     <p>error module - {$err:module}</p>
     </div>
    )
  }
 };

declare
%rest:GET
%rest:path("/gmack.nz/tags/{$id}")
%output:media-type("text/html")
%output:method("html5")
function router:tags($id as xs:string) {
  try {
    let $templatePath := $router:tPosts || "/tags.html"
    let $template :=
      if (doc-available($templatePath)) then (doc($templatePath)) else (
          fn:error($router:error('notFound'),'template doc not available on path' )
          )
  let $sID := substring-before($id, '.html')
  let $dataMap := map {
    'tag' :=  $sID 
    }

  let $map := map:new(( $router:map, $dataMap ))

  return
    templates:apply($template, $router:lookup, $map, $router:config )
}
catch * {(
      <rest:response>
      <http:response status="404"/>
      </rest:response>,
      <div>
      <h1> TODO! </h1>
      <p>{$id}</p>
      <p>error code - {$err:code}</p>
      <p>error description - {$err:description}</p>
      <p>error line number- {$err:line-number}</p>
      <p>error module - {$err:module}</p>
      </div>
      )}
};

 (:  HTML doc assets

  - scripts
  - styles
  - icons

 :)

declare
    %rest:GET
    %rest:path("/gmack.nz/resources/styles/{$css}")
    %output:media-type("text/css")
    %output:method("text")
function router:styles( $css ) {
  if ( util:binary-doc-available($router:base || "/resources/styles/" || $css ))
    then (util:binary-to-string( util:binary-doc( $router:base || "/resources/styles/" || $css )))
  else ('ERROR')
};

declare
    %rest:GET
    %rest:path("/gmack.nz/resources/scripts/{$script}")
    %output:media-type("application/x-javascript")
    %output:method("text")
function router:script( $script ) {
  if ( util:binary-doc-available($router:base || "/resources/scripts/" || $script ))
    then (util:binary-to-string( util:binary-doc( $router:base || "/resources/scripts/" || $script )))
  else ('ERROR')
};

declare
    %rest:GET
    %rest:path("/gmack.nz/resources/icons/{$icons}")
    %output:method("xml")
function router:icons( $icons ) {
if (doc-available($router:base || "/resources/icons/" || $icons ))
  then (doc($router:base || "/resources/icons/" || $icons )) else (
  fn:error($router:error('notFound'),'data not available on path' )
  )
};

declare
  %rest:GET
  %rest:path("/gmack.nz/media/{$id}")
  %output:method("binary")
  %output:media-type("application/octet-stream")
  function router:media( $id ) {
  try {
  if ( util:binary-doc-available($router:dMedia || "/" || $id ))
    then ( util:binary-doc( $router:dMedia || "/" || $id) )
  else (
    fn:error($router:error('notFound'),'data not available on path' )
    )
  }
  catch * {(
      <rest:response>
        <output:serialization-parameters>
        <output:media-type value='application/xml'/>
        <output:method value='xml'/>
      </output:serialization-parameters>
        <http:response status="200"/>
      </rest:response>,
      <div>
      <p>error code - {$err:code}</p>
      <p>error description - {$err:description}</p>
      <p>error line number- {$err:line-number}</p>
      <p>error module - {$err:module}</p>
      </div>
      )}
};
