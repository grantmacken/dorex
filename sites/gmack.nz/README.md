<!--BLURB-->
An experiment in building a front-end website application development environment and work-flow that uses an eXist application server to serve the site.

[gmack.nz](https://github.com/grantmacken/gmack.nz):
 [![Release](http://img.shields.io/github/release/grantmacken/gmack.nz.svg)]( https://github.com/grantmacken/gmack.nz/releases/latest )
 [![Issues](http://img.shields.io/github/issues/grantmacken/gmack.nz.svg)]( https://github.com/grantmacken/gmack.nz/issues )

<!--
[![Build Status](https://travis-ci.org/grantmacken/gmack.nz.svg?branch=master)](https://travis-ci.org/grantmacken/gmack.nz)
[tests](https://travis-ci.org/grantmacken/gmack.nz)
 [![status](https://travis-ci.org/grantmacken/gmack.nz.svg)]( https://travis-ci.org/grantmacken/gmack.nz )
-->

ISSUES
------

**Feature Requests and Bugs**: submit them through the project's issues tracker.<br/>
[![Issues](http://img.shields.io/github/issues/grantmacken/gmack.nz.svg)]( https://github.com/grantmacken/gmack.nz/issues )

<!--
http://ricostacruz.com/cheatsheets/badges.html
-->

-------------

<!--DESCRIPTION-->

App Deployment
--------------

The main release artifact for this project is a deployable website bundled as an eXist application package. (app)

The app contains HTML *templates* and xQuery *modules* which
can extract, query and utilise our data to provide a navigable website views. 
The app also contains resources in the form of Cascading Style Sheets (CSS) defining content
presentation and scripts that allow content interaction. 

And our built and bundled website app consists of
* modules:  HTML templates for pages and partials
* templates: xQuery modules
* resources:  styles and scripts 
* packaging: app root files for deploying and installing and controlling the
  website

#APP Routes

This app does not use a controller, instead it uses a single *restxq* endpoint. `/modules/api/router.xqm` All HTML views are routed via this module. However to understand how the router routes requests, you will need to look at how eXist behind openresty.(nginx).

Openresty rewrites requests which will be passed to the router.

```
#  home page rewrite: 
rewrite "^/?(?:index|index.html)?$" /pages/home.html break;

# posts Short URL rewrite
rewrite "^/?([na]{1}[0-9A-HJ-NP-Z_a-km-z]{3}[1-9]{1}([0-9]{1})?)$" /posts/$1.html break;

# media Short URL rewrite
rewrite "^/?([M]{1}[0-9A-HJ-NP-Z_a-km-z]{3}[1-9]{1}([0-9]{1})?)$" /media/$1.html break;
```

Our data content however are stored in a collection separate from the deployable website app. 
Also media referenced in content ( images and video ) are also stored outside the apps collection.

/data/{domain}/{collection}


So our data store consists of 
* docs:  XML documents    /data/{domain}/docs
* media: Binary files     /data/{domain}/media

The docs collection is divided into 3 folders ( pages | posts | uploads )

1. pages     a doc item that belongs to a named collection 
2. posts:    a doc item that belongs to a date archive collection ( posts )
1. uploads:  a doc item with media-info about an associated uploaded binary item.
            e.g. will have  md5 signature of the binary upload contained a signature element

------------------------------------------------------------------------------

## development vs production deployment

The same app is deployed in local development and remote production servers.

In a local development, we use ```systemctl``` (systemd) to set enviroment var

    sudo systemctl set-environment SERVER=development

In 'pre-install.xq' we use this to install triggers which are only used in our
development server. The data trigger is used to upload data from development to
the production server.


## issue resolution development

Development starts with a raised issue on github. The issue should contain a
checklist of tasks aimming to resolve the issue in question. To work on an issue
we create a branch using the issue as a reference point.
Issue resolution results in pull request.
Once we satisfy our merge criteria ( review, comment, lint and test criterion )
then we merge and close issue. Back on master, a semver release is
created based on the issue milestone and we build the xar release asset and
upload to github. We deploy to localhost development server, run tests then
deploy to remote.

`make issue` 
If on master, will create a new issue,
else will 'patch' the issue with data from ISSUE.md

`make branch` 
Create a branch from current issue 

commit 
add to issue file and sync with `make issue`


push when issue resolved

`make pr`
- create Pull Request 
- create shipit comment
- create status 
- merge
 

## a continuous build process, with preview in browser and tests

the content in the build folder is continously built from src files.

Our front-end workflow can process files through a transformation pipeline. e.g.

1. When source css files are modified, before placing into the build folder they may be 
    1. combined, 
    2. autoprefix altered
    3. minified
2. When a file is modified in the build folder, the file is stored into the local
development server and the servers response logged. 
3. When the sever log file is modified, signifying a successful upload the 
livereload server is notified and the response logged
4. When the livereload log file is modified we can run tests

Using this process we get a live browser preview as we make changes to our
source files. We can also invoke and check the output of any lints or tests. 


Watch is used to notify Make of changes to source files 
The dependency chain is managed through Make


## tests

Tests a ran using TAP. ( The Test Anything Protocol )
As per convention test are in the *t* dir and use the .t extension

Tests can be associated with ISSUES, so 11.t will be the tests associated with
issue #11.

Tests can be run using Prove

Tests are developed using script that can generate a TAP report

We use

* https://github.com/ingydotnet/test-more-bash
* https://github.com/substack/tape

