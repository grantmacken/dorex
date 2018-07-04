xquery version "3.1";

(:~
webmention.xq
our webmention endpoint end
@see http://markup.nz/archive/2014/04/24/receiving-webmentions
:)

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "xml";
declare option output:media-type "application/xml";
declare option output:indent "yes";
declare option output:encoding "UTF-8";

(: import module namespace muUtility="http://markup.nz/#muUtility" at "../lib/muUtility.xqm"; :)
import module namespace http = "http://expath.org/ns/http-client";

import module namespace system = "http://exist-db.org/xquery/system";
import module namespace util = "http://exist-db.org/xquery/util";
import module namespace xmldb = "http://exist-db.org/xquery/xmldb";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace response="http://exist-db.org/xquery/response";

(: import my libs :)

import module namespace muURL = "http://markup.nz/#muURL"  at '../lib/muURL.xqm';
import module namespace muSan = "http://markup.nz/#muSan"  at '../lib/muSan.xqm';
import module namespace muCache = "http://markup.nz/#muCache"  at '../lib/muCache.xqm';
import module namespace muUtility = "http://markup.nz/#muUtility"  at '../lib/muUtility.xqm';

let $app-root  :=   substring-before( system:get-module-load-path() ,'/module')
let $mentionStore := 	 $app-root || '/data/jobs/mentions'

let $app-path  :=   substring-after( $app-root ,'//')
let $domain  :=   substring-after( $app-root ,'/apps/')
let $serverName := request:get-server-name()
let $remotePort := request:get-remote-port()
let $remoteAddr := request:get-remote-addr()
let $remoteHost := request:get-remote-host()
let $target := request:get-parameter('target',())
let $tokTarget := tokenize($target,'://')
let $targetProtocol := $tokTarget[1]
let $splitTarget := tokenize($tokTarget[2],'/')
let $targetDomain := $splitTarget[1]
let $targetCollection := $splitTarget[2]
let $targetResource := $splitTarget[count($splitTarget)]

(: $source Thats YOU:  you are mentioning your URL as a source:)
let $source := request:get-parameter('source',())

(:
  https://checkmention.appspot.com/

TODO: to make responsive add job to que
set status then async out to carry out job
If there is a problem notify user

http://www.mnot.net/blog/2013/05/15/http_problem
http://msdn.microsoft.com/en-us/library/dd179357.aspx


:)

let $missingRequiredQueryParameter := function(){
   ( empty($target) or  empty($source) )
}

let $urlNotHttpProtocal := function(){
    not(starts-with( $targetProtocol, 'http' ))
}


let $isStatusOK := function( $header ){
   $header/@status = 200
}

let $isTargetWebMentionLinkInHeader := function( $head ){
  let $string := $head//http:header[@name='link'][contains(./@value/string() , 'rel="webmention"')]/@value/string()
  return
  if (empty($string)) then ( not(empty($string)))
  else(
   not(empty(substring-after( substring-before($string , '>'), '<')))
  )
}

