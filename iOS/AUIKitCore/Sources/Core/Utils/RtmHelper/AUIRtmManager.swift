//
//  AUIRtmManager.swift
//  AUIKit
//
//  Created by wushengtao on 2023/3/1.
//

import Foundation
//import AgoraRtcKit
import AgoraRtmKit

let kChannelType = AgoraRtmChannelType.stream


/// 对RTM相关操作的封装类
open class AUIRtmManager: NSObject {
    private var rtmChannelType: AgoraRtmChannelType = kChannelType
    private var streamChannel: AgoraRtmStreamChannel?
    private let proxy: AUIRtmMsgProxy = AUIRtmMsgProxy()
    
    private var rtmClient: AgoraRtmClientKit!
    private var rtmStreamChannelMap: [String: AgoraRtmStreamChannel] = [:]
    
    public private(set) var isLogin: Bool = false
    
    deinit {
        aui_info("deinit AUIRtmManager", tag: "AUIRtmManager")
        self.rtmClient.removeDelegate(proxy)
    }
    
    public init(rtmClient: AgoraRtmClientKit?, rtmChannelType: AgoraRtmChannelType) {
        self.rtmClient = rtmClient
        self.rtmChannelType = rtmChannelType
        super.init()
        self.rtmClient.addDelegate(proxy)
        aui_info("init AUIRtmManager", tag: "AUIRtmManager")
    }
    
    public func login(token: String, completion: @escaping (Error?)->()) {
        if isLogin {
            completion(nil)
            return
        }
        self.rtmClient.login(token) {[weak self] resp, error in
            aui_info("login: \(error?.errorCode.rawValue ?? 0)", tag: "AUIRtmManager")
            self?.isLogin = error == nil ? true : false
            completion(error?.toNSError())
        }
        aui_info("login ", tag: "AUIRtmManager")
    }
    
    public func logout() {
        aui_info("logout", tag: "AUIRtmManager")
        rtmClient.logout()
        isLogin = false
    }
    
    public func renew(token: String) {
        aui_info("renew: \(token)", tag: "AUIRtmManager")
        rtmClient.renewToken(token)
    }
    
    public func renewChannel(channelName: String, token: String) {
        guard let streamChannel = rtmStreamChannelMap[channelName] else {
            return
        }
        
        aui_info("renewChannel: \(channelName) token: \(token)", tag: "AUIRtmManager")
        streamChannel.renewToken(token)
    }
}

//MARK: user
extension AUIRtmManager {
    public func getUserCount(channelName: String, completion:@escaping (Error?, Int)->()) {
        guard let presence = rtmClient.getPresence() else {
            completion(AUICommonError.rtmError(-1).toNSError(), 0)
            return
        }
        
        let options = AgoraRtmPresenceOptions()
        options.includeUserId = false
        options.includeState = false
        presence.whoNow(channelName: channelName, channelType: rtmChannelType, options: options, completion: { resp, error in
//            aui_info("presence whoNow '\(channelName)' finished: \(error.errorCode.rawValue) list count: \(resp.userStateList.count) userId: \(AUIRoomContext.shared.commonConfig?.userId ?? "")", tag: "AUIRtmManager")
            aui_info("getUserCount: \(resp?.totalOccupancy ?? 0)", tag: "AUIRtmManager")
            let userList = resp?.userList()
            completion(error?.toNSError(), userList!.count)
        })
        aui_info("presence whoNow '\(channelName)'", tag: "AUIRtmManager")
    }
    
    func whoNow(channelName: String, completion:@escaping (Error?, [[String: String]]?)->()) {
        guard let presence = rtmClient.getPresence() else {
            completion(AUICommonError.rtmError(-1).toNSError(), nil)
            return
        }
        
        let options = AgoraRtmPresenceOptions()
        options.includeUserId = true
        options.includeState = true
        presence.whoNow(channelName: channelName, channelType: rtmChannelType, options: options, completion: { resp, error in
//            aui_info("presence whoNow '\(channelName)' finished: \(error.errorCode.rawValue) list count: \(resp?.userStateList.count ?? 0) userId: \(AUIRoomContext.shared.commonConfig?.userId ?? "")", tag: "AUIRtmManager")
            
            let userList = resp?.userList()
            completion(error?.toNSError(), userList)
        })
        aui_info("presence whoNow '\(channelName)'", tag: "AUIRtmManager")
    }
    
