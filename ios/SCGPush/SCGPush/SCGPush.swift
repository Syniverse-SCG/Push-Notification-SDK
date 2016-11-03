//
//  SCGPush.swift
//  SCGPush
//
//  Created by Slav Sarafski on 6/12/16.
//  Copyright © 2016 Spirit Invoker. All rights reserved.
//

import UIKit
import MobileCoreServices

open class SCGPush: NSObject {
    
    // PRIVATE VARIABLES
    fileprivate var _accessToken:String = ""
    
    // PUBLIC VARIABLES
    open var accessToken:String
    {
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue, forKey: ("scg-access-token-dont-replace-this-default"))
            if groupBundle != "" {
                if let groupDefault = UserDefaults(suiteName: groupBundle) {
                    groupDefault.set(newValue, forKey: ("scg-access-token-dont-replace-this-default"))
                }
            }
            _accessToken = newValue
        }
        get {
            _accessToken = ""
            let defaults = UserDefaults.standard
            if (defaults.string(forKey: "scg-access-token-dont-replace-this-default") != nil) {
                _accessToken = defaults.string(forKey: "scg-access-token-dont-replace-this-default")!
            } else {
                if let groupDefault = UserDefaults(suiteName: groupBundle) {
                    if let token = groupDefault.string(forKey: "scg-access-token-dont-replace-this-default") {
                        _accessToken = token
                    }
                }
            }
            return _accessToken
        }
    }
    
    open var callbackURI:String
    {
        set {
            let defaults = UserDefaults.standard
            defaults.set(newValue, forKey: ("scg-callback-uri-dont-replace-this-default"))
            if groupBundle != "" {
                if let groupDefault = UserDefaults(suiteName: groupBundle) {
                    groupDefault.set(newValue, forKey: ("scg-callback-uri-dont-replace-this-default"))
                }
            }
        }
        get {
            let defaults = UserDefaults.standard
            if (defaults.string(forKey: "scg-callback-uri-dont-replace-this-default") != nil) {
                return defaults.string(forKey: "scg-callback-uri-dont-replace-this-default")!
            }
            else {
                if let groupDefault = UserDefaults(suiteName: groupBundle) {
                    if let uri = groupDefault.string(forKey: "scg-callback-uri-dont-replace-this-default") {
                        return uri
                    }
                }
            }
            return ""
        }
    }
    
    open var appID:String = ""
    
    open var groupBundle:String = ""
    
    // PRIVATE VARIABLES
    fileprivate let tokenType = "APN"
    
    open static let instance = SCGPush()
    
    public override init (){
        
    }
    
    open func registerPushToken(deviceTokeData data:Data, completionBlock: (() -> Void)? = nil, failureBlock : ((Error?) -> ())? = nil) {
        
        let tokenChars = (data as NSData).bytes.bindMemory(to: CChar.self, capacity: data.count)
        var pushToken = ""
        for i in 0..<data.count {
            pushToken += String(format: "%02.2hhx", arguments: [tokenChars[i]])
            
        }
        
        registerPushToken(pushToken, completionBlock: completionBlock, failureBlock: failureBlock)
    }
    
    open func registerPushToken(_ deviceToken:String, completionBlock: (() -> Void)? = nil, failureBlock : ((Error?) -> ())? = nil)
    {
        saveDeviceToken(deviceToken: deviceToken as NSString)
        
        registerPushToken(completionBlock, failureBlock: failureBlock)
    }
    
    open func registerPushToken(_ completionBlock: (() -> Void)? = nil, failureBlock : ((Error?) -> ())? = nil)
    {
        let defaults = UserDefaults.standard
        if (defaults.string(forKey: "scg-push-token-dont-replace-this-default") == nil) {
            return
        }
        
        let deviceToken:String = defaults.string(forKey: "scg-push-token-dont-replace-this-default")!
        
        
        let params = ["app_id":appID as AnyObject,
                      "type":tokenType as AnyObject,
                      "token":deviceToken as AnyObject] as Dictionary<String, AnyObject>
        
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration)
        
        let urlString = "\(callbackURI)/push_tokens/register"
        let url = URL(string: urlString)
        
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody  = try! JSONSerialization.data(withJSONObject: params, options: [])
        
        let dataTask = session.dataTask(with: request, completionHandler: {
            (data: Data?, response: URLResponse?, error: Error?) -> Void in
            
            guard let httpResponse = response as? HTTPURLResponse, let _ = data
                else {
                    //print("error: not a valid http response")
                    if (failureBlock != nil) {
                        failureBlock! (error)
                    }
                    return
            }
            
            switch (httpResponse.statusCode)
            {
            case 200:
                if (completionBlock != nil) {
                    completionBlock! ()
                }
            case 204:
                if (completionBlock != nil) {
                    completionBlock! ()
                }
                
            default:
                if (failureBlock != nil) {
                    let errorSend = NSError(domain: (httpResponse.url?.absoluteString)!, code: httpResponse.statusCode, userInfo: nil)
                    failureBlock! (errorSend)
                }
            }
        })        

        dataTask.resume()
    }

    open func unregisterPushToken(_ completionBlock: (() -> Void)? = nil, failureBlock : ((Error?) -> ())? = nil)
    {
        let defaults = UserDefaults.standard
        let pushToken:String = defaults.string(forKey: "scg-push-token-dont-replace-this-default")! as String
        
        let params = ["app_id":appID,
                      "type":tokenType,
                      "token": pushToken] as Dictionary<String, String>
        
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration)
        
        let urlString = "\(callbackURI)/push_tokens/unregister"
        let url = URL(string: urlString)
        
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody  = try! JSONSerialization.data(withJSONObject: params, options: [])
        
        let dataTask = session.dataTask(with: request, completionHandler: {
            (data: Data?, response: URLResponse?, error: Error?) -> Void in
            
            guard let httpResponse = response as? HTTPURLResponse, let _ = data
                else {
                    //print("error: not a valid http response")
                    if (failureBlock != nil) {
                        failureBlock! (error)
                    }
                    return
            }
            
            switch (httpResponse.statusCode)
            {
            case 200:
                defaults.removeObject(forKey: "scg-push-token-dont-replace-this-default")
                if (completionBlock != nil) {
                    completionBlock! ()
                }
            case 204:
                defaults.removeObject(forKey: "scg-push-token-dont-replace-this-default")
                if (completionBlock != nil) {
                    completionBlock! ()
                }
                
            default:
                if (failureBlock != nil) {
                    let errorSend = NSError(domain: (httpResponse.url?.absoluteString)!, code: httpResponse.statusCode, userInfo: nil)
                    failureBlock! (errorSend)
                }
            }
        })        

        dataTask.resume()
    }
    //[NSObject : AnyObject]
    open func deliveryConfirmation(userInfo:NSDictionary ,completionBlock: (() -> Void)? = nil, failureBlock : ((Error?) -> ())? = nil)
    {
        if let messageID = userInfo["scg-message-id"]
        {
            deliveryConfirmation(messageID as! String, completionBlock: completionBlock, failureBlock: failureBlock)
        }
    }
    
    open func deliveryConfirmation(_ messageID:String ,completionBlock: (() -> Void)? = nil, failureBlock : ((Error?) -> ())? = nil)
    {
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration)
        
        let urlString = "\(callbackURI)/messages/\(messageID)/delivery_confirmation"
        let url = URL(string: urlString)
        
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let dataTask = session.dataTask(with: request, completionHandler: {
            (data: Data?, response: URLResponse?, error: Error?) -> Void in
            
            guard let httpResponse = response as? HTTPURLResponse, let _ = data
                else {
                    if (failureBlock != nil) {
                        failureBlock! (error)
                    }
                    return
            }
            
            switch (httpResponse.statusCode)
            {
            case 200:
                if (completionBlock != nil) {
                    completionBlock! ()
                }
            case 204:
                if (completionBlock != nil) {
                    completionBlock! ()
                }
                
            default:
                if (failureBlock != nil) {
                    let errorSend = NSError(domain: (httpResponse.url?.absoluteString)!, code: httpResponse.statusCode, userInfo: nil)
                    failureBlock! (errorSend)
                }
            }
        })        

        dataTask.resume()
    }
    
    open func interactionConfirmation(userInfo:NSDictionary ,completionBlock: (() -> Void)? = nil, failureBlock : ((Error?) -> ())? = nil) {
        if let messageID = userInfo["scg-message-id"]
        {
            interactionConfirmation(messageID as! String, completionBlock: completionBlock, failureBlock: failureBlock)
        }
    }
    
    open func interactionConfirmation(_ messageID:String ,completionBlock: (() -> Void)? = nil, failureBlock : ((Error?) -> ())? = nil) {
        
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration)
        
        let urlString = "\(callbackURI)/messages/\(messageID)/click_thru_confirmation"
        let url = URL(string: urlString)
        
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let dataTask = session.dataTask(with: request, completionHandler: {
            (data: Data?, response: URLResponse?, error: Error?) -> Void in
            
            guard let httpResponse = response as? HTTPURLResponse, let _ = data
                else {
                    if (failureBlock != nil) {
                        failureBlock! (error)
                    }
                    return
            }
            
            switch (httpResponse.statusCode)
            {
            case 200:
                if (completionBlock != nil) {
                    completionBlock! ()
                }
            case 204:
                if (completionBlock != nil) {
                    completionBlock! ()
                }
                
            default:
                if (failureBlock != nil) {
                    let errorSend = NSError(domain: (httpResponse.url?.absoluteString)!, code: httpResponse.statusCode, userInfo: nil)
                    failureBlock! (errorSend)
                }
            }
        })
        
        dataTask.resume()
    }
    
    open func loadAttachment(userInfo:NSDictionary ,completionBlock: ((_ contentURL:URL, _ contentType:String) -> Void)? = nil, failureBlock : ((Error?) -> ())? = nil) {
        if let attachmentID = userInfo["scg-attachment-id"] as? String,
           let messageID = userInfo["scg-message-id"] as? String
        {
            self.loadAttachment(messageID, attachmentID: attachmentID, completionBlock: completionBlock, failureBlock: failureBlock)
        }
    }
    
    open func loadAttachment(_ messageID:String, attachmentID:String ,completionBlock: ((_ contentURL:URL, _ contentType:String) -> Void)? = nil, failureBlock : ((Error?) -> ())? = nil) {
        
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration)
        let urlString = "\(callbackURI)/attachment/\(messageID)/\(attachmentID)"
