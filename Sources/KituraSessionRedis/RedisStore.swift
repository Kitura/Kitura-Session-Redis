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
    private let connectionParameters : RedisConnectionParameters
    private let redisOptions : RedisOptions
    private let redis: Redis
    private let semaphore : dispatch_semaphore_t
    
    public init (redisConnectionParameters: RedisConnectionParameters, redisDatabaseOptions: RedisOptions? = nil) {
        redis = Redis()
        semaphore = dispatch_semaphore_create(1)
        connectionParameters = redisConnectionParameters
        redisOptions = (redisDatabaseOptions != nil) ? redisDatabaseOptions! : RedisOptions()
    }
    
    private func authenticate(callback: RedisSetupCallback) {
        if let redisPassword = connectionParameters.redisPassword {
            self.redis.auth(redisPassword) { error in
                callback(error: error)
            }
        }
        else {
            callback(error: nil)
        }
    }
    
    private func setupRedis (callback: RedisSetupCallback) {
        redis.connect(host: self.connectionParameters.redisHost, port: self.connectionParameters.redisPort) { error in
            guard error == nil else {
                callback(error: RedisStore.createError(errorMessage: "Failed to connect to the Redis server at \(self.connectionParameters.redisHost):\(self.connectionParameters.redisPort). Error=\(error!.localizedDescription)"))
                return
            }
            self.authenticate { error in
                guard error == nil else {
                    callback(error: RedisStore.createError(errorMessage: "Failed to connect to the Redis server at \(self.connectionParameters.redisHost):\(self.connectionParameters.redisPort). Error=\(error!.localizedDescription)"))
                    return
                }
                self.selectRedisDatabase(callback: callback)
            }
        }
    }
    
    private func selectRedisDatabase (callback : RedisSetupCallback) {
        if redisOptions.databaseNumber != 0 {
            redis.select(redisOptions.databaseNumber) { error in
                if let error = error {
                    callback(error: RedisStore.createError(errorMessage: "Failed to select db \(self.redisOptions.databaseNumber) at the Redis server at \(self.connectionParameters.redisHost):\(self.connectionParameters.redisPort). Error=\(error.localizedDescription)"))
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
    
    private func runWithSemaphore(runClosure: RunClosure, apiCallback: APICallback) {
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        redisExecute(runClosure: runClosure) { redisData, error in
            dispatch_semaphore_signal(self.semaphore)
            apiCallback(data: redisData, error: error)
        }
    }
    
    private func redisConnect(callback: RedisSetupCallback) {
        if redis.connected == false {
            setupRedis() { error in
                callback(error: error)
            }
        }
        else {
            callback(error: nil)
        }
    }

    private func redisExecute(runClosure: RunClosure, semaphoreCallback: RunWithSemaphoreCallback) {
        redisConnect() { error in
            if let error = error {
                semaphoreCallback(data: nil, error: error)
            }
            else {
                runClosure(semaphoreCallback)
            }
        }
    }
    
    public func load(sessionId: String, callback: (data: NSData?, error: NSError?) -> Void) {
        runWithSemaphore (
            runClosure: { semaphoreCallback in
                self.redis.get(self.redisOptions.keyPrefix + sessionId) { redisString, error in
                    semaphoreCallback(data: redisString?.asData, error: error)
                }
            },
            apiCallback: { data, error in
                callback(data: data, error: error)
            }
        )
    }
    
    public func save(sessionId: String, data: NSData, callback: (error: NSError?) -> Void) {
        runWithSemaphore (
            runClosure: { semaphoreCallback in
                self.redis.set(self.redisOptions.keyPrefix + sessionId, value: RedisString(data), expiresIn: Double(self.redisOptions.ttl)) { _, error in
                    semaphoreCallback(data: nil, error: error)
                }
            },
            apiCallback: { _, error in
                callback(error: error)
            }
        )
    }
    
    public func touch(sessionId: String, callback: (error: NSError?) -> Void) {
        runWithSemaphore (
            runClosure: { semaphoreCallback in
                self.redis.expire(self.redisOptions.keyPrefix + sessionId, inTime: Double(self.redisOptions.ttl)) { _, error in
                    semaphoreCallback(data: nil, error: error)
                }
            },
            apiCallback: { _, error in
                callback(error: error)
            }
        )
    }
    
    public func delete(sessionId: String, callback: (error: NSError?) -> Void) {
        runWithSemaphore (
            runClosure: { semaphoreCallback in
                self.redis.del(self.redisOptions.keyPrefix + sessionId) { _, error in
                    semaphoreCallback(data: nil, error: error)
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
