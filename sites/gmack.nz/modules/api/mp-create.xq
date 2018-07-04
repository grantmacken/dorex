xquery version "3.1";
import module namespace archive="http://gmack.nz/#archive" at "../lib/archive.xqm";
import module namespace request="http://exist-db.org/xquery/request";

  try {
    let $log := function( $msg ){util:log-system-out( $msg )}
    let $base := 
      substring-before( replace(
            system:get-module-load-path(),
            '^(xmldb:exist://)?(embedded-eXist-server)?(.+)$',
            '$3'), '/modules')
    let $root := substring-before( $base,'/apps/')
    let $domain := substring-after( $base, 'apps/')
    let $dPath  := $root    || '/data/' || $domain
    let $dPosts := $dPath   || '/docs/posts'

    let $nl := "&#10;"
    let $body := util:binary-to-string( request:get-data() )
    let $content :=  archive:mpPost( parse-json( $body ))
    let $store := xmldb:store( $dPosts, $content//uid/string(), $content, 'application/xml' )
    return
    (
    $content
    )
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