//        let urlString = "https://www.hallaminternet.com/assets/https.jpg"
//        let urlString = "https://framework.realtime.co/blog/img/ios10-video.mp4"
        
        let url:URL = URL(string: urlString)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        
        request.addValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let dataTask = session.downloadTask(with: request, completionHandler: {
            (location: URL?, response: URLResponse?, error: Error?) -> Void in
            
            guard let httpResponse = response as? HTTPURLResponse
                else {
                    if (failureBlock != nil) {
                        failureBlock! (error)
                    }
                    return
            }
            var contentUrl:URL?
            let contentType:String = self.readTypeOfHeader(header: httpResponse)
            
            if let location = location {
                // Move temporary file to remove .tmp extension
                let tmpDirectory = NSTemporaryDirectory()
                let tmpFile = "file://".appending(tmpDirectory).appending(url.lastPathComponent)
                let tmpUrl = URL(string: tmpFile)!
                if FileManager.default.fileExists(atPath: tmpUrl.path) {
                    try! FileManager.default.removeItem(at: tmpUrl)
                }
                try! FileManager.default.moveItem(at: location, to: tmpUrl)
                contentUrl = tmpUrl
            }
            
            switch (httpResponse.statusCode)
            {
            case 200:
                if (completionBlock != nil) {
                    completionBlock! (contentUrl!, contentType)
                }
            case 204:
                if (completionBlock != nil) {
                    completionBlock! (contentUrl!, contentType)
                }
                
            default:
                if (failureBlock != nil) {
                    let errorSend = NSError(domain: (httpResponse.url?.absoluteString)!, code: httpResponse.statusCode, userInfo: nil)
                    failureBlock! (errorSend)
                }
            }
        })
        
        dataTask.resume()
    }
    
    open func saveDeviceToken(deviceTokenData tokenData:Data) {
        let tokenChars = (tokenData as NSData).bytes.bindMemory(to: CChar.self, capacity: tokenData.count)
        var pushToken = ""
        for i in 0..<tokenData.count {
            pushToken += String(format: "%02.2hhx", arguments: [tokenChars[i]])
            
        }
        
        let defaults = UserDefaults.standard
        defaults.set(pushToken, forKey: "scg-push-token-dont-replace-this-default")
    }
    
    open func saveDeviceToken(deviceToken token:NSString) {
        let defaults = UserDefaults.standard
        defaults.set(token, forKey: "scg-push-token-dont-replace-this-default")
    }
    
    func readTypeOfHeader(header:HTTPURLResponse) -> String {
        if let type:String = header.allHeaderFields["Content-Type"] as! String? {
            switch type {
            case "video/mpeg":
                return kUTTypeMPEG4 as String
            case "image/gif":
                return kUTTypeGIF as String
            case "image/png":
                return kUTTypePNG as String
            case "image/jpg":
                return kUTTypeImage as String
            default:
                return ""
            }
        }
        return ""
    }
}
