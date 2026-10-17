#pragma once

#include <driver/gpio.h>

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t leds_init(void);

#define FLASH_DEFAULT_DUTY_PCT 10  // flash brightness when no duty is given

// flash brightness 0..100 %
esp_err_t set_flash_duty(uint8_t percent);
esp_err_t set_flash_led(bool on);
void enqueue_message(const char* message);

#ifdef __cplusplus
}
#endif
