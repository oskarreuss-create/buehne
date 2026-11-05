#include "buehne_mpv.h"

#include <mpv/client.h>
#include <mpv/render.h>
#include <mpv/render_gl.h>

#include <CoreFoundation/CoreFoundation.h>
#include <CoreVideo/CoreVideo.h>
#include <IOSurface/IOSurface.h>
#include <OpenGL/CGLIOSurface.h>
#include <OpenGL/OpenGL.h>
#include <OpenGL/gl3.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct buehne_mpv {
    mpv_handle *mpv;
    mpv_render_context *render;
    CGLContextObj gl;
    GLuint fbo;
    GLuint texture;
    GLuint scan_fbo;
    GLuint scan_texture;
    IOSurfaceRef surface;
    int tex_w;
    int tex_h;
    int scan_w;
    int scan_h;
    int presented;
    /* Latest values delivered by mpv events. mpv_get_property waits for the core, which is busy during a seek;
       reading it on the UI thread froze the picture, the timer and the slider while the sound went on. */
    double time_pos;
    double duration;
    double speed;
    double ao_volume;
    int64_t dwidth;
    int64_t dheight;
    int pause;
    int tracks_dirty;
};

enum { OBS_TIME = 1, OBS_DURATION, OBS_PAUSE, OBS_DWIDTH, OBS_DHEIGHT, OBS_SPEED, OBS_TRACKS, REPLY_VOLUME };

static void fail(char *err, int errlen, const char *text) {
    if (err && errlen > 0) snprintf(err, (size_t)errlen, "%s", text);
}

static int opt(mpv_handle *mpv, const char *key, const char *value, char *err, int errlen) {
    int rc = mpv_set_option_string(mpv, key, value);
    if (rc < 0) {
        snprintf(err, (size_t)errlen, "%s=%s: %s", key, value, mpv_error_string(rc));
        return rc;
    }
    return 0;
}

static void gl_nop(void) {}

static void *gl_get_proc(void *ctx, const char *name) {
    (void)ctx;
    if (name && strcmp(name, "glFlush") == 0) return (void *)gl_nop;
    CFStringRef symbol = CFStringCreateWithCString(NULL, name, kCFStringEncodingASCII);
    CFBundleRef bundle = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.opengl"));
    void *addr = (bundle && symbol) ? CFBundleGetFunctionPointerForName(bundle, symbol) : NULL;
    if (symbol) CFRelease(symbol);
    return addr;
}

static int make_gl(buehne_mpv *box, char *err, int errlen) {
    CGLPixelFormatAttribute attrs[] = {
        kCGLPFAOpenGLProfile, (CGLPixelFormatAttribute)kCGLOGLPVersion_3_2_Core,
        kCGLPFAAccelerated,
        kCGLPFAColorSize, (CGLPixelFormatAttribute)24,
        kCGLPFAAlphaSize, (CGLPixelFormatAttribute)8,
        0
    };
    CGLPixelFormatObj format = NULL;
    GLint count = 0;
    if (CGLChoosePixelFormat(attrs, &format, &count) != kCGLNoError || !format) {
        fail(err, errlen, "CGL pixel format failed");
        return -1;
    }
    CGLContextObj context = NULL;
    if (CGLCreateContext(format, NULL, &context) != kCGLNoError || !context) {
        CGLReleasePixelFormat(format);
        fail(err, errlen, "CGL context failed");
        return -1;
    }
    CGLReleasePixelFormat(format);
    if (CGLSetCurrentContext(context) != kCGLNoError) {
        CGLReleaseContext(context);
        fail(err, errlen, "CGL make current failed");
        return -1;
    }
    box->gl = context;
    return 0;
}

static int make_render(buehne_mpv *box, char *err, int errlen) {
    mpv_opengl_init_params gl_params = {
.get_proc_address = gl_get_proc,
.get_proc_address_ctx = NULL,
}
;
    char *api = MPV_RENDER_API_TYPE_OPENGL;
    mpv_render_param params[] = {
        {MPV_RENDER_PARAM_API_TYPE, api},
        {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl_params},
        {0, NULL},
    };
    int rc = mpv_render_context_create(&box->render, box->mpv, params);
    if (rc < 0) {
        snprintf(err, (size_t)errlen, "gl render: %s", mpv_error_string(rc));
        return rc;
    }
    return 0;
}

