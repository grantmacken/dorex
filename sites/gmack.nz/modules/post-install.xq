xquery version "3.1";
(:~
:
@author gmack.nz
@version 01
:)
import module namespace xdb="http://exist-db.org/xquery/xmldb";
import module namespace xrest="http://exquery.org/ns/restxq/exist" at "java:org.exist.extensions.exquery.restxq.impl.xquery.exist.ExistRestXqModule";

(: The following external variables are set by the repo:deploy function :)

(: the target collection into which the app is deployed :)
declare variable $target external;
declare variable $domain  := substring-after( string($target), '/apps/');
declare variable $mentions := 'data/' || $domain || '/docs/mentions';

(:
my apps name is based on the domain name 
1. extract $domain
4. set permissions
 Register restxq modules. Should be done automatically, but there seems to be an occasional bug
:)

sm:chmod(xs:anyURI("/db/" || $mentions), "rwxrwxrwx"),
xrest:register-module(xs:anyURI($target || "/modules/api/router.xqm"))
