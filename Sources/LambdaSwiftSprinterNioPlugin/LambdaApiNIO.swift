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
import LambdaSwiftSprinter
import NIO
import NIOHTTP1

public typealias SprinterNIO = Sprinter<LambdaApiNIO>

public enum SprinterNIOError: Error {
    case invalidResponse(HTTPResponseStatus)
    case invalidBuffer
}

public var lambdaRuntimeTimeout: TimeAmount = .seconds(3600)
public var timeout = HTTPClient.Configuration.Timeout(connect: lambdaRuntimeTimeout,
                                                      read: lambdaRuntimeTimeout)

public var httpClient: HTTPClient = {
    let configuration = HTTPClient.Configuration(timeout: timeout)
    return HTTPClient(eventLoopGroupProvider: .createNew, configuration: configuration)
}()

public class LambdaApiNIO: LambdaAPI {
    let urlBuilder: LambdaRuntimeAPIUrlBuilder

    public required init(awsLambdaRuntimeAPI: String) throws {
        self.urlBuilder = try LambdaRuntimeAPIUrlBuilder(awsLambdaRuntimeAPI: awsLambdaRuntimeAPI)
    }

    public func getNextInvocation() throws -> (event: Data, responseHeaders: [AnyHashable: Any]) {
        let request = try HTTPClient.Request(url: urlBuilder.nextInvocationURL(), method: .GET)
        let result = try httpClient.execute(
            request: request
        ).wait()

        let httpHeaders = result.headers

        guard result.status.isValid() else {
            throw SprinterNIOError.invalidResponse(result.status)
        }

        if let body = result.body,
            let buffer = body.getBytes(at: 0, length: body.readableBytes) {
            let data = buffer.data
            return (event: data, responseHeaders: httpHeaders.dictionary)
        } else {
            throw SprinterNIOError.invalidBuffer
        }
    }

    public func postInvocationResponse(for requestId: String, httpBody: Data) throws {
        var request = try HTTPClient.Request(
            url: urlBuilder.invocationResponseURL(requestId: requestId),
            method: .POST
        )
        request.body = .data(httpBody)
        _ = try httpClient.execute(
            request: request
        ).wait()
    }

    public func postInvocationError(for requestId: String, error: Error) throws {
        let errorMessage = String(describing: error)
        let invocationError = InvocationError(errorMessage: errorMessage,
                                              errorType: "PostInvocationError")
        var request = try HTTPClient.Request(url: urlBuilder.invocationErrorURL(requestId: requestId),
                                             method: .POST)

        let httpBody = try Data(from: invocationError)
        request.body = .data(httpBody)

        _ = try httpClient.execute(
            request: request
        ).wait()
    }

    public func postInitializationError(error: Error) throws {
        let errorMessage = String(describing: error)
        let invocationError = InvocationError(errorMessage: errorMessage,
                                              errorType: "InvalidFunctionException")
        var request = try HTTPClient.Request(url: urlBuilder.initializationErrorRequest(),
                                             method: .POST)

        let httpBody = try Data(from: invocationError)
        request.body = .data(httpBody)

        _ = try httpClient.execute(
            request: request
        ).wait()
    }
}
