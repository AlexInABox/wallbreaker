#![no_std]
#![no_main]

use core::cell::RefCell;
use critical_section::Mutex;
use esp_hal::clock::CpuClock;
use esp_hal::delay::Delay;
use esp_hal::main;
use esp_radio::ble::controller::BleConnector;
use esp_radio::wifi::sniffer::PromiscuousPkt;
use esp_radio::wifi::{BandMode, SecondaryChannel};
use log::{error, info};

use bleps::{
    Ble, HciConnector,
    ad_structure::{
        AdStructure, BR_EDR_NOT_SUPPORTED, LE_GENERAL_DISCOVERABLE, create_advertising_data,
    },
    attribute_server::{AttributeServer, NotificationData, WorkResult},
    gatt,
    no_rng::NoRng,
};

extern crate alloc;
use alloc::collections::VecDeque;

mod payload;

esp_bootloader_esp_idf::esp_app_desc!();

unsafe extern "C" {
    fn esp_wifi_set_country_code(
        country: *const core::ffi::c_char,
        ieee80211d_enabled: bool,
    ) -> i32;
}

#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
    error!("{info}");
    loop {}
}

static PACKET_QUEUE: Mutex<RefCell<VecDeque<[u8; 13]>>> = Mutex::new(RefCell::new(VecDeque::new()));
const MAX_QUEUE_SIZE: usize = 1024;

fn rx_callback(pkt: PromiscuousPkt<'_>) {
    if pkt.data.len() >= 16 {
        let mut buf = [0u8; 13];
        buf[0..6].copy_from_slice(&pkt.data[4..10]);
        buf[6..12].copy_from_slice(&pkt.data[10..16]);
        buf[12] = pkt.rx_cntl.rssi as u8;
        critical_section::with(|cs| {
            let mut q = PACKET_QUEUE.borrow(cs).borrow_mut();
            if q.len() >= MAX_QUEUE_SIZE {
                q.pop_front();
            }
            q.push_back(buf);
        });
    }
}
const CHANNELS: &[u8] = &[
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, // 2.4 GHz
    36, 40, 44, 48, 52, 56, 60, 64, 100, 104, 108, 112, 116, 120, 124, 128, 132, 136,
    140, // 5 GHz
];

fn current_millis() -> u64 {
    esp_hal::time::Instant::now()
        .duration_since_epoch()
        .as_millis()
}

