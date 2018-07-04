xquery version "3.1";
(:~
generate Authorization oAuth 1.1 header value in order to make twitter
API calls
@author Grant MacKenzie 
@version 0.0.1
@see modules/tests/lib/oAuth.xqm
:)

module namespace oAuth="http://markup.nz/#oAuth";
import module namespace crypto="http://expath.org/ns/crypto";

(:
NOTE uses cypto module version 3.5
@see https://gist.github.com/joewiz/5929809

Notes: 
1. To make twitter posts on behalf of a user (me) then
use  the OAuth 1.0a protocol.

@see https://dev.twitter.com/oauth/overview/single-user

2. To
- Pull user timelines
- Access friends and followers of any account
- Access lists resources
- Search in Tweets
- Retrieve any user information
the use OAuth 2 

@see https://dev.twitter.com/oauth/application-only


What we want to do is generate the 
Authorization HEADER value
@see https://dev.twitter.com/oauth/overview/authorizing-requests

Params

two parts

1. twitter rest API REQUEST items
@see https://dev.twitter.com/rest/reference

6 map keys:  method, resource plus twitter credential keys:
1. method : ( POST | GET | DELETE )
2. resource: twitter resource url : https://api.twitter.com/1.1/statuses/update.json
3. oauth_consumer_key
4. oauth_consumer_key
4. oauth_consumer_secret
5. oauth_token

map any URL query params into key, value pairs as xQuery map
eg map { 'status': 'hio de hi' }

pass the 2 maps as params to the authorizationHeader function
:)


(:~
given two maps of key values as parameters this function 
should result in an 'authorization header' that can be
used to make a Twitter API request
see modules/tests/lib/oAuth.xqm;t-oAuth:buildHeaderString 
@param $map  key, value map of a twitter authorisation credentials plus method and API resource
@param $qMap key, value map of a URL query params
@return string repesenting a oAuth header value
:)
declare
function oAuth:authorizationHeader( $map as map(*), $qMap as map(*) ) as xs:string {
 try {
  let $log1 := util:log-system-out( ' Make Request ' )
  let $timeStamp := oAuth:createTimeStamp()
  let $nonce := oAuth:createNonce()
  let $params := map:merge((
 $qMap,
  map {
    'oauth_consumer_key' :  $map('oauth_consumer_key'),
    'oauth_nonce' : $nonce,
    'oauth_signature_method' : 'HMAC-SHA1',
    'oauth_timestamp' : $timeStamp,
    'oauth_token' : $map('oauth_token'),
    'oauth_version' : '1.0'
    }))

  let $resource := xmldb:decode-uri($map('resource'))
  let $log1 := util:log-system-out( 'timestamp: ' || $params('oauth_timestamp'))
  let $log2 := util:log-system-out('nonce: '  || $params('oauth_nonce') )
  let $log3 := util:log-system-out('resource: '  || $resource )

  let $oAuthSignature :=
      oAuth:calculateSignature(
      oAuth:createSignatureBaseString(
        $map('method'),
        $resource,
        oAuth:createParameterString( $params )
      ),
      oAuth:createSigningKey(
      $map('oauth_consumer_secret'),
      $map('oauth_token_secret'))
  )

  let $headerMap :=
      map {
        'oauth_consumer_key' : $map('oauth_consumer_key'),
        'oauth_nonce' :  $params('oauth_nonce'),
        'oauth_signature' : $oAuthSignature ,
        'oauth_signature_method' : $params('oauth_signature_method'),
        'oauth_timestamp' : $params('oauth_timestamp'),
        'oauth_token' : $map('oauth_token'),
        'oauth_version' : $params('oauth_version')
        }

      return (
        oAuth:buildHeaderString( $headerMap )
      )
    }
    catch *{()}
};

(:~
@see https://dev.twitter.com/oauth/overview/creating-signature
@see https://dev.twitter.com/oauth/overview/authorizing-requests
should produce the the Authorization header value for a twitter API call
@see modules/tests/lib/oAuth.xqm;t-oAuth:buildHeaderString 
@param $map map of params
@return string  oAuth header value
:)
declare
function oAuth:buildHeaderString(
  $map as map(*) ) as xs:string {
concat(
    'OAuth oauth_consumer_key="',
    encode-for-uri( $map('oauth_consumer_key')),
    '", oauth_nonce="',
    encode-for-uri( $map('oauth_nonce')),
    '", oauth_signature="',
     encode-for-uri($map('oauth_signature')),
    '", oauth_signature_method="',
    encode-for-uri( $map('oauth_signature_method')),
    '", oauth_timestamp="',
    encode-for-uri( $map('oauth_timestamp')),
    '", oauth_token="',
    encode-for-uri( $map('oauth_token')),
    '", oauth_version="',
    encode-for-uri( $map('oauth_version')),
    '"')
};

