/*
 * Copyright (C) 2025 Ascend Electronics Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef _ascend_rga_c_h_
#define _ascend_rga_c_h_

#include <stdint.h>
#include <sys/types.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <unistd.h>
#include <sys/mman.h>
#include <linux/stddef.h>

#include "drmrga.h"
#include "GrallocOps.h"
#include "RgaUtils.h"
#include "rga.h"

//////////////////////////////////////////////////////////////////////////////////
#include "RgaSingleton.h"

class AscendRga : public RgaSingleton<AscendRga> {
public:

    static inline AscendRga& get()
    {
        return getInstance();
    }

    int         AsRgaInit();
    void        AsRgaDeInit();
    void        AsRgaGetContext(void **ctx);
    int         AsRgaAllocBuffer(int drm_fd /* input */, bo_t *bo_info,
                                    int width, int height, int bpp, int flags);
    int         AsRgaFreeBuffer(int drm_fd /* input */, bo_t *bo_info);
    int         AsRgaGetAllocBuffer(bo_t *bo_info, int width, int height, int bpp);
    int         AsRgaGetAllocBufferExt(bo_t *bo_info, int width, int height, int bpp, int flags);
    int         AsRgaGetAllocBufferCache(bo_t *bo_info, int width, int height, int bpp);
    int         AsRgaGetMmap(bo_t *bo_info);
    int         AsRgaUnmap(bo_t *bo_info);
    int         AsRgaFree(bo_t *bo_info);
    int         AsRgaGetBufferFd(bo_t *bo_info, int *fd);
    int         AsRgaBlit(rga_info *src, rga_info *dst, rga_info *src1);
    int         AsRgaCollorFill(rga_info *dst);
    int         AsRgaCollorPalette(rga_info *src, rga_info *dst, rga_info *lut);
    int         AsRgaFlush();
    void        AsRgaSetLogOnceFlag(int log)
    {
        mLogOnce = log;
    }
    void        AsRgaSetAlwaysLogFlag(bool log)
    {
        mLogAlways = log;
    }
    void        AsRgaLogOutRgaReq(struct rga_req rgaReg);
    int         AsRgaLogOutUserPara(rga_info *rgaInfo);
    inline bool AsRgaIsReady()
    {
        return mSupportRga;
    }

    AscendRga();
    ~AscendRga();
private:
    bool mSupportRga;
    int mLogOnce;
    int mLogAlways;
    void *mContext;

    friend class RgaSingleton<AscendRga>;
};
#endif
