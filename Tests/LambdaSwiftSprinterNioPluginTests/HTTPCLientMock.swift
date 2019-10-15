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
import NIO
import NIOHTTP1
import NIOConcurrencyHelpers
import XCTest

@testable import LambdaSwiftSprinterNioPlugin

enum HTTPClientMockError: Error {
    case unknown
}

class HTTPClientMock: HTTPClientProtocol {
    
    public let eventLoopGroup: EventLoopGroup
    let eventLoopGroupProvider: HTTPClient.EventLoopGroupProvider
    let isShutdown = Atomic<Bool>(value: false)
    
    var response: HTTPClient.Response?
    var error: Error?
    
    public init(eventLoopGroupProvider: HTTPClient.EventLoopGroupProvider) {
        self.eventLoopGroupProvider = eventLoopGroupProvider
        switch self.eventLoopGroupProvider {
        case .shared(let group):
            self.eventLoopGroup = group
        case .createNew:
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        }
    }
    
    public func syncShutdown() throws {
        switch self.eventLoopGroupProvider {
        case .shared:
            self.isShutdown.store(true)
            return
        case .createNew:
            if self.isShutdown.compareAndExchange(expected: false, desired: true) {
                try self.eventLoopGroup.syncShutdownGracefully()
            } else {
                throw HTTPClientError.alreadyShutdown
            }
        }
    }
    
    fileprivate func makeFuture() -> EventLoopFuture<HTTPClient.Response> {
        let eventLoop = self.eventLoopGroup.next()
        
        guard let response = response else {
            return eventLoop.makeFailedFuture(HTTPClientMockError.unknown)
        }
        
        if let error = error {
            return eventLoop.makeFailedFuture(error)
        }
        
        let promise = eventLoop.makePromise(of: HTTPClient.Response.self)
        promise.succeed(response)
        return promise.futureResult
    }
    
    func get(url: String, deadline: NIODeadline?) -> EventLoopFuture<HTTPClient.Response> {
        return makeFuture()
    }
    
    func post(url: String, body: HTTPClient.Body?, deadline: NIODeadline?) -> EventLoopFuture<HTTPClient.Response> {
        return makeFuture()
    }
    
    func execute(request: HTTPClient.Request, deadline: NIODeadline?) -> EventLoopFuture<HTTPClient.Response> {
       return makeFuture()
    }
}
