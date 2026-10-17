#include <esp_event.h>
#include <esp_log.h>

#include <driver/spi_master.h>
#include <driver/gpio.h>

#include <esp_netif.h>
#include <esp_eth.h>
#include <esp_eth_mac.h>
#include <esp_eth_phy.h>
#include <esp_eth_netif_glue.h>

#include <esp_mac.h>

#include "net.h"

/*
* Hardware
* ESP32-CAM AI-Thinker module (changing the CAMERA PINS should work with any other esp32-cam, but I have not tested)
* W5500 Ethernet module
*
* GPI0 to GND and then reset to program
* GPI1 and GPI3 to your TX, RX uart for programming
* You need to disable power to the W5500 in order to program ESP32:
* GPIO2 (CS) is pulled low at reset, so the W5500 is selected and drives MISO.
* MISO is GPIO12, a strapping pin: if it is high at reset the ESP32 selects 1.8 V flash
* and the 3.3 V flash can't be read or written.
*
* ESP32-CAM  -> W5500
* GPIO14     -> SCLK
* GPIO2      -> SCS
* GPIO13     -> MOSI
* GPIO12     -> MISO
* GND        -> GND
*
* ESP32-CAM 3V3 -> W5500 VCC (the W5500 needs 3.3 V, the ESP32 pins are not 5 V tolerant)
*
* Since GPIO2 is used for chip select this should not affect SD card operations
* as SD card is also using HSPI spi interface
*/

#define ETH_SPI_HOST      SPI2_HOST
#define PIN_MISO          GPIO_NUM_12
#define PIN_MOSI          GPIO_NUM_13
#define PIN_SCLK          GPIO_NUM_14
#define PIN_CS            GPIO_NUM_2
#define PIN_INT           -1 // polling mode otherwise W5500 INT pin
#define PIN_RST           -1 // no hwd reset, optional but recommended, therwise W5500 RST pin

static const char *TAG = "eth";
static char hostname[32];
static uint8_t device_mac_addr[6];
static volatile uint8_t ip_last_octet = 0;

static spi_bus_config_t buscfg = {
  .miso_io_num = PIN_MISO,
  .mosi_io_num = PIN_MOSI,
  .sclk_io_num = PIN_SCLK,
  .quadwp_io_num = -1,
  .quadhd_io_num = -1,
  .max_transfer_sz = 4096,
};
static spi_device_interface_config_t devcfg = {
  .command_bits = 16, // Actually it's the address phase in W5500 SPI frame
  .address_bits = 8,  // Actually it's the control phase in W5500 SPI frame
  .mode = 0,
  .clock_speed_hz = 12 * 1000 * 1000,
  .spics_io_num = PIN_CS,
  .queue_size = 20
};

static void on_eth_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data) {
  switch (event_id) {
  case ETHERNET_EVENT_CONNECTED:
    ESP_LOGI(TAG, "Ethernet Link Up");
    break;
  case ETHERNET_EVENT_DISCONNECTED:
    // IP_EVENT_ETH_LOST_IP only fires after CONFIG_ESP_NETIF_IP_LOST_TIMER_INTERVAL,
    // so clear the IP as soon as the link goes down
    ip_last_octet = 0;
    ESP_LOGI(TAG, "Ethernet Link Down");
    break;
  case ETHERNET_EVENT_START:
    ESP_LOGI(TAG, "Ethernet Started");
    break;
  case ETHERNET_EVENT_STOP:
    ESP_LOGI(TAG, "Ethernet Stopped");
    break;
  default:
    break;
  }
}

static void on_ip_event(void *arg, esp_event_base_t event_base, int32_t event_id, void *event_data) {
  if (event_id == IP_EVENT_ETH_GOT_IP) {
    ip_event_got_ip_t *event = (ip_event_got_ip_t *) event_data;
    const esp_netif_ip_info_t *ip_info = &event->ip_info;
    ip_last_octet = esp_ip4_addr4(&ip_info->ip);

    ESP_LOGI(TAG, "Ethernet Got IP Address");
    ESP_LOGI(TAG, "~~~~~~~~~~~");
    ESP_LOGI(TAG, "HOSTNAME: %s", hostname);
    ESP_LOGI(TAG, "IP: " IPSTR, IP2STR(&ip_info->ip));
    ESP_LOGI(TAG, "MASK: " IPSTR, IP2STR(&ip_info->netmask));
    ESP_LOGI(TAG, "GW: " IPSTR, IP2STR(&ip_info->gw));
    ESP_LOGI(TAG, "~~~~~~~~~~~");
  } else if (event_id == IP_EVENT_ETH_LOST_IP) {
    ip_last_octet = 0;
    ESP_LOGW(TAG, "Ethernet Lost IP Address");
  }
}

