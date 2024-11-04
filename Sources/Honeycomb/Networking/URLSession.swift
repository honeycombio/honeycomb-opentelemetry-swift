
import Foundation

extension URLSession {
    @objc class func _init(
        configuration: URLSessionConfiguration,
        delegate originalDelegate: (any URLSessionDelegate)?,
        delegateQueue queue: OperationQueue?
    ) -> URLSession {
        // TODO: Add a comment.
        // Wharrrgggrrrble
        let delegate = if originalDelegate == nil {
            ProxyURLSessionTaskDelegate(nil)
        } else if let originalTaskDelegate = originalDelegate as? URLSessionTaskDelegate {
            ProxyURLSessionTaskDelegate(originalTaskDelegate)
        } else {
            originalDelegate
        }
        
        // Because the methods were swapped, this calls the original method.
        return URLSession._init(configuration: configuration, delegate: delegate, delegateQueue: queue)
    }
    
    /*
    @objc func _instrumented_dataTask(with request: URLRequest) -> URLSessionDataTask {
        // Because the methods were swapped, this calls the original method.
        return _instrumented_dataTask(with: request)
    }

    @objc func _instrumented_dataTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void
    ) -> URLSessionDataTask {
        // Because the methods were swapped, this calls the original method.
        let task = _instrumented_dataTask(with: request, completionHandler: completionHandler)
        
        // TODO: Check the URL here?
        
        // If there is a delegate for this session, attach it to the task as well.
        if let delegate = self.delegate as? URLSessionTaskDelegate {
            if #available(iOS 15.0, *) {
                task.delegate = delegate
            }
        }
        return task
    }

    static func swizzleInstanceMethod(original: Selector, instrumented: Selector) {
        guard let originalMethod = class_getInstanceMethod(self, original) else {
            print("unable to swizzle \(original): original method not found")
            return
        }
        guard let instrumentedMethod = class_getInstanceMethod(self, instrumented) else {
            print("unable to swizzle \(original): instrumented method not found")
            return
        }
        method_exchangeImplementations(originalMethod, instrumentedMethod)
    }
     */

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
        // TODO: Do I need to swizzle init too?
        
        // init(configuration:,delegate:,delegateQueue)
        let initSelector = #selector(URLSession.init(configuration:delegate:delegateQueue:))
        let instrumentedInitSelector = #selector(URLSession._init(configuration:delegate:delegateQueue:))
        swizzleClassMethod(original: initSelector, instrumented: instrumentedInitSelector)
        
        /*
        // dataTask(with:URLRequest)
        let dataTaskWithRequestSelector = #selector(
            URLSession.dataTask(with:) as (URLSession) -> (URLRequest) -> URLSessionDataTask
        )
        let instrumentedDataTaskWithRequestSelector = #selector(
            URLSession._instrumented_dataTask(with:)
        )
        swizzleInstanceMethod(
            original: dataTaskWithRequestSelector,
            instrumented: instrumentedDataTaskWithRequestSelector)

        // dataTask(with:URLRequest,completionHandler:)
        let dataTaskWithRequestAndCompletionSelector = #selector(
            URLSession.dataTask(with:completionHandler:)
                as (URLSession) -> (
                    URLRequest,
                    @escaping @Sendable (Data?, URLResponse?, (any Error)?) -> Void
                ) -> URLSessionDataTask
        )
        let instrumentedDataTaskWithRequestAndCompletionSelector = #selector(
            URLSession._instrumented_dataTask(with:completionHandler:)
        )
        swizzleInstanceMethod(
            original: dataTaskWithRequestAndCompletionSelector,
            instrumented: instrumentedDataTaskWithRequestAndCompletionSelector)
         */
    }
}
