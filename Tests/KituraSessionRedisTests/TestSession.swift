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

import Kitura
import KituraNet
import KituraSession

import Foundation
import XCTest
import SwiftyJSON

@testable import KituraSessionRedis

let sessionTestKey = "sessionKey"
let sessionTestValue = "sessionValue"
let cookie1Name = "cookie1Name"
let cookieDefaultName = "kitura-session-id"

class TestSession : XCTestCase, KituraTest {
    
    static var allTests : [(String, (TestSession) -> () throws -> Void)] {
        return [
                   ("testSimpleSession", testSimpleSession),
                   ("testCookieName", testCookieName),
        ]
    }
    
    #if os(Linux)
    typealias PropValue = Any
    #else
    typealias PropValue = AnyObject
    #endif
    
    func testSimpleSession() {
        setupRouter() { router, error in
            XCTAssertNil(error, error!)
            guard (error == nil && router != nil) else {
                return
            }
            self.performServerTest(router: router!, asyncTasks: {
                self.performRequest(method: "post", path: "/3/session", callback: {response in
                    XCTAssertNotNil(response, "ERROR!!! ClientRequest response object was nil")
                    guard (response != nil) else {
                        return
                    }
                    let (cookie3, _) = CookieUtils.cookieFrom(response: response!, named: cookieDefaultName)
                    XCTAssertNotNil(cookie3, "Cookie \(cookieDefaultName) wasn't found in the response.")
                    guard (cookie3 != nil) else {
                        return
                    }
                    let cookie3value = cookie3!.value
                    self.performRequest(method: "get", path: "/3/session", callback: { response in
                        XCTAssertNotNil(response, "ERROR!!! ClientRequest response object was nil")
                        guard (response != nil) else {
                            return
                        }
                        XCTAssertEqual(response!.statusCode, HTTPStatusCode.OK, "HTTP Status code was \(response!.statusCode)")
                        do {
                            let body = try response!.readString()
                            XCTAssertNotNil(body, "No response body")
                            guard (body != nil) else {
                                return
                            }
                            XCTAssertEqual(body!, sessionTestValue, "Body \(body) is not equal to \(sessionTestValue)")
                        }
                        catch{
                            XCTFail("No response body")
                        }
                        
                        },  headers: ["Cookie": "\(cookieDefaultName)=\(cookie3value); Zxcv=tyuiop"])
                })
            })
        }
    }
    
    func testCookieName() {
        setupRouter() { router, error in
            XCTAssertNil(error, error!)
            guard (error == nil && router != nil) else {
                return
            }
            self.performServerTest(router: router!, asyncTasks: {
                self.performRequest(method: "post", path: "/3/session", callback: {response in
                    XCTAssertNotNil(response, "ERROR!!! ClientRequest response object was nil")
                    guard (response != nil) else {
                        return
                    }
                    let (cookie3, _) = CookieUtils.cookieFrom(response: response!, named: cookieDefaultName)
                    XCTAssertNotNil(cookie3, "Cookie \(cookieDefaultName) wasn't found in the response.")
                    guard (cookie3 != nil) else {
                        return
                    }
                    let cookie3value = cookie3!.value
                    self.performRequest(method: "get", path: "/3/session", callback: { response in
                        XCTAssertNotNil(response, "ERROR!!! ClientRequest response object was nil")
                        guard (response != nil) else {
                            return
                        }
                        XCTAssertEqual(response!.statusCode, HTTPStatusCode.noContent, "Session route did not match single path request")
                        },  headers: ["Cookie": "\(cookie1Name)=\(cookie3value); Zxcv=tyuiop"])
                })
            })
        }
    }
    
    func setupRouter(callback: (Router?, String?) -> Void) {
        let router = Router()
        
        let password = read(fileName: "password.txt")
        let host = read(fileName: "host.txt")
        
        let redisStore = RedisStore(redisHost: host, redisPort: 6379, redisPassword: password)
        
        router.all(middleware: Session(secret: "Very very secret.....", store: redisStore))
        
        router.post("/3/session") {request, response, next in
            request.session?[sessionTestKey] = JSON(sessionTestValue as PropValue)
            response.status(.noContent)
            next()
        }
        
        router.get("/3/session") {request, response, next in
            response.headers.append("Content-Type", value: "text/plain; charset=utf-8")
            do {
                if let value = request.session?[sessionTestKey].string {
                    try response.status(.OK).send("\(value)").end()
                }
                else {
                    response.status(.noContent)
                }
            }
            catch {}
            next()
            
        }
        
        callback(router, nil)
    }
    
    func read(fileName: String) -> String {
        // Read in a configuration file into an NSData
        let fileData: Data
        
        let sourceFileName = NSString(string: #file)
        let pathToTestsPrefixRange: NSRange
        let lastSlash = sourceFileName.range(of: "/", options: .backwards)
        if  lastSlash.location != NSNotFound {
            pathToTestsPrefixRange = NSMakeRange(0, lastSlash.location+1)
        } else {
            pathToTestsPrefixRange = NSMakeRange(0, sourceFileName.length)
        }
        let pathToTests = sourceFileName.substring(with: pathToTestsPrefixRange)
        
        do {
            fileData = try Data(contentsOf: URL(fileURLWithPath: "\(pathToTests)\(fileName)"))
        }
        catch {
            XCTFail("Failed to read in the \(fileName) file [\(pathToTests)\(fileName)]")
            exit(1)
        }
        
        let resultString = String(data: fileData, encoding: .utf8)

        guard
            let resultLiteral = resultString
            else {
                XCTFail("Error in \(fileName).")
                exit(1)
        }
        return resultLiteral.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    
}