    public func setPresenceState(channelName: String, attr:[String: Any], completion: @escaping (Error?)->()) {
        guard let presence = rtmClient.getPresence() else {
            completion(AUICommonError.rtmError(-1).toNSError())
            return
        }
        
        var items: [AgoraRtmStateItem] = []
        attr.forEach { (key: String, value: Any) in
            let item = AgoraRtmStateItem()
            item.key = key
            if let val = value as? String {
                item.value = val
            } else if let val = value as? UInt {
                item.value = "\(val)"
            } else if let val = value as? Double {
                item.value = "\(val)"
            } else {
                aui_error("setPresenceState missmatch item: \(key): \(value)", tag: "AUIRtmManager")
                return
            }
            
            items.append(item)
        }
        presence.setState(channelName: channelName, channelType: rtmChannelType, items: items, completion: { resp, error in
            aui_info("presence setState '\(channelName)' finished: \(error?.errorCode.rawValue ?? 0)", tag: "AUIRtmManager")
            completion(error?.toNSError())
        })
        aui_info("presence setState'\(channelName)' ", tag: "AUIRtmManager")
    }
}

//MARK: subscribe
extension AUIRtmManager {
    public func subscribeAttributes(channelName: String, itemKey: String, delegate: AUIRtmAttributesProxyDelegate) {
        proxy.subscribeAttributes(channelName: channelName, itemKey: itemKey, delegate: delegate)
    }
    
    public func unsubscribeAttributes(channelName: String, itemKey: String, delegate: AUIRtmAttributesProxyDelegate) {
        proxy.unsubscribeAttributes(channelName: channelName, itemKey: itemKey, delegate: delegate)
    }
    
    public func subscribeMessage(channelName: String, delegate: AUIRtmMessageProxyDelegate) {
        proxy.subscribeMessage(channelName: channelName, delegate: delegate)
    }
    
    public func unsubscribeMessage(channelName: String, delegate: AUIRtmMessageProxyDelegate) {
        proxy.unsubscribeMessage(channelName: channelName, delegate: delegate)
    }
    
    public func subscribeUser(channelName: String, delegate: AUIRtmUserProxyDelegate) {
        proxy.subscribeUser(channelName: channelName, delegate: delegate)
    }
    
    public func unsubscribeUser(channelName: String, delegate: AUIRtmUserProxyDelegate) {
        proxy.unsubscribeUser(channelName: channelName, delegate: delegate)
    }
    
    public func subscribeError(channelName: String, delegate: AUIRtmErrorProxyDelegate) {
        proxy.subscribeError(channelName: channelName, delegate: delegate)
    }
    
    public func unsubscribeError(channelName: String, delegate: AUIRtmErrorProxyDelegate) {
        proxy.unsubscribeError(channelName: channelName, delegate: delegate)
    }
    
    public func subscribeLock(channelName: String, lockName: String, delegate: AUIRtmLockProxyDelegate) {
        proxy.subscribeLock(channelName: channelName, lockName: lockName, delegate: delegate)
    }
    
    public func unsubscribeLock(channelName: String, lockName: String, delegate: AUIRtmLockProxyDelegate) {
        proxy.unsubscribeLock(channelName: channelName, lockName: lockName, delegate: delegate)
    }
    
    func subscribe(channelName: String, completion:@escaping (Error?)->()) {
        let options = AgoraRtmSubscribeOptions()
        options.features = [.metadata, .presence, .lock]
        rtmClient.subscribe(channelName: channelName, option: options) { resp, error in
            aui_info("subscribe '\(channelName)' finished: \(error?.errorCode.rawValue ?? 0)", tag: "AUIRtmManager")
            completion(error?.toNSError())
        }
        aui_info("subscribe '\(channelName)'", tag: "AUIRtmManager")
    }
    
