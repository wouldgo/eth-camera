# eth-camera

An ESP32-CAM project that exposes a camera snapshot over HTTP via a wired Ethernet connection (W5500 SPI module). The device also blinks status messages in Morse code on a dedicated LED.

---

## Overview

The firmware runs on an **ESP32-CAM (AI-Thinker)** board and uses a **W5500** SPI-to-Ethernet chip to get a wired network connection. On boot it:

1. Blinks the flash LED to signal it is starting up.
2. Initialises Ethernet. DHCP runs in the background: boot does not wait for an IP address.
3. Initialises the OV2640 camera sensor.
4. Starts an HTTP server on port **3000**.
5. Every 30 s blinks the last octet of its IP address in Morse code on GPIO 33 (`0` = no IP yet).

A single HTTP endpoint is exposed:

```sh
GET http://<device-ip>:3000/snapshot
```

This returns a JPEG image taken at that moment (`image/jpeg`). While the photo is being taken the flash LED (GPIO 4) turns on, then off again. Requests are handled one at a time: a second client waits until the first one is served. A request within 3 s of the previous photo gets `429 Too Many Requests`.

---

## Hardware

The schematic is included in the `hardware/` folder (KiCad 10).

### Bill of Materials

| Ref  | Component               | Notes                                        |
|------|-------------------------|----------------------------------------------|
| U1   | ESP32-CAM (AI-Thinker)  | Main microcontroller + camera module         |
| IC1  | W5500                   | SPI Ethernet controller (via USR-ES1 module) |
| C1   | 470 µF 25 V capacitor   | Bulk decoupling on the 5 V rail              |
| C2   | 100 nF capacitor        | Bypass decoupling                            |
| J1   | 2-pin connector         | 5 V power input                              |
| SW1  | SS-12D00-G slide switch | Programming mode switch (GPIO0 to GND)       |
| SW2  | SS-12D00-G slide switch | W5500 power switch (switches its 3.3 V supply) |
| B1   | SKHLAAA010 tact button  | Reset button (to the ESP32-CAM "GND" pin next to U0T, which is RST on this board) |
| TP1  | Test point              | GND                                          |
| TP2  | Test point              | UART RX (GPIO 3)                             |
| TP3  | Test point              | UART TX (GPIO 1)                             |

### Wiring: ESP32-CAM → W5500

| ESP32-CAM GPIO | W5500 pin |
|----------------|-----------|
| GPIO 14        | SCLK      |
| GPIO 13        | MOSI      |
| GPIO 12        | MISO      |
| GPIO 2         | SCS (CS)  |
| GND            | GND       |
| 3V3 (via SW2)  | 3V3 (VCC) |

The W5500 `INT` and `RST` pins are not connected.

> **Note:** GPIO 2, 12, 13 and 14 are also the SD card lines (D0, D2, D3, CLK), so the SD card slot cannot be used together with the W5500.
>
> **Note:** the W5500 must be powered at 3.3 V (the USR-ES1 has no regulator, and the W5500 is rated for 4.6 V max). Its supply is the ESP32-CAM 3V3 pin, switched by SW2. The ESP32 pins are not 5 V tolerant.
>
> **Why the W5500 must be off while flashing:** GPIO 2 (CS) is pulled low at reset, so the W5500 is selected and drives MISO. MISO is GPIO 12, a strapping pin: if it is high at reset the ESP32 selects 1.8 V flash and the 3.3 V flash cannot be read or written.

### LEDs

| GPIO | Function                           |
|------|------------------------------------|
| 4    | Flash LED — lights during capture, dimmable via PWM (LEDC timer 1, 40 kHz) |
| 33   | Morse LED — blinks status messages |

### Programming

To flash the firmware:

1. Set **SW1** to connect GPIO 0 to GND.
2. Power off the W5500 with **SW2** (see the strapping note above).
3. Connect a USB-UART adapter to TP3 (GPIO 1, TX), TP2 (GPIO 3, RX) and TP1 (GND).
4. Press the reset button (B1), then flash with `idf.py flash`.
5. After flashing, set SW1 back to normal, power the W5500 on with SW2, and reset.

---

## Software

### Prerequisites

- [ESP-IDF](https://docs.espressif.com/projects/esp-idf/en/stable/esp32/get-started/) v5.x
- CMake ≥ 3.16

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

The W5500 Ethernet driver must be enabled. It is configured via `CONFIG_ETH_SPI_ETHERNET_W5500=y` (set in `sdkconfig.defaults`). The ESP32 internal Ethernet MAC is disabled (`CONFIG_ETH_USE_ESP32_EMAC=n`).

### Dependencies

Managed via [ESP-IDF Component Manager](https://docs.espressif.com/projects/idf-component-manager/en/latest/):

| Component                  | Version |
|----------------------------|---------|
| `espressif/esp32-camera`   | ^2.1.4  |

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
│   ├── eth-camera.kicad_pro   # KiCad project file
│   ├── board.scad             # Board reference model (not printed)
│   ├── chassis.scad           # Chassis: tray + lid
│   ├── meter_mount.scad       # Cone mount to the water meter
│   └── tray.stl / lid.stl / meter_mount.stl   # Printable parts
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

Takes a photo (1600×1200 UXGA) and sends it back as JPEG. The flash turns on and a couple of frames are discarded so exposure adapts before the real shot.

**Query parameters:**

| Name    | Values   | Default | Meaning                                  |
|---------|----------|---------|------------------------------------------|
| `flash` | `0`–`100`| `10`    | Flash brightness in % (PWM duty, `0` = off) |

```sh
curl -o photo.jpg "http://<device-ip>:3000/snapshot?flash=25"
```

**Response headers:**

| Header          | Value            |
|-----------------|------------------|
| Content-Type    | `image/jpeg`     |
| Content-Length  | image size       |
| Cache-Control   | `no-store`       |
| Connection      | `close`          |

**Error responses:**

| Status | Meaning                                  |
|--------|------------------------------------------|
| 400    | `flash` is not an integer in `0`–`100`   |
| 429    | Less than 3 s since the previous photo (`Retry-After: 3`) |
| 503    | Capture failed                           |

> **Security:** the endpoint has no authentication. Expose it only on a trusted LAN.

---

## License

See `managed_components/espressif__esp32-camera/LICENSE` for the camera component license.
