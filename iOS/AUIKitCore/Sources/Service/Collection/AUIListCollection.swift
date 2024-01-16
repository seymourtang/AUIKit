//
//  AUIListCollection.swift
//  AUIKitCore
//
//  Created by wushengtao on 2024/1/4.
//

import Foundation

public class AUIListCollection: AUIBaseCollection {
    private var currentList: [[String: Any]] = []{
        didSet {
            //TODO: if oldValue == currentList {return}
            self.attributesDidChangedClosure?(channelName, observeKey, currentList)
        }
    }
}

//MARK: private set meta data
extension AUIListCollection {
    private func rtmAddMetaData(publisherId: String,
                                valueCmd: String?,
                                value: [String: Any],
                                filter: [[String: Any]]?,
                                callback: ((NSError?)->())?) {
        if let _ = getItemIndexes(array: currentList, filter: filter) {
            callback?(NSError.auiError("rtmAddMetaData fail, the result was found in the filter: '\(filter ?? [])'"))
            return
        }
        if let err = self.metadataWillAddClosure?(publisherId, valueCmd, value) {
            callback?(err)
            return
        }
        var list = currentList
        list.append(value)
        
        guard let value = encodeToJsonStr(list) else {
            callback?(NSError.auiError("rtmAddMetaData fail"))
            return
        }
        
        aui_collection_log("rtmAddMetaData valueCmd: \(valueCmd ?? "") value: \(value), \nfilter: \(filter ?? [])")
        self.rtmManager.setBatchMetadata(channelName: channelName,
                                         lockName: kRTM_Referee_LockName,
                                         metadata: [observeKey: value]) { error in
            aui_collection_log("rtmAddMetaData completion: \(error?.localizedDescription ?? "success")")
            callback?(error)
        }
        currentList = list
    }
    
    private func rtmSetMetaData(publisherId: String,
                                valueCmd: String?,
                                value: [String: Any],
                                filter: [[String: Any]]?,
                                callback: ((NSError?)->())?) {
        guard let itemIndexes = getItemIndexes(array: currentList, filter: filter) else {
            callback?(NSError.auiError("rtmSetMetaData fail, the result was not found in the filter: '\(filter ?? [])'"))
            return
        }
        var list = currentList
        for itemIdx in itemIndexes {
            let item = list[itemIdx]
            //once break, always break
            if let err = self.metadataWillUpdateClosure?(publisherId, valueCmd, value, item) {
                callback?(err)
                return
            }
            
            var tempItem = item
            value.forEach { (key, value) in
                tempItem[key] = value
            }
            list[itemIdx] = tempItem
        }
        guard let value = encodeToJsonStr(list) else {
            callback?(NSError.auiError("rtmRemoveMetaData fail"))
            return
        }
        
        aui_collection_log("rtmSetMetaData valueCmd: \(valueCmd ?? ""), filter: \(filter ?? []), value: \(value)")
        self.rtmManager.setBatchMetadata(channelName: channelName,
                                         lockName: kRTM_Referee_LockName,
                                         metadata: [observeKey: value]) { error in
            aui_collection_log("rtmSetMetaData completion: \(error?.localizedDescription ?? "success")")
            callback?(error)
        }
        currentList = list
    }
    
    private func rtmMergeMetaData(publisherId: String,
                                  valueCmd: String?,
                                  value: [String: Any],
                                  filter: [[String: Any]]?,
                                  callback: ((NSError?)->())?) {
        guard let itemIndexes = getItemIndexes(array: currentList, filter: filter) else {
            callback?(NSError.auiError("rtmMergeMetaData fail, the result was not found in the filter: '\(filter ?? [])'"))
            return
        }
        
        var list = currentList
        for itemIdx in itemIndexes {
            let item = list[itemIdx]
            //once break, always break
            if let err = self.metadataWillMergeClosure?(publisherId, valueCmd, value, item) {
                callback?(err)
                return
            }
            
            let tempItem = mergeMap(origMap: item, newMap: value)
            list[itemIdx] = tempItem
        }
        
        guard let value = encodeToJsonStr(list) else {
            callback?(NSError.auiError("rtmRemoveMetaData fail"))
            return
        }
        
        aui_collection_log("rtmMergeMetaData valueCmd: \(valueCmd ?? ""), filter: \(filter ?? []), value: \(value)")
        self.rtmManager.setBatchMetadata(channelName: channelName,
                                         lockName: kRTM_Referee_LockName,
                                         metadata: [observeKey: value]) { error in
            aui_collection_log("rtmMergeMetaData completion: \(error?.localizedDescription ?? "success")")
            callback?(error)
        }
        currentList = list
    }
    