    func subscribe(channelName: String, rtcToken: String, completion:@escaping (Error?)->()) {
        let group = DispatchGroup()
        
        var messageError: Error? = nil
        var streamError: Error? = nil
        
        defer {
            group.notify(queue: DispatchQueue.main) {
                if streamError == nil, messageError == nil {
                    completion(nil)
                    return
                }
                
                completion(messageError ?? streamError)
            }
        }
        
        //1.subscribe message
        group.enter()
        subscribe(channelName: channelName) { error in
            messageError = error
            group.leave()
        }
        
        //2. join channel to use presence
        group.enter()
        let joinOption = AgoraRtmJoinChannelOption()
        joinOption.features = [.metadata, .presence, .lock]
        joinOption.token = rtcToken
        if rtmStreamChannelMap[channelName] == nil {
            let streamChannel = try? rtmClient.createStreamChannel(channelName)
            rtmStreamChannelMap[channelName] = streamChannel
        }
        guard let streamChannel = rtmStreamChannelMap[channelName] else {
            assert(false, "streamChannel not found")
            streamError = AUICommonError.rtmError(-1).toNSError()
            group.leave()
            return
        }
        
        streamChannel.join(joinOption) { resp, error in
            aui_info("join '\(channelName)' finished: \(error?.errorCode.rawValue ?? 0)", tag: "AUIRtmManager")
//            completion(error.toNSError())
            streamError = error?.toNSError()
            group.leave()
        }
        aui_info("join '\(channelName)' rtcToken: \(rtcToken)", tag: "AUIRtmManager")
    }
    
    func unSubscribe(channelName: String) {
        proxy.cleanCache(channelName: channelName)
        rtmClient.unsubscribe(channelName)
        
        guard let streamChannel = rtmStreamChannelMap[channelName] else {
            return
        }
        streamChannel.leave()
        rtmStreamChannelMap[channelName] = nil
    }
}

//MARK: Channel Metadata
extension AUIRtmManager {
    func cleanMetadata(channelName: String, lockName: String, completion: @escaping (Error?)->()) {
        guard let data = rtmClient.getStorage()?.createMetadata(), let storage = rtmClient.getStorage() else {
            assert(false, "cleanMetadata fail")
            return
        }
        
        let options = AgoraRtmMetadataOptions()
        options.recordTs = true
        options.recordUserId = true
        storage.removeChannelMetadata(channelName: channelName, 
                                      channelType: rtmChannelType,
                                      data: data,
                                      options: options,
                                      lock: lockName) { resp, error in
            aui_info("cleanMetadata[\(channelName)][\(lockName)] finished: \(error?.errorCode.rawValue ?? 0)", tag: "AUIRtmManager")
            completion(error?.toNSError())
        }
        aui_info("cleanMetadata[\(channelName)]", tag: "AUIRtmManager")

    }

    func setMetadata(channelName: String, 
                     lockName: String,
                     metadata: [String: String], 
                     completion: @escaping (Error?)->()) {
        guard let storage = rtmClient.getStorage(),
              let data = storage.createMetadata() else {
            assert(false, "setMetadata fail")
            return
        }
        metadata.forEach { (key: String, value: String) in
            let item = AgoraRtmMetadataItem()
            item.key = key
            item.value = value
            data.setMetadataItem(item)
        }

        let options = AgoraRtmMetadataOptions()
        options.recordTs = true
        options.recordUserId = true
        storage.setChannelMetadata(channelName: channelName,
                                   channelType: rtmChannelType,
                                   data: data,
                                   options: options,
                                   lock: lockName) { resp, error in
            aui_info("setMetadata[\(channelName)][\(lockName)] finished: \(error?.errorCode.rawValue ?? 0)", tag: "AUIRtmManager")
            completion(error?.toNSError())
        }
        aui_info("setMetadata \(metadata)", tag: "AUIRtmManager")
    }

