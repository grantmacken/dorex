xquery version "3.1";
(:~
Provide unit tests oAuth functions
@see ../../lib/oAuth.xqm
@author gmack.nz
@version 0.0.1


Vars used in tests from
@see https://dev.twitter.com/oauth/overview/authorizing-requests
@see https://dev.twitter.com/oauth/overview/creating-signatures

vars derived from above are placed in a map

:)

module namespace t-oAuth = "http://markup.nz/#t-oAuth";
import module namespace oAuth= "http://markup.nz/#oAuth" at "../../lib/oAuth.xqm";

declare namespace test="http://exist-db.org/xquery/xqsuite";

(:~
vars derived from URLs below are placed in a map for testing
@see https://dev.twitter.com/oauth/overview/authorizing-requests
@see https://dev.twitter.com/oauth/overview/creating-signatures
:)
declare variable $t-oAuth:map :=  map {
    'method' : 'post',
    'resource_URL' : 'https://api.twitter.com/1/statuses/update.json',
    'status' : 'Hello Ladies + Gentlemen, a signed OAuth request!',
    'include_entities' : 'true',
    'oauth_consumer_key' : 'xvz1evFS4wEEPTGEFPHBog',
    'oauth_consumer_secret' : 'kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw',
    'oauth_nonce' : 'kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg',
    'oauth_signature_method' : 'HMAC-SHA1',
    'oauth_timestamp' : '1318622958',
    'oauth_token' : '370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb',
    'oauth_token_secret' : 'LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE',
    'oauth_version' : '1.0'
    };

(:~
the https://dev.twitter.com/oauth/overview/creating-signatures
@param $arg1  method
@param $arg2  url
:)
declare
%test:name(
'createSignatureBaseString SHOULD return a url encoded string'
)
%test:args(
  'post',
  'https://api.twitter.com/1/statuses/update.json'
)
%test:assertEquals(
'POST&amp;https%3A%2F%2Fapi.twitter.com%2F1%2Fstatuses%2Fupdate.json&amp;include_entities%3Dtrue%26oauth_consumer_key%3Dxvz1evFS4wEEPTGEFPHBog%26oauth_nonce%3DkYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg%26oauth_signature_method%3DHMAC-SHA1%26oauth_timestamp%3D1318622958%26oauth_token%3D370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb%26oauth_version%3D1.0%26status%3DHello%2520Ladies%2520%252B%2520Gentlemen%252C%2520a%2520signed%2520OAuth%2520request%2521'
)
function t-oAuth:createSignatureBaseString( $arg1 as xs:string , $arg2 as xs:string) as xs:string {
oAuth:createSignatureBaseString(
$arg1,
$arg2,
 oAuth:createParameterString(
  map {
    'status' : $t-oAuth:map('status'),
    'include_entities' : $t-oAuth:map('include_entities'),
    'oauth_consumer_key' :  $t-oAuth:map('oauth_consumer_key'),
    'oauth_nonce' : $t-oAuth:map('oauth_nonce'),
    'oauth_signature_method' : $t-oAuth:map('oauth_signature_method'),
    'oauth_timestamp' : $t-oAuth:map('oauth_timestamp'),
    'oauth_token' : $t-oAuth:map('oauth_token'),
    'oauth_version' : $t-oAuth:map('oauth_version')
    }
  )
)
};

(:~
the https://dev.twitter.com/oauth/overview/creating-signatures
test from above page
@param $arg1 Consumer secret
@param $arg2 OAuth token secret
:)
declare
%test:name(
'createSigningKey SHOULD return a percent encoded string'
)
%test:args(
  'kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw',
  'LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE'
  )
%test:assertEquals('kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw&amp;LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE')
function t-oAuth:createSigningKey( $arg1 as xs:string , $arg2 as xs:string) as xs:string {
oAuth:createSigningKey( $arg1 , $arg2 )
};

(:~
the https://dev.twitter.com/oauth/overview/creating-signatures
test from above page
:)
declare
%test:name(
'createParameterString SHOULD return a percent encoded string'
)
%test:assertEquals(
'include_entities=true&amp;oauth_consumer_key=xvz1evFS4wEEPTGEFPHBog&amp;oauth_nonce=kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg&amp;oauth_signature_method=HMAC-SHA1&amp;oauth_timestamp=1318622958&amp;oauth_token=370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb&amp;oauth_version=1.0&amp;status=Hello%20Ladies%20%2B%20Gentlemen%2C%20a%20signed%20OAuth%20request%21'
)
function t-oAuth:createParameterString() as xs:string {
 oAuth:createParameterString(
  map {
    'status' : $t-oAuth:map('status'),
    'include_entities' : $t-oAuth:map('include_entities'),
    'oauth_consumer_key' :  $t-oAuth:map('oauth_consumer_key'),
    'oauth_nonce' : $t-oAuth:map('oauth_nonce'),
    'oauth_signature_method' : $t-oAuth:map('oauth_signature_method'),
    'oauth_timestamp' : $t-oAuth:map('oauth_timestamp'),
    'oauth_token' : $t-oAuth:map('oauth_token'),
    'oauth_version' : $t-oAuth:map('oauth_version')
    }
  )
};

