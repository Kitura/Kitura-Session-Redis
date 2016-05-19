/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import KituraSys
import KituraSession
import SwiftRedis

import Foundation

public class RedisStore: Store {
    
    public var ttl : Int
    
    public var db : Int
    
    public var redisHost : String
    
    public var redisPort : Int32
    
    public var redisPassword : String?
    
    private var redis: Redis
    
    private var queue : Queue
    
    init (redisHost: String, redisPort: Int32, redisPassword: String?=nil, ttl: Int = 3600, db: Int = 0) {
        self.ttl = ttl
        self.queue = Queue(type: .serial)
        self.db = db
        self.redisHost = redisHost
        self.redisPort = redisPort
        self.redisPassword = redisPassword
        
        redis = Redis()
    }
    
    public func setupRedis (callback: (error: NSError?) -> Void) {
        redis.connect(host: self.redisHost, port: self.redisPort) { error in
            if  let error = error {
                callback(error: NSError(domain: "SessionRedisDomain", code: 0, userInfo: [NSLocalizedDescriptionKey : "Failed to connect to the Redis server at \(self.redisHost):\(self.redisPort). Error=\(error.localizedDescription)"]))
            }
            else {
                if let redisPassword = self.redisPassword {
                    self.redis.auth(redisPassword) { error in
                        if  let error = error {
                            callback(error: NSError(domain: "SessionRedisDomain", code: 0, userInfo: [NSLocalizedDescriptionKey : "Failed to authenticate to the Redis server at \(self.redisHost):\(self.redisPort). Error=\(error.localizedDescription)"]))
                        }
                        else {
                            if self.db != 0 {
                                self.redis.select(self.db) { error in
                                    if  let error = error {
                                        callback(error: NSError(domain: "SessionRedisDomain", code: 0, userInfo: [NSLocalizedDescriptionKey :"Failed to select db \(self.db) at the Redis server at \(self.redisHost):\(self.redisPort). Error=\(error.localizedDescription)"]))
                                    }
                                    callback(error: nil)
                                }
                            }
                            else {
                                callback(error: nil)
                            }
                        }
                    }
                }
                else {
                    if self.db != 0 {
                        self.redis.select(self.db) { error in
                            if  let error = error {
                                callback(error: NSError(domain: "SessionRedisDomain", code: 0, userInfo: [NSLocalizedDescriptionKey :"Failed to select db \(self.db) at the Redis server at \(self.redisHost):\(self.redisPort). Error=\(error.localizedDescription)"]))
                            }
                            else {
                                callback(error: nil)
                            }
                        }
                    }
                    else {
                        callback(error: nil)
                    }
                }
            }
        }
    }
    
    public func load(sessionId: String, callback: (data: NSData?, error: NSError?) -> Void) {
        var redisData: NSData?
        var redisError: NSError?
        queue.queueSync {
            self.redis.get(sessionId) { redisString, error in
                redisData = redisString?.asData
                redisError = error
            }
        }
        callback(data: redisData, error: redisError)
    }
    
    public func save(sessionId: String, data: NSData, callback: (error: NSError?) -> Void) {
        var redisError: NSError?
        queue.queueSync {
            self.redis.set(sessionId, value: RedisString(data), expiresIn: Double(self.ttl)) { _, error in
                redisError = error
            }
        }
        callback(error: redisError)
    }
    
    public func touch(sessionId: String, callback: (error: NSError?) -> Void) {
        var redisError: NSError?
        queue.queueSync {
            self.redis.expire(sessionId, inTime: Double(self.ttl)) { _, error in
                redisError = error
            }
        }
        callback(error: redisError)
    }
    
    public func delete(sessionId: String, callback: (error: NSError?) -> Void) {
        var redisError: NSError?
        queue.queueSync {
            self.redis.del(sessionId) { _, error in
                redisError = error
            }
        }
        callback(error: redisError)
    }
}
