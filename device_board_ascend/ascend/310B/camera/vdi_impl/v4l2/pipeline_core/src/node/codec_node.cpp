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

#include "codec_node.h"
#include "camera_dump.h"
#include <securec.h>

extern "C" {
    #include <jpeglib.h>
    #include <transupp.h>
    #include "libavutil/frame.h"
    #include "libavcodec/avcodec.h"
    #include "libswscale/swscale.h"
    #include "libavformat/avformat.h"
    #include "libavutil/imgutils.h"
}

namespace OHOS::Camera {
uint32_t CodecNode::previewWidth_ = 1280;
uint32_t CodecNode::previewHeight_ = 720;
const unsigned long long TIME_CONVERSION_NS_S = 1000000000ULL; /* ns to s */

CodecNode::CodecNode(const std::string& name, const std::string& type, const std::string &cameraId)
    : NodeBase(name, type, cameraId)
{
    CAMERA_LOGV("%{public}s enter, type(%{public}s)\n", name_.c_str(), type_.c_str());
    jpegRotation_ = static_cast<uint32_t>(JXFORM_ROT_270);
    jpegQuality_ = 100; // 100:jpeg quality

    deviceManager_ = IDeviceManager::GetInstance();
    if (deviceManager_ == nullptr) {
        CAMERA_LOGE("get device manager failed.");
    }
    CameraId myCameraId = CAMERA_FIRST;
    sensorController_ = std::static_pointer_cast<SensorController>
        (deviceManager_->GetController(myCameraId, DM_M_SENSOR, DM_C_SENSOR));
    if (sensorController_ == nullptr) {
        CAMERA_LOGE("get device controller failed");
    }
}

CodecNode::~CodecNode()
{
    CAMERA_LOGI("~CodecNode Node exit.");
    if (_encoder != nullptr) {
        CAMERA_LOGI("CodecNode::Stop hal_mpp_ctx_delete\n");
        x264_picture_clean(&pic_in);
        x264_encoder_close(_encoder);
	    _encoder = nullptr;
    }
}  

RetCode CodecNode::Start(const int32_t streamId)
{
    CAMERA_LOGI("CodecNode::Start streamId = %{public}d\n", streamId);
    return RC_OK;
}

RetCode CodecNode::Stop(const int32_t streamId)
{
    CAMERA_LOGI("CodecNode::Stop streamId = %{public}d\n", streamId);
    if (_encoder != nullptr) {
        CAMERA_LOGI("CodecNode::Stop hal_mpp_ctx_delete\n");
        x264_picture_clean(&pic_in);
        x264_encoder_close(_encoder);
	    _encoder = nullptr;
    }
    return RC_OK;
}

RetCode CodecNode::Flush(const int32_t streamId)
{
    CAMERA_LOGI("CodecNode::Flush streamId = %{public}d\n", streamId);
    return RC_OK;
}

static void RotJpegImg(
    const unsigned char *inputImg, size_t inputSize, unsigned char **outImg, size_t *outSize, JXFORM_CODE rotDegrees)
{
    struct jpeg_decompress_struct inputInfo;
    struct jpeg_error_mgr jerrIn;
    struct jpeg_compress_struct outInfo;
    struct jpeg_error_mgr jerrOut;
    jvirt_barray_ptr *src_coef_arrays;
    jvirt_barray_ptr *dst_coef_arrays;

    inputInfo.err = jpeg_std_error(&jerrIn);
    jpeg_create_decompress(&inputInfo);
    outInfo.err = jpeg_std_error(&jerrOut);
    jpeg_create_compress(&outInfo);
    jpeg_mem_src(&inputInfo, inputImg, inputSize);
    jpeg_mem_dest(&outInfo, outImg, (unsigned long *)outSize);

    JCOPY_OPTION copyoption;
    jpeg_transform_info transformoption;
    transformoption.transform = rotDegrees;
    transformoption.perfect = TRUE;
    transformoption.trim = FALSE;
    transformoption.force_grayscale = FALSE;
    transformoption.crop = FALSE;

    jcopy_markers_setup(&inputInfo, copyoption);
    (void)jpeg_read_header(&inputInfo, TRUE);

    if (!jtransform_request_workspace(&inputInfo, &transformoption)) {
        CAMERA_LOGE("%s: transformation is not perfect", __func__);
        return;
    }

    src_coef_arrays = jpeg_read_coefficients(&inputInfo);
    jpeg_copy_critical_parameters(&inputInfo, &outInfo);
    dst_coef_arrays = jtransform_adjust_parameters(&inputInfo, &outInfo, src_coef_arrays, &transformoption);
    jpeg_write_coefficients(&outInfo, dst_coef_arrays);
    jcopy_markers_execute(&inputInfo, &outInfo, copyoption);
    jtransform_execute_transformation(&inputInfo, &outInfo, src_coef_arrays, &transformoption);

    jpeg_finish_compress(&outInfo);
    jpeg_destroy_compress(&outInfo);
    (void)jpeg_finish_decompress(&inputInfo);
    jpeg_destroy_decompress(&inputInfo);
}

RetCode CodecNode::ConfigJpegOrientation(common_metadata_header_t* data)
{
    camera_metadata_item_t entry;
    int ret = FindCameraMetadataItem(data, OHOS_JPEG_ORIENTATION, &entry);
    if (ret != 0 || entry.data.i32 == nullptr) {
        CAMERA_LOGI("tag OHOS_JPEG_ORIENTATION not found");
        return RC_OK;
    }

    JXFORM_CODE jxRotation = JXFORM_ROT_270;
    int32_t ohosRotation = *entry.data.i32;
    if (ohosRotation == OHOS_CAMERA_JPEG_ROTATION_0) {
        jxRotation = JXFORM_NONE;
    } else if (ohosRotation == OHOS_CAMERA_JPEG_ROTATION_90) {
        jxRotation = JXFORM_ROT_90;
    } else if (ohosRotation == OHOS_CAMERA_JPEG_ROTATION_180) {
        jxRotation = JXFORM_ROT_180;
    } else {
        jxRotation = JXFORM_NONE;
    }
    jpegRotation_ = static_cast<uint32_t>(jxRotation);
    return RC_OK;
}

RetCode CodecNode::ConfigJpegQuality(common_metadata_header_t* data)
{
    camera_metadata_item_t entry;
    int ret = FindCameraMetadataItem(data, OHOS_JPEG_QUALITY, &entry);
    if (ret != 0) {
        CAMERA_LOGI("tag OHOS_JPEG_QUALITY not found");
        return RC_OK;
    }

    const int HIGH_QUALITY_JPEG = 100;
    const int MIDDLE_QUALITY_JPEG = 95;
    const int LOW_QUALITY_JPEG = 85;

    CAMERA_LOGI("OHOS_JPEG_QUALITY is = %{public}d", static_cast<int>(entry.data.u8[0]));
    if (*entry.data.i32 == OHOS_CAMERA_JPEG_LEVEL_LOW) {
        jpegQuality_ = LOW_QUALITY_JPEG;
    } else if (*entry.data.i32 == OHOS_CAMERA_JPEG_LEVEL_MIDDLE) {
        jpegQuality_ = MIDDLE_QUALITY_JPEG;
    } else if (*entry.data.i32 == OHOS_CAMERA_JPEG_LEVEL_HIGH) {
        jpegQuality_ = HIGH_QUALITY_JPEG;
    } else {
        jpegQuality_ = HIGH_QUALITY_JPEG;
    }
    return RC_OK;
}

RetCode CodecNode::Config(const int32_t streamId, const CaptureMeta& meta)
{
    if (meta == nullptr) {
        CAMERA_LOGE("meta is nullptr");
        return RC_ERROR;
    }

    common_metadata_header_t* data = meta->get();
    if (data == nullptr) {
        CAMERA_LOGE("data is nullptr");
        return RC_ERROR;
    }

    RetCode rc = ConfigJpegOrientation(data);

    rc = ConfigJpegQuality(data);
    return rc;
}

void CodecNode::encodeJpegToMemory(unsigned char* image, int width, int height,
    const char* comment, unsigned long* jpegSize, unsigned char** jpegBuf)
{
    struct jpeg_compress_struct cInfo;
    struct jpeg_error_mgr jErr;
    JSAMPROW row_pointer[1];
    int row_stride = 0;
    constexpr uint32_t colorMap = 3;
    constexpr uint32_t pixelsThick = 3;

    cInfo.err = jpeg_std_error(&jErr);

    jpeg_create_compress(&cInfo);
    cInfo.image_width = width;
    cInfo.image_height = height;
    cInfo.input_components = colorMap;
    cInfo.in_color_space = JCS_RGB;

    jpeg_set_defaults(&cInfo);
    CAMERA_LOGE("CodecNode::encodeJpegToMemory jpegQuality_ is = %{public}d", jpegQuality_);
    jpeg_set_quality(&cInfo, jpegQuality_, TRUE);
    jpeg_mem_dest(&cInfo, jpegBuf, jpegSize);
    jpeg_start_compress(&cInfo, TRUE);

    if (comment) {
        jpeg_write_marker(&cInfo, JPEG_COM, (const JOCTET*)comment, strlen(comment));
    }

    row_stride = width;
    while (cInfo.next_scanline < cInfo.image_height) {
        row_pointer[0] = &image[cInfo.next_scanline * row_stride * pixelsThick];
        jpeg_write_scanlines(&cInfo, row_pointer, 1);
    }

    jpeg_finish_compress(&cInfo);
    jpeg_destroy_compress(&cInfo);

    size_t rotJpgSize = 0;
    unsigned char* rotJpgBuf = nullptr;
    /* rotate image */
    RotJpegImg(*jpegBuf, *jpegSize, &rotJpgBuf, &rotJpgSize, static_cast<JXFORM_CODE>(jpegRotation_));
    if (rotJpgBuf != nullptr && rotJpgSize != 0) {
        free(*jpegBuf);
        *jpegBuf = rotJpgBuf;
        *jpegSize = rotJpgSize;
    }
}

static int findStartCode(unsigned char *data, size_t dataSz)
{
    constexpr uint32_t dataSize = 4;
    constexpr uint32_t dataBit2 = 2;
    constexpr uint32_t dataBit3 = 3;

    if (data == nullptr) {
        CAMERA_LOGI("CodecNode::findStartCode paramater == nullptr");
        return -1;
    }

    if ((dataSz > dataSize) && (data[0] == 0) && (data[1] == 0) && \
        (data[dataBit2] == 0) && (data[dataBit3] == 1)) {
        return 4; // 4:start node
    }

    return -1;
}

static constexpr uint32_t nalBit = 0x1F;

void CodecNode::SerchIFps(unsigned char* buf, size_t bufSize, std::shared_ptr<IBuffer>& buffer)
{
    size_t nalType = 0;
    size_t idx = 0;
    size_t size = bufSize;
    constexpr uint32_t nalTypeValue = 0x05;

    if (buffer == nullptr || buf == nullptr) {
        CAMERA_LOGI("CodecNode::SerchIFps paramater == nullptr");
        return;
    }

    for (int i = 0; i < bufSize; i++) {
        int ret = findStartCode(buf + idx, size);
        if (ret == -1) {
            idx += 1;
            size -= 1;
        } else {
            nalType = ((buf[idx + ret]) & nalBit);
            CAMERA_LOGI("CodecNode::SerchIFps nalu == 0x%{public}x buf == 0x%{public}x \n", nalType, buf[idx + ret]);
            if (nalType == nalTypeValue) {
                buffer->SetEsKeyFrame(1);
                CAMERA_LOGI("CodecNode::SerchIFps SetEsKeyFrame == 1 nalu == 0x%{public}x\n", nalType);
                break;
            } else {
                idx += ret;
                size -= ret;
            }
        }

        if (idx >= bufSize) {
            break;
        }
    }

    if (idx >= bufSize) {
        buffer->SetEsKeyFrame(0);
        CAMERA_LOGI("CodecNode::SerchIFps SetEsKeyFrame == 0 nalu == 0x%{public}x idx = %{public}d\n",
            nalType, idx);
    }
}

void CodecNode::Yuv422ToH264(std::shared_ptr<IBuffer>& buffer)
{
    if (buffer == nullptr) {
        CAMERA_LOGI("CodecNode::Yuv422ToH264 buffer == nullptr");
        buffer->SetEsFrameSize(0);
        return;
    }

    uint32_t width = buffer->GetWidth();
    uint32_t height = buffer->GetHeight();
     x264_picture_t  pic_out;

    int ret = 0;
    x264_nal_t *nalValue = nullptr;
    int i_nal = 0;
    {
        std::unique_lock<std::mutex> l(hal_x264);
        if (_encoder == nullptr)
        {
            x264_param_default(&param);
            param.i_frame_reference = 1;
            param.i_scenecut_threshold = 0;
            param.b_deblocking_filter = 0;
            param.b_cabac = 0;
            param.i_bframe = 0;
            param.analyse.intra = 0;
            param.analyse.inter = 0;
            param.analyse.b_transform_8x8 = 0;
            param.analyse.i_me_method = X264_ME_DIA;
            param.analyse.i_subpel_refine = 0;
            param.rc.i_aq_mode = 0;
            param.analyse.b_mixed_references = 0;
            param.analyse.i_trellis = 0;
            param.i_bframe_adaptive = X264_B_ADAPT_NONE;
            param.rc.b_mb_tree = 0;
            param.analyse.i_weighted_pred = X264_WEIGHTP_NONE;
            param.analyse.b_weighted_bipred = 0;
            param.rc.i_lookahead = 0;

            param.i_width = width;
            param.i_height = height;
            _encoder = x264_encoder_open(&param);
            if (!_encoder)
            {
                return;
            }

            x264_picture_alloc(&pic_in, X264_CSP_I420, param.i_width, param.i_height);

            pic_in.img.i_csp = X264_CSP_I420;
            pic_in.img.i_plane = 3;
        }
	
        uint8_t *y = pic_in.img.plane[0];
        uint8_t *u = pic_in.img.plane[1];
        uint8_t *v = pic_in.img.plane[2];
	    int i = 0 , j = 0 ;
        int widthStep422 = param.i_width * 2;

        v4l2_buf_type bufType = sensorController_->GetSensorBufferType();
        if (bufType == V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE)
        {
            uint8_t *y_src = (uint8_t *)buffer->GetVirAddress();
            uint8_t *uv_src = (uint8_t *)buffer->GetVirAddress() + width * height;

            uint8_t *y_dst = y;
            uint8_t *u_dst = y + width * height;
            uint8_t *v_dst = u_dst + (width * height) / 4;

            // Copy Y plane
            memcpy(y_dst, y_src, width * height);

            // Split UV plane
            for (int i = 0; i < (width * height) / 2; i += 2)
            {
                *u_dst++ = uv_src[i];
                *v_dst++ = uv_src[i + 1];
            }
        } else {
            for (i = 0; i < param.i_height; i += 2)
            {
                uint8_t *p422 = (uint8_t *)buffer->GetVirAddress() + i * widthStep422;
                for (j = 0; j < widthStep422; j += 4)
                {
                    *(y++) = p422[j];
                    *(u++) = p422[j + 1];
                    *(y++) = p422[j + 2];
                }
                p422 += widthStep422;
                for (j = 0; j < widthStep422; j += 4)
                {
                    *(y++) = p422[j];
                    *(v++) = p422[j + 3];
                    *(y++) = p422[j + 2];
                }
            }
        }

        pic_in.i_type = X264_TYPE_AUTO;


        int ret = x264_encoder_encode(_encoder, &nalValue, &i_nal, &pic_in, &pic_out);
        if (ret < 0)
        {
            buffer->SetEsFrameSize(0);
            x264_picture_clean(&pic_in);
            x264_encoder_close(_encoder);
            _encoder = nullptr;
            return;
        }
        pic_in.i_pts = i_pts++;
    }

    int len = 0;
    int i = 0;
    struct timespec ts = {};
    int64_t timestamp = 0;
    if (i_nal > 0)
    {
        for (i = 0; i < i_nal; i++)
        {
            int ret = memcpy_s((uint8_t*)buffer->GetVirAddress() + len, buffer->GetSize() - len, (nalValue + i)->p_payload, (nalValue + i)->i_payload);
            len += (nalValue + i)->i_payload;
        }	
        SerchIFps((unsigned char *)buffer->GetVirAddress(), len, buffer);
        buffer->SetEsFrameSize(len);
        clock_gettime(CLOCK_MONOTONIC, &ts);
        timestamp = ts.tv_nsec + ts.tv_sec * TIME_CONVERSION_NS_S;
        buffer->SetEsTimestamp(timestamp);
    } else {
        buffer->SetBufferStatus(CAMERA_BUFFER_STATUS_INVALID);
    }
    CAMERA_LOGI("ForkNode::ForkBuffers H264 size = %{public}d timestamp = %{public}lld\n",
        len, timestamp);
    return;
}

void CodecNode::Yuv422ToRGBA8888(std::shared_ptr<IBuffer>& buffer)
{
    if (buffer == nullptr) {
        CAMERA_LOGI("CodecNode::Yuv422ToRGBA8888 buffer == nullptr");
        return;
    }
    AVPixelFormat myFormat = AV_PIX_FMT_YUYV422;
    v4l2_buf_type bufType = sensorController_->GetSensorBufferType();
    
    if(bufType == V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE)
    {
        myFormat = AV_PIX_FMT_NV21;
    }

    AVFrame *pFrameRGBA = nullptr;
    AVFrame *pFrame = nullptr;
    pFrame = av_frame_alloc();
    pFrameRGBA = av_frame_alloc();

    void* temp = malloc(buffer->GetSize());
    if (temp == nullptr) {
        CAMERA_LOGI("CodecNode::Yuv422ToRGBA8888 malloc buffer == nullptr");
        return;
    }
    int ret = memcpy_s((uint8_t *)temp, buffer->GetSize(), (uint8_t *)buffer->GetVirAddress(), buffer->GetSize());
    if (ret == 0) {
        buffer->SetEsFrameSize(buffer->GetSize());
    } else {
        printf("memcpy_s failed!\n");
        buffer->SetEsFrameSize(0);
    }

    av_image_fill_arrays(pFrame->data, pFrame->linesize, (uint8_t *)temp,
        myFormat, previewWidth_, previewHeight_, 1);
    av_image_fill_arrays(pFrameRGBA->data, pFrameRGBA->linesize, (uint8_t *)buffer->GetVirAddress(),
        AV_PIX_FMT_RGBA, previewWidth_, previewHeight_, 1);

    struct SwsContext* imgCtx = sws_getContext(previewWidth_, previewHeight_, myFormat, previewWidth_,
                                               previewHeight_, AV_PIX_FMT_RGBA, SWS_BILINEAR, 0, 0, 0);

    if (imgCtx != nullptr) {
        sws_scale(imgCtx, pFrame->data, pFrame->linesize, 0, previewHeight_,
                  pFrameRGBA->data, pFrameRGBA->linesize);
        if (imgCtx) {
            sws_freeContext(imgCtx);
            imgCtx = nullptr;
        }
    } else {
        sws_freeContext(imgCtx);
        imgCtx = nullptr;
    }
    av_frame_free(&pFrame);
    av_frame_free(&pFrameRGBA);
    free(temp);
}

void CodecNode::Yuv422ToJpeg(std::shared_ptr<IBuffer>& buffer)
{
    constexpr uint32_t RGB24Width = 3;

    if (buffer == nullptr) {
        CAMERA_LOGI("CodecNode::Yuv422ToJpeg buffer == nullptr");
        return;
    }
    AVPixelFormat myFormat = AV_PIX_FMT_YUYV422;
    v4l2_buf_type bufType = sensorController_->GetSensorBufferType();
    
    if(bufType == V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE)
    {
        myFormat = AV_PIX_FMT_NV21;
    }

    uint8_t* jBuf = nullptr;
    unsigned long jpegSize = 0;
    uint32_t tempSize = (previewWidth_ * previewHeight_ * RGB24Width);
    void* temp = malloc(tempSize);
    if (temp == nullptr) {
        CAMERA_LOGI("CodecNode::Yuv422ToJpeg malloc buffer == nullptr");
        return;
    }

    AVFrame *m_pFrameRGB = nullptr;
    AVFrame *pFrameYUV = nullptr;
    pFrameYUV = av_frame_alloc();
    m_pFrameRGB = av_frame_alloc();

    av_image_fill_arrays(pFrameYUV->data, pFrameYUV->linesize, (uint8_t *)buffer->GetVirAddress(),
        myFormat, previewWidth_, previewHeight_, 1);
    av_image_fill_arrays(m_pFrameRGB->data, m_pFrameRGB->linesize, (uint8_t *)temp,
        AV_PIX_FMT_RGB24, previewWidth_, previewHeight_, 1);
    
    struct SwsContext* imgCtx = sws_getContext(previewWidth_, previewHeight_, myFormat, previewWidth_,
                                               previewHeight_, AV_PIX_FMT_RGB24, SWS_BILINEAR, 0, 0, 0);

    sws_scale(imgCtx, pFrameYUV->data, pFrameYUV->linesize, 0, previewHeight_,
              m_pFrameRGB->data, m_pFrameRGB->linesize);
    sws_freeContext(imgCtx);
    imgCtx = nullptr;
    av_frame_free(&pFrameYUV);
    av_frame_free(&m_pFrameRGB);
    encodeJpegToMemory((uint8_t *)temp, previewWidth_, previewHeight_, nullptr, &jpegSize, &jBuf);

    int ret = memcpy_s((uint8_t*)buffer->GetVirAddress(), buffer->GetSize(), jBuf, jpegSize);
    if (ret == 0) {
        buffer->SetEsFrameSize(jpegSize);
    } else {
        CAMERA_LOGI("memcpy_s failed, ret = %{public}d\n", ret);
        buffer->SetEsFrameSize(0);
    }

    free(jBuf);
    free(temp);
    CAMERA_LOGE("CodecNode::Yuv422ToJpeg jpegSize = %{public}d\n", jpegSize);
}

void CodecNode::DeliverBuffer(std::shared_ptr<IBuffer>& buffer)
{
    if (buffer == nullptr) {
        CAMERA_LOGE("CodecNode::DeliverBuffer frameSpec is null");
        return;
    }

    if (buffer->GetBufferStatus() != CAMERA_BUFFER_STATUS_OK) {
        CAMERA_LOGE("CodecNode::DeliverBuffer BufferStatus() != CAMERA_BUFFER_STATUS_OK");
        return NodeBase::DeliverBuffer(buffer);
    }

    int32_t id = buffer->GetStreamId();
    CAMERA_LOGI("CodecNode::DeliverBuffer, streamId[%{public}d], index[%{public}d],\
format = %{public}d, encode =  %{public}d",
        id, buffer->GetIndex(), buffer->GetFormat(), buffer->GetEncodeType());

    int32_t encodeType = buffer->GetEncodeType();
    if (encodeType == ENCODE_TYPE_JPEG) {
        Yuv422ToJpeg(buffer);
    } else if (encodeType == ENCODE_TYPE_H264) {
        Yuv422ToH264(buffer);
    } else if (encodeType == ENCODE_TYPE_NULL) {
        Yuv422ToRGBA8888(buffer);
    } else {
        Yuv422ToRGBA8888(buffer);
        CAMERA_LOGI("CodecNode::DeliverBuffer StreamId %{public}d error, unknow encodeType, %{public}d",
            id, encodeType);
    }

    CameraDumper& dumper = CameraDumper::GetInstance();
    dumper.DumpBuffer("board_RKCodecNode", ENABLE_RKCODEC_NODE_CONVERTED, buffer);

    return NodeBase::DeliverBuffer(buffer);
}

RetCode CodecNode::Capture(const int32_t streamId, const int32_t captureId)
{
    CAMERA_LOGV("CodecNode::Capture");
    return RC_OK;
}

RetCode CodecNode::CancelCapture(const int32_t streamId)
{   
    CAMERA_LOGI("CodecNode::CancelCapture streamid = %{public}d", streamId);
    std::unique_lock<std::mutex> l(hal_x264);
    if (_encoder != nullptr) {
        CAMERA_LOGI("CodecNode::Stop hal_mpp_ctx_delete\n");
        x264_picture_clean(&pic_in);
        x264_encoder_close(_encoder);
        _encoder = nullptr;
    }
    return RC_OK;
}

REGISTERNODE(CodecNode, {"Codec"})
} // namespace OHOS::Camera