(:~
createParameterString SHOULD return a percent encoded string
@see modules/tests/lib/oAuth.xqm;t-oAuth:createParameterString
@param $params map of params
@return string 
:)
declare function oAuth:createParameterString(
$params as map(*) ) as xs:string {
  string-join(
  (
  for $item in (
    map:for-each( $params,
      function( $key, $value ) {
        concat(
        encode-for-uri( $key ),
        '=',
        encode-for-uri( $value )
        )
        }
      ))
   order by $item
    return
    $item
  ),
      '&amp;'
    )
};

(: TODO! above use sort after eXist implements sort
    map:for-each( $params,
      function( $key, $value ) {
        concat(
        encode-for-uri( $key ),
        '=',
        encode-for-uri( $value )
        )
        }
      )
:)

(:~
createSignatureBaseString SHOULD return a percent encoded string
https://dev.twitter.com/oauth/overview/creating-signatures
To encode the HTTP method, base URL, and parameter string into a single string:
 - Convert the HTTP Method to uppercase and set the output string equal to this value.
 - Append the ‘&’ character to the output string.
 - Percent encode the URL and append it to the output string.
 - Append the ‘&’ character to the output string.
 - Percent encode the parameter string and append it to the output string
@see modules/tests/lib/oAuth.xqm;t-oAuth:createSignatureBaseString
@param $method  as xs:string,
@return string 
:)
declare function oAuth:createSignatureBaseString(
$method as xs:string,
$baseUrl as xs:string,
$parameterString as xs:string
) as xs:string {
  string-join((
    upper-case( $method ) ,
    encode-for-uri( $baseUrl ),
    encode-for-uri( $parameterString )
    ),
  '&amp;'
  )
};


(:~
createSigningKey SHOULD return a percent encoded string
@see modules/tests/lib/oAuth.xqm;t-oAuth:createSigningKey
@param $consumerSecret  Consumer secreti
@param $accessTokenSecret  OAuth token secret
@return string 
:)
declare function oAuth:createSigningKey(
  $consumerSecret as xs:string, 
  $accessTokenSecret as xs:string
  ) as xs:string  {
string-join(
  (
  encode-for-uri( $consumerSecret ),
  encode-for-uri( $accessTokenSecret )
  ),'&amp;'
)
};

(:~
calculateSignature SHOULD return a base64 encoded string
@see modules/tests/lib/oAuth.xqm;t-oAuth:calculateSignature
@param $signatureBaseString  percent encoded base string 
@param $signingKey percent encoded signing key 
@return base64 string
:)
declare function oAuth:calculateSignature(
  $signatureBaseString as xs:string,
  $signingKey as xs:string
  ) as xs:string  {
crypto:hmac(
  $signatureBaseString,
  $signingKey,
  'HmacSha1',
  'base64'
)
};

declare function oAuth:createNonce() as xs:string {
  util:uuid()
};

(:
@see https://gist.github.com/joewiz/5929809
Generates an OAuth timestamp, which takes the form of
the number of seconds since the Unix Epoch. You can test
these values against http://www.epochconverter.com/.
@see http://en.wikipedia.org/wiki/Unix_time 
:)
declare function oAuth:createTimeStamp() as xs:unsignedLong {
    let $unix-epoch := xs:dateTime('1970-01-01T00:00:00Z')
    let $now := current-dateTime()
    let $duration-since-epoch := $now - $unix-epoch
    let $seconds-since-epoch :=
        days-from-duration($duration-since-epoch) * 86400 (: 60 * 60 * 24 :)
        +
        hours-from-duration($duration-since-epoch) * 3600 (: 60 * 60 :)
        +
        minutes-from-duration($duration-since-epoch) * 60
        +
        seconds-from-duration($duration-since-epoch)
    return
        xs:unsignedLong($seconds-since-epoch)
};