buehne_mpv *buehne_mpv_open(const char *path, const char *peak_nits, char *err, int errlen) {
    return buehne_mpv_open_ex(path, peak_nits, 0, err, errlen);
}

buehne_mpv *buehne_mpv_open_ex(const char *path, const char *peak_nits, int silent, char *err, int errlen) {
    mpv_handle *mpv = mpv_create();
    if (!mpv) {
        fail(err, errlen, "mpv_create failed");
        return NULL;
    }
    const char *peak = (peak_nits && peak_nits[0]) ? peak_nits : "1000";
    if (opt(mpv, "config", "no", err, errlen) < 0
        || opt(mpv, "terminal", "no", err, errlen) < 0
        || opt(mpv, "input-default-bindings", "no", err, errlen) < 0
        || opt(mpv, "input-vo-keyboard", "no", err, errlen) < 0
        || opt(mpv, "osc", "no", err, errlen) < 0
        || opt(mpv, "keep-open", "yes", err, errlen) < 0
        || opt(mpv, "hwdec", "videotoolbox", err, errlen) < 0
        || opt(mpv, "vd-lavc-dr", "yes", err, errlen) < 0
        || opt(mpv, "vo", "libmpv", err, errlen) < 0
        || opt(mpv, "icc-profile-auto", "no", err, errlen) < 0
        || opt(mpv, "target-prim", "display-p3", err, errlen) < 0
        || opt(mpv, "target-trc", "linear", err, errlen) < 0
        || opt(mpv, "target-peak", peak, err, errlen) < 0
        || opt(mpv, "tone-mapping", "spline", err, errlen) < 0
        || opt(mpv, "sub-visibility", "yes", err, errlen) < 0
        || opt(mpv, "osd-level", "0", err, errlen) < 0
        || opt(mpv, "blend-subtitles", "yes", err, errlen) < 0
        || opt(mpv, "dither-depth", "no", err, errlen) < 0
        || opt(mpv, "deband", "no", err, errlen) < 0
        || (!silent && opt(mpv, "audio-buffer", "0.02", err, errlen) < 0)
        || (silent && (opt(mpv, "ao", "null", err, errlen) < 0
            || opt(mpv, "aid", "no", err, errlen) < 0
            || opt(mpv, "mute", "yes", err, errlen) < 0
            || opt(mpv, "sid", "no", err, errlen) < 0))) {
        mpv_terminate_destroy(mpv);
        return NULL;
    }
    int rc = mpv_initialize(mpv);
    if (rc < 0) {
        snprintf(err, (size_t)errlen, "initialize: %s", mpv_error_string(rc));
        mpv_terminate_destroy(mpv);
        return NULL;
    }
    buehne_mpv *box = calloc(1, sizeof(*box));
    if (!box) {
        mpv_terminate_destroy(mpv);
        fail(err, errlen, "out of memory");
        return NULL;
    }
    box->mpv = mpv;
    box->speed = 1;
    box->ao_volume = -1;
    box->tracks_dirty = 1;
    mpv_observe_property(mpv, OBS_TIME, "time-pos", MPV_FORMAT_DOUBLE);
    mpv_observe_property(mpv, OBS_DURATION, "duration", MPV_FORMAT_DOUBLE);
    mpv_observe_property(mpv, OBS_PAUSE, "pause", MPV_FORMAT_FLAG);
    mpv_observe_property(mpv, OBS_DWIDTH, "dwidth", MPV_FORMAT_INT64);
    mpv_observe_property(mpv, OBS_DHEIGHT, "dheight", MPV_FORMAT_INT64);
    mpv_observe_property(mpv, OBS_SPEED, "speed", MPV_FORMAT_DOUBLE);
    mpv_observe_property(mpv, OBS_TRACKS, "track-list", MPV_FORMAT_NONE);
    if (make_gl(box, err, errlen) < 0 || make_render(box, err, errlen) < 0) {
        buehne_mpv_close(box);
        return NULL;
    }
    const char *cmd[] = {"loadfile", path, "replace", NULL};
    rc = mpv_command(mpv, cmd);
    if (rc < 0) {
        snprintf(err, (size_t)errlen, "loadfile: %s", mpv_error_string(rc));
        buehne_mpv_close(box);
        return NULL;
    }
    return box;
}

