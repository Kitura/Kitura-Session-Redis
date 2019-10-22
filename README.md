<p align="center">
    <a href="http://kitura.io/">
        <img src="https://raw.githubusercontent.com/IBM-Swift/Kitura/master/Sources/Kitura/resources/kitura-bird.svg?sanitize=true" height="100" alt="Kitura">
    </a>
</p>


<p align="center">
    <a href="https://ibm-swift.github.io/Kitura-Session-Redis/index.html">
    <img src="https://img.shields.io/badge/apidoc-KituraSessionRedis-1FBCE4.svg?style=flat" alt="APIDoc">
    </a>
    <a href="https://travis-ci.org/IBM-Swift/Kitura-Session-Redis">
    <img src="https://travis-ci.org/IBM-Swift/Kitura-Session-Redis.svg?branch=master" alt="Build Status - Master">
    </a>
    <img src="https://img.shields.io/badge/os-macOS-green.svg?style=flat" alt="macOS">
    <img src="https://img.shields.io/badge/os-linux-green.svg?style=flat" alt="Linux">
    <img src="https://img.shields.io/badge/license-Apache2-blue.svg?style=flat" alt="Apache 2">
    <a href="http://swift-at-ibm-slack.mybluemix.net/">
    <img src="http://swift-at-ibm-slack.mybluemix.net/badge.svg" alt="Slack Status">
    </a>
</p>

# Kitura-Session-Redis

A [Kitura-Session](https://github.com/IBM-Swift/Kitura-Session) store using [Redis](http://redis.io/) as the backing store.

## Swift version
The latest version of Kitura-Session-Redis requires **Swift 4.0 or newer**. You can download this version of the Swift binaries by following this [link](https://swift.org/download/). Compatibility with other Swift versions is not guaranteed.

## Usage

#### Add dependencies

Add the `Kitura-Session-Redis` package to the dependencies within your application’s `Package.swift` file. Substitute `"x.x.x"` with the latest `Kitura-Session-Redis` [release](https://github.com/IBM-Swift/Kitura-Session-Redis/releases).

```swift
.package(url: "https://github.com/IBM-Swift/Kitura-Session-Redis.git", from: "x.x.x")
```

Add `KituraSessionRedis` to your target's dependencies:

```swift
.target(name: "example", dependencies: ["KituraSessionRedis"]),
```

#### Import package

```swift
import KituraSessionRedis
```

### Getting Started

In order to use Redis as a session store, create an instance of `RedisStore`, and pass it to the `Session` constructor:

```swift
import KituraSession
import KituraSessionRedis

let redisStore = RedisStore(redisHost: host, redisPort: port, redisPassword: password)
let session = Session(secret: "Your secret string", store: redisStore)
```

The `RedisStore` constructor requires both the host and port for the Redis server to be defined, the rest of the parameters are optional:

```swift
init(redisHost: String, redisPort: Int32, redisPassword: String?=nil, ttl: Int = 3600, db: Int = 0, keyPrefix: String = "s:")
```

**Where:**
   - *redisHost* is the host of the Redis server.
   - *redisPort* is the port the Redis server is listening on.
   - *redisPassword* is the password to use if Redis password authentication is set up on the Redis server.
   - *ttl* is the time to live value for the stored entries, defaults to 3600 seconds.
   - *db* is the number of the Redis database to store the session data in, defaults to 0.
   - *keyPrefix* is the prefix to be added to the keys of the stored data, defaults to "s:".

You can set the Redis password in your `redis.conf` file:
```
requirepass <your password>
```
The maximum number of databases is also defined in `redis.conf`:
```
databases <number of databases>
```
The *db* parameter that is passed to the constructor must be between 0 and this number minus 1.

## Contributing

Contributions to the Kitura-Session-Redis project are welcome.  You will want to be able to test your changes locally before submitting a pull request.

To run the tests for `Kitura-Session-Redis` you must first set up Redis.
From the Kitura-Session-Redis directory, run the following commands:

#### macOS
```
brew install redis --build-from-source || brew outdated redis || brew upgrade redis
export REDIS_CONF_FILE=/usr/local/etc/redis.conf
password=$(head -n 1 "Tests/KituraSessionRedisTests/password.txt")
sudo perl -pi -e "s/# requirepass foobared/requirepass ${password}/g" $REDIS_CONF_FILE
redis-server $REDIS_CONF_FILE
```

#### Linux
```
sudo apt-get update -y
sudo apt-get install -y redis-server
export REDIS_CONF_FILE=/etc/redis/redis.conf
sudo chmod go+x /etc/redis/
sudo chmod go+r $REDIS_CONF_FILE
password=$(head -n 1 "Tests/KituraSessionRedisTests/password.txt")
sudo perl -pi -e "s/# requirepass foobared/requirepass ${password}/g" $REDIS_CONF_FILE
sudo service redis-server restart
```

Then run  `swift test`.

## API Documentation
For more information visit our [API reference](https://ibm-swift.github.io/Kitura-Session-Redis/index.html).

## Community

We love to talk server-side Swift, and Kitura. Join our [Slack](http://swift-at-ibm-slack.mybluemix.net/) to meet the team!

## License
This library is licensed under Apache 2.0. Full license text is available in [LICENSE](LICENSE.txt).