    private func rtmRemoveMetaData(publisherId: String,
                                   valueCmd: String?,
                                   filter: [[String: Any]]?,
                                   callback: ((NSError?)->())?) {
        guard let itemIndexes = getItemIndexes(array: currentList, filter: filter) else {
            callback?(NSError.auiError("rtmRemoveMetaData fail, the result was not found in the filter: '\(filter ?? [])'"))
            return
        }
        
        for itemIdx in itemIndexes {
            let item = currentList[itemIdx]
            if let err = self.metadataWillRemoveClosure?(publisherId, valueCmd, item) {
                callback?(err)
                return
            }
        }
        
        let filterList = currentList.enumerated().filter { !itemIndexes.contains($0.offset) }
        let list = filterList.map { $0.element }
        guard let value = encodeToJsonStr(list) else {
            callback?(NSError.auiError("rtmRemoveMetaData fail"))
            return
        }
        
        aui_collection_log("rtmRemoveMetaData valueCmd: \(valueCmd ?? ""), filter: \(filter ?? []), value: \(value)")
        self.rtmManager.setBatchMetadata(channelName: channelName,
                                         lockName: kRTM_Referee_LockName,
                                         metadata: [observeKey: value]) { error in
            aui_collection_log("rtmRemoveMetaData completion: \(error?.localizedDescription ?? "success")")
            callback?(error)
        }
        currentList = list
    }
    
    private func rtmCalculateMetaData(publisherId: String,
                                      valueCmd: String?,
                                      key: [String],
                                      value: AUICollectionCalcValue,
                                      filter: [[String: Any]]?,
                                      callback: ((NSError?)->())?) {
        //TODO: will calculate?
        
        guard let itemIndexes = getItemIndexes(array: currentList, filter: filter) else {
            callback?(NSError.auiError("rtmCalculateMetaData fail, the result was not found in the filter"))
            return
        }
        
        var list = currentList
        for itemIdx in itemIndexes {
            let item = currentList[itemIdx]
            
            if let err = self.metadataWillCalculateClosure?(publisherId,
                                                            valueCmd,
                                                            item,
                                                            key,
                                                            value.value,
                                                            value.min,
                                                            value.max) {
                callback?(err)
                return
            }
            
            guard let tempItem = calculateMap(origMap: item,
                                              key: key,
                                              value: value.value,
                                              min: value.min,
                                              max: value.max) else {
                callback?(NSError.auiError("rtmCalculateMetaData fail! calculate meta data return nil"))
                return
            }
            list[itemIdx] = tempItem
        }
        
        guard let value = encodeToJsonStr(list) else {
            callback?(NSError.auiError("rtmCalculateMetaData fail! map encode fail"))
            return
        }
        aui_collection_log("rtmCalculateMetaData valueCmd: \(valueCmd ?? "") key: \(key), value: \(value)")
        self.rtmManager.setBatchMetadata(channelName: channelName,
                                         lockName: kRTM_Referee_LockName,
                                         metadata: [observeKey: value]) { error in
            aui_collection_log("rtmCalculateMetaData completion: \(error?.localizedDescription ?? "success")")
            callback?(error)
        }
        currentList = list
    }
    
    private func rtmCleanMetaData(callback: ((NSError?)->())?) {
        aui_collection_log("rtmCleanMetaData")
        self.rtmManager.cleanBatchMetadata(channelName: channelName,
                                           lockName: kRTM_Referee_LockName,
                                           removeKeys: [observeKey]) { error in
            aui_collection_log("rtmCleanMetaData completion: \(error?.localizedDescription ?? "success")")
            callback?(error)
        }
    }
}

