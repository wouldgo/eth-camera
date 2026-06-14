#pragma once

#include <esp_system.h>
#include <esp_camera.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct jpeg_image {
  camera_fb_t* fb;
} jpeg_image;

esp_err_t configure_camera(void);
jpeg_image camera_capture();
esp_err_t camera_release(jpeg_image* img);

#ifdef __cplusplus
}
#endif
