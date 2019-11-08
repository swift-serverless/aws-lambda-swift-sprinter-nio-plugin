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

import Foundation
import NIO
import NIOHTTP1
import NIOFoundationCompat
import LambdaSwiftSprinter

public typealias AsyncDictionaryNIOLambda = ([String: Any], Context, @escaping (DictionaryResult) -> Void) -> Void
public typealias AsyncCodableNIOLambda<Event: Decodable, Response: Encodable> = (Event, Context, @escaping (Result<Response, Error>) -> Void) -> Void

public typealias SyncDictionaryNIOLambda = ([String: Any], Context) throws -> [String: Any]
public typealias SyncCodableNIOLambda<Event: Decodable, Response: Encodable> = (Event, Context) -> EventLoopFuture<Response>

public protocol SyncNIOLambdaHandler: LambdaHandler {
    
    func handler(event: Data, context: Context) -> EventLoopFuture<Data>
}

public extension SyncNIOLambdaHandler {
    
    func commonHandler(event: Data, context: Context) -> LambdaResult {
        do {
            let data = try handler(event: event, context: context).wait()
            return .success(data)
        } catch {
            return .failure(error)
        }
    }
}

public protocol AsyncNIOLambdaHandler: LambdaHandler {
    
    func handler(event: Data, context: Context, completion: @escaping (LambdaResult) -> Void)
}

public extension AsyncNIOLambdaHandler {
    func commonHandler(event: Data, context: Context) -> LambdaResult {
        let eventLoop = httpClient.eventLoopGroup.next()
        let promise = eventLoop.makePromise(of: LambdaResult.self)
        handler(event: event, context: context) { result in
            
            switch result {
                case .success(_):
                    promise.succeed(result)
                case .failure(let error):
                    promise.fail(error)
            }
        }
        do {
            let result = try promise.futureResult.wait()
            return result
        } catch {
            return .failure(error)
        }
    }
}

struct CodableSyncNIOLambdaHandler<Event: Decodable, Response: Encodable>: SyncNIOLambdaHandler {
    
    let handlerFunction: (Event, Context) -> EventLoopFuture<Response>

    func handler(event: Data, context: Context) -> EventLoopFuture<Data> {
        
        let eventLoop = httpClient.eventLoopGroup.next()
        let promise = eventLoop.makePromise(of: Data.self)
        do {
            let eventObj = try event.decode() as Event
            let responseObj = try handlerFunction(eventObj, context).wait()
            let response = try Data(from: responseObj)
            promise.succeed(response)
        } catch {
            promise.fail(error)
        }
        return promise.futureResult
    }
}

struct CodableAsyncNIOLambdaHandler<Event: Decodable, Response: Encodable>: AsyncNIOLambdaHandler {
    let handlerFunction: AsyncCodableLambda<Event, Response>

    func handler(event: Data, context: Context, completion: @escaping (LambdaResult) -> Void) {
        do {
            let data = try event.decode() as Event
            handlerFunction(data, context) { outputResult in
                switch outputResult {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let outputDict):
                    do {
                        let outputData = try Data(from: outputDict)
                        completion(.success(outputData))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
}

struct DictionarySyncNIOLambdaHandler: SyncNIOLambdaHandler {
    
    let completionHandler: ([String: Any], Context) throws -> [String: Any]
    func handler(event: Data, context: Context) -> EventLoopFuture<Data> {
        
        let eventLoop = httpClient.eventLoopGroup.next()
        let promise = eventLoop.makePromise(of: Data.self)
        do {
            let data = try event.jsonObject()
            let output = try completionHandler(data, context)
            let responseObj = try Data(jsonObject: output)
            promise.succeed(responseObj)
        } catch {
            promise.fail(error)
        }
        return promise.futureResult
    }
}

struct DictionaryAsyncNIOLambdaHandler: AsyncNIOLambdaHandler {
    let completionHandler: AsyncDictionaryLambda

    func handler(event: Data, context: Context, completion: @escaping (LambdaResult) -> Void) {
        do {
            let jsonDictionary = try event.jsonObject()
            completionHandler(jsonDictionary, context) { outputResult in
                switch outputResult {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let outputDict):
                    do {
                        let outputData = try Data(jsonObject: outputDict)
                        completion(.success(outputData))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
}

public extension Sprinter where API == LambdaApiNIO {
    func register(handler name: String, lambda: @escaping SyncDictionaryNIOLambda) {
        let handler = DictionarySyncNIOLambdaHandler(completionHandler: lambda)
        register(handler: name, lambda: handler)
    }
    
    func register(handler name: String, lambda: @escaping AsyncDictionaryNIOLambda) {
        let handler = DictionaryAsyncNIOLambdaHandler(completionHandler: lambda)
        register(handler: name, lambda: handler)
    }
    
    func register<Event: Decodable, Response: Encodable>(handler name: String,
                                                         lambda: @escaping SyncCodableNIOLambda<Event, Response>) {
        let handler = CodableSyncNIOLambdaHandler(handlerFunction: lambda)
        register(handler: name, lambda: handler)
    }
    
    func register<Event: Decodable, Response: Encodable>(handler name: String,
                                                         lambda: @escaping AsyncCodableNIOLambda<Event, Response>) {
        let handler = CodableAsyncNIOLambdaHandler(handlerFunction: lambda)
        register(handler: name, lambda: handler)
    }
}
