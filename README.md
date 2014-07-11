rpache
======

Rpache is a lua-based methodology of having a dynamic configuration of nginx. Its greatly inspired by [hipache](https://github.com/samalba/hipache-nginx). It utilized redis as its database.

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
