# Kitura-Session-Redis
Kitura-Session store using Redis as the backing store


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

let redisStore = RedisStore(redisHost: host, redisPort: port, redisPassword: password)
let session = Session(secret: <secret>, store: redisStore)
```

`RedisStore` constructor requires Redis server host and port. The rest of the parameters are optional:

```swift
init (redisHost: String, redisPort: Int32, redisPassword: String?=nil, ttl: Int = 3600, db: Int = 0, keyPrefix: String = "s:")
```

You can set Redis password in `redis.conf` file:
```
requirepass <your password>
```
The maximum number of databases is also set in `redis.conf` file:
```
databases <number of databases>
```
The `db` passed to the constructor must be between 0 and this number minus 1.

## License
This library is licensed under Apache 2.0. Full license text is available in [LICENSE](LICENSE.txt).
