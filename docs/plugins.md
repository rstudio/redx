Plugins
=======

Plugins allow people to expand redx capabilities. There are three functions your plugin **must** support, `pre, `balance`, `post`. Each of these methods are passed the request object, the session data, and the parameter (as configured in your configuration file)

### Request Object
The request object is the lapis session that stores all sorts of information about [the request](http://leafo.net/lapis/reference/actions.html#request-object).

### Session Data
Session data is information about the request that redx has generated. It is a table variable type (dictionary) that contains the follow key values
 * **frontend** - the frontend key used
 * **backend** - the backend key used
 * **servers** - list of servers available for this backend
 * **config** - a dictionary of configs set for this backend
 * **server** - The server choosen to proxy the request to

### Parameter
The parameter is anything of your choosing. You specify it in the config file, but you can only have one param (but you're free to use a table if you want)

## Pre
The `pre` function is run after the frontend and backend is pulled from redis, but before a backend has been choosen to route to. Some examples of what you could use the `pre` function to do are, custom authorization, backend rate limiting, test for required headers, etc.

Also, by using [ngx.redirect](http://wiki.nginx.org/HttpLuaModule#ngx.redirect), you can redirect them to a custom page (ie 403 unauthorized page, or login portal).

If you wish the method to do nothig, just return nil.
```return nil```

## Balance
The `balance` function is run to figure out which server in the backend to proxy the request to. Multiple plugins can be used in a "daisy-chain" kind of way. Each plugin is run with the list of available servers and should return a list of remaining available servers. 

For example, say you have two plugins enabled, `score` and `random`. The `score` plugin is configured in your configuration file to behave in a `least-score` manner (in oppose to `most-score`). The score value can be whatever you want, number of connections, CPU utilization, number of threads that server is using, etc. In our case, lets assume its number of connections. 
Say a request comes in a backend, and 1 server has 30 connections, while the other 2 servers have 10 connections each. The `score` plugin will receive all three servers as input, and it will return the 2 servers with 10 connections. Then, the `random` plugin recieve the output of the `score` plugin (ie those 2 servers) and picks a random one and returns 1 server. That server is then used to proxy the request.
It is always a good idea to enable `random` as the last plugin, as a "catch all" in case you have gone through all other plugins and were not able to filter down to a single server.

If you wish the balance function to do thing, just return the list of server you recieved
``` return session['servers']```

## Post
The `post` function is run after a server has been chosen to proxy the request to. This can be used to do things as write the server to a cookie for stickiness, send metric data to a service, server level rate limiting, etc.

If you wish the method to do nothig, just return nil.
```return nil```
