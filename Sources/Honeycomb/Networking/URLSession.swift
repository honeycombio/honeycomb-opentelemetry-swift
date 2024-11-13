import Foundation

// Swizzle the constructor of URLSession to wrap the provided delegate with our own.
extension URLSession {
    @objc class func _init(
        configuration: URLSessionConfiguration,
        delegate originalDelegate: (any URLSessionDelegate)?,
        delegateQueue queue: OperationQueue?
    ) -> URLSession {
        // Proxy the delegate if it's a URLSessionTaskDelegate.
        let delegate =
            if originalDelegate == nil {
                ProxyURLSessionTaskDelegate(nil)
            } else if let originalTaskDelegate = originalDelegate as? URLSessionTaskDelegate {
                ProxyURLSessionTaskDelegate(originalTaskDelegate)
            } else {
                originalDelegate
            }

        // Because the methods were swapped, this calls the original method.
        return URLSession._init(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: queue
        )
    }

    static func swizzleClassMethod(original: Selector, instrumented: Selector) {
        guard let originalMethod = class_getClassMethod(self, original) else {
            print("unable to swizzle \(original): original method not found")
            return
        }
        guard let instrumentedMethod = class_getClassMethod(self, instrumented) else {
            print("unable to swizzle \(original): instrumented method not found")
            return
        }
        method_exchangeImplementations(originalMethod, instrumentedMethod)
    }

    static func swizzle() {
        // init(configuration:,delegate:,delegateQueue)
        let initSelector = #selector(URLSession.init(configuration:delegate:delegateQueue:))
        let instrumentedInitSelector = #selector(
            URLSession._init(configuration:delegate:delegateQueue:)
        )
        swizzleClassMethod(original: initSelector, instrumented: instrumentedInitSelector)
    }
}
