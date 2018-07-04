xquery version "3.1";

(:~
This module will 
generate tap output from an xqsuite tests.

it requires a single parameter 
'the path of the module'

we also want to produce formated error lines suitable for text editors.

In order to get an errorformat with a linenumber for both the module function and test function
The module should contain a see annotation locating the testSuite
Each function tested should contain a see annotation locating the test

@author gmack.nz
@version 1.0
~:)

declare boundary-space preserve;
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "text";
declare option output:media-type "text/plain";
declare option output:item-separator "&#10;";
declare option output:encoding "UTF-8";

import module namespace util = "http://exist-db.org/xquery/util";
import module namespace inspect = "http://exist-db.org/xquery/inspection";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace test="http://exist-db.org/xquery/xqsuite"
  at "resource:org/exist/xquery/lib/xqsuite/xqsuite.xql";

let $nl := "&#10;"
let $space := '&#32;' (: space :)
let $SUCCESS := $nl || 'ok' || $space
let $FAILURE := $nl || 'not ok' || $space

let $base := replace(
 system:get-module-load-path(),
 '^(xmldb:exist://)?(embedded-eXist-server)?(.+)$',
 '$3')

let $appRoot  := substring-before( $base , '/modules')

let $log := function( $msg ){
  util:log-system-out( $msg )
  }

let $getPath := function( $pth ){
  xs:anyURI( $appRoot || '/' || $pth )
  }

let $getRelPath := function( $abspth ){
  xs:anyURI( substring-after($abspth, $appRoot || '/' ))
  }

let $mod := request:get-parameter('mod', 'modules/lib/muFrontmatter.xqm')
let $myModule :=  inspect:inspect-module( $getPath( $mod ) )
let $myModulePrefix := $myModule/@prefix/string()
let $myModuleURI :=    $myModule/@uri/string()
let $myModuleLocation :=    $myModule/@location/string()
let $myModuleDescription := normalize-space($myModule/description/string())
let $myModuleSee :=         normalize-space($myModule/see/string())

let $myModuleString := util:binary-to-string(util:binary-doc( $myModuleLocation ))
let $myModuleStringLines := tokenize( $myModuleString , '(\r\n?|\n\r?)')

let $testsString := util:binary-to-string(util:binary-doc(  $getPath($myModuleSee)  ))
let $testsStringLines := tokenize( $testsString , '(\r\n?|\n\r?)')

let $getLineNumber := function( $seqLines, $pattern ){
 for $line at $i in $seqLines
  return 
  if ( matches($line, $pattern ))
  then ( $i ) 
  else()
}

let $testSuite := test:suite( inspect:module-functions( $getPath($myModuleSee) )) 
(: main loop ---  for each testcase  --- :)
  let $testCases :=
  for $node at $i in  $testSuite//testcase
    let $counter := string($i) || $space
    let $testCaseName  := $node/@name/string()
    let $testCaseClass := $node/@class/string()
    let $testSearchPattern := $testCaseClass|| '\('
    let $myModuleFunctionNode := $myModule//function[ contains( normalize-space(./see/string()), $testCaseClass) ]
    let $myModFuncName := $myModuleFunctionNode/@name/string()
    let $myModFuncDescription :=  normalize-space($myModuleFunctionNode/description/string())
    let $myModFuncSee := normalize-space($myModuleFunctionNode/see/string())
    let $mySearchPattern := $myModFuncSee || '$'
    let $testOK :=
      if( $node/failure[@message]  )then( 'failure' )
      else if( $node/error[@message]  )then( 'error' )
      else('success')

    let $message := 
      switch ($testOK)
        case "success" return ( $SUCCESS || $counter || $testCaseName )
        case "error" return ( 
          $FAILURE || $counter || ' - ' || $testCaseName  || ' - ' || $testCaseClass ||
            $nl || $space || '---' ||
            $nl || $space || 'type: ' ||  $node/error/@type/string() ||  
            $nl || $space || 'message: ' ||  $node/error/@message/string() || 
            $nl || $space || 'module-function-at: ' ||
            $getRelPath($myModuleLocation)  || ':' || 
            $getLineNumber( $myModuleStringLines, $mySearchPattern )   || ':E: ' ||
            substring-after( $myModFuncName, ':' )  ||
            ' - '  || $node/error/@type/string() ||
            $nl || $space || 'unit-test-at: ' || 
            $myModuleSee  || ':' || 
            $getLineNumber( $testsStringLines, $testSearchPattern )   || ':E: ' ||
            substring-after(  $testCaseClass, ':' ) ||
           ' - '  || $node/error/@type/string() || 
            $nl || $space || '...'
          )
        case "failure"
        return (
            $FAILURE || $counter || ' - ' ||  $testCaseName || ' - ' || $testCaseClass ||
            $nl || $space || '---' ||
            $nl || $space || 'message: ' ||  $node/failure/@message/string() || 
            $nl || $space || 'expected: ' || $node/failure/string() || 
            $nl || $space || 'actual ' ||  $node/output/string() ||
            $nl || $space || 'module-function-at: ' ||
            $getRelPath($myModuleLocation)  || ':' || 
            $getLineNumber( $myModuleStringLines, $mySearchPattern )  || ':W: ' ||
            substring-after( $myModFuncName , ':')  ||
            ' - '  || $node/failure/@message/string() || 
            $nl || $space || 'unit-test-at: ' || 
            $myModuleSee  || ':' || 
            $getLineNumber( $testsStringLines, $testSearchPattern )  || ':W: ' ||
            substring-after( $myModFuncName , ':')  ||
            ' - '  || $node/failure/@message/string() || 
            $nl || $space || '...'
            )
        default return ()

  return (
      $message
      )

(: tests
serialize($myModule) , 
serialize($testSuite),
$myModuleString || $nl,
serialize(inspect:module-functions( $getPath($myModuleSee) )
$myModuleLocation || $nl,
util:binary-doc-available($myModuleLocation) || $nl,
$getPath($myModuleSee) || $nl, 
util:binary-doc-available( $getPath($myModuleSee)) || $nl, 
$myModuleSee || $nl,
$appRoot || $nl,
$testsString || $nl,
:)

return (
'TAP version 13' || $nl,
'1..' || $testSuite/testsuite[1]/@tests/string(),
$testCases,
$nl
)
