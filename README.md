# eth-camera

An ESP32-CAM project that exposes a camera snapshot over HTTP via a wired Ethernet connection (W5500 SPI module). The device also blinks status messages in Morse code on a dedicated LED.

---

## Overview

The firmware runs on an **ESP32-CAM (AI-Thinker)** board and uses a **W5500** SPI-to-Ethernet chip to get a wired network connection. On boot it:

1. Blinks the flash LED to signal it is starting up.
2. Initialises Ethernet (DHCP) and gets an IP address.
3. Initialises the OV2640 camera sensor.
4. Starts an HTTP server on port **3000**.
5. Periodically blinks a status number in Morse code on GPIO 33.
A single HTTP endpoint is exposed:

```sh
GET http://<device-ip>:3000/snapshot
```

This returns a JPEG image taken at that moment (`image/jpeg`). While the photo is being taken the flash LED (GPIO 4) turns on, then off again. If another request is already in progress the server replies with `503 Service Unavailable`.

---

## Hardware

The PCB design is included in the `hardware/` folder (KiCad 10).

### Bill of Materials

| Ref  | Component               | Notes                                        |
|------|-------------------------|----------------------------------------------|
| U1   | ESP32-CAM (AI-Thinker)  | Main microcontroller + camera module         |
| IC1  | W5500                   | SPI Ethernet controller (via USR-ES1 module) |
| C1   | 470 µF 25 V capacitor   | Bulk decoupling on the 5 V rail              |
| C2   | 100 nF capacitor        | Bypass decoupling                            |
| J1   | 2-pin connector         | 5 V power input                              |
| SW1  | SS-12D00-G slide switch | Power switch                                 |
| SW2  | SS-12D00-G slide switch | Programming mode switch (GPIO0 to GND)       |
| B1   | SKHLAAA010 tact button  | Reset button                                 |
| TP1–3| Test points             | Debug pads                                   |

### Wiring: ESP32-CAM → W5500

| ESP32-CAM GPIO | W5500 pin |
|----------------|-----------|
| GPIO 14        | SCLK      |
| GPIO 13        | MOSI      |
| GPIO 12        | MISO      |
| GPIO 2         | SCS (CS)  |
| GND            | GND       |
| 5 V (external) | VCC       |

> **Note:** GPIO 2 is used for chip-select. This is compatible with the SD card slot since both share the HSPI bus.

### LEDs

| GPIO | Function                           |
|------|------------------------------------|
| 4    | Flash LED — lights during capture  |
| 33   | Morse LED — blinks status messages |

### Programming

To flash the firmware:

1. Set **SW2** to connect GPIO 0 to GND.
2. Power off the W5500 (disconnecting its power prevents conflicts).
3. Connect a USB-UART adapter to GPIO 1 (TX) and GPIO 3 (RX).
4. Press the reset button (B1), then flash with `idf.py flash`.
5. After flashing, set SW2 back to normal and reset.

---

## Software

### Prerequisites

- [ESP-IDF](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/get-started/) v5.x
- CMake ≥ 3.5

### Build & Flash

```bash
# Set up ESP-IDF environment (run once per shell session)
. $IDF_PATH/export.sh

# Build
idf.py build

# Flash and monitor
idf.py -p /dev/ttyUSB0 flash monitor
```

### Configuration

`sdkconfig.defaults` sets sensible defaults for the ESP32-CAM:

| Setting                  | Value           |
|--------------------------|-----------------|
| CPU frequency            | 240 MHz         |
| Flash size               | 4 MB            |
| Flash frequency          | 80 MHz          |
| Flash mode               | QIO             |
| PSRAM                    | Enabled, 80 MHz |
| FreeRTOS tick rate       | 1000 Hz         |

The W5500 Ethernet driver must be enabled. It is configured via `CONFIG_ETH_SPI_ETHERNET_W5500=y` (already set in `sdkconfig`).

### Dependencies

Managed via [ESP-IDF Component Manager](https://docs.espressif.com/projects/idf-component-manager/en/latest/):

| Component                  | Version |
|----------------------------|---------|
| `espressif/esp32-camera`   | latest  |

Dependencies are resolved automatically during build.

---

## Project Structure

```sh
eth-camera/
├── main/
│   ├── app_main.c        # Entry point, boot sequence
│   ├── camera.c / .h     # Camera init and frame capture (OV2640)
│   ├── http.c / .h       # HTTP server, /snapshot endpoint
│   ├── leds.c / .h       # Flash LED + Morse LED with queue
│   └── net/
│       ├── net.c / .h    # Ethernet init (W5500 over SPI)
├── hardware/
│   ├── eth-camera.kicad_sch   # Schematic
│   ├── eth-camera.kicad_pcb   # PCB layout
│   └── eth-camera.kicad_pro   # KiCad project file
├── CMakeLists.txt
├── sdkconfig.defaults
└── README.md
```

---

## Device Hostname

On boot the firmware derives a unique hostname from the ESP32 factory MAC address:

```sh
camera-XXYYZZ
```

where `XXYYZZ` are the last three bytes of the MAC. The hostname is set on the DHCP/netif layer so it may appear in your router's DHCP table.

---

## API

### `GET /snapshot`

Takes a photo and streams it back as JPEG.

**Response headers:**

| Header          | Value            |
|-----------------|------------------|
| Content-Type    | `image/jpeg`     |
| Cache-Control   | `no-store`       |
| Connection      | `close`          |

**Error responses:**

| Status | Meaning                                  |
|--------|------------------------------------------|
| 503    | Camera busy (another request in progress) or capture failed |

---

## License

See `managed_components/espressif__esp32-camera/LICENSE` for the camera component license.
