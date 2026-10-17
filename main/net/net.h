#pragma once

#include <esp_system.h>

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t net_init();
// last octet of the current IP address, 0 when no IP is assigned
uint8_t net_ip_last_octet(void);

#ifdef __cplusplus
}
#endif
