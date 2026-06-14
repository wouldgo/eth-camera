#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <esp_log.h>

#include "leds.h"

#define MORSE_LED   GPIO_NUM_33
#define FLED        GPIO_NUM_4

#define BLINK_TIME 120   // ms, = 1 morse time unit
typedef struct {
    char c;
    const char *morse;
} morse_t;

static const morse_t morse_table[] = {
  {'A', ".-"},    {'B', "-..."},  {'C', "-.-."}, {'D', "-.."},
  {'E', "."},     {'F', "..-."},  {'G', "--."},  {'H', "...."},
  {'I', ".."},    {'J', ".---"},  {'K', "-.-"},  {'L', ".-.."},
  {'M', "--"},    {'N', "-."},    {'O', "---"},  {'P', ".--."},
  {'Q', "--.-"},  {'R', ".-."},   {'S', "..."},  {'T', "-"},
  {'U', "..-"},   {'V', "...-"},  {'W', ".--"},  {'X', "-..-"},
  {'Y', "-.--"},  {'Z', "--.."},
  {'0', "-----"}, {'1', ".----"}, {'2', "..---"},{'3', "...--"},
  {'4', "....-"}, {'5', "....."}, {'6', "-...."},{'7', "--..."},
  {'8', "---.."}, {'9', "----."},
  {'_', "..--.-"},
  {' ', " "}  // special case for word gap
};

static const char* morse_lookup(char c) {
  if (c >= 'a' && c <= 'z') c -= 32;  // to uppercase

  for (size_t i = 0; i < sizeof(morse_table)/sizeof(morse_t); i++) {
    if (morse_table[i].c == c) {
      return morse_table[i].morse;
    }
  }
  return NULL;
}

typedef struct {
  const char* message;
} led_event_t;
static QueueHandle_t led_queue;

static esp_err_t set_morse_led(bool on) {
  return gpio_set_level(MORSE_LED, on ? 0 : 1);
}
static void morse_blink_symbol(char s) {
  set_morse_led(true);

  if (s == '.')
    vTaskDelay(pdMS_TO_TICKS(BLINK_TIME));
  else if (s == '-')
    vTaskDelay(pdMS_TO_TICKS(3 * BLINK_TIME));

  set_morse_led(false);
  vTaskDelay(pdMS_TO_TICKS(BLINK_TIME)); // gap between symbols
}
static void blink_string(const char *text) {
  while (*text) {
    if (*text == ' ') {
      vTaskDelay(pdMS_TO_TICKS(7 * BLINK_TIME));
      text++;
      continue;
    }

    const char *code = morse_lookup(*text);
    if (code) {
      while (*code) {
        morse_blink_symbol(*code++);
      }
      vTaskDelay(pdMS_TO_TICKS(2 * BLINK_TIME)); // letter gap
    }
    text++;
  }
}
static void ping_led_task(void *arg) {
  led_event_t evt;

  while (xQueueReceive(led_queue, &evt, portMAX_DELAY)) {
    blink_string(evt.message);
  }
}

static const char *TAG = "leds";
static gpio_config_t io_conf = {
  .mode = GPIO_MODE_OUTPUT,
  .pin_bit_mask = (1ULL << MORSE_LED) | (1ULL << FLED),
  .pull_down_en = 0,
  .pull_up_en = 0,
  .intr_type = GPIO_INTR_DISABLE,
};

esp_err_t leds_init(void) {
  ESP_LOGI(TAG, "initialize leds");
  esp_err_t ret = gpio_config(&io_conf);
  if (ret != ESP_OK) {
    return ret;
  }

  ret = gpio_set_level(FLED, 0);
  if (ret != ESP_OK) {
    return ret;
  }
  ret = gpio_set_level(MORSE_LED, 1);
  if (ret != ESP_OK) {
    return ret;
  }

  led_queue = xQueueCreate(8, sizeof(led_event_t));
  xTaskCreate(ping_led_task, "led_queue_task", 2048, NULL, 4, NULL);

  return ESP_OK;
}

esp_err_t set_flash_led(bool on) {
  return gpio_set_level(FLED, on ? 1 : 0);
}

void enqueue_message(const char* message) {
  led_event_t evt = {
    .message = message,
  };
  xQueueSend(led_queue, &evt, 0);
}
