# aws-lambda-swift-sprinter-nio-plugin


[![Swift 5](https://img.shields.io/badge/Swift-5.0-blue.svg)](https://swift.org/download/) ![](https://img.shields.io/badge/version-1.0.0.alpha.1-red)

The project implements an HTTPS client plugin for the [LambdaSwiftSprinter](https://github.com/swift-sprinter/aws-lambda-swift-sprinter-core) framework.

The plugin is based on swift-nio 2.0 and uses the third part library [async-http-client](https://github.com/swift-server/async-http-client.git)


- Allow the handler to make an HTTPS call.  Swift's implementation relies on ``libgnutls`` which expects to find its root certificates in ``/etc/ssl/certs/ca-certificates.crt`` directory.  That directory is absent on Amazon Linux.  **Currently calls to HTTPS endpoint will fail with an error** : ``error setting certificate verify locations:\n CAfile: /etc/ssl/certs/ca-certificates.crt\n CApath: /etc/ssl/certs``
This library fix this issue by using `swift-nio 2`.

# Usage

To know more have a look to this [example](https://github.com/swift-sprinter/aws-lambda-swift-sprinter/Examples/HTTPSRequest)


# Contributions

Contributions are more than welcome! Follow [this guide](/https://github.com/swift-sprinter/aws-lambda-swift-sprinter-nio-plugin/blob/master/CONTRIBUTING.md) to contribute.