    func updateMetadata(channelName: String, 
                        lockName: String,
                        metadata: [String: String],
                        completion: @escaping (Error?)->()) {
        guard let storage = rtmClient.getStorage(),
                  let data = storage.createMetadata() else {
            assert(false, "updateMetadata fail")
            return
        }
        metadata.forEach { (key: String, value: String) in
            let item = AgoraRtmMetadataItem()
            item.key = key
            item.value = value
            data.setMetadataItem(item)
        }

        let options = AgoraRtmMetadataOptions()
        options.recordTs = true
        options.recordUserId = true
        storage.updateChannelMetadata(channelName: channelName,
                                      channelType: rtmChannelType,
                                      data: data,
                                      options: options,
                                      lock: lockName) { resp, error in
            aui_info("updateMetadata[\(channelName)][\(lockName)] finished: \(error?.errorCode.rawValue ?? 0)", tag: "AUIRtmManager")
            completion(error?.toNSError())
        }
        aui_info("updateMetadata \(metadata)", tag: "AUIRtmManager")
    }
    
    func getMetadata(channelName: String, completion: @escaping (Error?, [String: String]?)->()) {
        guard let storage = rtmClient.getStorage() else {
            assert(false, "getMetadata fail")
            return
        }
        storage.getChannelMetadata(channelName: channelName, channelType: rtmChannelType, completion: { resp, error in
            aui_info("getMetadata[\(channelName)] finished: \(error?.errorCode.rawValue ?? 0) item count: \(resp?.data?.getItems().count ?? 0)", tag: "AUIRtmManager")
            var map: [String: String] = [:]
            resp?.data?.getItems().forEach({ item in
                map[item.key] = item.value
            })
            completion(error?.toNSError(), map)
        })
        aui_info("getMetadata", tag: "AUIRtmManager")
    }
}

//MARK: user metadata
extension AUIRtmManager {
    func subscribeUser(userId: String) {
        guard let storage = rtmClient.getStorage() else {
            assert(false, "subscribeUserMetadata fail")
            return
        }
        storage.subscribeUserMetadata(userId: userId, completion: { resp, error in
            aui_info("subscribeUser finished: \(error?.errorCode.rawValue ?? 0)", tag: "AUIRtmManager")
        })
        aui_info("subscribeUserMetadata", tag: "AUIRtmManager")
    }
    
    func unSubscribeUser(userId: String) {
        guard let storage = rtmClient.getStorage() else {
            aui_error("subscribeUserMetadata fail", tag: "AUIRtmManager")
            assert(false, "subscribeUserMetadata fail")
            return
        }
        storage.unsubscribeUserMetadata(userId: userId)
        aui_info("subscribeUserMetadata", tag: "AUIRtmManager")
    }
    
    func removeUserMetadata(userId: String) {
        guard let storage = rtmClient.getStorage(),
                  let data = storage.createMetadata() else {
            aui_info("removeUserMetadata fail", tag: "AUIRtmManager")
            assert(false, "removeUserMetadata fail")
            return
        }
        let options = AgoraRtmMetadataOptions()
        options.recordTs = true
        options.recordUserId = true
        
        storage.removeUserMetadata(userId: userId, data: data, options: options, completion: { resp, error in
            aui_info("removeUserMetadata finished: \(error?.errorCode.rawValue ?? 0)", tag: "AUIRtmManager")
        })
        aui_info("removeUserMetadata", tag: "AUIRtmManager")
    }
    
    func setUserMetadata(userId: String, metadata: [String: String]) {
        guard let storage = rtmClient.getStorage(),
                let data = storage.createMetadata() else {
            assert(false, "setUserMetadata fail")
            return
        }
        let options = AgoraRtmMetadataOptions()
        options.recordTs = true
        options.recordUserId = true
        
        metadata.forEach { (key: String, value: String) in
            let item = AgoraRtmMetadataItem()
            item.key = key
            item.value = value
            data.setMetadataItem(item)
        }
        
        storage.setUserMetadata(userId: userId, data: data, options: options, completion: { resp, error in
            aui_info("setUserMetadata finished: \(error?.errorCode.rawValue ?? 0)", tag: "AUIRtmManager")
        })
        aui_info("setUserMetadata", tag: "AUIRtmManager")
    }
    
