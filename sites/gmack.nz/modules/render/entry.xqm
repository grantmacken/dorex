xquery version "3.1";
module namespace entry="http://gmack.nz/#entry";

import module namespace templates="http://exist-db.org/xquery/templates";

(:~
#ENTRY#
@author Grant MacKenzie
@version 0.01
this is the xQuery module for providing a html view of
data in /data/posts
:)

declare
function entry:name($node as node(), $model as map(*)) {
(  element {local-name($node)} {
   $model('domain')
  })
};

declare
function entry:id($node as node(), $model as map(*)) {
(  element {local-name($node)} {
   $model('id')
  })
};

declare
function entry:not-found($node as node(), $model as map(*)) {
(  element {local-name($node)} {
  templates:process( $node/node(), $model )
  })
};

declare
function entry:summary($node as node(), $model as map(*)) {
 ()
};

declare
function entry:published($node as node(), $model as map(*)) {
element {local-name($node)} {
  attribute class { $node/@class/string() },
  attribute datetime { $model('published')},
 format-dateTime($model('published') , "[D1o] of [MNn] [Y]", "en", (), ()) 
  }
};

declare
function entry:permalink($node as node(), $model as map(*)) {
element {local-name($node)} {
  attribute class { $node/@class/string() },
  attribute href { $model('url')},
  attribute rel { $node/@rel/string() },
  attribute title { 'published ' ||  $model('kind') },
  templates:process( $node/node(), $model )
  }
};

declare
function entry:in-reply-to($node as node(), $model as map(*)) {
element {local-name($node)} {
  attribute class { $node/@class/string() },
  attribute href { $model('in-reply-to')},
  attribute rel { $node/@rel/string()},
  attribute title { 'published ' ||  $model('kind') },
   $model('in-reply-to')
  }
};

(:~
kinds of posts
notes, articles, photos
:)


declare
function entry:note($node as node(), $model as map(*)) {
element {local-name($node)} {
  attribute class { $node/@class/string() },
   $model('content')/value/string()
  }
};

declare
function entry:photo($node as node(), $model as map(*)) {
element {local-name($node)} {
  attribute  id { $node/@class/string() },
  attribute class { $node/@class/string() },
   $model('content')/node()
  }
};

declare
function entry:photo-img($node as node(), $model as map(*)) {
element {local-name($node)} {
  attribute class { $node/@class/string() },
  attribute alt { $node/@alt/string() },
  attribute src { $model('photo') }
  }
};

declare
function entry:photo-caption($node as node(), $model as map(*)) {
element {local-name($node)} {
  attribute class { $node/@class/string() },
   $model('content')/node()
  }
};


(:
 if we have a mapped category then 
  process the template
:)

declare
function entry:tags($node as node(), $model as map(*)) {
  if ( empty( $model('category')) ) then ()
  else (
      element {local-name($node)} {
  templates:process( $node/node(), $model )
  }
)
  };

declare
function entry:tag-list($node as node(), $model as map(*)) {
element {local-name($node)} {(
   element small {'tags  [ ' || count($model('category')) || ' ]&#10;'},
  for-each(  $model('category') , function($a) {
  '&#10;' ,
   element a { 
    attribute href { concat('/tags/', $a) }
    , $a }
    }))
  (: $model('category' ) || '  TODO! tokenize and create horizontal list of categories':)
  }
};

declare
function entry:mentions( $node as node(), $model as map(*)) {
let $pagesPath := $model('data-pages')
(: check if we have mentions url :)
let $mentionsPath := $model('data-mentions') || '/' || $model('id')
let $docMentions := doc( $mentionsPath )
(: let $seqMentionSources := :) 
(:   if ( $docMentions instance of document-node() ) then ( :) 
(:      $docMentions//source :)
(:   ) :)
 (: attribute id { $node/@id/string(), :)
(:   else () :)
return
if ( doc( $mentionsPath ) ) then (
  element {local-name($node)} {(
    attribute id { $node/@id/string() },
    templates:process( $node/node(), $model )
    )}
)
else ()
};

declare
function entry:comments( $node as node(), $model as map(*)) {
let $pagesPath := $model('data-pages')
(: check if we have mentions url :)
let $mentionsPath := $model('data-mentions') || '/' || $model('id')
let $docMentions  := doc( $mentionsPath )
let $seqComments  := $docMentions//entry[./in-reply-to]
let $dataMap := map {
  'commentCount' := count($seqComments),
  'commentNodes' := $seqComments
  }

return
if ( doc( $mentionsPath ) ) then (
  element {local-name($node)} {(
    attribute id { $node/@id/string() },
    templates:process( $node/node(),  map:new(($model,$dataMap)) )
   )}
)
else ()
};

declare
function entry:commentsCount( $node as node(), $model as map(*)) {
  element {local-name($node)} { ' [ ' || $model('commentCount')  || ' ] ' }
};

declare
function entry:comment( $node as node(), $model as map(*)) {
  for-each(  $model('commentNodes') , function( $comment ) {
    let $dataMap := map {
      'comment' := $comment
      }
    return (
    templates:process(
        element {local-name($node)} {
          attribute class {
          'templates:include?path=templates/includes/comment.html'}
            },  map:new(($model,$dataMap)) )

    )
  })
};

declare
function entry:commentAuthor( $node as node(), $model as map(*)) {
  element {local-name($node)} {(
    attribute class { $node/@class/string() },
    attribute href { $model('comment')/author//url/string() },
    $model('comment')/author//name/string()
    )}
};

declare
function entry:commentContent( $node as node(), $model as map(*)) {
  element {local-name($node)} {(
    attribute class { $node/@class/string() },
    $model('comment')/content/string()
    )}
};

declare
function entry:commentURL( $node as node(), $model as map(*)) {
  element {local-name($node)} {(
    attribute class { $node/@class/string() },
    attribute href { $model('comment')/url/string() },
    templates:process( $node/node(), $model )
    )}
};

declare
function entry:commentPublished( $node as node(), $model as map(*)) {
  element {local-name($node)} {(
     attribute class { $node/@class/string() },
    $model('comment')/published/string()
    )}
};



(: ( :)
(:     element {local-name($node/*[1])} { $node/*[1]/string() || ' [ ' || count( $seqMentionSources ) || ' ]&#10;'}, :)
(:       for-each(  $seqMentionSources, function($a) { :)
(:     '&#10;' , :)
(:     element a { :)
(:       attribute href {  $a } :)
(:       , $a } :)
(:       })) :)