uint8_t net_ip_last_octet(void) {
  return ip_last_octet;
}

static esp_err_t generate_laa_mac(uint8_t mac[6]) {
  uint8_t base_mac[6];

  esp_err_t err = esp_read_mac(base_mac, ESP_MAC_EFUSE_FACTORY);
  if (err != ESP_OK) {
    return err;
  }
  memcpy(mac, base_mac, 6);

  // Set Local Admin bit (bit 1) and clear multicast bit (bit 0)
  mac[0] = (mac[0] | 0x02) & 0xFE;

  // last byte so ETH MAC differs from WiFi MAC
  mac[5] ^= 0x01;
  return ESP_OK;
}

static esp_err_t generate_hostname(uint8_t mac_addr[6], char *hostname, size_t len) {
  int written = snprintf(hostname, len, "camera-%02X%02X%02X",
                         mac_addr[3], mac_addr[4], mac_addr[5]);

  if (written < 0 || written >= len) {
    return ESP_FAIL;
  }
  return ESP_OK;
}

esp_err_t net_init() {
#if !CONFIG_ETH_SPI_ETHERNET_W5500
  ESP_LOGE(TAG, "net with w5500 is not configured in this firmware");
  return ESP_ERR_INVALID_STATE;
#else
  ESP_ERROR_CHECK(esp_netif_init());
  esp_err_t err = esp_event_loop_create_default();
  if (err != ESP_OK && err != ESP_ERR_INVALID_STATE) {
    ESP_ERROR_CHECK(err);
  }

  esp_netif_config_t cfg = ESP_NETIF_DEFAULT_ETH();
  esp_netif_t *eth_netif = esp_netif_new(&cfg);

  ESP_ERROR_CHECK(eth_netif ? ESP_OK : ESP_ERR_NO_MEM);
  ESP_ERROR_CHECK(esp_event_handler_register(ETH_EVENT, ESP_EVENT_ANY_ID, &on_eth_event, NULL));
  ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_ETH_GOT_IP, &on_ip_event, NULL));
  ESP_ERROR_CHECK(esp_event_handler_register(IP_EVENT, IP_EVENT_ETH_LOST_IP, &on_ip_event, NULL));

  eth_mac_config_t mac_config = ETH_MAC_DEFAULT_CONFIG();
  mac_config.sw_reset_timeout_ms = 100;

  eth_phy_config_t phy_config = ETH_PHY_DEFAULT_CONFIG();
  phy_config.autonego_timeout_ms = 0;
  phy_config.reset_gpio_num = PIN_RST;

  esp_err_t ret = spi_bus_initialize(ETH_SPI_HOST, &buscfg, SPI_DMA_CH_AUTO);
  if (ret == ESP_ERR_INVALID_STATE) {
    ESP_LOGW(TAG, "SPI bus already initialized");
  } else {
    ESP_ERROR_CHECK(ret);
  }

  eth_w5500_config_t w5500_config = ETH_W5500_DEFAULT_CONFIG(ETH_SPI_HOST, &devcfg);
  w5500_config.int_gpio_num = PIN_INT;
  if (w5500_config.int_gpio_num == -1) {
    w5500_config.poll_period_ms = 10;
  }

  esp_eth_mac_t *mac = esp_eth_mac_new_w5500(&w5500_config, &mac_config);
  if (!mac) {
    ESP_LOGE(TAG, "Failed to create mac");
    return ESP_ERR_INVALID_STATE;
  }
  esp_eth_phy_t *phy = esp_eth_phy_new_w5500(&phy_config);
  if (!phy) {
    ESP_LOGE(TAG, "Failed to create phy");
    return ESP_ERR_INVALID_STATE;
  }

  esp_eth_config_t config = ETH_DEFAULT_CONFIG(mac, phy);
  esp_eth_handle_t eth_handle = NULL;

  ESP_ERROR_CHECK(esp_eth_driver_install(&config, &eth_handle));

  ESP_ERROR_CHECK(generate_laa_mac(device_mac_addr));
  ESP_ERROR_CHECK(generate_hostname(device_mac_addr, hostname, sizeof(hostname)));
  ESP_ERROR_CHECK(esp_eth_ioctl(eth_handle, ETH_CMD_S_MAC_ADDR, device_mac_addr));
  ESP_ERROR_CHECK(esp_netif_set_hostname(eth_netif, hostname));

  /* attach Ethernet driver to TCP/IP stack */
  ESP_ERROR_CHECK(esp_netif_attach(eth_netif, esp_eth_new_netif_glue(eth_handle)));
  /* start Ethernet driver state machine */
  ESP_ERROR_CHECK(esp_eth_start(eth_handle));

  return ESP_OK;
#endif
}
