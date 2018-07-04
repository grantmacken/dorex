xquery version "3.1";
import module namespace request="http://exist-db.org/xquery/request";
declare namespace json="http://www.json.org";
declare namespace map="http://www.w3.org/2005/xpath-functions/map";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
(: declare option output:method "json"; :)
(: declare option output:media-type "application/json"; :)
(: declare option output:indent "yes"; :)

declare function local:recurse($node) {
    for $child in $node/node()
    return
        local:render($child)
};

declare function local:render($node) {
    typeswitch($node)
        case text() return $node
        case element(entry)  return
        element { name( $node ) }{(
          element type { attribute json:array {'true'}, 'h-' || name( $node ) },
          element properties { local:recurse($node) })}
        case element(content) return element { name( $node ) }{ local:recurse($node) }
        case element(category) return element { name( $node ) }{ attribute json:array {'true'}, $node/string() }
        case element(published) return element { name( $node ) }{ attribute json:array {'true'}, $node/string() }
        case element(value) return element { name( $node ) }{ $node/string() }
        case element(html) return element { name( $node ) }{ $node/string() }
        default return element { name( $node ) }{ attribute json:array {'true'}, local:recurse($node) }
};


  try {
let $params := 
    <output:serialization-parameters>
      <output:method value="json"/>
      <output:media-type value="application/json"/>
    </output:serialization-parameters>
    let $sID :=  util:binary-to-string( request:get-data() )
    let $log := function( $msg ){util:log-system-out( $msg )}
     let $base := 
      substring-before( replace(
            system:get-module-load-path(),
            '^(xmldb:exist://)?(embedded-eXist-server)?(.+)$',
            '$3'), '/modules')
      let $root := substring-before( $base, '/apps/')
      let $domain := substring-after( $base, 'apps/')
      let $dPath  := $root || '/data/' || $domain
      let $doc := doc( $dPath || '/docs/posts/' || $sID )
      let $nl := "&#10;"
      let $seq := $doc/*/*
      let $properties := map {}
      let $jDoc := local:recurse( $doc )
      let $jsn := serialize($jDoc,$params)
    (: local:recurse( doc( $dPath || '/docs/posts/' || $sID )) :)
    (: $nl, :)
    (: $jDoc,$nl, :)
      return $jsn
  }
  catch * {(
      <rest:response>
      <hc:response status="404"/>
      </rest:response>,
      <div>
      <p>error code - {$err:code}</p>
      <p>error description - {$err:description}</p>
      <p>error line number- {$err:line-number}</p>
      <p>error module - {$err:module}</p>
      </div>
      )}