void buehne_mpv_close(buehne_mpv *box) {
    if (!box) return;
    if (box->gl) CGLSetCurrentContext(box->gl);
    if (box->fbo) glDeleteFramebuffers(1, &box->fbo);
    if (box->texture) glDeleteTextures(1, &box->texture);
    if (box->scan_fbo) glDeleteFramebuffers(1, &box->scan_fbo);
    if (box->scan_texture) glDeleteTextures(1, &box->scan_texture);
    if (box->surface) CFRelease(box->surface);
    if (box->render) mpv_render_context_free(box->render);
    if (box->mpv) mpv_terminate_destroy(box->mpv);
    if (box->gl) {
        CGLSetCurrentContext(NULL);
        CGLReleaseContext(box->gl);
    }
    free(box);
}

static void drain(buehne_mpv *box) {
    while (1) {
        mpv_event *event = mpv_wait_event(box->mpv, 0);
        if (!event || event->event_id == MPV_EVENT_NONE) break;
        if (event->event_id == MPV_EVENT_GET_PROPERTY_REPLY && event->reply_userdata == REPLY_VOLUME) {
            mpv_event_property *reply = event->data;
            if (event->error >= 0 && reply && reply->format == MPV_FORMAT_DOUBLE) box->ao_volume = *(double *)reply->data;
            continue;
        }
        if (event->event_id != MPV_EVENT_PROPERTY_CHANGE) continue;
        mpv_event_property *prop = event->data;
        if (!prop) continue;
        if (event->reply_userdata == OBS_TRACKS) {
            box->tracks_dirty = 1;
            continue;
        }
        if (prop->format == MPV_FORMAT_NONE || !prop->data) continue;
        switch (event->reply_userdata) {
        case OBS_TIME: box->time_pos = *(double *)prop->data; break;
        case OBS_DURATION: box->duration = *(double *)prop->data; break;
        case OBS_SPEED: box->speed = *(double *)prop->data; break;
        case OBS_PAUSE: box->pause = *(int *)prop->data; break;
        case OBS_DWIDTH: box->dwidth = *(int64_t *)prop->data; break;
        case OBS_DHEIGHT: box->dheight = *(int64_t *)prop->data; break;
        default: break;
        }
    }
}

void buehne_mpv_play(buehne_mpv *box) {
    if (!box) return;
    int flag = 0;
    box->pause = 0;
    mpv_set_property_async(box->mpv, 0, "pause", MPV_FORMAT_FLAG, &flag);
}

void buehne_mpv_pause(buehne_mpv *box) {
    if (!box) return;
    int flag = 1;
    box->pause = 1;
    mpv_set_property_async(box->mpv, 0, "pause", MPV_FORMAT_FLAG, &flag);
}

void buehne_mpv_seek(buehne_mpv *box, double seconds) {
    if (!box) return;
    char text[64];
    snprintf(text, sizeof text, "%.3f", seconds);
    const char *cmd[] = {"seek", text, "absolute", NULL};
    mpv_command_async(box->mpv, 0, cmd);
}

void buehne_mpv_set_volume(buehne_mpv *box, double volume) {
    if (!box) return;
    double value = volume * 100.0;
    mpv_set_property_async(box->mpv, 0, "ao-volume", MPV_FORMAT_DOUBLE, &value);
}

void buehne_mpv_set_rate(buehne_mpv *box, double rate) {
    if (!box) return;
    mpv_set_property_async(box->mpv, 0, "speed", MPV_FORMAT_DOUBLE, &rate);
}

