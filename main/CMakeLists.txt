file(GLOB_RECURSE app_sources "*.c")

idf_component_register(
  SRCS ${app_sources}
  PRIV_INCLUDE_DIRS .
  PRIV_REQUIRES
    log
    driver
    esp32-camera
    esp_eth
    esp_netif
    esp_http_server
    lwip
    esp_event
    nvs_flash
    esp_psram
    esp_timer
    esp_driver_ledc
)
