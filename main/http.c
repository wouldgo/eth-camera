#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>
#include <esp_log.h>

#include "http.h"
#include "camera.h"
#include "leds.h"

#ifndef MIN
#define MIN(a,b) (((a)<(b))?(a):(b))
#endif

#define TCP_PORT 3000

static const size_t http_max_response_chunk_size = 560;
static SemaphoreHandle_t camera_mutex = NULL;
static const char *TAG = "http";

static httpd_handle_t server = NULL;

static esp_err_t snapshot_handler(httpd_req_t *req) {
#if !ESP_CAMERA_SUPPORTED && !CONFIG_ETH_SPI_ETHERNET_W5500
  ESP_LOGW(TAG, "not supposed to work!");
  return ESP_ERR_INVALID_STATE;
#else
  esp_err_t res = ESP_OK;
  jpeg_image img = {0};
  bool response_started = false;

  if (xSemaphoreTake(camera_mutex, 0) != pdTRUE) {
    ESP_LOGW(TAG, "request rejected: already in use");

    httpd_resp_set_status(req, "503 Service Unavailable");
    httpd_resp_set_type(req, "text/plain");
    httpd_resp_set_hdr(req, "Retry-After", "3");
    httpd_resp_set_hdr(req, "Connection", "close");

    return httpd_resp_send(req, "already in use", HTTPD_RESP_USE_STRLEN);
  }

  ESP_LOGI(TAG, "taking picture...");
  set_flash_led(true);
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

  size_t bytes_remaining = img.fb->len;
  size_t offset = 0;
  ESP_LOGD(TAG, "bytes_remaining: %zu", bytes_remaining);
  ESP_LOGD(TAG, "offset: %zu", offset);
  while (bytes_remaining > 0) {
    ESP_LOGD(TAG, "=============");
    if (httpd_req_to_sockfd(req) < 0) {
      ESP_LOGI(TAG, "client disconnected");
      break;
    }

    size_t chunk_size = MIN(bytes_remaining, http_max_response_chunk_size);
    res = httpd_resp_send_chunk(req,
          (const char *)&img.fb->buf[offset], chunk_size);

    if (res != ESP_OK) {
      ESP_LOGE(TAG, "send failed");
      break;
    }

    if (!response_started) {
      response_started = true;
    }
    offset += chunk_size;
    bytes_remaining -= chunk_size;
    ESP_LOGD(TAG, "chunk_size: %zu", chunk_size);
    ESP_LOGD(TAG, "offset: %zu", offset);
    ESP_LOGD(TAG, "bytes_remaining: %zu", bytes_remaining);
  }

  if (response_started) {
    httpd_resp_send_chunk(req, NULL, 0);
    ESP_LOGI(TAG, "photo sent");
  }

  cleanup:
  if (img.fb) {
    res = camera_release(&img);
    img.fb = NULL;
  }

  xSemaphoreGive(camera_mutex);
  ESP_LOGI(TAG, "camera released");

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

  camera_mutex = xSemaphoreCreateMutex();

  register_routes();
  return ESP_OK;
}


// #define TCP_PORT 3000        // Port your server will listen on
// #define TCP_BACKLOG 5        // Max pending connections

// static void tcp_server_task(void *pvParameters) {
//   int listen_sock = socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
//   if (listen_sock < 0) {
//     ESP_LOGE(TAG, "Unable to create socket: errno %d", errno);
//     vTaskDelete(NULL);
//     return;
//   }

//   struct sockaddr_in server_addr;
//   server_addr.sin_family = AF_INET;
//   server_addr.sin_port = htons(TCP_PORT);
//   server_addr.sin_addr.s_addr = htonl(INADDR_ANY);

//   int err = bind(listen_sock, (struct sockaddr *)&server_addr, sizeof(server_addr));
//   if (err < 0) {
//     ESP_LOGE(TAG, "Socket unable to bind: errno %d", errno);
//     close(listen_sock);
//     vTaskDelete(NULL);
//     return;
//   }

//   err = listen(listen_sock, TCP_BACKLOG);
//   if (err < 0) {
//     ESP_LOGE(TAG, "Error occurred during listen: errno %d", errno);
//     close(listen_sock);
//     vTaskDelete(NULL);
//     return;
//   }

//   ESP_LOGI(TAG, "TCP server listening on port %d", TCP_PORT);

//   while (1) {
//     struct sockaddr_in client_addr;
//     socklen_t client_addr_len = sizeof(client_addr);
//     int client_sock = accept(listen_sock, (struct sockaddr *)&client_addr, &client_addr_len);
//     if (client_sock < 0) {
//       ESP_LOGE(TAG, "Unable to accept connection: errno %d", errno);
//       continue;
//     }

//     ESP_LOGI(TAG, "Client connected");

//     char rx_buffer[128];
//     int len;
//     while ((len = recv(client_sock, rx_buffer, sizeof(rx_buffer) - 1, 0)) > 0) {
//       rx_buffer[len] = 0; // null-terminate string
//       ESP_LOGI(TAG, "Received %d bytes: %s", len, rx_buffer);

//       // Echo back to client
//       send(client_sock, rx_buffer, len, 0);
//     }

//     if (len == 0) {
//       ESP_LOGI(TAG, "Connection closed");
//     } else if (len < 0) {
//       ESP_LOGE(TAG, "recv failed: errno %d", errno);
//     }

//     close(client_sock);
//   }

//   close(listen_sock);
//   vTaskDelete(NULL);
// }

//xTaskCreate(tcp_server_task, "tcp_server", 4096, NULL, 5, NULL);
