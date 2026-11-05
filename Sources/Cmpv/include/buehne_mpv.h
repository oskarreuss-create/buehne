#ifndef BUEHNE_MPV_H
#define BUEHNE_MPV_H

#include <stdint.h>

typedef struct buehne_mpv buehne_mpv;

buehne_mpv *buehne_mpv_open(const char *path, const char *peak_nits, char *err, int errlen);
buehne_mpv *buehne_mpv_open_ex(const char *path, const char *peak_nits, int silent, char *err, int errlen);
void buehne_mpv_close(buehne_mpv *box);
void buehne_mpv_play(buehne_mpv *box);
void buehne_mpv_pause(buehne_mpv *box);
void buehne_mpv_seek(buehne_mpv *box, double seconds);
void buehne_mpv_ao_reload(buehne_mpv *box);
void buehne_mpv_set_volume(buehne_mpv *box, double volume);
void buehne_mpv_set_rate(buehne_mpv *box, double rate);
double buehne_mpv_get_volume(buehne_mpv *box);
double buehne_mpv_get_rate(buehne_mpv *box);
int buehne_mpv_poll(buehne_mpv *box, double *time, double *duration, int *paused, int *width, int *height, char *err, int errlen);
int buehne_mpv_render_linear(buehne_mpv *box, int width, int height, void *rgba16f, char *err, int errlen);
int buehne_mpv_render_surface(buehne_mpv *box, int width, int height, void **surface, char *err, int errlen);
int buehne_mpv_property(buehne_mpv *box, const char *name, char *buf, int len);
int buehne_mpv_set(buehne_mpv *box, const char *name, const char *value);
int buehne_mpv_track_json(buehne_mpv *box, char *buf, int len);

#endif
