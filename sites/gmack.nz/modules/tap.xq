xquery version "3.1";

(:~
This module will 
generate tap output from an xqsuite tests.

it requires a single parameter 
'the path of the module'

we also want to produce formated error lines suitable for text editors.

In order to get an errorformat with a linenumber for both the module function and test function

- The module SHOULD contain a top level see annotation locating the testSuite
- Each function tested SHOULD contain a function see annotation locating the test

the function see annotations ( as per follow http://xqdoc.org/xqdoc_comments_doc.html) 
have the pattern 
[test module path];[test module function]
'modules/tests/lib/NAME.xqm:function'

'To link to a library or main module contained in xqDoc, simply provide
the URI for the library or main module. To link to a specific function
(or variable) defined in an xqDoc library or main module, simply provide
the URI for the library or main module followed by a ';' and finally the
function or variable name.'

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

declare variable $error := map {
'notFound' := QName( 'http://markup.nz/#err','documentNotAvailable'),
'wmError'  : QName( 'http://markup.nz/#err','webmentionError')
};

try {

let $nl := "&#10;"
let $space := '&#32;' (: space :)
let $hashIdent := '#&#32;&#32;&#32;' (: space :)
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

let $mod := request:get-parameter('mod', 'modules/lib/oAuth.xqm')

let $myModule :=
  if ( util:binary-doc-available( $getPath( $mod ) ) )
    then (
       $log( 'module found: ' || $getPath( $mod )  ),
       inspect:inspect-module( $getPath( $mod ) ))
    else (
     fn:error(
      $error('notFound'),
      $getPath( $mod )
      )
    )


let $myModulePrefix :=
  if ( $myModule/@prefix )
    then (
       $log( 'module prefix: ' || $myModule/@prefix/string()),
       $myModule/@prefix/string()
      )
    else (
     fn:error(
      $error('notFound'),
       'module prefix'
      )
    )

let $myModuleURI :=    $myModule/@uri/string()
let $myModuleLocation :=    xs:anyURI($myModule/@location/string())
let $myModuleDescription := normalize-space($myModule/description/string())

let $myModuleSee :=
  if ( $myModule/see/text() )
    then (
       $log( 'module see: ' || $myModule/see/string() ),
        normalize-space($myModule/see/string())
      )
    else (
     fn:error(
      $error('notFound'),
       'module see'
      )
    )

let $testsDoc :=
  if ( util:binary-doc-available( $getPath( $myModuleSee ) ) )
    then (
       $log( 'module found: ' || $getPath( $myModuleSee ) ),
       util:binary-doc(  $getPath( $myModuleSee )  )
       )
    else (
     fn:error(
      $error('notFound'),
      $getPath( $myModuleSee )
       )
    )



let $myModuleString := util:binary-to-string(util:binary-doc( $myModuleLocation ))
let $myModuleStringLines := tokenize( $myModuleString , '(\r\n?|\n\r?)')

let $testsString := util:binary-to-string( $testsDoc )
let $testsStringLines := tokenize( $testsString , '(\r\n?|\n\r?)')

let $getLineNumber := function( $seqLines, $pattern ){
 for $line at $i in $seqLines
  return 
  if ( matches($line, $pattern ))
  then ( $i )
  else()
}

(: let $seqModFunctionItems  :=  inspect:module-functions( $myModuleLocation  ) :)


let $seqModFunctionItems := 
  if ( not(empty( inspect:module-functions( $myModuleLocation ))) )
    then (
       $log( 'module functions count: ' || string( count(inspect:module-functions( $myModuleLocation )) )),
       inspect:module-functions( $myModuleLocation )
       )
    else (
     fn:error(
      $error('notFound'),
      'no functions found in module'
       )
    )


let $testModuleLocation :=  xs:anyURI( $getPath( $myModuleSee ) )

let $seqTestFunctionItems := 
  if ( not(empty( inspect:module-functions( $testModuleLocation ))) )
    then (
       $log( 'test module functions count: ' || string( count(inspect:module-functions( $testModuleLocation )) )),
       inspect:module-functions( $testModuleLocation )
       )
    else (
     fn:error(
      $error('notFound'),
      'no test functions found in module'
       )
    )
 (: inspect:module-functions( $getPath($myModuleSee) ) :)

let $testSuite := test:suite( $seqTestFunctionItems )
  let $testCases :=
  for $node at $i in  $testSuite//testcase
    let $counter := xs:string($i) || $space
    let $testCaseName  := $node/@name/string()
    let $testCaseClass :=  $node/@class/string()
    let $log1 :=  $log( 'TEST:[ ' || $counter || '] ' || $testCaseClass  )
    let $testSearchPattern := $testCaseClass || '\('
    let $myModuleFunctionNode := 
      $myModule//function[ contains( normalize-space(./see/string() ), $testCaseClass) ]
    let $log2 :=  if ( empty( $myModuleFunctionNode ) ) then (
    $log( 'TEST:[ ' || $counter || ']  WARNING: no @see found in module function' ),
    $log( 'TEST:[ ' || $counter || ']  FAILURE: to run tests' ),
     fn:error(
      $error('notFound'),
      'no @see found in module function'
       )
    ) else ()
    let $myModFuncName := $myModuleFunctionNode/@name/string()
    let $myModFuncDescription :=  normalize-space($myModuleFunctionNode/description/string())
    let $myModFuncSee := normalize-space($myModuleFunctionNode/see/string())
    let $mySearchPattern := $myModFuncSee || '$'
    (: let $logFunc := $log( $testCaseName ) :)
    let $testOK :=
      if( $node/failure[@message]  )then( 'failure' )
      else if( $node/error[@message]  )then( 'error' )
      else('success')

    let $message := 
      switch ($testOK)
        case "success" return ( $SUCCESS || $counter || $testCaseName )
        case "error" return ( 
          $FAILURE || $counter || ' - ' || $testCaseName  || ' - ' || $testCaseClass ||
            $nl || $hashIdent || 'Failed test.' || $node/error/@message/string() || 
            $nl || $hashIdent || 'at '  || $myModuleSee || ' line ' || $getLineNumber( $testsStringLines, $testSearchPattern ) ||
            $nl || $hashIdent || 'message: ' ||  $node/error/@message/string() ||
            $nl || $hashIdent || 'module-function-at: ' ||
            $getRelPath($myModuleLocation)  || ':' || 
            $getLineNumber( $myModuleStringLines, $mySearchPattern )   || ':E: ' ||
            substring-after( $myModFuncName, ':' )  ||
            ' - '  || $node/error/@type/string() ||
            $nl || $hashIdent ||  'unit-test-at: ' || 
            $myModuleSee  || ':' || 
            $getLineNumber( $testsStringLines, $testSearchPattern )   || ':E: ' ||
            substring-after(  $testCaseClass, ':' ) ||
           ' - '  || $node/error/@type/string() || 
            $nl
          )
        case "failure"
        return (
            $FAILURE || $counter || ' - ' ||  $testCaseName || ' - ' || $testCaseClass ||
            $nl || $hashIdent || 'Failed test.' || $node/error/@message/string() || 
            $nl || $hashIdent || 'at'  || $space ||  $myModuleSee || $space ||
            'line' || $space || $getLineNumber( $testsStringLines, $testSearchPattern ) ||
            $nl || $hashIdent || '  expected: ' || $node/failure/string() || 
            $nl || $hashIdent || '    actual: ' ||  $node/output/string() ||
            $nl || $hashIdent || 'message: ' ||  $node/failure/@message/string() || 
            $nl || $hashIdent || 'module-function-at: ' ||
            $getRelPath($myModuleLocation)  || ':' || 
            $getLineNumber( $myModuleStringLines, $mySearchPattern )  || ':W: ' ||
            substring-after( $myModFuncName , ':')  ||
            ' - '  || $node/failure/@message/string() || 
            $nl || $hashIdent || 'unit-test-at: ' || 
            $myModuleSee  || ':' || 
            $getLineNumber( $testsStringLines, $testSearchPattern )  || ':W: ' ||
            substring-after( $myModFuncName , ':')  ||
            ' - '  || $node/failure/@message/string() || 
             $nl || $space 
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
'1..' || $testSuite/testsuite[1]/@tests/string(),
$testCases,
$nl
)
}
catch * {
let $nl := "&#10;"
let $space := '&#32;'
return
(
  'error code:' || $space || $err:code || $nl,
  'error description:' || $space || $err:description || $nl,
  'error line number:' || $space || $err:line-number || $nl,
  'error module:' || $space || $err:module || $nl
)}
