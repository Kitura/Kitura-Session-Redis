# Kitura-Session-Redis
Kitura-Session store using Redis as the backing store

[![Build Status - Master](https://travis-ci.org/IBM-Swift/Kitura.svg?branch=master)](https://travis-ci.org/IBM-Swift/Kitura-Session-Redis)
![Mac OS X](https://img.shields.io/badge/os-Mac%20OS%20X-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)
![Apache 2](https://img.shields.io/badge/license-Apache2-blue.svg?style=flat)

## Summary
 [Kitura-Session](https://github.com/IBM-Swift/Kitura-Session) store using [Redis](http://redis.io/) as the backing store

## Table of Contents
* [Swift version](#swift-version)
* [API](#api)
* [License](#license)

## Swift version
The latest version of Kitura-Credentials works with the DEVELOPMENT-SNAPSHOT-2016-05-09-a version of the Swift binaries. You can download this version of the Swift binaries by following this [link](https://swift.org/download/). Compatibility with other Swift versions is not guaranteed.


## API
In order to use Redis as session store, create an instance of `RedisStore`, and pass it to `Session` constructor:

```swift
import KituraSession
import KituraSessionRedis

let connectionParameters = RedisConnectionParameters(host: host, port: port, password: password)
let options = RedisOptions(ttl: ttl)
let redisStore = RedisStore(redisConnectionParameters: connectionParameters, redisDatabaseOptions: options)

let session = Session(secret: <secret>, store: redisStore)
```

`RedisStore` constructor gets two parameters: `RedisConnectionParameters` (host, port, and optional password) and optional `RedisOptions` (ttl, database number, and key prefix):

```swift
public init (redisConnectionParameters: RedisConnectionParameters, redisDatabaseOptions: RedisOptions? = nil)
```

You can set Redis password in `redis.conf` file:
```
requirepass <your password>
```
The maximum number of databases is also set in `redis.conf` file:
```
databases <number of databases>
```
The `databaseNumber` in  `RedisOptions` must be between 0 and this number minus 1.

## License
This library is licensed under Apache 2.0. Full license text is available in [LICENSE](LICENSE.txt).
