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
import Dispatch

import Foundation

public class RedisStore: Store {
    
    
    public let redisHost : String
    public let redisPort : Int32
    public let redisPassword : String?
    
    public let keyPrefix : String
    public let ttl : Int
    public let db : Int

    private var redis: Redis
    
    private let semaphore : dispatch_semaphore_t
    
    init (redisHost: String, redisPort: Int32, redisPassword: String?=nil, ttl: Int = 3600, db: Int = 0, keyPrefix: String = "s:") {
        self.ttl = ttl
        self.db = db
        self.redisHost = redisHost
        self.redisPort = redisPort
        self.redisPassword = redisPassword
        self.keyPrefix = keyPrefix
        
        redis = Redis()
        semaphore = dispatch_semaphore_create(1)
    }
    
    private func setupRedis (callback: RedisSetupCallback) {
        redis.connect(host: self.redisHost, port: self.redisPort) { error in
            guard error == nil else {
                callback(error: RedisStore.createError(errorMessage: "Failed to connect to the Redis server at \(self.redisHost):\(self.redisPort). Error=\(error!.localizedDescription)"))
                return
            }
            
            if let redisPassword = self.redisPassword {
                self.redis.auth(redisPassword) { error in
                    guard error == nil else {
                        callback(error: RedisStore.createError(errorMessage: "Failed to authenticate to the Redis server at \(self.redisHost):\(self.redisPort). Error=\(error!.localizedDescription)"))
                        return
                    }
                    self.selectRedisDatabase(callback: callback)
                }
            }
            else {
                self.selectRedisDatabase(callback: callback)
            }
        }
    }
    
    private func selectRedisDatabase (callback : RedisSetupCallback) {
        if db != 0 {
            redis.select(self.db) { error in
                if let error = error {
                    callback(error: RedisStore.createError(errorMessage: "Failed to select db \(self.db) at the Redis server at \(self.redisHost):\(self.redisPort). Error=\(error.localizedDescription)"))
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
    
    private static func createError(errorMessage: String) -> NSError {
        #if os(Linux)
            let userInfo: [String: Any]
        #else
            let userInfo: [String: String]
        #endif
        userInfo = [NSLocalizedDescriptionKey: errorMessage]
        return NSError(domain: "SessionRedisDomain", code: 0, userInfo: userInfo)

    }
    
    private func runWithSemaphore (runClosure: RunClosure, apiCallback: APICallback) {
        
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        redisExecute(runClosure: runClosure) { redisData, error in
            dispatch_semaphore_signal(self.semaphore)
            apiCallback(data: redisData, error: error)
        }
    }
    
    private func redisExecute (runClosure: RunClosure, semCallback: RunWithSemaphoreCallback) {
        if redis.connected == false {
            setupRedis() { error in
                if let error = error {
                    semCallback(data: nil, error: error)
                }
                else {
                    runClosure(semCallback)
                }
            }
        }
        else {
            runClosure(semCallback)
        }
    }
    
    public func load(sessionId: String, callback: (data: NSData?, error: NSError?) -> Void) {
        runWithSemaphore (
            runClosure: { semCallback in
                self.redis.get(self.keyPrefix + sessionId) { redisString, error in
                    semCallback(data: redisString?.asData, error: error)
                }
            },
            apiCallback: { data, error in
                callback(data: data, error: error)
            }
        )

    }
    
    public func save(sessionId: String, data: NSData, callback: (error: NSError?) -> Void) {
        runWithSemaphore (
            runClosure: { semCallback in
                self.redis.set(self.keyPrefix + sessionId, value: RedisString(data), expiresIn: Double(self.ttl)) { _, error in
                    semCallback(data: nil, error: error)
                }
            },
            apiCallback: { _, error in
                callback(error: error)
            }
        )

    }
    
    public func touch(sessionId: String, callback: (error: NSError?) -> Void) {
        runWithSemaphore (
            runClosure: { semCallback in
                self.redis.expire(self.keyPrefix + sessionId, inTime: Double(self.ttl)) { _, error in
                    semCallback(data: nil, error: error)
                }
            },
            apiCallback: { _, error in
                callback(error: error)
            }
        )

    }
    
    public func delete(sessionId: String, callback: (error: NSError?) -> Void) {
        runWithSemaphore (
            runClosure: { semCallback in
                self.redis.del(self.keyPrefix + sessionId) { _, error in
                    semCallback(data: nil, error: error)
                }
            },
            apiCallback: { _, error in
                callback(error: error)
            }
        )
    }
    
    private typealias RunClosure = ((data: NSData?, error: NSError?) -> Void) -> Void
    private typealias RunWithSemaphoreCallback = (data: NSData?, error: NSError?) -> Void
    private typealias RedisSetupCallback = (error: NSError?) -> Void
    private typealias APICallback = (data: NSData?, error: NSError?) -> Void

}