//MARK: override IAUICollection
extension AUIListCollection {
    public override func updateMetaData(valueCmd: String?,
                                        value: [String : Any],
                                        filter: [[String: Any]]?,
                                        callback: ((NSError?) -> ())?) {
        if AUIRoomContext.shared.getArbiter(channelName: channelName)?.isArbiter() ?? false {
            let currentUserId = AUIRoomContext.shared.currentUserInfo.userId
            rtmSetMetaData(publisherId: currentUserId, 
                           valueCmd: valueCmd,
                           value: value, 
                           filter: filter,
                           callback: callback)
            return
        }
        
        let payload = AUICollectionMessagePayload(type: .update, 
                                                  dataCmd: valueCmd,
                                                  filter: filter == nil ? nil : AUIAnyType(array: filter!),
                                                  data: AUIAnyType(map: value))
        let message = AUICollectionMessage(channelName: channelName,
                                           messageType: AUIMessageType.normal,
                                           sceneKey: observeKey,
                                           uniqueId: UUID().uuidString,
                                           payload: payload)

        guard let jsonStr = encodeModelToJsonStr(message) else {
            callback?(NSError.auiError("updateMetaData fail"))
            return
        }
        
        let userId = AUIRoomContext.shared.getArbiter(channelName: channelName)?.lockOwnerId ?? ""
        rtmManager.publishAndWaitReceipt(userId: userId,
                                         channelName: channelName,
                                         message: jsonStr,
                                         uniqueId: message.uniqueId,
                                         completion: callback)
    }
    
    public override func mergeMetaData(valueCmd: String?,
                                       value: [String : Any],
                                       filter: [[String: Any]]?,
                                       callback: ((NSError?) -> ())?) {
        if AUIRoomContext.shared.getArbiter(channelName: channelName)?.isArbiter() ?? false {
            let currentUserId = AUIRoomContext.shared.currentUserInfo.userId
            rtmMergeMetaData(publisherId: currentUserId,
                             valueCmd: valueCmd,
                             value: value,
                             filter: filter,
                             callback: callback)
            return
        }
        
        let payload = AUICollectionMessagePayload(type: .merge,
                                                  dataCmd: valueCmd,
                                                  filter: filter == nil ? nil : AUIAnyType(array: filter!),
                                                  data: AUIAnyType(map: value))
        let message = AUICollectionMessage(channelName: channelName,
                                           messageType: AUIMessageType.normal,
                                           sceneKey: observeKey,
                                           uniqueId: UUID().uuidString,
                                           payload: payload)

        guard let jsonStr = encodeModelToJsonStr(message) else {
            callback?(NSError.auiError("mergeMetaData fail"))
            return
        }
        
        let userId = AUIRoomContext.shared.getArbiter(channelName: channelName)?.lockOwnerId ?? ""
        rtmManager.publishAndWaitReceipt(userId: userId,
                                         channelName: channelName,
                                         message: jsonStr,
                                         uniqueId: message.uniqueId,
                                         completion: callback)
    }
    
    public override func addMetaData(valueCmd: String?,
                                     value: [String : Any],
                                     filter: [[String: Any]]?,
                                     callback: ((NSError?) -> ())?) {
        if AUIRoomContext.shared.getArbiter(channelName: channelName)?.isArbiter() ?? false {
            let currentUserId = AUIRoomContext.shared.currentUserInfo.userId
            rtmAddMetaData(publisherId: currentUserId,
                           valueCmd: valueCmd,
                           value: value,
                           filter: filter,
                           callback: callback)
            return
        }
        
        let payload = AUICollectionMessagePayload(type: .add,
                                                  dataCmd: valueCmd,
                                                  filter: filter == nil ? nil : AUIAnyType(array: filter!),
                                                  data: AUIAnyType(map: value))
        let message = AUICollectionMessage(channelName: channelName,
                                           messageType: AUIMessageType.normal,
                                           sceneKey: observeKey,
                                           uniqueId: UUID().uuidString,
                                           payload: payload)

        guard let jsonStr = encodeModelToJsonStr(message) else {
            callback?(NSError.auiError("addMetaData fail"))
            return
        }
        
        let userId = AUIRoomContext.shared.getArbiter(channelName: channelName)?.lockOwnerId ?? ""
        rtmManager.publishAndWaitReceipt(userId: userId,
                                         channelName: channelName,
                                         message: jsonStr,
                                         uniqueId: message.uniqueId,
                                         completion: callback)
        
    }
    