void buehne_mpv_ao_reload(buehne_mpv *box) {
    if (!box) return;
    const char *cmd[] = {"ao-reload", NULL};
    mpv_command_async(box->mpv, 0, cmd);
}

double buehne_mpv_get_volume(buehne_mpv *box) {
    if (!box) return -1;
    /* Answer from the last request; the fresh value arrives through drain(). Never waits for the core. */
    mpv_get_property_async(box->mpv, REPLY_VOLUME, "ao-volume", MPV_FORMAT_DOUBLE);
    return box->ao_volume < 0 ? -1 : box->ao_volume / 100.0;
}

double buehne_mpv_get_rate(buehne_mpv *box) {
    if (!box) return -1;
    return box->speed;
}

int buehne_mpv_poll(buehne_mpv *box, double *time, double *duration, int *paused, int *width, int *height, char *err, int errlen) {
    if (!box) return -1;
    drain(box);
    if (time) *time = box->time_pos;
    if (duration) *duration = box->duration;
    if (paused) *paused = box->pause;
    if (width) *width = (int)box->dwidth;
    if (height) *height = (int)box->dheight;
    (void)err;
    (void)errlen;
    return 0;
}

int buehne_mpv_take_tracks_dirty(buehne_mpv *box) {
    if (!box) return 0;
    int dirty = box->tracks_dirty;
    box->tracks_dirty = 0;
    return dirty;
}

int buehne_mpv_property(buehne_mpv *box, const char *name, char *buf, int len) {
    if (!box || !name || !buf || len < 2) return -1;
    buf[0] = 0;
    char *value = NULL;
    if (mpv_get_property(box->mpv, name, MPV_FORMAT_STRING, &value) < 0 || !value) return -1;
    snprintf(buf, (size_t)len, "%s", value);
    mpv_free(value);
    return 0;
}

mpv_handle *buehne_mpv_handle(buehne_mpv *box) {
    return box ? box->mpv : NULL;
}

static int ensure_scan(buehne_mpv *box, int width, int height, char *err, int errlen) {
    if (box->scan_texture && box->scan_w == width && box->scan_h == height) return 0;
    if (box->scan_fbo) glDeleteFramebuffers(1, &box->scan_fbo);
    if (box->scan_texture) glDeleteTextures(1, &box->scan_texture);
    box->scan_fbo = 0;
    box->scan_texture = 0;
    glGenTextures(1, &box->scan_texture);
    glBindTexture(GL_TEXTURE_2D, box->scan_texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F, width, height, 0, GL_RGBA, GL_HALF_FLOAT, NULL);
    glGenFramebuffers(1, &box->scan_fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, box->scan_fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, box->scan_texture, 0);
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        snprintf(err, (size_t)errlen, "scan fbo incomplete %u", status);
        return -1;
    }
    box->scan_w = width;
    box->scan_h = height;
    return 0;
}

