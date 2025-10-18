#include <hardware/pio.h>
#include <hardware/address_mapped.h>
#include <hardware/clocks.h>
#include <hardware/gpio.h>
#include <hardware/timer.h>
#include <hardware/watchdog.h>
#include <pico/platform/common.h>
#include <pico/stdio.h>
#include <pico/time.h>
#include <stdint.h>
#include <stdio.h>

// Include generated files
#include "sm.pio.h"
#include "rom.h"

#define P_ADDR_BASE 0     // Address LSB Pin
#define NUM_ADDR_PINS 15

#define P_DATA_BASE 15    // Data LSB Pin
#define NUM_DATA_PINS 8

#define P_M2 27           // CPU Clock
#define P_ROMSEL 26       // Active Low when address is active

#define P_DATA_OUT_ENABLE 28

#define ADDR_PIO pio0
#define DATA_PIO pio1
#define NOT_PIO pio2

#define RUNNING_CLOCK_KHZ 250000

static uint address_sm;
static uint data_sm;
static uint data_sm_offset;


static void setup_sm(void) {
  address_sm = pio_claim_unused_sm(ADDR_PIO, true);

  // Load program
  uint address_sm_offset = pio_add_program(ADDR_PIO, &address_read_program);

  // Init pins and set pull-ups BEFORE pio_gpio_init
  for (int i = 0; i < NUM_ADDR_PINS; ++i) {
    gpio_init(P_ADDR_BASE + i);
    gpio_set_dir(P_ADDR_BASE + i, GPIO_IN);
    // gpio_pull_up(P_ADDR_BASE + i);
    pio_gpio_init(ADDR_PIO, P_ADDR_BASE + i);
  }

  gpio_init(P_M2);
  gpio_set_dir(P_M2, GPIO_IN);
  // gpio_pull_up(P_M2);
  pio_gpio_init(ADDR_PIO, P_M2);

  // Config
  pio_sm_config address_c =
    address_read_program_get_default_config(address_sm_offset);
  sm_config_set_in_pins(&address_c, P_ADDR_BASE);

  // Configure input shifting
  sm_config_set_in_shift(&address_c,
      false, // Shift to left (MSB first)
      false, // No autopush
      16);   // 16 bits threshold

  // Run address sm at full speed
  sm_config_set_clkdiv(&address_c, 1.0f);

  // Directions: address bus + trigger as inputs
  pio_sm_set_consecutive_pindirs(ADDR_PIO, address_sm, P_ADDR_BASE, NUM_ADDR_PINS,
      false);

  // Use wrap target label start
  pio_sm_init(ADDR_PIO, address_sm, address_sm_offset + address_read_wrap_target,
      &address_c);

  // Start SM
  pio_sm_set_enabled(ADDR_PIO, address_sm, true);


  // Data state machine setup
  data_sm = pio_claim_unused_sm(DATA_PIO, true);

  data_sm_offset = pio_add_program(DATA_PIO, &data_control_program);

  pio_sm_config data_c =
      data_control_program_get_default_config(data_sm_offset);

  // sm_config_set_jmp_pin(&data_c, P_RW_DECISION);

  sm_config_set_set_pins(&data_c, P_DATA_BASE, NUM_DATA_PINS);
  sm_config_set_out_pins(&data_c, P_DATA_BASE, NUM_DATA_PINS);
  sm_config_set_in_pins(&data_c, P_DATA_BASE);

  // Configure shift for data control
  sm_config_set_in_shift(&data_c, false, false, 8);
  sm_config_set_out_shift(&data_c, false, false, 8);


  // Initialize data pins
  for (int i = 0; i < NUM_DATA_PINS; ++i) {
    pio_gpio_init(DATA_PIO, P_DATA_BASE + i);
  }

  pio_sm_set_consecutive_pindirs(DATA_PIO, data_sm, P_DATA_BASE, NUM_DATA_PINS, true);

  // Initialize and configure data state machine
  pio_sm_init(DATA_PIO, data_sm, data_sm_offset + data_control_wrap_target,
      &data_c);

  pio_sm_set_enabled(DATA_PIO, data_sm, true);


  // Load the PIO program
  uint not_offset = pio_add_program(NOT_PIO, &not_gate_program);

  // Get a free state machine
  uint not_sm = pio_claim_unused_sm(NOT_PIO, true);

  // Configure the input pin
  pio_gpio_init(NOT_PIO, P_ROMSEL);
  pio_sm_set_consecutive_pindirs(NOT_PIO, not_sm, P_ROMSEL, 1, false);

  // Configure the output pin (side-set)
  pio_gpio_init(NOT_PIO, P_DATA_OUT_ENABLE);
  pio_sm_set_consecutive_pindirs(NOT_PIO, not_sm, P_DATA_OUT_ENABLE, 1, true);

  // Get default config
  pio_sm_config not_c = not_gate_program_get_default_config(not_offset);

  // Configure side-set pins
  sm_config_set_sideset_pins(&not_c, P_DATA_OUT_ENABLE);
  pio_gpio_init(NOT_PIO, P_DATA_OUT_ENABLE);

  // Configure the input pin for WAIT instruction
  sm_config_set_in_pins(&not_c, P_ROMSEL);

  // Initialize and start the state machine
  pio_sm_init(NOT_PIO, not_sm, not_offset, &not_c);
  pio_sm_set_enabled(NOT_PIO, not_sm, true);
}

int main() {

  stdio_init_all();
  sleep_ms(500);

  gpio_init(PICO_DEFAULT_LED_PIN);
  gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);

  gpio_put(PICO_DEFAULT_LED_PIN, 1);
  sleep_ms(4000);
  gpio_put(PICO_DEFAULT_LED_PIN, 0);

  if (watchdog_caused_reboot()) {
    printf("[BOOT] Watchdog caused reboot!\n");
    stdio_flush();
    for (int i = 0; i < 5; i++) {
      gpio_put(PICO_DEFAULT_LED_PIN, 1);
      sleep_ms(100);
      gpio_put(PICO_DEFAULT_LED_PIN, 0);
      sleep_ms(100);
    }
  }

  set_sys_clock_khz(RUNNING_CLOCK_KHZ, true);

  for (int pin = 0; pin <= 28; pin++) {
        // Initialize the pin
        gpio_init(pin);

        // Set the pin as output
        gpio_set_dir(pin, GPIO_OUT);

        // Turn the pin ON (set HIGH/3.3V)
        gpio_put(pin, 1);
    }

    // Keep the program running
    while (true) {
        tight_loop_contents();
    }


  printf("[BOOT] Successfully set clock to %d\n", RUNNING_CLOCK_KHZ);
  stdio_flush();

  setup_sm();

  printf("[BOOT] Successfully enabled state machines\n");
  printf("[BOOT] STARTUP SUCCESSFUL!\n\n");
  stdio_flush();


  gpio_put(PICO_DEFAULT_LED_PIN, 1);
  while (true) {
    while (pio_sm_is_rx_fifo_empty(ADDR_PIO, address_sm)) {
      tight_loop_contents();
    }

    uint16_t addr = pio_sm_get(ADDR_PIO, address_sm);
    uint8_t data_to_send = rom_arr[addr];
    pio_sm_put(DATA_PIO, data_sm, data_to_send);
    // printf("0x%04x\n", addr);
  }
}
