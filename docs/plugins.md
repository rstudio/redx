Plugins
=======

Plugins allow redx to be extended in all sorts of ways. This can anywhere from custom load balncing algorthms, authorization, rate limiting, metrics collection, etc. Each plugin is actually executed three times at different points of the request. 

Its executed after the frontend and backend information has been acquired, but before the load balancing algorthm has been run. This is good for stuff like rate limiting, authorization, or reject requests that don't contain the proper header or cookie. 

Each plugin is next executed while trying to find the server to proxy the request to. This is where you'd want to inject your own load balancing algorthm if you choose. When picking the server, a list of all available servers are passed to the first plugin. That plugin returns a list of still available servers (it may filter no servers from the list, one or two, or all but one). This new list is then passed to the next plugin until there is only one server left.
For an example, say you had a backend with 5 servers. The first plugin is load balancing based on least connections. Two of the servers are tied with least number of connections of 10 connections. Those two servers are then passed to the second plugin which is called "random". This plugin gets those two servers, picks a random one, that becomes the server we proxy to. By daisy-chaining multiple plugins together you can get a very flexible means to load balance. 

Then, after a server has been picked to proxy to, each plugin is run again to do any actions it wants. An example of this may be to write the server to a cookie for stickiness, collect metrics, or add custom headers to the request.

Develop Plugins
===============

There are three functions your plugin can support (all are optional), `pre, `balance`, `post`. Each of these methods are passed the request object, the session data, and the parameter (as configured in your configuration file)

### Request Object
The request object is the lapis session that stores all sorts of information about [the request](http://leafo.net/lapis/reference/actions.html#request-object).

### Session Data
Session data is information about the request that redx has generated. It is a table variable type (dictionary) that contains the follow key values
 * **frontend** - the frontend used
 * **backend** - the backend used
 * **servers** - list of servers available for this backend and their scores
 * **config** - a dictionary of configs set for this backend
 * **server** - The server choosen to proxy the request to

### Parameter
The parameter is anything of your choosing. You specify it in the config file, but you can only have one param (but you're free to use a table if you want)

## Pre
The `pre` function is run after the frontend and backend is pulled from redis, but before a server has been choosen to route to. Some examples of what you could use the `pre` function to do are, custom authorization, backend rate limiting, test for required headers, etc. This function should **always** return `nil` unless you want to halt the request with an error code and message. If you wish to halt the request and respond with an error code and message, return a table with `status` as the error code and `message` as the message. You can also return an optional `content\_type` (default is "text/plain")

#### Example
```moonscript
M.pre = (request, session, param) ->
    if param == "call it quits"
        return status: 500, message: "I'm calling it quits", content_type: "text/plain"
    else
        return nil
```

Also, by using [ngx.redirect](http://wiki.nginx.org/HttpLuaModule#ngx.redirect), you can redirect them to a custom page (ie 403 unauthorized page, or login portal).

## Balance
The `balance` function is run to figure out which server in the backend to proxy the request to. Multiple plugins can be used in a "daisy-chain" kind of way. Each plugin is run with the list of available servers and should return a list of remaining available servers. 

## Post
The `post` function is run after a server has been chosen to proxy the request to. This can be used to do things as write the server to a cookie for stickiness, send metric data to a service, server level rate limiting, etc. Similar to `pre`, you can redirect here or return an error code and message. Otherwise, this function should **always** return `nil`.
