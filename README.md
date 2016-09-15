[![Build Status](https://travis-ci.org/rstudio/redx.svg)](https://travis-ci.org/rstudio/redx)
redx
======

Redx (or redis-nginx) is an embedded lua based approach of having a dynamic configuration of nginx of frontends and
backends with redis as its data store. It was inspired by [hipache](https://github.com/hipache/hipache). It has a
RESTful API (that runs within nginx itself) to manage the many-to-one relationships between frontends to backends, set
configurations, and more.

One of the main benefits of redx is the ability to update your nginx config without needing to reload nginx. This is
useful for environments with a highly dynamic topology where backends and frontends are added/removed several times a
second (ie PaaS). Also, this allows you to have a single nginx config across multiple nginx servers making it easier to 
have true high availability and scalability on your load balancing layer. 

Redx is licensed under the [2-Clause BSD License](https://opensource.org/licenses/BSD-2-Clause).

Project Status
==============

At [RStudio](http://www.rstudio.com/), we are using it in production serving all web traffic for
[shinyapps.io](https://www.shinyapps.io/).

How it works
============

## The Components
Redx is composed of two components; the api and main. The api is a restful api embedded in lua and runs within the nginx
process. It runs on its own port (for ease of firewall security) and is manages the frontends and backends in the nginx
config by editing the redis database.

The other component is main, and this is what takes regular traffic from your users. It looks up the proper backend to
 proxy the request to based on the host and path.

## The fallback
In the event that there isn't a frontend or backend match for an incoming request **OR** the backend server
(ie a cache miss), the request was proxied to a server that isn't responding, the request is sent to the `fallback`.
This is typically your application server, which handles these failure scenario. Several headers are added to the
request to help your application server understand the context in which the request is coming in
(ie cache miss vs. port not open). In some cases, you may want to update redx by hitting the API and insert the missing 
frontend and/or backend and send them back to nginx to try again, or maybe you want to forward them to a 
custom 404 page. Its up to you to decide what the behavior you want it to be.

Performance
===========

At [RStudio](http://www.rstudio.com/), we find that redx performs slightly slower than regular redis config files. 
Of course, this makes sense, as you're now querying a remote redis server to lookup frontends and backends, instead of 
caching all that in local memory. In our unofficial benchmarks, we see a 10ms increase in response time with using a 
third party redis hosting service. Of course latency to your redis server is a big factor. Redx though, keeps a pool of 
connections that are reused instead of making separate calls on each request.

That being said, the payoff of having dynamic configuration and being able to easily do high availability with active 
active nginx load balancers is well worth the 10ms cost in my opinion. Each environment is different and has different 
requirements, goals, etc. So its up to you to decide what is worth what.

Requirements
============

[lapis](http://leafo.net/lapis/) version 1.0.4-1

[openresty](http://openresty.org/) 1.7.2 or greater

A [redis](http://redis.io/) server

Setup Dev Environment
=====================

Setup and start vagrant

```bash
  vagrant plugin install vagrant-berkshelf --plugin-version '>= 2.0.1'
  vagrant plugin install vagrant-omnibus
  vagrant up
```

The redx code on your local workstation is run within vagrant (due to sharing the redx directory with vagrant at 
`/home/vagrant/redx`). As you make code changes, they should take affect immediately and do not require reloading nginx. 
You will however need to reload nginx when you change the nginx config located 
`vagrant://etc/nginx/sites-available/redx.conf`. To see redx logs, see `/var/log/nginx/[access,error].log`

## Git Hooks
It is recommended that you setup two git hooks.

The pre-commit hook (`./git/hooks/pre-commit`) should be used to ensure you don't make changes to the moonscript code 
without recompiling the lua code.
```bash
#!/bin/sh

moonc -t lua/ .
```

The pre-push hook (`./git/hooks/pre-push`) should be used to ensure you've run all tests and they all pass.
```bash
#!/bin/sh

busted lua/spec/
```

Testing
=======

Redx uses a testing framework, [busted](http://olivinelabs.com/busted/), to run integration tests. To run these tests, 
execute `busted lua/spec`. Continuous integration is setup with [travis ci](https://travis-ci.org/rstudio/redx).

Configuration
=============

The configuration of redx is loaded from `lua/conf/config.lua`. This file consists of the following configuration options

##### redis\_host
An IP address or hostname to a redis server

##### redis\_port
An port number of the redis server to connect to

##### redis\_password
If you have a redis password, put it here. If you don't leave it an empty string (ie `''`)

##### redis\_timeout
This is the connection timeout for any redis connection, in milliseconds

##### redis\_keepalive\_pool\_size
The pool size of keepalive connections to maintain, per nginx worker.

##### redis\_keepalive\_max\_idle\_timeout
max idle timeout for keepalive connection, in milliseconds

##### max\_path\_length
The max number of parts to the path to look up. This defines the max length of a path to be to looked up to a 
corresponding frontend in redis.

Say in your service, your path always consists of an account name and service name (ie http://sasservice.com/jdoe/app1). 
So the max path length you want to support for your application here is 2. If the user, comes into nginx with more to 
the path than that (ie http://sasservice.com/jdoe/app1/static/js/base.js), but when request comes in, redx will only 
search for "sasservice.com/jdoe/app1" first and "sasservice.com/jdoe" second and "sasservice.com" third, for frontends 
in the database.

For another example, say you only want to route traffic based on the domain (ie 'chad.myserver.com'). Setting the 
max\_path\_length to 0 will cause redx to only look for frontends on the domain with no path.

##### plugins
A list of plugins to enable. Plugins are executed in the order they are given. If you wish to pass a parameter to a 
plugin, make a plugin an array, where the first element is the plugin name and the second is the parameter. 

Here is an example.
```lua
M.plugins = {
  'stickiness',
  { 'score', 'most' },
  'random'
}
```

##### session\_length
The amount of time (in seconds) you wish the session cookie to keep alive. This is applicable when using cookies as a 
user specific persistence datastore (ie stickiness).

##### default\_score
The default score is the score that is inserted into backends in the case where a score is not provided 
(ie batch updating). If this config option isn't specified, it defaults to 0 (zero).

API
===

The api is [documented here](https://github.com/rstudio/redx/blob/master/docs/api.md)

Plugins
=======

Redx has a plugin architecture to allow others to easily expand its capability to do more (publicly or privately).

See the [plugins documentation](https://github.com/rstudio/redx/blob/master/docs/plugins.md)
