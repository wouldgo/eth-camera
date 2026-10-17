#include <esp_log.h>
#include <esp_timer.h>
#include <stdlib.h>

#include "http.h"
#include "camera.h"
#include "leds.h"

#define TCP_PORT 3000
#define SNAPSHOT_MIN_INTERVAL_US (3 * 1000 * 1000) // min time between two snapshots

static const char *TAG = "http";

static httpd_handle_t server = NULL;
static int64_t last_snapshot_us = 0;

// Reads ?flash=0..100 (flash duty %). Missing key -> FLASH_DEFAULT_DUTY_PCT.
static esp_err_t parse_flash_duty(httpd_req_t *req, uint8_t *duty) {
  *duty = FLASH_DEFAULT_DUTY_PCT;

  char query[32];
  char value[8];
  if (httpd_req_get_url_query_str(req, query, sizeof(query)) != ESP_OK ||
      httpd_query_key_value(query, "flash", value, sizeof(value)) != ESP_OK) {
    return ESP_OK;
  }

  char *end = NULL;
  long parsed = strtol(value, &end, 10);
  if (end == value || *end != '\0' || parsed < 0 || parsed > 100) {
    return ESP_ERR_INVALID_ARG;
  }
  *duty = (uint8_t)parsed;
  return ESP_OK;
}

// esp_http_server handles one request at a time, so concurrent clients are queued
static esp_err_t snapshot_handler(httpd_req_t *req) {
#if !ESP_CAMERA_SUPPORTED || !CONFIG_ETH_SPI_ETHERNET_W5500
  ESP_LOGW(TAG, "not supposed to work!");
  return ESP_ERR_INVALID_STATE;
#else
  esp_err_t res = ESP_OK;
  jpeg_image img = {0};

  uint8_t flash_duty;
  if (parse_flash_duty(req, &flash_duty) != ESP_OK) {
    httpd_resp_set_status(req, "400 Bad Request");
    httpd_resp_set_type(req, "text/plain");
    return httpd_resp_send(req, "flash must be an integer 0..100", HTTPD_RESP_USE_STRLEN);
  }

  int64_t now = esp_timer_get_time();
  if (last_snapshot_us != 0 && now - last_snapshot_us < SNAPSHOT_MIN_INTERVAL_US) {
    ESP_LOGW(TAG, "request rejected: rate limited");

    httpd_resp_set_status(req, "429 Too Many Requests");
    httpd_resp_set_type(req, "text/plain");
    httpd_resp_set_hdr(req, "Retry-After", "3");
    httpd_resp_set_hdr(req, "Connection", "close");

    return httpd_resp_send(req, "too many requests", HTTPD_RESP_USE_STRLEN);
  }
  last_snapshot_us = now;

  ESP_LOGI(TAG, "taking picture... (flash %u%%)", flash_duty);
  set_flash_duty(flash_duty);
  img = camera_capture();
  set_flash_led(false);

  if (!img.fb || !img.fb->buf || img.fb->len == 0) {
    ESP_LOGE(TAG, "capture failed");

    httpd_resp_set_status(req, "503 Service Unavailable");
    httpd_resp_set_type(req, "text/plain");
    res = httpd_resp_send(req, "cannot acquire camera data", HTTPD_RESP_USE_STRLEN);
    goto cleanup;
  }

  ESP_LOGI(TAG, "picture taken. size: %zu bytes", img.fb->len);

  httpd_resp_set_type(req, "image/jpeg");
  httpd_resp_set_hdr(req, "Connection", "close");
  httpd_resp_set_hdr(req, "Cache-Control", "no-store");

  res = httpd_resp_send(req, (const char *)img.fb->buf, img.fb->len);
  if (res != ESP_OK) {
    ESP_LOGE(TAG, "send failed: %s", esp_err_to_name(res));
  } else {
    ESP_LOGI(TAG, "photo sent");
  }

  cleanup:
  if (img.fb) {
    camera_release(&img);
    ESP_LOGI(TAG, "camera released");
  }

  return res;
#endif
}

static esp_err_t register_routes(void) {
  httpd_uri_t uris[] = {
    {
      .uri = "/snapshot",
      .method = HTTP_GET,
      .handler = snapshot_handler,
      .user_ctx = NULL,
    },
  };

  size_t count = sizeof(uris) / sizeof(uris[0]);

  for (size_t i = 0; i < count; i++) {
    ESP_LOGI(TAG, "registering %d handler", i);
    esp_err_t err = httpd_register_uri_handler(server, &uris[i]);
    if (err != ESP_OK) {
      return err;
    }
  }
  return ESP_OK;
}

esp_err_t start_webserver(void) {
  ESP_LOGI(TAG, "initialize httpd webserver");
  if (server != NULL) {
    return ESP_OK;
  }

  httpd_config_t config = HTTPD_DEFAULT_CONFIG();
  config.server_port = TCP_PORT;

  esp_err_t ret = httpd_start(&server, &config);
  if (ret != ESP_OK) {
    ESP_LOGE(TAG, "initialize httpd webserver failed");
    return ret;
  }

  ret = register_routes();
  if (ret != ESP_OK) {
    ESP_LOGE(TAG, "register routes failed");
    httpd_stop(server);
    server = NULL;
    return ret;
  }
  return ESP_OK;
}
