rpache
======

Rpache is a lua-based methodology of having a dynamic configuration of nginx. Its greatly inspired by [hipache](https://github.com/samalba/hipache-nginx). It utilized redis as its database.

How it works
============

rpache is composed of two components; the api and main. The api is a restful api embedded in lua and runs within the nginx process. It runs on a specific port and is manages the backends associated to references in the redis database.

The other component is main, and this is what takes regular traffic, looks up the proper backend based on the subdomain and url, and proxies the request.

Setup Dev Environment
=====================

Setup and start vagrant

```bash
  vagrant plugin install vagrant-berkshelf --plugin-version '>= 2.0.1'
  vagrant plugin install vagrant-omnibus
  vagrant up
```

Start nginx

```bash
  vagrant ssh -c "sudo nginx -c $(pwd)/rpache/nginx.conf"
```

## Example usage

```bash
  # API runs on port 8081
  # add duckduckgo as a backend to localhost_demo (localhost => account_name, demo => app_name)
  curl -XPOST localhost:8081/localhost_demo?host=duckduckgo.com\&port=80
  # add google as a backend also
  curl -XPOST localhost:8081/localhost_demo?host=google.com\&port=80

  # MAIN runs on port 8080
  # get routed to one of the backends we created
  curl -L localhost:8080/demo
```

API
===

#### Get an upstream(s) for a reference

```
GET /<reference>
  @params:
    random: boolean (optional)
```

Example `curl localhost:8080/myref`
Example `curl localhost:8080/myref?randome=true`

#### Add an upstream to a reference

```
POST /<reference>
  @params
    host: string (required)
    port: integer (required)
```

Example `curl -X POST "localhost:8080/myref?host=agent01&port=443"`

#### Delete an upstream for a reference

```
DELETE /<reference>
  @params
    host: string (required)
    port: integer (required)
```

Example `curl -X DELETE "localhost:8080/myref?host=agent01&port=443"`

#### Delete all upstreams for reference

```
DELETE /<reference>
```

Example `curl -X DELETE "localhost:8080/myref`


TODO
====

1. monitor for "dead" backends, and disable them when they are down. (#hint, use sdiff in redis)
