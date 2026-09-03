# Wallbreaker [![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)

Passive Wi-Fi signal analysis for locating active WLAN-capable devices. An ESP32-C5 captures 802.11 frames in monitor mode (2.4/5 GHz) and streams source MAC, destination MAC and RSSI over BLE to a mobile app.

## Repository layout

```
firmware/    Rust no_std firmware for the ESP32-C5 (sniffing, BLE GATT server)
mobile/      Flutter app (BLE client, RSSI graph, haptic feedback, OUI lookup)
paper/       Bachelor thesis source (Typst)
defense/     Defense presentation source (Typst)
```

## Building

### Firmware

```bash
cd firmware
cargo build --release
```

Flash and monitor:

```bash
cargo run --release
```

Requires the `espflash` runner (see `.cargo/config.toml`) and a toolchain with the `riscv32imac-unknown-none-elf` target, as pinned in `rust-toolchain.toml`.

### Mobile app

```bash
cd mobile
flutter run
```

The app targets iOS and Android. It connects to the sensor via BLE, displays the RSSI history, provides haptic guidance, and resolves MAC addresses to vendors from the bundled OUI database.

## License

GNU AGPL v3. See [LICENSE](LICENSE).

## Citing

See [CITATION.bib](CITATION.bib).