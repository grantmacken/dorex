xquery version "3.1";
(:~
xThis module provides the functions that extract frontmatter from a markdown
document.
@author Grant Mackenzie
@version 1.0
@see modules/tests/lib/muFrontmatter.xqm
:)
module namespace muFrontmatter = "http://gmack.nz/#muFrontmatter";
import module namespace util = "http://exist-db.org/xquery/util";

declare variable $muFrontmatter:ERROR-canNotParse := xs:QName("muFrontmatter:ERROR-canNotParse");

(:~xx
given text containing html comment frontmatter source extract content
@param $source  md doc containing html frontmatter
@return frontmatter
:)
declare function muFrontmatter:extract($source){
  let $src := normalize-space( $source )
  let $pattern :=  '^<!\-\-'
  let $flags := ''
  return
  if ( matches( $src, $pattern, $flags ) )
    then (
        normalize-space( substring-after(substring-before( $src, '-->' ), '<!--'))
        )
  else(
      util:log-system-out( 'no match' )
      )
};

(:~
given text containing html comment frontmatter source extract content
@param $source  md doc containing html frontmatter
@return frontmatter
:)
declare function muFrontmatter:normalize( $string, $token ){
  let $options := map { "liberal": true(), "duplicates": "use-last" }
  let $lines := tokenize( $string , '\n')
  let $log-out := util:log-system-out(count($lines))
  let $prop := 
    for $line in $lines
      let $key := replace( substring-before($line, $token ), '\C', '' ) 
      let $val := normalize-space( substring-after($line, $token) )
      return ( $key || ': "' || $val || '"' )
  (: let $log-out := util:log-system-out($prop) :)
  let $wrap := '{' || $prop || '}'
  return
      parse-json( $wrap, $options )
};

(:~
given markdown text beginning with a html comment as 'frontmatter'
then the parse function should try to convert the 'frontmatter' into a 
map item ( instance of map )
@param $source  md doc containing html frontmatter
@return instance of map
@see modules/tests/lib/muFrontmatter.xqm;t-muFrontmatter:parse_1
@see modules/tests/lib/muFrontmatter.xqm;t-muFrontmatter:parse_2
@see modules/tests/lib/muFrontmatter.xqm;t-muFrontmatter:parse_3
@see modules/tests/lib/muFrontmatter.xqm;t-muFrontmatter:parse_4
@see modules/tests/lib/muFrontmatter.xqm;t-muFrontmatter:parse_5
:)
declare function muFrontmatter:parse($source) as map(){
  let $string := normalize-space( muFrontmatter:extract( $source ))
  let $log-out := util:log-system-out($string)
  let $options := map { "liberal": true(), "duplicates": "use-last" }
  return
  try{
    if ( starts-with( $string, '{' ) )
      then (
          parse-json( $string, $options )
          )
    else if ( contains( $string, '=' ) )
      then (
        muFrontmatter:normalize( $string, '=' )
        )
    else if ( contains( $string, ':' ) )
      then (
        muFrontmatter:normalize( $string, ':' )
        )
    else (
       error($muFrontmatter:ERROR-canNotParse, "Can not parse frontmatter")
        )
  }
  catch * {
    error($muFrontmatter:ERROR-canNotParse, "Can not parse frontmatter")
    }
};

(:~
get the property key value from a front matter source
@param $prop    property 'key'
@param $source  md doc containing html frontmatter
@return property 'value'
@see modules/tests/lib/muFrontmatter.xqm;t-muFrontmatter:getProperty
:)
declare function muFrontmatter:getProperty( $prop, $source){
  let $map := muFrontmatter:parse( $source )
  return
  (
  util:log-system-out( $map($prop) ),
  $map($prop)
  )
 };
