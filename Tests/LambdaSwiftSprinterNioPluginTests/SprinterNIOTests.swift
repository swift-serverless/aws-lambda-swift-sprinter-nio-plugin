//    Copyright 2019 (c) Andrea Scuderi - https://github.com/swift-sprinter
//
//    Licensed under the Apache License, Version 2.0 (the "License");
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//
//        http://www.apache.org/licenses/LICENSE-2.0
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.

import AsyncHTTPClient
import LambdaSwiftSprinter
import NIO
import NIOHTTP1
import NIOConcurrencyHelpers
import XCTest


@testable import LambdaSwiftSprinterNioPlugin
@testable import LambdaSwiftSprinter

struct Event: Codable {
    let name: String
}

struct Response: Codable {
    let value: String
}

final class SprinterNIOTests: XCTestCase {
    
     var httpClientMock: HTTPClientMock!
    
    override func setUp() {
        
        httpClientMock = HTTPClientMock(eventLoopGroupProvider: .createNew)
        try? httpClient.syncShutdown()
        httpClient = httpClientMock
    }
    
    override func tearDown() {
        
        try? httpClientMock?.syncShutdown()
        httpClientMock = nil
        
        try? httpClient.syncShutdown()
        let configuration = HTTPClient.Configuration(timeout: timeout)
        httpClient = HTTPClient(eventLoopGroupProvider: .createNew, configuration: configuration)
    }
    
    func testRegisterSyncNIOWithCompletion() {
        let environment = ["AWS_LAMBDA_RUNTIME_API": "runtime",
                           "_HANDLER": "Lambda.handler"]
        let sprinter = try? Sprinter<LambdaApiNIO>(environment: environment)
        
        let completion: SyncDictionaryNIOLambda = { (_, _) -> [String: Any] in
            ["": ""]
        }
        sprinter?.register(handler: "handler", lambda: completion)
        
        guard let lambda = sprinter?.lambdas["handler"] else {
            XCTFail("Unexpected")
            return
        }
        XCTAssertNotNil(lambda)
    }
    
    func testRegisterAsyncNIOWithCompletion() {
        let environment = ["AWS_LAMBDA_RUNTIME_API": "runtime",
                           "_HANDLER": "Lambda.handler"]
        let sprinter = try? Sprinter<LambdaApiNIO>(environment: environment)
        
        let lambdaFunction: AsyncDictionaryLambda = { _, _, completion in
            completion(.success(["": ""]))
        }
        sprinter?.register(handler: "handler", lambda: lambdaFunction)
        
        guard let lambda = sprinter?.lambdas["handler"] else {
            XCTFail("Unexpected")
            return
        }
        XCTAssertNotNil(lambda)
    }
    
    func testRegisterSyncNIOTyped() {
        let environment = ["AWS_LAMBDA_RUNTIME_API": "runtime",
                           "_HANDLER": "Lambda.handler"]
        
        let sprinter = try? Sprinter<LambdaApiNIO>(environment: environment)
       
        
        let handlerFunction: SyncCodableNIOLambda<Event, Response> = { (Event, Context) -> EventLoopFuture<Response> in
       
            let eventloop = httpClient.eventLoopGroup.next()
            let promise = eventloop.makePromise(of: Response.self)
            let response = Response(value: "test")
            promise.succeed(response)
            return promise.futureResult
        }
        
        sprinter?.register(handler: "handler", lambda: handlerFunction)
        
        guard let lambda = sprinter?.lambdas["handler"] else {
            XCTFail("Unexpected")
            return
        }
        XCTAssertNotNil(lambda)
    }
    
    func testRegisterAsyncNIOTyped() {
        let environment = Fixtures.validEnvironment
        let sprinter = try? Sprinter<LambdaApiNIO>(environment: environment)
        
        let handlerFunction: AsyncCodableNIOLambda<Event, Response> = { (_, _, completion) -> Void in
            completion(.success(Response(value: "test")))
        }
        
        sprinter?.register(handler: "handler", lambda: handlerFunction)
        
        guard let lambda = sprinter?.lambdas["handler"] else {
            XCTFail("Unexpected")
            return
        }
        
        XCTAssertNotNil(lambda)
    }
    
    static var allTests = [
        ("testRegisterAsyncNIOTyped", testRegisterAsyncNIOTyped),
        ("testRegisterAsyncNIOWithCompletion", testRegisterAsyncNIOWithCompletion),
        ("testRegisterSyncNIOTyped", testRegisterSyncNIOTyped),
        ("testRegisterSyncNIOWithCompletion", testRegisterSyncNIOWithCompletion),
    ]
}