static int ensure_surface(buehne_mpv *box, int width, int height, char *err, int errlen) {
    if (box->surface && box->tex_w == width && box->tex_h == height) return 0;
    if (box->fbo) glDeleteFramebuffers(1, &box->fbo);
    if (box->texture) glDeleteTextures(1, &box->texture);
    if (box->surface) CFRelease(box->surface);
    box->fbo = 0;
    box->texture = 0;
    box->surface = NULL;
    int bpe = 8;
    size_t row = (size_t)width * 8;
    int format = kCVPixelFormatType_64RGBAHalf;
    CFNumberRef w = CFNumberCreate(NULL, kCFNumberIntType, &width);
    CFNumberRef h = CFNumberCreate(NULL, kCFNumberIntType, &height);
    CFNumberRef bytes = CFNumberCreate(NULL, kCFNumberIntType, &bpe);
    CFNumberRef rowNum = CFNumberCreate(NULL, kCFNumberSInt64Type, &row);
    CFNumberRef pf = CFNumberCreate(NULL, kCFNumberSInt32Type, &format);
    const void *keys[] = {
        kIOSurfaceWidth, kIOSurfaceHeight, kIOSurfaceBytesPerElement, kIOSurfaceBytesPerRow, kIOSurfacePixelFormat
    };
    const void *vals[] = { w, h, bytes, rowNum, pf };
    CFDictionaryRef props = CFDictionaryCreate(NULL, keys, vals, 5, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    IOSurfaceRef surface = props ? IOSurfaceCreate(props) : NULL;
    if (props) CFRelease(props);
    CFRelease(w);
    CFRelease(h);
    CFRelease(bytes);
    CFRelease(rowNum);
    CFRelease(pf);
    if (!surface) {
        fail(err, errlen, "IOSurface failed");
        return -1;
    }
    glGenTextures(1, &box->texture);
    glBindTexture(GL_TEXTURE_RECTANGLE, box->texture);
    CGLError glerr = CGLTexImageIOSurface2D(box->gl, GL_TEXTURE_RECTANGLE, GL_RGBA16F, width, height, GL_RGBA, GL_HALF_FLOAT, surface, 0);
    if (glerr != kCGLNoError) {
        CFRelease(surface);
        snprintf(err, (size_t)errlen, "CGLTexImageIOSurface2D %d", glerr);
        return -1;
    }
    glGenFramebuffers(1, &box->fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, box->fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_RECTANGLE, box->texture, 0);
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        CFRelease(surface);
        snprintf(err, (size_t)errlen, "surface fbo incomplete %u", status);
        return -1;
    }
    box->surface = surface;
    box->tex_w = width;
    box->tex_h = height;
    return 0;
}

static int render_fbo(buehne_mpv *box, int fbo, int width, int height, char *err, int errlen) {
    int flip = 1;
    int block = 0;
    int format = GL_RGBA16F;
    mpv_opengl_fbo target = {
        .fbo = fbo,
        .w = width,
        .h = height,
        .internal_format = format,
    };
    mpv_render_param params[] = {
        {MPV_RENDER_PARAM_OPENGL_FBO, &target},
        {MPV_RENDER_PARAM_FLIP_Y, &flip},
        {MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME, &block},
        {0, NULL},
    };
    int rc = mpv_render_context_render(box->render, params);
    if (rc < 0) snprintf(err, (size_t)errlen, "render: %s", mpv_error_string(rc));
    return rc;
}

int buehne_mpv_render_linear(buehne_mpv *box, int width, int height, void *rgba16f, char *err, int errlen) {
    if (!box || !box->render || !box->gl || !rgba16f || width < 2 || height < 2) return -1;
    if (CGLSetCurrentContext(box->gl) != kCGLNoError) {
        fail(err, errlen, "CGL make current failed");
        return -1;
    }
    if (ensure_scan(box, width, height, err, errlen) < 0) return -1;
    mpv_render_context_update(box->render);
    if (render_fbo(box, (int)box->scan_fbo, width, height, err, errlen) < 0) return -1;
    glBindFramebuffer(GL_READ_FRAMEBUFFER, box->scan_fbo);
    glReadPixels(0, 0, width, height, GL_RGBA, GL_HALF_FLOAT, rgba16f);
    glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
    return 0;
}

int buehne_mpv_render_surface(buehne_mpv *box, int width, int height, void **surface, char *err, int errlen) {
    if (!box || !box->render || !box->gl || !surface || width < 2 || height < 2) return -1;
    if (CGLSetCurrentContext(box->gl) != kCGLNoError) {
        fail(err, errlen, "CGL make current failed");
        return -1;
    }
    uint64_t flags = mpv_render_context_update(box->render);
    if (box->presented && (flags & MPV_RENDER_UPDATE_FRAME) == 0) return 1;
    if (ensure_surface(box, width, height, err, errlen) < 0) return -1;
    if (render_fbo(box, (int)box->fbo, width, height, err, errlen) < 0) return -1;
    glFlush();
    box->presented = 1;
    *surface = (void *)box->surface;
    return 0;
}