#[main]
fn main() -> ! {
    esp_println::logger::init_logger_from_env();

    let mac_addr = esp_hal::efuse::base_mac_address();
    let mac = mac_addr.as_bytes();
    let hex = b"0123456789ABCDEF";
    let name_buf = [
        b'W',
        b'A',
        b'L',
        b'L',
        b'B',
        b'R',
        b'E',
        b'A',
        b'K',
        b'E',
        b'R',
        b'_',
        hex[(mac[3] & 0xF) as usize],
        hex[(mac[4] & 0xF) as usize],
        hex[(mac[5] & 0xF) as usize],
    ];
    let name_str = core::str::from_utf8(&name_buf).unwrap();
    info!("Starting device: {name_str}");

    let peripherals = esp_hal::init(esp_hal::Config::default().with_cpu_clock(CpuClock::max()));
    let delay = Delay::new();

    esp_alloc::heap_allocator!(#[esp_hal::ram(reclaimed)] size: 65536);

    let timg0 = esp_hal::timer::timg::TimerGroup::new(peripherals.TIMG0);
    let sw_interrupt =
        esp_hal::interrupt::software::SoftwareInterruptControl::new(peripherals.SW_INTERRUPT);
    esp_rtos::start(timg0.timer0, sw_interrupt.software_interrupt0);

    let (mut wifi, interfaces) =
        esp_radio::wifi::new(peripherals.WIFI, Default::default()).unwrap();
    let mut current_band = BandMode::_2_4G;
    wifi.set_band_mode(current_band.clone()).unwrap();

    unsafe {
        let _ = esp_wifi_set_country_code(c"DE".as_ptr(), false);
    }

    let mut sniffer = interfaces.sniffer;
    sniffer.set_promiscuous_mode(true).unwrap();
    sniffer.set_receive_cb(rx_callback);

    let connector = BleConnector::new(peripherals.BT, Default::default()).unwrap();
    let hci = HciConnector::new(connector, current_millis);

    let adv_params = bleps::AdvertisingParameters {
        advertising_interval_min: 0x2000,
        advertising_interval_max: 0x2000,
        advertising_type: bleps::AdvertisingType::AdvInd,
        own_address_type: bleps::OwnAddressType::Public,
        peer_address_type: bleps::PeerAddressType::Public,
        peer_address: [0u8; 6],
        advertising_channel_map: 7,
        filter_policy: bleps::AdvertisingFilterPolicy::All,
    };

    let ad_data = create_advertising_data(&[AdStructure::Flags(
        LE_GENERAL_DISCOVERABLE | BR_EDR_NOT_SUPPORTED,
    )]);
    let scan_resp_data = create_advertising_data(&[AdStructure::CompleteLocalName(name_str)]);

    let mut sent_count = 0u32;
    let mut channels = CHANNELS.iter().cycle();

    loop {
        let sniffer_val = &[] as &[u8];

        gatt!([service {
            uuid: "0000ffe0-0000-1000-8000-00805f9b34fb",
            characteristics: [characteristic {
                uuid: "0000ffe1-0000-1000-8000-00805f9b34fb",
                notify: true,
                value: sniffer_val,
                name: "sniffer_char",
            },],
        },]);

        let mut rng = NoRng;
        let mut cccd_buf = [0u8; 2];
        let mut batch_bytes = [0u8; 18 * 13];

        let mut ble = Ble::new(&hci);
        ble.init().unwrap();
        ble.cmd_set_le_advertising_parameters_custom(&adv_params)
            .unwrap();

        if let Ok(data) = ad_data {
            let _ = ble.cmd_set_le_advertising_data(data);
        }
        if let Ok(data) = scan_resp_data {
            let _ = ble.cmd_set_le_scan_rsp_data(data);
        }

        info!("Starting BLE Advertising...");
        let _ = ble.cmd_set_le_advertise_enable(true);

        let mut srv = AttributeServer::new(&mut ble, &mut gatt_attributes, &mut rng);

        'connection: loop {
            let channel = *channels.next().unwrap();
            let target_band = if channel >= 32 {
                BandMode::_5G
            } else {
                BandMode::_2_4G
            };

            if current_band != target_band.clone() {
                let _ = sniffer.set_promiscuous_mode(false);
                if wifi.set_band_mode(target_band.clone()).is_ok() {
                    current_band = target_band;
                }
                let _ = sniffer.set_promiscuous_mode(true);
            }

            info!("Hopping to Wi-Fi channel {channel}");
            let _ = wifi.set_channel(channel, SecondaryChannel::None);

            let start_time = current_millis();
            while current_millis() - start_time < 100 {
                let notifications_enabled = srv
                    .get_characteristic_value(sniffer_char_notify_enable_handle, 0, &mut cccd_buf)
                    .map_or(false, |_| cccd_buf[0] & 1 != 0);

                let num_packets = critical_section::with(|cs| {
                    let queue = PACKET_QUEUE.borrow(cs).borrow();
                    let n = 18.min(queue.len());
                    for i in 0..n {
                        batch_bytes[i * 13..(i + 1) * 13].copy_from_slice(&queue[i]);
                    }
                    n
                });

                let notification = (notifications_enabled && num_packets > 0).then(|| {
                    NotificationData::new(sniffer_char_handle, &batch_bytes[..num_packets * 13])
                });

                match srv.do_work_with_notification(notification) {
                    Ok(WorkResult::GotDisconnected) => {
                        info!("BLE Client disconnected.");
                        break 'connection;
                    }
                    Ok(WorkResult::DidWork) if num_packets > 0 => {
                        critical_section::with(|cs| {
                            let mut queue = PACKET_QUEUE.borrow(cs).borrow_mut();
                            for _ in 0..num_packets {
                                queue.pop_front();
                            }
                        });
                        sent_count += num_packets as u32;
                        info!("Sent {num_packets} pkts (Total: {sent_count})");
                    }
                    _ => {}
                }

                delay.delay_millis(if num_packets == 0 { 10 } else { 5 });
            }
        }
    }
}
