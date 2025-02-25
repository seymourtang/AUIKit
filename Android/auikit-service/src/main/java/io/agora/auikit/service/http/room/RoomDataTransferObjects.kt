package io.agora.auikit.service.http.room

import io.agora.auikit.model.AUIRoomInfo
import io.agora.auikit.service.http.PayloadResp

data class CreateRoomReq(
    val roomId: String,
    val payload: AUIRoomInfo
)
data class CreateRoomResp(
    val roomId: String,
    val roomName: String
)
data class RoomUserReq(
    val roomId: String
)
data class DestroyRoomResp(
    val roomId: String
)
data class RoomReq(
    val channelName: String
)
data class RoomListReq(
    val pageSize: Int,
    val lastCreateTime: Long?
)
data class RoomListResp(
    val pageSize: Int,
    val count: Int,
    val list: List<PayloadResp<AUIRoomInfo>>
){
    fun getRoomList(): List<AUIRoomInfo>{
        val list = mutableListOf<AUIRoomInfo>()
        this.list.forEach {
            list.add(AUIRoomInfo().apply {
                roomId = it.roomId
                roomName = it.payload?.roomName ?: ""
                memberCount = it.payload?.memberCount ?: 0
                owner = it.payload?.owner
                thumbnail = it.payload?.thumbnail ?: ""
                createTime = it.createTime
            })
        }
        return list
    }
}

data class CreateChatRoomReq(
    val roomId : String,
    val userId : String,
    val userName: String,
    val description:String,
    val custom : String
)

data class CreateChatRoomRsp(
    val chatRoomId : String,
)

