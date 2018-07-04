xquery version "3.1";
module namespace feed="http://gmack.nz/#feed";
import module namespace templates="http://exist-db.org/xquery/templates";

(: import module namespace util="http://exist-db.org/xquery/util"; :)
(: import module namespace xmldb="http://exist-db.org/xquery/xmldb"; :)
(: import module namespace response="http://exist-db.org/xquery/response"; :)
(: import module namespace note="http://markup.co.nz/#note" at "../lib/note.xqm"; :)
(:~
FEED
@author Grant MacKenzie
@version 0.01
info: pages vs posts
this is the xQuery module for providing a 'feed' view of entries posted to this site

routes: ../api/router.xqm

  archive-views: provide  date stamped landing pages
  - a feed of recent  entries   e.g.   /               last 20 entries displayed on home page
  - a feed of archived entries  e.g.   /YYYY/MM          entries for month
  - a feed of a 'type of entry' e.g.   /notes          last 40 notes
                                       /articles/2016  articles published/updated on date 

  tagged view (all posted categorised as ) /tags/[tag-name]
                                e.g.    /tags/tag       entries categorised as .. tag
  search view
:)

declare
function feed:info($node as node(), $model as map(*)) {
  ()
};

declare
function feed:getKindOfPost( $id ) {
   switch( substring( $id,1,1) )
      case 'n' return 'note'
      case 'r' return 'reply'
      case 'a' return 'article'
      case 'p' return 'photo'
      default return 'note'
};

(: note 
TODO!


    for $entry at $i in xmldb:xcollection($model('data-posts'))/*
    order by xs:dateTime($entry/published) descending
    return 
      templates:process(
        element article {
          attribute class {
            'templates:include?path=templates/includes/' ||
           'note'  ||
            '.html' }
            },
            map:new(($model,
            map {
            'kind' := 'note',
            'id' := $entry/uid/string(),
            'url' := $entry/url/string(),
            'published' :=  $entry/published/string(),
            'category' :=  if( $entry/category/text()) then ($entry/category/string()) else(),
            'photo' :=  if( $entry/photo/text()) then ($entry/photo/string()) else(),
            'content' :=  $entry/content
            }))
       )
:)

declare
function feed:recent-entries($node as node(), $model as map(*)) {
    for $entry at $i in xmldb:xcollection($model('data-posts'))/*
    order by xs:dateTime($entry/published) descending
    let $kindOfPost := feed:getKindOfPost( $entry/uid/string() )
    let $dataMap := map {
    'kind' := $kindOfPost,
    'id' := $entry/uid/string(),
    'url' := $entry/url/string(),
    'published' :=  $entry/published/string(),
    'category' :=  if( $entry/category/text()) then ($entry/category/string()) else(),
    'in-reply-to' :=  if( $entry/in-reply-to/text()) then ($entry/in-reply-to/string()) else(),
    'syndicate-to' :=  if( $entry/syndicate-to/text()) then ($entry/syndicate-to/string()) else(),
    'photo' :=  if( $entry/photo/text()) then ($entry/photo/string()) else(),
    'content' :=  if( $entry/content ) then ($entry/content) else ()
    }
    return
      templates:process(
        element article {
          attribute class {
          'templates:include?path=templates/includes/' ||
          $kindOfPost  ||
          '.html' }
            },
            map:new(($model,$dataMap))
       )
};

declare
function feed:tagged-entries($node as node(), $model as map(*)) {
  let $filter := xmldb:xcollection($model('data-posts'))/entry[category =  $model('tag')]
  return (
   element h2 {
    count($filter) || ' tagged as ' || $model('tag')
    },
for $entry at $i in $filter
    order by xs:dateTime($entry/published) descending
   let $kindOfPost := feed:getKindOfPost( $entry/uid/string() )
    let $dataMap := map {
    'kind' := $kindOfPost,
    'id' := $entry/uid/string(),
    'url' := $entry/url/string(),
    'published' :=  $entry/published/string(),
    'category' :=  if( $entry/category/text()) then ($entry/category/string()) else(),
    'in-reply-to' :=  if( $entry/in-reply-to/text()) then ($entry/in-reply-to/string()) else(),
    'syndicate-to' :=  if( $entry/syndicate-to/text()) then ($entry/syndicate-to/string()) else(),
    'photo' :=  if( $entry/photo/text()) then ($entry/photo/string()) else(),
    'content' :=  if( $entry/content ) then ($entry/content) else ()
    }
    return 
      templates:process(
        element article {
          attribute class {
            'templates:include?path=templates/includes/' ||
            $kindOfPost ||
            '.html' }
            },
            map:new(($model, $dataMap))
       )

)
};
