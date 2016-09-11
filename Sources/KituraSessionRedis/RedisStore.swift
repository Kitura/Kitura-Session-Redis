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

import KituraSession
import SwiftRedis
import Dispatch

import Foundation

// MARK RedisStore

/// An implementation of the `Store` protocol for the storage of `Session` data
/// using Redis.
public class RedisStore: Store {
    
    /// The Time to Live value for the stored entries.
    public var ttl: Int
    
    /// The number of the Redis database to store the session data in.
    public var db: Int
    
    /// The host of the Redis server.
    public var redisHost: String
    
    /// The port the Redis server is listening on.
    public var redisPort: Int32
    
    /// The password to use if Redis password authentication is setup on the Redis server.
    public var redisPassword: String?
    
    /// The prefix to be added to the keys of the stored data.
    public var keyPrefix: String
    
    private var redis: Redis
    
    private let semaphore = DispatchSemaphore(value: 1)
    
    /// Initialize an instance of `RedisStore`.
    ///
    /// - Parameter redisHost: The host of the Redis server.
    /// - Parameter redisPort: The port the Redis server is listening on.
    /// - Parameter redisPassword: The password to use if Redis password authentication is setup on the Redis server.
    /// - Parameter ttl: The Time to Live value for the stored entries.
    /// - Parameter db: The number of the Redis database to store the session data in.
    /// - Parameter keyPrefix: The prefix to be added to the keys of the stored data.
    public init(redisHost: String, redisPort: Int32, redisPassword: String?=nil, ttl: Int = 3600, db: Int = 0, keyPrefix: String = "s:") {
        self.ttl = ttl
        self.db = db
        self.redisHost = redisHost
        self.redisPort = redisPort
        self.redisPassword = redisPassword
        self.keyPrefix = keyPrefix
        
        redis = Redis()
    }
    
    private func setupRedis(callback: RedisSetupCallback) {
        redis.connect(host: self.redisHost, port: self.redisPort) { error in
            guard error == nil else {
                callback(RedisStore.createError(errorMessage: "Failed to connect to the Redis server at \(self.redisHost):\(self.redisPort). Error=\(error!.localizedDescription)"))
                return
            }
            
            if let redisPassword = self.redisPassword {
                self.redis.auth(redisPassword) { error in
                    guard error == nil else {
                        callback(RedisStore.createError(errorMessage: "Failed to authenticate to the Redis server at \(self.redisHost):\(self.redisPort). Error=\(error!.localizedDescription)"))
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
    
    private func selectRedisDatabase(callback : RedisSetupCallback) {
        if db != 0 {
            redis.select(self.db) { error in
                if let error = error {
                    callback(RedisStore.createError(errorMessage: "Failed to select db \(self.db) at the Redis server at \(self.redisHost):\(self.redisPort). Error=\(error.localizedDescription)"))
                }
                else {
                    callback(nil)
                }
            }
        }
        else {
            callback(nil)
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
    
    private func runWithSemaphore(runClosure: RunClosure, apiCallback: @escaping APICallback) {
        _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        redisExecute(runClosure: runClosure) { redisData, error in
            self.semaphore.signal()
            apiCallback(redisData, error)
        }
    }
    
    private func redisExecute(runClosure: RunClosure, semCallback: @escaping RunWithSemaphoreCallback) {
        if redis.connected == false {
            setupRedis() { error in
                if let error = error {
                    semCallback(nil, error)
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
    
    /// Load the session data.
    ///
    /// - Parameter sessionId: The ID of the session.
    /// - Parameter callback: The closure to invoke once the session data is fetched.
    public func load(sessionId: String, callback: @escaping (Data?, NSError?) -> Void) {
        runWithSemaphore (
            runClosure: { semCallback in
                self.redis.get(self.keyPrefix + sessionId) { redisString, error in
                    semCallback(redisString?.asData, error)
                }
            },
            apiCallback: { data, error in
                callback(data, error)
            }
        )

    }
    
    /// Save the session data.
    ///
    /// - Parameter sessionId: The ID of the session.
    /// - Parameter data: The data to save.
    /// - Parameter callback: The closure to invoke once the session data is saved.
    public func save(sessionId: String, data: Data, callback: @escaping (NSError?) -> Void) {
        runWithSemaphore (
            runClosure: { semCallback in
                let value = RedisString(data)
                
                self.redis.set(self.keyPrefix + sessionId, value: value, expiresIn: Double(self.ttl)) { _, error in
                    semCallback(nil, error)
                }
            },
            apiCallback: { _, error in
                callback(error)
            }
        )

    }
    
    /// Touch the session data.
    ///
    /// - Parameter sessionId: The ID of the session.
    /// - Parameter callback: The closure to invoke once the session data is touched.
    public func touch(sessionId: String, callback: @escaping (NSError?) -> Void) {
        runWithSemaphore (
            runClosure: { semCallback in
                self.redis.expire(self.keyPrefix + sessionId, inTime: Double(self.ttl)) { _, error in
                    semCallback(nil, error)
                }
            },
            apiCallback: { _, error in
                callback(error)
            }
        )

    }
    
    /// Delete the session data.
    ///
    /// - Parameter sessionId: The ID of the session.
    /// - Parameter callback: The closure to invoke once the session data is deleted.
    public func delete(sessionId: String, callback: @escaping (NSError?) -> Void) {
        runWithSemaphore (
            runClosure: { semCallback in
                self.redis.del(self.keyPrefix + sessionId) { _, error in
                    semCallback(nil, error)
                }
            },
            apiCallback: { _, error in
                callback(error)
            }
        )
    }
    
    private typealias RunClosure = ((Data?, NSError?) -> Void) -> Void
    private typealias RunWithSemaphoreCallback = (Data?, NSError?) -> Void
    private typealias RedisSetupCallback = (NSError?) -> Void
    private typealias APICallback = (Data?, NSError?) -> Void

}