(:~
the https://dev.twitter.com/oauth/overview/creating-signatures
test from above page
@param $arg1 Consumer secret
@param $arg2 OAuth token secret
:)
declare
%test:name(
'calculateSignature SHOULD return a base64 encoded string'
)
%test:args(
  'post',
  'https://api.twitter.com/1/statuses/update.json',
  'kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw',
  'LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE'
  )
%test:assertEquals('tnnArxj06cWHq44gCs1OSKk/jLY=')
function t-oAuth:calculateSignature(
  $arg1 as xs:string,
  $arg2 as xs:string,
  $arg3 as xs:string,
  $arg4 as xs:string
  ) as xs:string {
oAuth:calculateSignature(
  oAuth:createSignatureBaseString(
  $arg1,
  $arg2,
  oAuth:createParameterString(
    map {
      'status' : $t-oAuth:map('status'),
      'include_entities' : $t-oAuth:map('include_entities'),
      'oauth_consumer_key' :  $t-oAuth:map('oauth_consumer_key'),
      'oauth_nonce' : $t-oAuth:map('oauth_nonce'),
      'oauth_signature_method' : $t-oAuth:map('oauth_signature_method'),
      'oauth_timestamp' : $t-oAuth:map('oauth_timestamp'),
      'oauth_token' : $t-oAuth:map('oauth_token'),
      'oauth_version' : $t-oAuth:map('oauth_version')
      }
    )
  ),
  oAuth:createSigningKey( $arg3, $arg4 )
 )
};



(:~
the https://dev.twitter.com/oauth/overview/creating-signatures
test from above page
@param $arg1 method
@param $arg2 URL
@param $arg3 Consumer secret
@param $arg4 OAuth token secret
:)
declare
%test:name(
'buildHeaderString SHOULD return a string'
)
%test:args(
  'post',
  'https://api.twitter.com/1/statuses/update.json',
  'kAcSOqF21Fu85e7zjz7ZN2U4ZRhfV3WpwPAoE3Z7kBw',
  'LswwdoUaIvS8ltyTt5jkRh4J50vUPVVHtR2YPi5kE'
  )
%test:assertEquals(
'OAuth oauth_consumer_key="xvz1evFS4wEEPTGEFPHBog", oauth_nonce="kYjzVBB8Y0ZFabxSWbWovY3uYSQ2pTgmZeNu2VS4cg", oauth_signature="tnnArxj06cWHq44gCs1OSKk%2FjLY%3D", oauth_signature_method="HMAC-SHA1", oauth_timestamp="1318622958", oauth_token="370773112-GmHxMAgYyLbNEtIKZeRNFsMKPR9EyMZeS9weJAEb", oauth_version="1.0"'
)
function t-oAuth:buildHeaderString(
  $arg1 as xs:string,
  $arg2 as xs:string,
  $arg3 as xs:string,
  $arg4 as xs:string
  ) as xs:string {

let $oauthSignature := oAuth:calculateSignature(
  oAuth:createSignatureBaseString(
  $arg1,
  $arg2,
  oAuth:createParameterString(
    map {
      'status' : $t-oAuth:map('status'),
      'include_entities' : $t-oAuth:map('include_entities'),
      'oauth_consumer_key' :  $t-oAuth:map('oauth_consumer_key'),
      'oauth_nonce' : $t-oAuth:map('oauth_nonce'),
      'oauth_signature_method' : $t-oAuth:map('oauth_signature_method'),
      'oauth_timestamp' : $t-oAuth:map('oauth_timestamp'),
      'oauth_token' : $t-oAuth:map('oauth_token'),
      'oauth_version' : $t-oAuth:map('oauth_version')
      }
    )
  ),
  oAuth:createSigningKey( $arg3, $arg4 )
 )

return
oAuth:buildHeaderString(
 map {
  'oauth_consumer_key' : $t-oAuth:map('oauth_consumer_key'),
  'oauth_nonce' :  $t-oAuth:map('oauth_nonce'),
  'oauth_signature' : $oauthSignature,
  'oauth_signature_method' : $t-oAuth:map('oauth_signature_method'),
  'oauth_timestamp' : $t-oAuth:map('oauth_timestamp'),
  'oauth_token' : $t-oAuth:map('oauth_token'),
  'oauth_version' : $t-oAuth:map('oauth_version')
  }
)
};
