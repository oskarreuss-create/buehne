#include "buehne_mpv.h"

#include <mpv/client.h>

#include <stdio.h>
#include <string.h>

mpv_handle *buehne_mpv_handle(buehne_mpv *box);

int buehne_mpv_set(buehne_mpv *box, const char *name, const char *value) {
    mpv_handle *mpv = buehne_mpv_handle(box);
    if (!mpv || !name || !value) return -1;
    return mpv_set_property_string(mpv, name, value);
}

static const mpv_node *map_get(const mpv_node_list *map, const char *key) {
    if (!map || !map->keys) return NULL;
    for (int i = 0; i < map->num; i++) {
        if (map->keys[i] && strcmp(map->keys[i], key) == 0) return &map->values[i];
    }
    return NULL;
}

static void jadd(char *buf, int len, int *used, const char *text) {
    if (!text || *used >= len - 1) return;
    int n = snprintf(buf + *used, (size_t)(len - *used), "%s", text);
    if (n > 0) *used += n;
    if (*used >= len) *used = len - 1;
}

static void jescape(char *buf, int len, int *used, const char *text) {
    jadd(buf, len, used, "\"");
    for (const unsigned char *p = (const unsigned char *)(text ? text : ""); *p && *used < len - 8; p++) {
        char one[8];
        if (*p == '"' || *p == '\\') snprintf(one, sizeof one, "\\%c", *p);
        else if (*p < 0x20) snprintf(one, sizeof one, "\\u%04x", *p);
        else snprintf(one, sizeof one, "%c", *p);
        jadd(buf, len, used, one);
    }
    jadd(buf, len, used, "\"");
}

static void jfield(char *buf, int len, int *used, const mpv_node_list *map, const char *key, int comma) {
    const mpv_node *node = map_get(map, key);
    if (comma) jadd(buf, len, used, ",");
    jadd(buf, len, used, "\"");
    jadd(buf, len, used, key);
    jadd(buf, len, used, "\":");
    if (!node) {
        jadd(buf, len, used, "\"\"");
        return;
    }
    char num[32];
    switch (node->format) {
    case MPV_FORMAT_STRING:
        jescape(buf, len, used, node->u.string);
        break;
    case MPV_FORMAT_FLAG:
        jadd(buf, len, used, node->u.flag ? "true" : "false");
        break;
    case MPV_FORMAT_INT64:
        snprintf(num, sizeof num, "%lld", (long long)node->u.int64);
        jadd(buf, len, used, num);
        break;
    case MPV_FORMAT_DOUBLE:
        snprintf(num, sizeof num, "%g", node->u.double_);
        jadd(buf, len, used, num);
        break;
    default:
        jadd(buf, len, used, "\"\"");
        break;
    }
}

int buehne_mpv_track_json(buehne_mpv *box, char *buf, int len) {
    if (!buf || len < 3) return -1;
    snprintf(buf, (size_t)len, "[]");
    mpv_handle *mpv = buehne_mpv_handle(box);
    if (!mpv) return -1;
    mpv_node node;
    if (mpv_get_property(mpv, "track-list", MPV_FORMAT_NODE, &node) < 0) return -1;
    if (node.format != MPV_FORMAT_NODE_ARRAY || !node.u.list) {
        mpv_free_node_contents(&node);
        return -1;
    }
    int used = 0;
    jadd(buf, len, &used, "[");
    int wrote = 0;
    mpv_node_list *list = node.u.list;
    for (int i = 0; i < list->num; i++) {
        if (list->values[i].format != MPV_FORMAT_NODE_MAP || !list->values[i].u.list) continue;
        if (wrote) jadd(buf, len, &used, ",");
        jadd(buf, len, &used, "{");
        mpv_node_list *map = list->values[i].u.list;
        jfield(buf, len, &used, map, "id", 0);
        jfield(buf, len, &used, map, "type", 1);
        jfield(buf, len, &used, map, "lang", 1);
        jfield(buf, len, &used, map, "title", 1);
        jfield(buf, len, &used, map, "codec", 1);
        jfield(buf, len, &used, map, "selected", 1);
        jadd(buf, len, &used, "}");
        wrote = 1;
    }
    jadd(buf, len, &used, "]");
    buf[used < len ? used : len - 1] = 0;
    mpv_free_node_contents(&node);
    return 0;
}