    public override func removeMetaData(valueCmd: String?,
                                        filter: [[String: Any]]?,
                                        callback: ((NSError?) -> ())?) {
        if AUIRoomContext.shared.getArbiter(channelName: channelName)?.isArbiter() ?? false {
            let currentUserId = AUIRoomContext.shared.currentUserInfo.userId
            rtmRemoveMetaData(publisherId: currentUserId, 
                              valueCmd: valueCmd,
                              filter: filter,
                              callback: callback)
            return
        }
        
        
        let payload = AUICollectionMessagePayload(type: .remove, 
                                                  dataCmd: valueCmd,
                                                  filter: filter == nil ? nil : AUIAnyType(array: filter!))
        let message = AUICollectionMessage(channelName: channelName,
                                           messageType: AUIMessageType.normal,
                                           sceneKey: observeKey,
                                           uniqueId: UUID().uuidString,
                                           payload: payload)

        guard let jsonStr = encodeModelToJsonStr(message) else {
            callback?(NSError.auiError("removeMetaData fail"))
            return
        }
        
        let userId = AUIRoomContext.shared.getArbiter(channelName: channelName)?.lockOwnerId ?? ""
        rtmManager.publishAndWaitReceipt(userId: userId,
                                         channelName: channelName,
                                         message: jsonStr,
                                         uniqueId: message.uniqueId,
                                         completion: callback)
    }
    
    public override func calculateMetaData(valueCmd: String?,
                                           key: [String],
                                           value: Int,
                                           min: Int,
                                           max: Int,
                                           filter: [[String: Any]]?,
                                           callback: ((NSError?)->())?) {
        if AUIRoomContext.shared.getArbiter(channelName: channelName)?.isArbiter() ?? false {
            let currentUserId = AUIRoomContext.shared.currentUserInfo.userId
            rtmCalculateMetaData(publisherId: currentUserId,
                                 valueCmd: valueCmd,
                                 key: key,
                                 value: AUICollectionCalcValue(value: value, min: min, max: max),
                                 filter: filter,
                                 callback: callback)
            return
        }
        
        let calcData = AUICollectionCalcData(key: key,
                                             value: AUICollectionCalcValue(value: value, min: min, max: max))
        let data: [String: Any] = encodeModel(calcData) ?? [:]
        let payload = AUICollectionMessagePayload(type: .calculate,
                                                  dataCmd: valueCmd,
                                                  data: AUIAnyType(map: data))
        let message = AUICollectionMessage(channelName: channelName,
                                           messageType: AUIMessageType.normal,
                                           sceneKey: observeKey,
                                           uniqueId: UUID().uuidString,
                                           payload: payload)

        guard let jsonStr = encodeModelToJsonStr(message) else {
            callback?(NSError.auiError("updateMetaData fail"))
            return
        }
        let userId = AUIRoomContext.shared.getArbiter(channelName: channelName)?.lockOwnerId ?? ""
        rtmManager.publishAndWaitReceipt(userId: userId,
                                         channelName: channelName,
                                         message: jsonStr,
                                         uniqueId: message.uniqueId,
                                         completion: callback)
    }
    
    public override func cleanMetaData(callback: ((NSError?) -> ())?) {
        if AUIRoomContext.shared.getArbiter(channelName: channelName)?.isArbiter() ?? false {
            rtmCleanMetaData(callback: callback)
            return
        }
        
        let payload = AUICollectionMessagePayload(type: .clean, data: nil)
        let message = AUICollectionMessage(channelName: channelName,
                                           messageType: AUIMessageType.normal,
                                           sceneKey: observeKey,
                                           uniqueId: UUID().uuidString,
                                           payload: payload)
        
        guard let jsonStr = encodeModelToJsonStr(message) else {
            callback?(NSError.auiError("removeMetaData fail"))
            return
        }
        let userId = AUIRoomContext.shared.getArbiter(channelName: channelName)?.lockOwnerId ?? ""
        rtmManager.publishAndWaitReceipt(userId: userId,
                                         channelName: channelName,
                                         message: jsonStr,
                                         uniqueId: message.uniqueId,
                                         completion: callback)
    }
}

