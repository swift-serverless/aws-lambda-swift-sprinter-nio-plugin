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

/**
 `SyncCodableNIOLambda<Event: Decodable, Response: Encodable>` lambda handler typealias.
 
 ### Usage Example: ###

 ```
 import AsyncHTTPClient
 import Foundation
 #if canImport(FoundationNetworking)
     import FoundationNetworking
 #endif
 import LambdaSwiftSprinter
 import LambdaSwiftSprinterNioPlugin
 import Logging
 import NIO
 import NIOFoundationCompat
 
 struct Event: Codable {
     let url: String
 }

 struct Response: Codable {
     let url: String
     let content: String
 }
 
 let syncCodableNIOLambda: SyncCodableNIOLambda<Event, Response> = { (event, context) throws -> EventLoopFuture<Response> in
     
     let request = try HTTPClient.Request(url: event.url)
     let future = httpClient.execute(request: request, deadline: nil)
         .flatMapThrowing { (response) throws -> String in
                 guard let body = response.body,
                     let value = body.getString(at: 0, length: body.readableBytes) else {
                         throw SprinterError.invalidJSON
             }
             return value
         }.map { content -> Response in
             return Response(url: event.url, content: content)
         }
     return future
 }
 do {
     let sprinter = try SprinterNIO()
     sprinter.register(handler: "getHttps", lambda: syncCodableNIOLambda)
     
     try sprinter.run()
 } catch {
     //log the error
 }
 ```
*/
public typealias SyncCodableNIOLambda<Event: Decodable, Response: Encodable> = (Event, Context) throws -> EventLoopFuture<Response>

/**
 `SyncDictionaryNIOLambda` lambda handler typealias.

 ### Usage Example: ###
 
 ```
 import AsyncHTTPClient
 import Foundation
 #if canImport(FoundationNetworking)
     import FoundationNetworking
 #endif
 import LambdaSwiftSprinter
 import LambdaSwiftSprinterNioPlugin
 import Logging
 import NIO
 import NIOFoundationCompat
 
 enum MyError: Error {
     case invalidParameters
 }
 
 let syncDictionaryNIOLambda: SyncDictionaryNIOLambda = { (event, context) throws -> EventLoopFuture<[String: Any]> in

     guard let url = event["url"] as? String else {
         throw MyError.invalidParameters
     }

     let request = try HTTPClient.Request(url: url)
     let future = httpClient.execute(request: request, deadline: nil)
         .flatMapThrowing { (response) throws -> String in
             guard let body = response.body,
                 let value = body.getString(at: 0, length: body.readableBytes) else {
                     throw SprinterError.invalidJSON
             }
             return value
         }.map { content -> [String: Any] in
             return ["url": url,
                     "content": content]
         }
     return future
 }
 do {
     let sprinter = try SprinterNIO()
     sprinter.register(handler: "getHttps", lambda: syncDictionaryNIOLambda)
     
     try sprinter.run()
 } catch {
     //log the error
 }
 ```
*/
public typealias SyncDictionaryNIOLambda = ([String: Any], Context) throws -> EventLoopFuture<[String: Any]>


/**
 `AsyncCodableNIOLambda<Event: Decodable, Response: Encodable>` lambda handler typealias.
 
 - Parameter

 - Usage example:
 
 ```
 import AsyncHTTPClient
 import Foundation
 #if canImport(FoundationNetworking)
     import FoundationNetworking
 #endif
 import LambdaSwiftSprinter
 import LambdaSwiftSprinterNioPlugin
 import Logging
 import NIO
 import NIOFoundationCompat
 
 struct Event: Codable {
     let url: String
 }

 struct Response: Codable {
     let url: String
     let content: String
 }
 
 let asyncCodableNIOLambda: AsyncCodableNIOLambda<Event, Response> = { (event, context, completion) -> Void in
     do {
         let request = try HTTPClient.Request(url: event.url)
         let reponse: Response = try httpClient.execute(request: request, deadline: nil)
             .flatMapThrowing { (response) throws -> String in
                 guard let body = response.body,
                     let value = body.getString(at: 0, length: body.readableBytes) else {
                         throw SprinterError.invalidJSON
                 }
                 return value
         }.map { content -> Response in
             return Response(url: event.url, content: content)
         }
         .wait()
         completion(.success(reponse))
     } catch {
         completion(.failure(error))
     }
 }
 do {
     let sprinter = try SprinterNIO()
     sprinter.register(handler: "getHttps", lambda: asyncCodableNIOLambda)
     
     try sprinter.run()
 } catch {
     //log the error
 }
 ```
*/
public typealias AsyncCodableNIOLambda<Event: Decodable, Response: Encodable> = (Event, Context, @escaping (Result<Response, Error>) -> Void) -> Void


/**
 `AsyncDictionaryNIOLambda` lambda handler typealias.

 ### Usage Example: ###
 ```
 import AsyncHTTPClient
 import Foundation
 #if canImport(FoundationNetworking)
     import FoundationNetworking
 #endif
 import LambdaSwiftSprinter
 import LambdaSwiftSprinterNioPlugin
 import Logging
 import NIO
 import NIOFoundationCompat
 
 enum MyError: Error {
     case invalidParameters
 }
 
 let asynchDictionayNIOLambda: AsyncDictionaryNIOLambda = { (event, context, completion) -> Void in
     guard let url = event["url"] as? String else {
         completion(.failure(MyError.invalidParameters))
         return
     }
     do {
         let request = try HTTPClient.Request(url: url)
         let dictionary: [String: Any] = try httpClient.execute(request: request, deadline: nil)
             .flatMapThrowing { (response) throws -> String in
                 guard let body = response.body,
                     let value = body.getString(at: 0, length: body.readableBytes) else {
                         throw SprinterError.invalidJSON
                 }
                 return value
         }.map { content -> [String: Any] in
             return ["url": url,
                     "content": content]
         }
         .wait()
         completion(.success(dictionary))
     } catch {
         completion(.failure(error))
     }
 }
 do {
     let sprinter = try SprinterNIO()
     sprinter.register(handler: "getHttps", lambda: asynchDictionayNIOLambda)
     
     try sprinter.run()
 } catch {
     //log the error
 }
 ```
*/
public typealias AsyncDictionaryNIOLambda = ([String: Any], Context, @escaping (DictionaryResult) -> Void) -> Void

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
    
    let handlerFunction: (Event, Context) throws -> EventLoopFuture<Response>

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
    
    let completionHandler: ([String: Any], Context) throws -> EventLoopFuture<[String: Any]>
    func handler(event: Data, context: Context) -> EventLoopFuture<Data> {
                
        let eventLoop = httpClient.eventLoopGroup.next()
        let promise = eventLoop.makePromise(of: Data.self)
        do {
            let data = try event.jsonObject()
            let output = try completionHandler(data, context)
            .flatMapThrowing{ (dictionary) -> Data in
                return try Data(jsonObject: dictionary)
            }
            .wait()
            promise.succeed(output)
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
