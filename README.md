redx (experimental)
======

Redx is a lua-based approach of having a dynamic configuration of nginx. Its greatly inspired by [hipache](https://github.com/samalba/hipache-nginx). It has a restful api (that runs inside nginx itself) to manage the many-to-one relationships between frontends that points to a backend. Frontends are host and paths, while backends is a list of upstream servers.

How it works
============

Redx is composed of two components; the api and main. The api is a restful api embedded in lua and runs within the nginx process. It runs on a specific port and is manages the backends associated to references in the redis database.

The other component is main, and this is what takes regular traffic, looks up the proper backend based on host and path.

Setup Dev Environment
=====================

Setup and start vagrant

```bash
  vagrant plugin install vagrant-berkshelf --plugin-version '>= 2.0.1'
  vagrant plugin install vagrant-omnibus
  vagrant up
  vagrant ssh -c 'lapis server'
```
