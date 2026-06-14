#pragma once

#include <driver/gpio.h>

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t leds_init(void);

esp_err_t set_flash_led(bool on);
void enqueue_message(const char* message);

#ifdef __cplusplus
}
#endif
