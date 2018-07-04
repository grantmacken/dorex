xquery version "3.1";
(:~
Provide unit tests archive functions
@see ../../lib/archive.xqm
@author gmack
@version 1.0
:)

module namespace t-archive = "http://gmack.nz/#t-archive";
import module namespace archive = "http://gmack.nz/#archive" at "../../lib/archive.xqm";

declare namespace test="http://exist-db.org/xquery/xqsuite";

declare
%test:name(
"given a date ( 2016-07-08 ), then `getShortDate` function 
should return a  5 digit integer [16190]
representing a short year plus number of days"
)
%test:args('2016-07-08')
%test:assertEquals(16190)
function t-archive:getShortDate($arg){
archive:getShortDate($arg)
};

declare
%test:name(
"given short-date integer (16190), then `encode` function 
should return [3Ug] which is an encoded base60 3 char string "
)
%test:args('16190')
%test:assertEquals('3Uq')
function t-archive:encode($arg){
  archive:encode(xs:integer($arg))
};

declare
%test:name(
"given a b60 encoded string (3Ug) then `decode` function should 
return [16190] which represents a short 2 digit year + days in the year" 
)
%test:args('3Uq')
%test:assertEquals('16190')
function t-archive:decode($arg){
  archive:decode($arg)
};

declare
%test:name(
"given short-date (16190), then `formatShortDate` function
should return a formated date string [2016-07-08] " 
)
%test:args('16190')
%test:assertEquals('2016-07-08')
function t-archive:formatShortDate($arg){
  archive:formatShortDate($arg)
};

