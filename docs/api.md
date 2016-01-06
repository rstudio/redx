API
===

### (GET) /frontends

The `frontends` endpoint allows you to get all current frontends

#### Examples

##### `GET` example
```
curl localhost:8081/frontends
```

### (GET|POST|PUT|DELETE) /frontends/\<url\>/\<backend_name\>

The `frontends` endpoint allows you to get, update, or delete a frontend. Take note that `POST` and `PUT` are treated the same on this endpoint. It is also important that you character escape the frontend url properly.

#### Examples

##### `GET` example
```
curl localhost:8081/frontends/myhost.com%2Ftest%2F
```

##### `POST/PUT` example
```
curl -X POST localhost:8081/frontends/myhost.com%2Ftest/mybackend
```

##### `DELETE` example
```
curl -X DELETE localhost:8081/frontends/myhost.com%2Ftest%2F
```

### (GET) /backends

The `backends` endpoint allows you to get all backends.

#### Examples

##### `GET` example
```
curl localhost:8081/backends
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

### (GET|PUT|DELETE) /backends/\<name\>/config/\<config_name\>/\<config_value\>

The `backend configuration` endpoint allows you to get, update, or replace a backend config. Be sure to character escape as needed.

#### Examples

##### `GET` example
```
curl localhost:8081/backends/mybackend/config/max_score
```

##### `PUT` example
```
curl -X PUT localhost:8081/backends/mybackend/config/max_score/30
```

##### `DELETE` example
```
curl -X DELETE localhost:8081/backends/mybackend/config/max_score
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

The json body must follow this json structure exactly. The list of backend servers can be either a string (the server address) or an array (the server address and score value).

```
{
    "frontends": [
        {
            "url": "localhost/search/",
            "backend_name": "12345"
        },
        {
            "url": "test.com/menlo/park/",
            "backend_name": "menlobackend"
        }
    ],
    "backends": [
        {
            "name": "12345",
            "servers": [
                ["google.com:80", 0]
                ["duckduckgo.com:80", 0]
            ],
            "config": {
                "city": "boston"
            }
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
            "url": "localhost/test/",
            "backend_name": "12345"
        }
    ],
    "backends": [
        {
            "name": "12345",
            "servers": [
                "google.com:80",
                ["duckduckgo.com:80", 10]
            ],
            "config": {
                "sky_color": "blue"
            }
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
            "url": "localhost/test/"
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

