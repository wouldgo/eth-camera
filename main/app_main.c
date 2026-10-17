#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include <esp_log.h>

#include "net/net.h"
#include "camera.h"
#include "http.h"
#include "leds.h"

// support IDF 5.x
#ifndef portTICK_RATE_MS
#define portTICK_RATE_MS portTICK_PERIOD_MS
#endif

static const char *TAG = "eth_camera";
static TaskHandle_t booting_time_handle = NULL;
static void booting_time(void *pvParameters) {
  while(true) {
    if (ulTaskNotifyTake(pdTRUE, pdMS_TO_TICKS(100)) > 0) {
      ESP_LOGI(TAG, "boot is ended");
      break;
    }
    set_flash_led(true);

    vTaskDelay(pdMS_TO_TICKS(100));
    set_flash_led(false);
  }
  vTaskDelete(NULL);
}

void app_main(void) {
  ESP_ERROR_CHECK(leds_init());
  ESP_LOGI(TAG, "leds ready");

  xTaskCreate(booting_time, "booting_time", 4096, NULL, 5, &booting_time_handle);

  ESP_ERROR_CHECK(net_init());
  ESP_LOGI(TAG, "net ready");

  ESP_ERROR_CHECK(configure_camera());
  ESP_LOGI(TAG, "camera initialized");

  if (booting_time_handle != NULL) {
    xTaskNotifyGive(booting_time_handle);
    booting_time_handle = NULL;
  }

  ESP_ERROR_CHECK(start_webserver());
  ESP_LOGI(TAG, "camera boot ended correctly");
  char buffer[16];
  while(true) {
    uint8_t ip_octet = net_ip_last_octet();
    snprintf(buffer, sizeof(buffer), "%u", ip_octet);
    enqueue_message(buffer);
    ESP_LOGI(TAG, "alive: ip .%u", ip_octet);
    vTaskDelay(pdMS_TO_TICKS(30 * 1000));
  }
}
