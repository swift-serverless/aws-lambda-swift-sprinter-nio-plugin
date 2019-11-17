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

final class LambdaApiNIOTests: XCTestCase {
    
    enum ErrorMock: Error {
        case someError
    }
    
    let awsLambdaRuntimeAPI = "localhost:80"
    var api: LambdaApiNIO!
    var httpClientMock: HTTPClientMock!
    var urlBuilder: LambdaRuntimeAPIUrlBuilder!
    let validData = "{\"dictionary\":{\"name\":\"N\",\"value\":10},\"float\":0.9,\"string\":\"Name\",\"int\":1}".data(using: .utf8)!
    var validResponse: HTTPClient.Response!
    var invalidResponseBody: HTTPClient.Response!
    var invalidResponseStatus: HTTPClient.Response!
    let requestID = "009248902898383-298783789-933098"
    var networkError = NSError(
        domain: "NSURLErrorDomain",
        code: -1004, // kCFURLErrorCannotConnectToHost
        userInfo: nil
    )
    
    
    override func setUp() {
        
        urlBuilder = try? LambdaRuntimeAPIUrlBuilder(awsLambdaRuntimeAPI: awsLambdaRuntimeAPI)
        XCTAssertNotNil(urlBuilder)
        
        validResponse = HTTPClient.Response(host: urlBuilder.nextInvocationURL().host!,
                                            status: HTTPResponseStatus(statusCode: 200),
                                            headers: HTTPHeaders([("Accepts", "application/json")]),
                                            body: validData.byteBuffer)
        invalidResponseBody = HTTPClient.Response(host: urlBuilder.nextInvocationURL().host!,
                                                  status: HTTPResponseStatus(statusCode: 200),
                                                  headers: HTTPHeaders([("Accepts", "application/json")]),
                                                  body: nil)
        invalidResponseStatus = HTTPClient.Response(host: urlBuilder.nextInvocationURL().host!,
                                                    status: HTTPResponseStatus(statusCode: 400),
                                                    headers: HTTPHeaders([("Accepts", "application/json")]),
                                                    body: nil)
        
        try? httpClient.syncShutdown()
        
        httpClientMock = HTTPClientMock(eventLoopGroupProvider: .createNew)
        httpClient = httpClientMock
        api = try? LambdaApiNIO(awsLambdaRuntimeAPI: awsLambdaRuntimeAPI)
    }
    
    override func tearDown() {
        try? httpClientMock?.syncShutdown()
        api = nil
        httpClientMock = nil
        
        try? httpClient.syncShutdown()
        let configuration = HTTPClient.Configuration(timeout: timeout)
        httpClient = HTTPClient(eventLoopGroupProvider: .createNew, configuration: configuration)
    }
    
    func testInit() {
        
        XCTAssertNotNil(api)
        XCTAssertNotNil(api?.urlBuilder)
        
        // when invalid awsLambdaRuntimeAPI
        XCTAssertThrowsError(try LambdaApiNIO(awsLambdaRuntimeAPI: "##"))
    }
    
    public func testGetNextInvocation() {
        
        //When valid response
        httpClientMock.response = validResponse
        let value:(event: Data,responseHeaders: [AnyHashable: Any])? = try? api.getNextInvocation()
        XCTAssertNotNil(value?.event)
        XCTAssertNotNil(value?.responseHeaders)
        
        //When invalid status
        httpClientMock.response = invalidResponseStatus
        let value1:(event: Data,responseHeaders: [AnyHashable: Any])? = try? api.getNextInvocation()
        XCTAssertNil(value1?.event)
        XCTAssertNil(value1?.responseHeaders)
        XCTAssertThrowsError(try api.getNextInvocation())
        
        //When null body
        httpClientMock.response = invalidResponseBody
        let value2:(event: Data,responseHeaders: [AnyHashable: Any])? = try? api.getNextInvocation()
        XCTAssertNil(value2?.event)
        XCTAssertNil(value2?.responseHeaders)
        XCTAssertThrowsError(try api.getNextInvocation())
        
        //When network error
        httpClientMock.response = validResponse
        httpClientMock.error = networkError
        let value3:(event: Data,responseHeaders: [AnyHashable: Any])? = try? api.getNextInvocation()
        XCTAssertNil(value3?.event)
        XCTAssertNil(value3?.responseHeaders)
        XCTAssertThrowsError(try api.getNextInvocation())
        
    }
    
    public func testPostInvocationResponse() {
        
        //When valid response
        httpClientMock.response = validResponse
        XCTAssertNoThrow(try api.postInvocationResponse(for: requestID, httpBody: validData))
        
        //When network error
        httpClientMock.response = validResponse
        httpClientMock.error = networkError
        XCTAssertThrowsError(try api.postInvocationResponse(for: requestID, httpBody: validData))
    }
    
    public func testPostInvocationError() {
        
        //When valid response
        httpClientMock.response = validResponse
        XCTAssertNoThrow(try api.postInvocationError(for: requestID, error: ErrorMock.someError))
        
        //When network error
        httpClientMock.response = validResponse
        httpClientMock.error = networkError
        XCTAssertThrowsError(try api.postInvocationError(for: requestID, error: ErrorMock.someError))
    }
    
    public func testPostInitializationError() {
        //When valid response
        httpClientMock.response = validResponse
        XCTAssertNoThrow(try api.postInitializationError(error: ErrorMock.someError))
        
        //When network error
        httpClientMock.response = validResponse
        httpClientMock.error = networkError
        XCTAssertThrowsError(try api.postInitializationError(error: ErrorMock.someError))
    }
    
    static var allTests = [
           ("testGetNextInvocation", testGetNextInvocation),
        ("testInit", testInit),
        ("testPostInitializationError", testPostInitializationError),
        ("testPostInvocationError", testPostInvocationError),
        ("testPostInvocationResponse", testPostInvocationResponse),
    ]
}
