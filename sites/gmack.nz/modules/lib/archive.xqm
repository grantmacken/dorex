xquery version "3.1";
(:~
module used for archiving and retieving  posts
module uses base60 to encode and decode 2016-10-13

@author gmack.nz
@version 01
@see modules/tests/lib/archive.xqm
:)

module namespace archive = "http://gmack.nz/#archive";

declare namespace contentextraction = "http://exist-db.org/xquery/contentextraction";
declare namespace xh="http://www.w3.org/1999/xhtml";

declare variable $archive:error := map {
'archiveError' := QName( 'http://gmack.nz/#archve','archiveError')
};

(:~
get kind of post from uid
@param $uid a post id
@return   a kind of post string 
:)
declare
function archive:mpPost( $map ){
 let $type :=  substring-after( $map( 'type' ), '-')
 let $isArray := function( $v ){ $v instance of array(*)}
 let $isString := function( $v ){ $v instance of xs:string}
 let $properties := $map( 'properties' )
return
 element { $type } {
  map:for-each($properties, function( $k, $v ){ 
   if ( $isArray( $v )  ) then
    array:for-each( $v ,
      function( $i ) {
         if ( $isString( $i) ) then (
           element { $k } { normalize-space( $i ) }
          (: $i :)
          ) 
        else (
           if ( $i instance of map(*) ) then (
             element { $k } {
              map:for-each($i, function( $key, $val ){
                element { $key } { $val }
                })
              }
             (: proccess content 
             map:keys ( $i ):)
            ) else ()
          )
        }
      )
  else (
      )
   })
  }
};


(:~
get kind of post from uid
@param $uid a post id
@return   a kind of post string 
:)
declare
function archive:getKindOfPost( $uid ){
  switch( substring( $uid,1,1) )
      case "n" return 'note'
      case "r" return 'reply'
      case "a" return 'article'
      case "p" return 'photo'
      default return 'note'
};


(:~
get content
@param $contentNode a post content item
@return   a document node 

TODO!
  md:parse
  util:parse-html
        (: contentextraction:get-metadata-and-content(  $contentNode/value )//xh:body :)
:)
declare
function archive:getContent( $contentNode ){
  if ( $contentNode/html/text() ) then
    try {
        contentextraction:get-metadata-and-content(  $contentNode/html/node() )//xh:body
    } catch * { 
      fn:error($archive:error('archiveError'),'TODO! parse error ' ) 
    }
  else if ( $contentNode/value/text() ) then
    try {
      $contentNode/value/string()
    } catch * { 
      fn:error($archive:error('archiveError'),'TODO! parse error ' ) 
    }
  else ()
};

(:~
encode as base60
@param $n a short date year + days in year
should
@return   a base 60 encoded string 
@see modules/tests/lib/archive.xqm;t-archive:getShortDate
:)
declare
function archive:getShortDate( $date ){
format-date(xs:date($date),"[Y01][d]")
};

(:~
encode as short date as base60 string
@param $n a short date year + days in year
@return   a base 64 encodes string 
@see modules/tests/lib/archive.xqm;t-archive:encode
:)
declare
function archive:encode($n as xs:integer){
let $seq1 := (0 to 9)
let $seq2 := map(function($x) { codepoints-to-string($x) }, string-to-codepoints('A') to string-to-codepoints('H'))
let $seq3 := map(function($x) { codepoints-to-string($x) }, string-to-codepoints('J') to string-to-codepoints('N'))
let $seq4 := map(function($x) { codepoints-to-string($x) }, string-to-codepoints('P') to string-to-codepoints('Z'))
let $seq5 := ('_')
let $seq6 := map(function($x) { codepoints-to-string($x) }, string-to-codepoints('a') to string-to-codepoints('k'))
let $seq7 := map(function($x) { codepoints-to-string($x) }, string-to-codepoints('m') to string-to-codepoints('z'))
let $seqChars := ($seq1, $seq2, $seq3, $seq4, $seq5 , $seq6, $seq7)
let $base := count($seqChars)
let $getRemainder := function($n){($n mod xs:integer($base))}
(: if($n gt 59 ) then (($n mod xs:integer($base)) + 1) :)
(: else($n + 1) :)
(: } :)
let $getChar := function($n){$seqChars[xs:integer($getRemainder($n) + 1)]}
let $nextN := function($n){ ($n - xs:integer($getRemainder($n))) div xs:integer($base)}
let $seqNth := ( xs:integer($nextN($nextN($n))), xs:integer($nextN($n)) , xs:integer($n) )
return
(
string-join(map(function($n){$getChar($n)}, $seqNth),'')
)
};


(:~
decoded base60 
@param encoded
@return decoded
@see modules/tests/lib/archive.xqm;t-archive:decode
:)
declare function archive:decode($b60){
  let $base := 60
(:  The entry point is  $strB60 :)
  let $seqDecode :=
  map(function( $codePoint ){
   let $c := xs:integer($codePoint)
   return
           if ($c >= 48 and $c <= 57 ) then ($c - 48)
     else if ($c >= 65 and $c <= 72 ) then ($c - 55)
     else if ($c eq 73 or $c eq 108 ) then (1)
     else if ($c >= 74 and $c <= 78 ) then ($c - 56)
     else if ($c eq 79 ) then (0)
     else if ($c >= 80 and $c <= 90 ) then ($c - 57)
     else if ($c eq 95 ) then (34)
     else if ($c >= 97 and $c <= 107 ) then ($c - 62)
     else if ($c >= 109 and $c <= 122 ) then ($c - 63)
     else(0)
     },
     (map(function($ch){string-to-codepoints($ch)}, (for $ch in string-to-codepoints($b60)
    return codepoints-to-string($ch)))
     ))
  let $tot := function($n2, $c){xs:integer(($base * $n2) + $c )}
  let $n2 := 0
  let $dc1 := $tot($n2, $seqDecode[1])
  let $dc2 := $tot($dc1, $seqDecode[2])
  let $decoded := $tot($dc2, $seqDecode[3])
  return
   $tot($dc2, $seqDecode[3]  )
};

(:~
convert a decoded  short date into formated date string
@param  decoded short year 
@return a formated date string [yyyy-mm-dd]
@see modules/tests/lib/archive.xqm;t-archive:formatShortDate
:)
declare
function archive:formatShortDate( $decoded ){
  let $yr := '20' || substring($decoded, 1, 2)
  let $yrStart := xs:date($yr || string('-01-01'))
  let $dysInYr := substring($decoded, 3, 5)
  let $duration := xs:dayTimeDuration("P" || string(xs:integer($dysInYr)- 1)  || "D")
  let $decodedDate := xs:date($yrStart + $duration)
  let $formatedDate := format-date($decodedDate, "[Y0001]-[M01]-[D01]", 'en', (), ())
  return
  xs:date($yrStart + $duration)
 };
