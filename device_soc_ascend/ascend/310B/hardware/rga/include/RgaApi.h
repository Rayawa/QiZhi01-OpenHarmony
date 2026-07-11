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

#include "drmrga.h"
#include "rga.h"

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Compatible with the old version of C interface.The new
 * version of the C interface no longer requires users to
 * initialize rga, so RgaInit and RgaDeInit are just for
 * compatibility with the old C interface, so please do
 * not use ctx, because it is usually a NULL.
 */
#define RgaInit(ctx) ( { \
    int ret = 0; \
    ret = c_AsRgaInit(); \
    c_AsRgaGetContext(ctx); \
    ret; \
})
#define RgaDeInit(ctx) do { \
    (void)(ctx);        /* unused */ \
    c_AsRgaDeInit(); \
} while (0)
#define RgaBlit(...) c_AsRgaBlit(__VA_ARGS__)
#define RgaCollorFill(...) c_AsRgaColorFill(__VA_ARGS__)
#define RgaFlush() c_AsRgaFlush()

int  c_AsRgaInit(void);
void c_AsRgaDeInit(void);
void c_AsRgaGetContext(void **ctx);
int  c_AsRgaBlit(rga_info_t *src, rga_info_t *dst, rga_info_t *src1);
int  c_AsRgaColorFill(rga_info_t *dst);
int  c_AsRgaFlush(void);

int c_AsRgaGetAllocBuffer(bo_t *bo_info, int width, int height, int bpp);
int c_AsRgaGetAllocBufferCache(bo_t *bo_info, int width, int height, int bpp);
int c_AsRgaGetMmap(bo_t *bo_info);
int c_AsRgaUnmap(bo_t *bo_info);
int c_AsRgaFree(bo_t *bo_info);
int c_AsRgaGetBufferFd(bo_t *bo_info, int *fd);

#ifdef __cplusplus
}
#endif

#endif /* #ifndef _ascend_rga_c_h_ */