let $isTargetWebMentionLinkInHead := function( $page ){
  not(empty($page//*[local-name(.) eq 'link'][@rel="webmention"]/@href/string()))
}

let $isTargetValidResource := function($head, $page){
    if($isTargetWebMentionLinkInHeader($head)) then (true())
    else if ($isTargetWebMentionLinkInHead($page)) then (true())
    else (false())
    }

let $sourceHasTextContentType := function( $page ){
  let $string := $page//http:header[@name="content-type"][contains(./@value/string() , 'text/html')]/@value/string()
  return
  not(empty($string))
}

let $sourcelinksToTarget  := function($page, $target){not(empty($page//*[@href=$target]))}

let $condition :=
    if( $missingRequiredQueryParameter() ) then (
        <problem xmlns="urn:ietf:rfc:XXXX">
            <title>Missing Required Query Parameter</title>
            <detail>Query parameters must be target and source</detail>
        </problem>)
    else if( $urlNotHttpProtocal() ) then (
        <problem xmlns="urn:ietf:rfc:XXXX">
            <title>Specified target URL MUST contain the http protocol</title>
            <detail>{$target} does not have http protocal </detail>
        </problem>
         )
   else if( $targetDomain ne $domain ) then (
        <problem xmlns="urn:ietf:rfc:XXXX">
            <title>Specified target URL MUST point to my domain</title>
            <detail>The request query parameter ```target```  </detail>
        </problem>
         )
       else if( $targetCollection ne 'archive') then (
        <problem xmlns="urn:ietf:rfc:XXXX">
            <title>Specified target URL MUST point to an archived post</title>
            <detail>Target: {$target}  </detail>
        </problem>
         )
   else(
   let $reqTarget :=
        <http:request href="{ $target }" method="get" timeout="5">
    	<http:header name="Connection" value="close" />
        </http:request>
   let $wmTarget := http:send-request( $reqTarget )
   let $wmTargetResponseHeaders := $wmTarget[1]
   let $wmTargetResponseBody := $wmTarget[2]
   let $targetProblems :=
        if( not( $isStatusOK($wmTargetResponseHeaders)) ) then (
         <problem xmlns="urn:ietf:rfc:XXXX">
            <title>Specified target URL not found.</title>
            <detail>{$target} not found</detail>
        </problem>
        )
        else if(  not( $isTargetValidResource($wmTargetResponseHeaders, $wmTargetResponseBody))
        ) then (
        <problem xmlns="urn:ietf:rfc:XXXX">
            <title>Specified target URL does not accept webmentions. </title>
            <detail>{$target} No 'webmention' endpoint found in either response 'headers' or the response html 'head' </detail>
        </problem>
        )
        else()
   return
      if( empty($targetProblems) ) then (
       let $sourceProblems := ''
       let $reqSource :=
            <http:request href="{ $source }" method="get" timeout="10">
        	<http:header name="Connection" value="close" />
            </http:request>
        let $wmSource := http:send-request( $reqSource )
        let $wmSourceResponseHeaders := $wmSource[1]
        let $wmSourceResponseBody := $wmSource[2]
        let $srcProbs :=   if(  not( $isStatusOK($wmSourceResponseHeaders))) then (
         <problem xmlns="urn:ietf:rfc:XXXX">
            <title>Source URL not found.</title>
            <detail>{$source} not found</detail>
        </problem>
        )
        else if( not( $sourceHasTextContentType( $wmSourceResponseHeaders ))) then (
         <problem xmlns="urn:ietf:rfc:XXXX">
            <title>Source has Invalid Content-Type</title>
            <detail>With a GET of the source the response entity SHOULD have text/* ContentType</detail>
        </problem>
        )
       else if( not( $sourcelinksToTarget( $wmSourceResponseBody , $target))) then (
         <problem xmlns="urn:ietf:rfc:XXXX">
            <title>Source has no link to target</title>
            <detail>With a GET of the source there SHOULD be link to target in response content</detail>
        </problem>
        )
        else(
         (:{$contents}
	let $store := muCache:store-content( $source , $wmSourceResponseBody )

        (:let $store := xmldb:store($collection-uri, $resource-name,
            $contents, $mime-type):)
        :)
  let $idHash := muURL:urlHash( $source || $target )
        let $beforeArchive := substring-before($target, '/archive/')
        let $afterArchive := substring-after($target, '/archive/')
        let $seqDates := tokenize( $afterArchive , '/')
        let $rmlast := remove( $seqDates , count($seqDates))
        let $dateJoin := string-join($rmlast, '/')
         return (<location>{$target || '#' || $idHash} </location> )
        )
        return ( $srcProbs )
      )
      else($targetProblems)
   )

let $resource-name := muURL:urlHash( $source || $target ) || '.xml'

let $contents :=
	<mention>
	    <remote port="{$remotePort}" addr="{$remoteAddr}" host="{$remoteHost}" />
	    <target>{$target}</target>
	    <source>{$source}</source>
	    {$condition}
	</mention>


  let $storeMention :=
  if( muUtility:isProblem ( $condition ) ) then ( $condition )
  else(
  try {
  xmldb:store($mentionStore,
  $resource-name ,
  $contents
  )
  }
  catch java:org.xmldb.api.base.XMLDBException {
  <problem xmlns="urn:ietf:rfc:XXXX">
  <title>Failed to store document:</title>
  <detail>
  <err-code>{$err:code }</err-code>
  <err-description>{$err:description}</err-description>
  <collection-uri>{$mentionStore}</collection-uri>
  <resource-name>{$resource-name}</resource-name>
  </detail>
  </problem>
  }

      )

return

if( muUtility:isProblem ( $storeMention ) ) then (
response:set-status-code(400),
$storeMention
)
else(
response:set-status-code(202),
        <mention>
        <remote port="{$remotePort}" addr="{$remoteAddr}" host="{$remoteHost}" />
        <target>{$target}</target>
        <source>{$source}</source>
{$condition}
<stored>{$storeMention}</stored>
</mention>
)
