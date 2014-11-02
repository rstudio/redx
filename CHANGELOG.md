Changelog
=========

## 2.0 (2014-11-1)

### Features
+ [PR](https://github.com/rstudio/redx/pull/7): Plugin-support
+ Code optimizations and refactoring
+ Switched redis database to use hashes instead of sorted sets
+ `/batch` now supports backend configs and score values
+ Add support for a max\_path\_length of zero (only frontends with domain only, no path)

### Backwards Incompatibility Note
There is a significant database restructuring in this version of redx. If you're upgrading from a previous version, flush the db after updating.
A new path was added (the plugins directory), so you'll need to update the `lua_package_path` in your nginx config. See `nginx.conf.example` for an example.

## 1.3.0 (2014-10-20)

### Feature
+ [PR](https://github.com/rstudio/redx/pull/6): Added two new API endpoints. `/backends` and `/frontends` with gets all frontends or backends.

## 1.2.1 (2014-10-15)

### Feature
+ [PR](https://github.com/rstudio/redx/pull/5): Adds the ability to set a default score value when one is not provided.

## 1.2.0 (2014-10-14)

### Backwards Incompatibility Note
There is a significant database restructuring in this version of redx. If you're upgrading from a previous version, flush the db after updating.

### Feature
+ [PR](https://github.com/rstudio/redx/pulls): Add ability to probabilistically load balance backends based on their score value (most or least)

## 1.1.0 (2014-07-27)

### Feature
+ [PR](https://github.com/rstudio/redx/pull/1): Add new api endpoint, `/orphans`, that returns or deletes all frontends and backends that are orphaned.

## 1.1 (2014-07-27)

### Bug Fixes
+ [BUG](https://github.com/rstudio/redx/commit/d5051bbdc573b5017382268ec7dcf118a2fe0305): in common condition, the get\_frontend function in the redis library would not close the connection or release it back to the keepalive pool. 
