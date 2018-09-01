# dorex

[WIP] Docker, OpenResty and eXist (dorex)
<!-- Value Proposition -->
Created to help me build secure websites

<!--Short Description -->
Made to Fork or Clone, this my current working development environment 
to help me work with OpenResty and eXistdb. 
Both OpenResty and eXistdb run in containers.

OpenResty is set up as a reverse proxy and gateway for the eXist database.


# Domains

Project is setup to work with your multiple registered website *domains*

In '.env' file located at the project root set the DOMAINS key values to
a space limited list of the domains you own. 

Each listed domain will have its own dir located in the sites dir.

## Server Name Indication (SNI)[https://en.wikipedia.org/wiki/Server_Name_Indication]

The domains are hosted on a single cloud host server, with the domain names resolved through SNI.
The first domain in the DOMAIN list will be the common name when we use certbot to get our certs,
so this site should be the first to get up and running

## Current Working Domain 

To set the current working domain, set the 'DOMAIN' key value in .env file
Once set, the Make commands will resolve to this domain

If you change the working domain, you will need to 
```
make down
make up 
```


## github: 

This project assumes you have 
 - set your git user.name
 - set up your github account
 - obtained a github access token
```

git config user.name
curl -s https://api.github.com/users/$(git config user.name) | jq '.name'
```

### A subrepo for each domain

Create a repo on github using your current domain name,
then clone into this project as subrepo

```
git subrepo clone <repo> sites/$(DOMAIN) 
```

To boot website project with some boilerplate files

```
make init-site-domain
```




# Make

Project uses a Makefile located in the project root.

```
make up
```

This will run the eXist and openresty server in thier own containers.
The containers belong to a common network.

