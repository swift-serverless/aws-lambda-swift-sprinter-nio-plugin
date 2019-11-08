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
import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import LambdaSwiftSprinter
import NIO
import NIOHTTP1
import NIOFoundationCompat

public typealias SprinterNIO = Sprinter<LambdaApiNIO>

public enum SprinterNIOError: Error {
    case invalidResponse(HTTPResponseStatus)
    case invalidBuffer
}

public var lambdaRuntimeTimeout: TimeAmount = .seconds(3600)
public var timeout = HTTPClient.Configuration.Timeout(connect: lambdaRuntimeTimeout,
                                                      read: lambdaRuntimeTimeout)

public var httpClient: HTTPClientProtocol = {
    let configuration = HTTPClient.Configuration(timeout: timeout)
    return HTTPClient(eventLoopGroupProvider: .createNew, configuration: configuration)
}()

public protocol HTTPClientProtocol: class {
    var eventLoopGroup: EventLoopGroup { get }
    func get(url: String, deadline: NIODeadline?) -> EventLoopFuture<HTTPClient.Response>
    func post(url: String, body: HTTPClient.Body?, deadline: NIODeadline?)  -> EventLoopFuture<HTTPClient.Response>
    func execute(request: HTTPClient.Request, deadline: NIODeadline?) -> EventLoopFuture<HTTPClient.Response>
    func syncShutdown() throws
}

extension HTTPClient: HTTPClientProtocol {
    
}

///  The `LambdaApiNIO` class implements the LambdaAPI protocol using NIO.
///    
public class LambdaApiNIO: LambdaAPI {
    
    let urlBuilder: LambdaRuntimeAPIUrlBuilder
    
    private let _nextInvocationRequest: HTTPClient.Request

    /// Construct a `LambdaApiNIO` class.
    ///
    /// - parameters
    ///     - awsLambdaRuntimeAPI: AWS_LAMBDA_RUNTIME_API
    public required init(awsLambdaRuntimeAPI: String) throws {
        self.urlBuilder = try LambdaRuntimeAPIUrlBuilder(awsLambdaRuntimeAPI: awsLambdaRuntimeAPI)
        self._nextInvocationRequest = try HTTPClient.Request(url: urlBuilder.nextInvocationURL(), method: .GET)
    }

    /// Call the next invocation API to get the next event. The response body contains the event data. Response headers contain the `RequestID` and other information.
    ///
    /// - returns:
    ///     - `(event: Data, responseHeaders: [AnyHashable: Any])` the event to process and the responseHeaders
    /// - throws:
    ///     - `invalidBuffer` if the body is empty or the buffer doesn't contain data.
    ///     - `invalidResponse(HTTPResponseStatus)` if the HTTP response is not valid.
    public func getNextInvocation() throws -> (event: Data, responseHeaders: [AnyHashable: Any]) {
        let result = try httpClient.execute(
            request: _nextInvocationRequest,
            deadline: nil
        ).wait()

        let httpHeaders = result.headers

        guard result.status.isValid() else {
            throw SprinterNIOError.invalidResponse(result.status)
        }

        if let body = result.body,
            let data = body.getData(at: 0,
                                    length: body.readableBytes,
                                    byteTransferStrategy: .noCopy) {
            return (event: data, responseHeaders: httpHeaders.dictionary)
        } else {
            throw SprinterNIOError.invalidBuffer
        }
    }

    /// Sends an invocation response to Lambda.
    ///
    /// - parameters:
    ///     - requestId: Request ID
    ///     - httpBody: data body.
    /// - throws:
    ///     - HttpClient errors
    public func postInvocationResponse(for requestId: String, httpBody: Data) throws {
        var request = try HTTPClient.Request(
            url: urlBuilder.invocationResponseURL(requestId: requestId),
            method: .POST
        )
        request.body = .data(httpBody)
        _ = try httpClient.execute(
            request: request,
            deadline: nil
        ).wait()
    }

    /// Sends an invocation error to Lambda.
    ///
    /// - parameters:
    ///     - requestId: Request ID
    ///     - error: error
    /// - throws:
    ///     - HttpClient errors
    public func postInvocationError(for requestId: String, error: Error) throws {
        let errorMessage = String(describing: error)
        let invocationError = InvocationError(errorMessage: errorMessage,
                                              errorType: "PostInvocationError")
        var request = try HTTPClient.Request(url: urlBuilder.invocationErrorURL(requestId: requestId),
                                             method: .POST)

        let httpBody = try Data(from: invocationError)
        request.body = .data(httpBody)

        _ = try httpClient.execute(
            request: request,
            deadline: nil
        ).wait()
    }

    /// Sends an initialization error to Lambda.
    ///
    /// - parameters:
    ///     - error: error
    /// - throws:
    ///     - HttpClient errors
    public func postInitializationError(error: Error) throws {
        let errorMessage = String(describing: error)
        let invocationError = InvocationError(errorMessage: errorMessage,
                                              errorType: "InvalidFunctionException")
        var request = try HTTPClient.Request(url: urlBuilder.initializationErrorRequest(),
                                             method: .POST)

        let httpBody = try Data(from: invocationError)
        request.body = .data(httpBody)

        _ = try httpClient.execute(
            request: request,
            deadline: nil
        ).wait()
    }
}
