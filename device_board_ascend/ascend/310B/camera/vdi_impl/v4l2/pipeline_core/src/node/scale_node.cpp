/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *     http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "scale_node.h"
//#include "node_utils.h"
#include <securec.h>
#include "cstdint"
#include "memory"
namespace OHOS::Camera {
ScaleNode::ScaleNode(const std::string& name, const std::string& type, const std::string &cameraId)
    : NodeBase(name, type, cameraId)
{
    CAMERA_LOGV("%{public}s enter, type(%{public}s)\n", name_.c_str(), type_.c_str());
}

ScaleNode::~ScaleNode()
{
    CAMERA_LOGI("~ScaleNode Node exit.");
}

RetCode ScaleNode::Start(const int32_t streamId)
{
    CAMERA_LOGI("ScaleNode::Start streamId = %{public}d\n", streamId);
    return RC_OK;
}

RetCode ScaleNode::Stop(const int32_t streamId)
{
    CAMERA_LOGI("ScaleNode::Stop streamId = %{public}d\n", streamId);
    return RC_OK;
}

RetCode ScaleNode::Flush(const int32_t streamId)
{
    CAMERA_LOGI("ScaleNode::Flush streamId = %{public}d\n", streamId);
    return RC_OK;
}

void ScaleNode::DeliverBuffer(std::shared_ptr<IBuffer>& buffer)
{
    if (buffer == nullptr) {
        CAMERA_LOGE("ScaleNode::DeliverBuffer frameSpec is null");
        return;
    }

    if (buffer->GetBufferStatus() != CAMERA_BUFFER_STATUS_OK) {
        CAMERA_LOGE("BufferStatus() != CAMERA_BUFFER_STATUS_OK");
        return NodeBase::DeliverBuffer(buffer);
    }

    int32_t id = buffer->GetStreamId();
    CAMERA_LOGI("ScaleNode::DeliverBuffer, streamId[%{public}d],\
index[%{public}d], %{public}d * %{public}d ==> %{public}d * %{public}d, encodeType = %{public}d",
        buffer->GetStreamId(), buffer->GetIndex(),
        buffer->GetCurWidth(), buffer->GetCurHeight(), buffer->GetWidth(), buffer->GetHeight(),
        buffer->GetEncodeType());

    if (buffer->GetEncodeType() == ENCODE_TYPE_NULL) {
        //NodeUtils::BufferScaleFormatTransform(buffer);
    }
    NodeBase::DeliverBuffer(buffer);
}

RetCode ScaleNode::Capture(const int32_t streamId, const int32_t captureId)
{
    CAMERA_LOGV("ScaleNode::Capture");
    return RC_OK;
}

RetCode ScaleNode::CancelCapture(const int32_t streamId)
{
    CAMERA_LOGI("ScaleNode::CancelCapture streamid = %{public}d", streamId);

    return RC_OK;
}

REGISTERNODE(ScaleNode, {"Scale"})
} // namespace OHOS::Camera
