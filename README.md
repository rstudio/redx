[![Build Status](https://travis-ci.org/rstudio/redx.svg)](https://travis-ci.org/rstudio/redx)
redx
======

Redx (or redis-nginx) is an embedded lua based approach of having a dynamic configuration of nginx of frontends and backends with redis as the data store. Its inspired by [hipache](https://github.com/samalba/hipache-nginx). It has a restful api (that runs within nginx itself) to manage the many-to-one relationships between frontends to backends. 

One of the main benefits of redx is the ability to update your nginx config without needing to reload nginx. This is useful for environments that are nearly constantly changing their large nginx config due to cases such as elastic backends or new user signups. Also, this allows you to have a single nginx config across multiple nginx servers making it easier to have high availability and scalability on your load balancing layer. 

Project Status
==============

Redx is new, but at [rstudio](http://www.rstudio.com/), we are using it in production serving all web traffic for [shinyapps](https://www.shinyapps.io/).

How it works
============

## The Components
Redx is composed of two components; the api and main. The api is a restful api embedded in lua and runs within the nginx process. It runs on its own port (for ease of firewall security) and is manages the frontends and backends in the nginx config by editing the redis database.

The other component is main, and this is what takes regular traffic from your users. It looks up the proper backend to proxy the request to based on the host and path.

## The fallback
In the event that there isn't a frontend or backend match for an incoming request **OR** the backend server the request was proxied to isn't responding, the request is sent to the `fallback`. This is typically your application server, which handles these failure scenario. Several headers are added to the request to help your application server understand the context in which the request is coming in. In some cases, you may want to update redx by hitting the API and insert the missing frontend and/or backend and sent them back to nginx, or maybe you want to forward them to a custom 404 page. Its up to you to decide what the behavior you want it to be.

Performance
===========

At [rstudio](http://www.rstudio.com/), we find that redx performs slightly slower than regular redis config files. Of course, this makes sense, as you're now querying a remote redis server to lookup frontends and backends, instead of caching all that in local memory. In our unofficial benchmarks, we see a 10ms increase in response time. That being said, the payoff of having dynamic configuration and being able to easily do high availability with active active nginx load balancer is well worth the 10ms cost. Each environment is different and has different requirements, goals, etc. So its up to you to decide what is worth what.

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

The redx code on your local workstation is run within vagrant (due to sharing the redx directory with vagrant at `/home/vagrant/redx`). As you make code changes, they should take affect immediately and do not require reloading nginx. You will however need to reload nginx when you change the nginx config located `vagrant://etc/nginx/sites-available/redx.conf`.
To see redx logs, see `/var/log/nginx/[access,error].log`

Testing
=======

Redx uses a testing framework, [busted](http://olivinelabs.com/busted/), to run integration tests. To run these tests, execute `busted lua/spec`. Continuous integration is setup with [travis ci](https://travis-ci.org/rstudio/redx).

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
The max number of path parts to look up. This defines the max length of a path to be to lookup the corresponding frontend in redis.

Say in your service, your path always consists of an account name and service name ( ie http://sasservice.com/jdoe/app1). The user, may come into nginx with more to the path than that (ie http://sasservice.com/jdoe/app1/static/js/base.js), but when request comes in, redx will only search for "sasservice.com/jdoe/app1" first and "sasservice.com/jdoe" second as frontends in the database.

Currently max_path_length must be a minimum of 1, but that will change in the future.

##### stickiness
The amount of time (in seconds) you wish the session to be "sticky", and consistently use the same upstream server. If you wish to disable "stickiness", set value to 0 (zero).

##### balance\_algorithm
The load balancing algorithm you want to use to balance traffic to your backends. The options are `least-score`, `most-score`, and `random`. `Random` is the default.

Load Balancing Algorithms
=========================

Redx has a few options for how to load balance to various backends. The default, is `random` which works exactly how you would imagine. The other options are `least-score` and `most-score`. 
For `least-score` and `most-score`, associated with each backend, is a score. This score number is arbitrary, and can be whatever you want it to be. It can represent the number of connections a backend has, the amount of cpu or memory a backend is using, or something custom to your application like number of threads.
Each set of backends can be configured to have a maximum score (ie max number of connections, CPU usage, max number of threads, etc). This maximum value is used in evaluating which backend traffic is sent to. It is important to note, that due to the score values are assumed not to be realtime, we use a probabilistic approach to routing traffic. This is so we don't send all traffic to a single backend in between each update of the score value. So efforts to balance traffic is "best efforts" and are **NOT** guarenteed. Similar to a casino, while you may statistically loose some money sometimes, eventually the house always wins.
Load balancing does **NOT** override stickiness. If you have stickiness enabled, it is honored while a stickiness session exists. But new traffic, aka traffic that doesn't have an active stickiness session, are load balanced according to the algorithm chosen.

API
===

### (GET|POST|PUT|DELETE) /frontends/\<url\>/\<backend_name\>

The `frontends` endpoint allows you to get, update, or delete a frontend. Take note that `POST` and `PUT` are treated the same on this endpoint. It is also important that you character escape the frontend url properly.

#### Examples

##### `GET` example
```
curl localhost:8081/frontends/myhost.com%2Ftest
```

##### `POST/PUT` example
```
curl -X POST localhost:8081/frontends/myhost.com%2Ftest/mybackend
```

##### `DELETE` example
```
curl -X DELETE localhost:8081/frontends/myhost.com%2Ftest
```

### (GET|POST|PUT|DELETE) /backends/\<name\>/\<server\>

The `backends` endpoint allows you to get, update, replace, or delete a backend. Using the `POST` method will "append-only" to the backend, while the `PUT` method will replace what is there in a single redis commit. Be sure to character escape as needed.

#### Examples

##### `GET` example
```
curl localhost:8081/backends/mybackend
```

##### `POST/PUT` example
```
curl -X POST localhost:8081/backends/mybackend/google.com%3A80
```

##### `DELETE` example
```
# will delete the entire backend
curl -X DELETE localhost:8081/backends/mybackend
# will delete one server in the backend
curl -X DELETE localhost:8081/backends/mybackend/google.com%3A80
```

### (PUT) /backends/\<name\>/\<server\>/score/\<score>

The `backend score` endpoint allows you to update the score a backend has. This score is used by the `least-score` and `most-score` load balancing algorithm to probabilistically send incoming requests to the most probably backend with the least or most score.

#### Examples

##### `PUT` example
```
curl -X PUT localhost:8081/backends/mybackend/google.com%3A80/score/31
```

### (GET|PUT) /backends/\<name\>/config/\<config_name\>/\<config_value\>

The `backend configuration` endpoint allows you to get, update, or replace a backend config. Be sure to character escape as needed.

#### Examples

##### `GET` example
```
curl localhost:8081/backends/mybackend/config/_max_score/30
```

##### `PUT` example
```
curl -X PUT localhost:8081/backends/mybackend/config/_max_score
```

### (DELETE) /flush

Flush clears the redis database of all data. Its literally runs the [`FLUSHDB`](http://redis.io/commands/flushdb) command within redis.

#### Examples

##### `DELETE` example

```
curl -X DELETE localhost:8081/flush
```
### (POST|PUT|DELETE) /batch

Batch allows you to make multiple edits in a single http request and redis commit. You **MUST** have a json body with your http request. Similar to the `backends` endpoint, the `POST` method will "append-only" to the backend, while the `PUT` method will replace what is there in a single redis commit.

The json body must follow this json structure exactly

```
{
    "frontends": [
        {
            "url": "localhost/search",
            "backend_name": "12345"
        },
        {
            "url": "test.com/menlo/park",
            "backend_name": "menlobackend"
        }
    ],
    "backends": [
        {
            "name": "12345",
            "servers": [
                "google.com:80",
                "duckduckgo.com:80"
            ]
        },
        {
            "name": "menlobackend",
            "servers": [
                "menloparkmuseum.org",
                "tesc.edu"
            ]
        }
    ]
}
```

#### Examples

##### `POST/PUT` example
```
curl -X POST localhost:8081/batch -d '{
    "frontends": [
        {
            "url": "localhost/test",
            "backend_name": "12345"
        }
    ],
    "backends": [
        {
            "name": "12345",
            "servers": [
                "google.com:80",
                "duckduckgo.com:80"
            ]
        }
    ]
}'
```
##### `DELETE` example
```
# will delete the frontend and backend
curl -X DELETE localhost:8081/batch -d '{
    "frontends": [
        {
            "url": "localhost/test"
        }
    ],
    "backends": [
        {
            "name": "12345"
        }
    ]
}'

# will delete only one of the servers in the backend
curl -X DELETE localhost:8081/batch -d '{
    "backends": [
        {
            "name": "12345",
            "servers": [
                "google.com:80"
            ]
        }
    ]
}'
```

### (GET) /health
This endpoint is designed to be used to check the health of redx. When you hit this endpoint, redx with attempt to write, read, and delete a key in redis to confirm that its capable of accessing redis. Getting a `200` response code from this endpoint should mean that the redx service is healthy.

##### `GET` example
```
curl localhost:8081/health
```

### (GET|DELETE) /orphans
Will return or delete any frontends and backends that are orphans. Meaning a list of any frontends that point to a missing backend, or any backends that don't have a frontend pointing to it.

##### `GET` example
```
curl localhost:8081/orphans
```

##### `DELETE` example
```
curl -X DELETE localhost:8081/orphans
```