//MARK: override AUIRtmAttributesProxyDelegate
extension AUIListCollection {
    public override func onAttributesDidChanged(channelName: String, key: String, value: Any) {
        guard channelName == self.channelName, key == self.observeKey else {return}
        guard let list = value as? [[String: Any]] else {return}
        self.currentList = list
    }
}

//MARK: override AUIRtmMessageProxyDelegate
extension AUIListCollection {
    public override func onMessageReceive(publisher: String, message: String) {
        guard let map = decodeToJsonObj(message) as? [String: Any],
              let collectionMessage: AUICollectionMessage = decodeModel(map),
              collectionMessage.sceneKey == observeKey else {
            return
        }
        aui_collection_log("onMessageReceive: \(map)")
        let uniqueId = collectionMessage.uniqueId
        let channelName = collectionMessage.channelName
        guard channelName == self.channelName else {return}
        if collectionMessage.messageType == .receipt {
            if let callback = rtmManager.receiptCallbackMap[uniqueId]?.closure {
                rtmManager.markReceiptFinished(uniqueId: uniqueId)
                let data = collectionMessage.payload.data?.toJsonObject() as? [String : Any] ?? [:]
                let error: AUICollectionError? = decodeModel(data)
                let code = error?.code ?? 0
                let reason = error?.reason ?? "success"
                callback(code == 0 ? nil : NSError.auiError(reason))
            }
            return
        }
        
        guard let updateType = collectionMessage.payload.type else {
            sendReceipt(publisher: publisher,
                        uniqueId: uniqueId,
                        error: NSError.auiError("updateType not found"))
            return
        }
        
        let filter: [[String: Any]]? = collectionMessage.payload.filter?.toJsonObject() as? [[String: Any]]
        let valueCmd = collectionMessage.payload.dataCmd
        var err: NSError? = nil
        switch updateType {
        case .add, .update, .merge:
            if let value = collectionMessage.payload.data?.toJsonObject() as? [String : Any] {
                if updateType == .add {
                    rtmAddMetaData(publisherId: publisher,
                                   valueCmd: valueCmd,
                                   value: value,
                                   filter: filter) { [weak self] error in
                        self?.sendReceipt(publisher: publisher,
                                          uniqueId: uniqueId,
                                          error: error)
                    }
                } else if updateType == .merge {
                    rtmMergeMetaData(publisherId: publisher,
                                     valueCmd: valueCmd,
                                     value: value, 
                                     filter: filter) {[weak self] error in
                        self?.sendReceipt(publisher: publisher, 
                                          uniqueId: uniqueId,
                                          error: error)
                    }
                } else {
                    rtmSetMetaData(publisherId: publisher, 
                                   valueCmd: valueCmd,
                                   value: value,
                                   filter: filter) {[weak self] error in
                        self?.sendReceipt(publisher: publisher, 
                                          uniqueId: uniqueId,
                                          error: error)
                    }
                }
                return
            }
            err = NSError.auiError("payload is not a map")
        case .remove:
            rtmRemoveMetaData(publisherId: publisher, 
                              valueCmd: valueCmd,
                              filter: filter) {[weak self] error in
                self?.sendReceipt(publisher: publisher, 
                                  uniqueId: uniqueId,
                                  error: error)
            }
        case .clean:
            rtmCleanMetaData(callback: {[weak self] error in
                self?.sendReceipt(publisher: publisher, 
                                  uniqueId: uniqueId,
                                  error: error)
            })
        case .calculate:
            if let value = collectionMessage.payload.data?.toJsonObject() as? [String : Any],
               let data: AUICollectionCalcData = decodeModel(value) {
                rtmCalculateMetaData(publisherId: publisher,
                                     valueCmd: valueCmd,
                                     key: data.key,
                                     value: data.value,
                                     filter: filter) {[weak self] error in
                    self?.sendReceipt(publisher: publisher,
                                      uniqueId: uniqueId,
                                      error: error)
                }
                return
            }
            err = NSError.auiError("payload is not a map")
        }
        
        guard let err = err else {return}
        sendReceipt(publisher: publisher,
                    uniqueId: uniqueId,
                    error: err)
    }
}
