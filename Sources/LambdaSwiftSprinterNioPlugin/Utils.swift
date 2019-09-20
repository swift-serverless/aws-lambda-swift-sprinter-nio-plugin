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
import LambdaSwiftSprinter
import NIO
import NIOHTTP1

internal extension Array where Element == UInt8 {
    var data: Data {
        return Data(self)
    }
}

internal extension HTTPHeaders {
    var dictionary: [String: String] {
        var headers: [String: String] = [:]
        forEach { key, value in
            headers[key] = value
        }
        return headers
    }
}

internal extension Data {
    func decode<T: Decodable>() throws -> T {
        let jsonDecoder = JSONDecoder()
        guard let input = try? jsonDecoder.decode(T.self, from: self) else {
            throw SprinterError.invalidJSON
        }
        return input
    }

    init<T: Encodable>(from object: T) throws {
        let jsonEncoder = JSONEncoder()
        self = try jsonEncoder.encode(object)
    }
}

internal extension HTTPResponseStatus {
    func isValid() -> Bool {
        switch self {
        case .ok,
             .created,
             .accepted,
             .nonAuthoritativeInformation,
             .noContent,
             .resetContent,
             .partialContent:
            return true
        default:
            return false
        }
    }
}