    func updateUserMetadata(userId: String, metadata: [String: String]) {
        guard let storage = rtmClient.getStorage(),
                let data = storage.createMetadata() else {
            aui_error("updateUserlMetadata fail", tag: "AUIRtmManager")
            assert(false, "updateUserlMetadata fail")
            return
        }
        let options = AgoraRtmMetadataOptions()
        options.recordTs = true
        options.recordUserId = true
        
        metadata.forEach { (key: String, value: String) in
            let item = AgoraRtmMetadataItem()
            item.key = key
            item.value = value
            data.setMetadataItem(item)
        }
        
        storage.updateUserMetadata(userId: userId, data: data, options: options, completion: { resp, error in
            aui_info("updateUserlMetadata finished: \(error?.errorCode.rawValue ?? 0)", tag: "AUIRtmManager")
        })
        aui_info("updateUserlMetadata ", tag: "AUIRtmManager")
    }
    
    func getUserMetadata(userId: String) {
        guard let storage = rtmClient.getStorage() else {
            aui_error("getUserMetadata fail", tag: "AUIRtmManager")
            return
        }
        
        storage.getUserMetadata(userId: userId) { resp, error in
            aui_info("getUserMetadata: \(error?.errorCode.rawValue ?? 0)", tag: "AUIRtmManager")
        }
        aui_info("getUserMetadata ", tag: "AUIRtmManager")
    }
}

//MARK: message
extension AUIRtmManager {
    public func publish(channelName: String, message: String, completion: @escaping (NSError?)->()) {
        let options = AgoraRtmPublishOptions()
        rtmClient.publish(channelName: channelName, message: message, option: options) { resp, error in
            var callbackError: NSError?
            if let error = error {
                callbackError = AUICommonError.httpError(error.errorCode.rawValue, error.reason).toNSError()
            }
            completion(callbackError)
            aui_info("publish '\(message)' to '\(channelName)': \(error?.errorCode.rawValue ?? 0)", tag: "AUIRtmManager")
        }
        aui_info("publish '\(message)' to '\(channelName)'", tag: "AUIRtmManager")
    }
}

//MARK: lock
extension AUIRtmManager {
    public func setLock(channelName: String, lockName: String, completion:@escaping((Error?)->())) {
        rtmClient.getLock()?.setLock(channelName: channelName, channelType: .message, lockName: lockName, ttl: 10) { resp, errorInfo in
            aui_info("setLock[\(channelName)][\(lockName)]: \(errorInfo?.reason ?? "")")
            completion(errorInfo?.toNSError())
        }
    }
    public func acquireLock(channelName: String, lockName: String, completion:@escaping((Error?)->())) {
        rtmClient.getLock()?.acquireLock(channelName: channelName, channelType: .message, lockName: lockName, retry: true) { resp, errorInfo in
            aui_info("acquireLock[\(channelName)][\(lockName)]: \(errorInfo?.errorCode.rawValue ?? 0)")
            completion(errorInfo?.toNSError())
        }
    }
    
    public func releaseLock(channelName: String, lockName: String, completion:@escaping((Error?)->())) {
        rtmClient.getLock()?.releaseLock(channelName: channelName, channelType: .message, lockName: lockName, completion: { resp, errorInfo in
            aui_info("releaseLock[\(channelName)][\(lockName)]: \(errorInfo?.reason ?? "")")
            completion(errorInfo?.toNSError())
        })
    }
    
    public func removeLock(channelName: String, lockName: String, completion:@escaping((Error?)->())) {
        rtmClient.getLock()?.removeLock(channelName: channelName, channelType: .message, lockName: lockName, completion: { resp, errorInfo in
            aui_info("removeLock[\(channelName)][\(lockName)]: \(errorInfo?.reason ?? "")")
            completion(errorInfo?.toNSError())
        })
    }
}

extension AgoraRtmErrorInfo {
    func toNSError()-> NSError? {
        return self.errorCode == .ok ? nil : NSError(domain: self.reason, code: self.errorCode.rawValue)
    }
}

