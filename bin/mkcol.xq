(:~
:
@author Grant Mackenzie
@version 0.1
:)
xquery version "3.1";
try{
 let $nl := "&#10;"
 let $path  := ']] .. DBPATH .. [['
 let $mkcol :=  function(){
  'hi'
 }
   return(
   $mkcol()
)
} catch * {()}

