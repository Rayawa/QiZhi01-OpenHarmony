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

#ifndef HOS_CAMERA_ASCODEC_NODE_H
#define HOS_CAMERA_ASCODEC_NODE_H

#include <vector>
#include <condition_variable>
#include <ctime>
#include <mutex>
#include "x264.h"
#include "device_manager_adapter.h"
#include "utils.h"
#include "camera.h"
#include "source_node.h"
#include "sensor_controller.h"



namespace OHOS::Camera {
class CodecNode : public NodeBase {
public:
    CodecNode(const std::string& name, const std::string& type, const std::string &cameraId);
    ~CodecNode() override;
    RetCode Start(const int32_t streamId) override;
    RetCode Stop(const int32_t streamId) override;
    void DeliverBuffer(std::shared_ptr<IBuffer>& buffer) override;
    virtual RetCode Capture(const int32_t streamId, const int32_t captureId) override;
    RetCode CancelCapture(const int32_t streamId) override;
    RetCode Flush(const int32_t streamId);
    RetCode ConfigJpegOrientation(common_metadata_header_t* data);
    RetCode ConfigJpegQuality(common_metadata_header_t* data);
    RetCode Config(const int32_t streamId, const CaptureMeta& meta) override;
private:
    void encodeJpegToMemory(unsigned char* image, int width, int height,
            const char* comment, unsigned long* jpegSize, unsigned char** jpegBuf);
    void Yuv422ToRGBA8888(std::shared_ptr<IBuffer>& buffer);
    void SerchIFps(unsigned char* buf, size_t bufSize, std::shared_ptr<IBuffer>& buffer);
    void Yuv422ToH264(std::shared_ptr<IBuffer>& buffer);
    void Yuv422ToJpeg(std::shared_ptr<IBuffer>& buffer);
    char *share_mem_init(int order, size_t size);
    static uint32_t                       previewWidth_;
    static uint32_t                       previewHeight_;
    uint32_t jpegRotation_;
    uint32_t jpegQuality_;
    bool isFirst_ = true;
    char *shareBuf_ = NULL; 
    char *subShareBuf_ = NULL;
    std::shared_ptr<SensorController> sensorController_ = nullptr;
    std::shared_ptr<IDeviceManager>     deviceManager_ = nullptr;
    std::mutex hal_x264; 
    x264_t *_encoder = nullptr;
    x264_picture_t pic_in;
    x264_param_t param;
    int i_pts = 0;
};
} // namespace OHOS::Camera
#endif
