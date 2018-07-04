xquery version "3.1";
module namespace site="http://gmack.nz/#site";
import module namespace map="http://www.w3.org/2005/xpath-functions/map";
import module namespace templates="http://exist-db.org/xquery/templates";
(:~
: SITE
: @author Grant MacKenzie
: @version 0.01
: @see ../api/router.xqm
:)

declare
function site:info($node as node(), $model as map(*)) {
  element p { 'model items'},
  element ul {
   map:for-each-entry($model, function($k, $v) {
   element li { $k }
    })
  }
  ,
  element p { 'model strings'},
  element dl {
   map:for-each-entry($model, function($k, $v) {(
   if ( not(($v instance of xs:string) or ($v instance of xs:boolean)  ) )  then ()
    else(
    element dt { $k },
    element dd { string($v)}
   ))}) 
  },
  element p { 'configuration items'},
  element ul {
   map:for-each-entry($model('configuration'), function($k, $v) {
   element li { $k }
    })
  }
  ,
  element p { 'configuration strings'},
  element dl {
   map:for-each-entry($model('configuration'), function($k, $v) {(
   if ( not(($v instance of xs:string) or ($v instance of xs:boolean)  ) )  then ()
    else(
    element dt { $k },
    element dd { string($v) }
   ))}) 
  }
};

(: declare :)
(: function site:ip($node as node(), $model as map(*)) { :)
(:   element {local-name($node)} { :)
(:   (  map:get($model('request'), 'IP')  ) :)
(:   } :)
(: }; :)

(: declare :)
(: function site:is-localhost($node as node(), $model as map(*)) { :)
(:   element {local-name($node)} { :)
(:   (  map:get($model('request'), 'is-localhost')  ) :)
(:   } :)
(: }; :)

(: declare :)
(: function site:nginx-request-uri($node as node(), $model as map(*)) { :)
(:   element {local-name($node)} { :)
(:   (  map:get($model('request'), 'nginx-request-uri')  ) :)
(:   } :)
(: }; :)

(: declare :)
(: function site:header-names($node as node(), $model as map(*)) { :)
(:   element {local-name($node)} { :)
(:   (  map:get($model('request'), 'header-names')  ) :)
(:   } :)
(: }; :)

declare
function site:banner($node as node(), $model as map(*)) {
  element {local-name($node)} {
    attribute title {$model('title')},
    attribute role { $node/@role/string()},
    templates:process( $node/node(), $model )
    }
};


declare
function site:script-livereload($node as node(), $model as map(*)) {
 if ( $model('is-phantom') )then ()
 else if ( $model('is-localhost') )  
 then ( <script src="http://127.0.0.1:35729/livereload.js"></script> )
 else ()
};

declare
function site:title($node as node(), $model as map(*)) {
  element {local-name($node)} {
    attribute title {$node/@title/string()  },
    attribute href {$model('website')},
   $model('domain')
  }
};

declare
function site:author($node as node(), $model as map(*)) {
  element {local-name($node)} {
    attribute title {$model('title')},
    attribute href {$model('website')},
     $model('author')
    }
};

declare
function site:version($node as node(), $model as map(*)) {
  element {local-name($node)} {
     $model('version')
    }
};
(: declare :)
(: function site:name($node as node(), $model as map(*)) { :)
(:   element {local-name($node)} { :)
(:   ( map:get($model('site'), 'name') ) :)
(:   } :)
(: }; :)

(: declare :)
(: function site:abbrev($node as node(), $model as map(*)) { :)
(:   element {local-name($node)} { :)
(:    ( map:get($model('site'), 'abbrev') ) :)
(:   } :)
(: }; :)

(: declare :)
(: function site:pages-nav($node as node(), $model as map(*)) { :)
(: let $home := map:get(map:get($model, 'site'), 'abbrev') :)
(: let $seq := map:get(map:get($model, 'nav'), 'top-level-pages') :)
(: let $reqItem := map:get(map:get($model, 'nav'), 'item') :)
(: let $isItemIndex := map:get(map:get($model, 'nav'), 'item-is-index') :)
(: let $itemCollection := map:get(map:get($model, 'nav'), 'item-collection') :)
(: let $listItems := :)
(:   for $item at $i in $seq :)
(:   return :)
(:   if($item eq 'home') then( :)
(:     if( $item eq $itemCollection) :)
(:          then (<li><strong>{$home}</strong></li>) :)
(:     else (<li><a href="/">{$home}</a></li> ) :)
(:     ) :)
(:   else( :)
(:     if( $item eq $itemCollection ) then ( :)
(:       if( $isItemIndex ) :)
(:         then( :)
(:         <li><strong>{$item}</strong></li> :)
(:         ) :)
(:       else( :)
(:         <li> :)
(:             <a class="under-collection" href="/{$item}">{$item}</a> :)
(:         </li> :)
(:         ) :)
(:       ) :)
(:       else (<li><a href="/{$item}">{$item}</a></li> ) :)
(:   ) :)
(: return :)
(:       <ul> :)
(:           {$listItems} :)
(:       </ul> :)
(: }; :)
