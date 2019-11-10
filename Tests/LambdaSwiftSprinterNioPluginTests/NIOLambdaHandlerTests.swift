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

class SyncNIOLambdaHandlerMock: SyncNIOLambdaHandler {
    
    
    var data = Data()
    var error: Error?

    func handler(event: Data, context: Context) -> EventLoopFuture<Data> {
        let eventloop = httpClient.eventLoopGroup.next()
        let promise = eventloop.makePromise(of: Data.self)
        if let error = error {
            promise.fail(error)
        } else {
            promise.succeed(data)
        }
        return promise.futureResult
    }
}

class AsyncNIOLambdaHandlerMock: AsyncNIOLambdaHandler {
    var data = Data()
    var error: Error?

    func handler(event: Data, context: Context, completion: @escaping (LambdaResult) -> Void) {
        if let error = error {
            completion(.failure(error))
            return
        }
        completion(.success(data))
    }
}


@testable import LambdaSwiftSprinterNioPlugin

final class NIOLambdaHandlerTests: XCTestCase {

    var validData: Data!
    var validContext: Context!
    var invalidData: Data!
    var httpClientMock: HTTPClientMock!
    
    override func setUp() {
        validData = Fixtures.validJSON.data(using: .utf8)
        XCTAssertNotNil(validData)
        
        validContext = try? Context(environment: Fixtures.fullValidEnvironment,
                                    responseHeaders: Fixtures.fullValidHeaders)
        XCTAssertNotNil(validContext)
        
        invalidData = Fixtures.invalidJSON.data(using: .utf8)
        XCTAssertNotNil(invalidData)
        try? httpClient.syncShutdown()
        
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
    
    func testDictionarySyncNIOLambdaHandler() {
        // When valid Data and valid completionHandler
        let lambda = DictionarySyncNIOLambdaHandler { (dictionary, _) -> EventLoopFuture<[String: Any]> in
            let eventloop = httpClient.eventLoopGroup.next()
            let promise = eventloop.makePromise(of: [String: Any].self)
            promise.succeed(dictionary)
            return promise.futureResult
        }
        let result = try? lambda.handler(event: validData,
            context: validContext).wait()
        XCTAssertNotNil(result)

        // When invalid Data and valid completionHandler
        XCTAssertThrowsError(try lambda.handler(event: invalidData,
            context: validContext).wait())

        // When valid Data and invalid completionHandler
        let lambda2 = DictionarySyncNIOLambdaHandler { (_, _) -> EventLoopFuture<[String: Any]> in
            throw ErrorMock.someError
        }

        XCTAssertThrowsError(try lambda2.handler(event: validData,
            context: validContext).wait())

        // When invalid Data and invalid completionHandler
        XCTAssertThrowsError(try lambda2.handler(event: invalidData,
            context: validContext).wait())
    }

    func testDictionaryAsyncNIOLambdaHandler() {
        // When valid Data and valid completionHandler
        let lambda = DictionaryAsyncNIOLambdaHandler { dictionary, _, completion in
            completion(.success(dictionary))
        }
        let expectSuccess1 = expectation(description: "expect1")
        let expectFail1 = expectation(description: "expect1")
        expectFail1.isInverted = true
        lambda.handler(event: validData, context: validContext) { result in
            switch result {
            case .failure:
                expectFail1.fulfill()
            case .success(let result):
                XCTAssertNotNil(result)
                expectSuccess1.fulfill()
            }
        }

        // When invalid Data and valid completionHandler
        let expectSuccess2 = expectation(description: "expect2")
        expectSuccess2.isInverted = true
        let expectFail2 = expectation(description: "expect2")

        lambda.handler(event: invalidData, context: validContext) { result in
            switch result {
            case .failure(let error):
                XCTAssertNotNil(error)
                expectFail2.fulfill()
            case .success:
                expectSuccess2.fulfill()
            }
        }

        // When valid Data and invalid completionHandler
        let lambda2 = DictionaryAsyncNIOLambdaHandler { _, _, completion in
            completion(.failure(ErrorMock.someError))
        }

        let expectSuccess3 = expectation(description: "expect3")
        expectSuccess3.isInverted = true
        let expectFail3 = expectation(description: "expect3")

        lambda2.handler(event: validData, context: validContext) { result in
            switch result {
            case .failure(let error):
                XCTAssertNotNil(error)
                expectFail3.fulfill()
            case .success:
                expectSuccess3.fulfill()
            }
        }

        // When invalid Data and valid completionHandler
        let expectSuccess4 = expectation(description: "expect3")
        expectSuccess4.isInverted = true
        let expectFail4 = expectation(description: "expect3")

        lambda2.handler(event: validData, context: validContext) { result in
            switch result {
            case .failure(let error):
                XCTAssertNotNil(error)
                expectFail4.fulfill()
            case .success:
                expectSuccess4.fulfill()
            }
        }
        waitForExpectations(timeout: 1, handler: nil)
    }

    func testCodableSyncNIOLambdaHandler() {
        // When valid Data and valid completionHandler
        let lambda = CodableSyncNIOLambdaHandler<EventMock, EventMock> { (event, _) -> EventLoopFuture<EventMock> in
            
            let eventloop = httpClient.eventLoopGroup.next()
            let promise = eventloop.makePromise(of: EventMock.self)
            promise.succeed(event)
            return promise.futureResult
        }

        let result = try? lambda.handler(event: validData,
            context: validContext).wait()
        XCTAssertNotNil(result)

        // When invalid Data and valid completionHandler
        XCTAssertThrowsError(try lambda.handler(event: invalidData,
            context: validContext).wait())

        // When valid Data and invalid completionHandler
        let lambda2 = CodableSyncNIOLambdaHandler<EventMock, EventMock> { (_, _) -> EventLoopFuture<EventMock> in
            let eventloop = httpClient.eventLoopGroup.next()
            let promise = eventloop.makePromise(of: EventMock.self)
            promise.fail(ErrorMock.someError)
            return promise.futureResult
        }

        XCTAssertThrowsError(try lambda2.handler(event: validData,
            context: validContext).wait())

        // When invalid Data and invalid completionHandler
        XCTAssertThrowsError(try lambda2.handler(event: invalidData,
            context: validContext).wait())
    }

    func testCodableAsyncNIOLambdaHandler() {
        // When valid Data and valid completionHandler
        let lambda = CodableAsyncNIOLambdaHandler<EventMock, EventMock> { event, _, completion in
            completion(.success(event))
        }

        let expectSuccess1 = expectation(description: "expect1")
        let expectFail1 = expectation(description: "expect1")
        expectFail1.isInverted = true
        lambda.handler(event: validData, context: validContext) { result in
            switch result {
            case .failure:
                expectFail1.fulfill()
            case .success(let result):
                XCTAssertNotNil(result)
                expectSuccess1.fulfill()
            }
        }

        // When invalid Data and valid completionHandler
        let expectSuccess2 = expectation(description: "expect2")
        expectSuccess2.isInverted = true
        let expectFail2 = expectation(description: "expect2")

        lambda.handler(event: invalidData, context: validContext) { result in
            switch result {
            case .failure(let error):
                XCTAssertNotNil(error)
                expectFail2.fulfill()
            case .success:
                expectSuccess2.fulfill()
            }
        }

        // When valid Data and invalid completionHandler
        let lambda2 = CodableAsyncNIOLambdaHandler<EventMock, EventMock> { _, _, completion in
            completion(.failure(ErrorMock.someError))
        }
        let expectSuccess3 = expectation(description: "expect3")
        expectSuccess3.isInverted = true
        let expectFail3 = expectation(description: "expect3")

        lambda2.handler(event: invalidData, context: validContext) { result in
            switch result {
            case .failure(let error):
                XCTAssertNotNil(error)
                expectFail3.fulfill()
            case .success:
                expectSuccess3.fulfill()
            }
        }

        // When invalid Data and invalid completionHandler
        let expectSuccess4 = expectation(description: "expect2")
        expectSuccess4.isInverted = true
        let expectFail4 = expectation(description: "expect2")

        lambda2.handler(event: invalidData, context: validContext) { result in
            switch result {
            case .failure(let error):
                XCTAssertNotNil(error)
                expectFail4.fulfill()
            case .success:
                expectSuccess4.fulfill()
            }
        }

        waitForExpectations(timeout: 1, handler: nil)
    }

    func testSyncNIOLambdaHandler() {
        let lambdaHandler = SyncNIOLambdaHandlerMock()

        let environment = Fixtures.fullValidEnvironment
        let responseHeaders = Fixtures.fullValidHeaders

        guard let context = try? Context(environment: environment,
                                         responseHeaders: responseHeaders) else {
            XCTFail("context cannot be nil")
            return
        }

        // when error
        lambdaHandler.error = ErrorMock.someError
        let result = lambdaHandler.commonHandler(event: Data(), context: context)
        switch result {
        case .failure(let error):
            XCTAssertNotNil(error)
        case .success:
            XCTFail("Unexpected")
        }

        // when success
        lambdaHandler.error = nil
        let result2 = lambdaHandler.commonHandler(event: Data(), context: context)
        switch result2 {
        case .failure:
            XCTFail("Unexpected")
        case .success(let value):
            XCTAssertNotNil(value)
        }
    }

    func testAsyncNIOLambdaHandler() {
        let lambdaHandler = AsyncNIOLambdaHandlerMock()
        let validData = Fixtures.validJSON.data(using: .utf8)!

        let environment = Fixtures.fullValidEnvironment
        let responseHeaders = Fixtures.fullValidHeaders

        guard let context = try? Context(environment: environment,
                                         responseHeaders: responseHeaders) else {
            XCTFail("context cannot be nil")
            return
        }

        // when error
        lambdaHandler.error = ErrorMock.someError
        let result = lambdaHandler.commonHandler(event: validData, context: context)
        switch result {
        case .failure(let error):
            XCTAssertNotNil(error)
        case .success:
            XCTFail("Unexpected")
        }

        // when success
        lambdaHandler.error = nil
        let result2 = lambdaHandler.commonHandler(event: validData, context: context)
        switch result2 {
        case .failure:
            XCTFail("Unexpected")
        case .success(let value):
            XCTAssertNotNil(value)
        }
    }

    static var allTests = [
        ("testAsyncNIOLambdaHandler", testAsyncNIOLambdaHandler),
        ("testCodableAsyncNIOLambdaHandler", testCodableAsyncNIOLambdaHandler),
        ("testCodableSyncNIOLambdaHandler", testCodableSyncNIOLambdaHandler),
        ("testDictionaryAsyncNIOLambdaHandler", testDictionaryAsyncNIOLambdaHandler),
        ("testDictionarySyncNIOLambdaHandler", testDictionarySyncNIOLambdaHandler),
        ("testSyncNIOLambdaHandler", testSyncNIOLambdaHandler),
    ]
}
