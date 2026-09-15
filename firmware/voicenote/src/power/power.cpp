#include "power.h"

#include <Arduino.h>
#include <driver/rtc_io.h>
#include <esp_sleep.h>

#include "../../config.h"
#include "../bsp/board_power_bsp.h"

namespace {

board_power_bsp_t* board = nullptr;
WakeReason wakeReason = WakeReason::PowerOn;

const gpio_num_t HeldPins[] = {VBAT_HOLD_PIN, EPD_PWR_PIN, AUDIO_PWR_PIN, PA_CTRL_PIN};

struct BatteryPoint {
  uint16_t millivolts;
  uint8_t percent;
};

const BatteryPoint BatteryCurve[] = {
    {4200, 100}, {4100, 90}, {4000, 78}, {3900, 62}, {3800, 45},
    {3700, 28},  {3600, 14}, {3500, 6},  {3400, 2},  {3300, 0},
};

void readWakeReason() {
  switch (esp_sleep_get_wakeup_cause()) {
    case ESP_SLEEP_WAKEUP_TIMER:
      wakeReason = WakeReason::Timer;
      break;
    case ESP_SLEEP_WAKEUP_EXT1: {
      uint64_t pins = esp_sleep_get_ext1_wakeup_status();
      wakeReason = (pins & (1ULL << BTN_TOP_PIN)) ? WakeReason::TopButton : WakeReason::RecButton;
      break;
    }
    default:
      wakeReason = WakeReason::PowerOn;
      break;
  }
}

}  // namespace

void powerBegin() {
  readWakeReason();
  gpio_set_level(VBAT_HOLD_PIN, 1);
  gpio_set_level(EPD_PWR_PIN, 1);
  gpio_set_level(AUDIO_PWR_PIN, 1);
  board = new board_power_bsp_t(EPD_PWR_PIN, AUDIO_PWR_PIN, VBAT_HOLD_PIN);
  board->VBAT_POWER_ON();
  board->POWEER_EPD_OFF();
  board->POWEER_Audio_OFF();
  pinMode(PA_CTRL_PIN, OUTPUT);
  digitalWrite(PA_CTRL_PIN, LOW);
  gpio_deep_sleep_hold_dis();
  for (gpio_num_t pin : HeldPins) {
    gpio_hold_dis(pin);
  }
  pinMode(BTN_REC_PIN, INPUT_PULLUP);
  pinMode(BTN_TOP_PIN, INPUT_PULLUP);
}

WakeReason powerWakeReason() {
  return wakeReason;
}

void powerDisplayOn() {
  board->POWEER_EPD_ON();
  delay(20);
}

void powerDisplayOff() {
  board->POWEER_EPD_OFF();
}

void powerAudioOn() {
  board->POWEER_Audio_ON();
  delay(20);
}

void powerAudioOff() {
  board->POWEER_Audio_OFF();
}

void powerDeepSleep(uint32_t timerSeconds) {
  esp_sleep_disable_wakeup_source(ESP_SLEEP_WAKEUP_ALL);
  const uint64_t mask = (1ULL << BTN_REC_PIN) | (1ULL << BTN_TOP_PIN);
  esp_sleep_enable_ext1_wakeup_io(mask, ESP_EXT1_WAKEUP_ANY_LOW);
  rtc_gpio_pulldown_dis(BTN_REC_PIN);
  rtc_gpio_pullup_en(BTN_REC_PIN);
  rtc_gpio_pulldown_dis(BTN_TOP_PIN);
  rtc_gpio_pullup_en(BTN_TOP_PIN);
  if (timerSeconds > 0) {
    esp_sleep_enable_timer_wakeup(static_cast<uint64_t>(timerSeconds) * 1000000ULL);
  }
  for (gpio_num_t pin : HeldPins) {
    gpio_hold_en(pin);
  }
  gpio_deep_sleep_hold_en();
  esp_deep_sleep_start();
}

int batteryPercent() {
  analogSetPinAttenuation(BAT_ADC_PIN, ADC_11db);
  uint32_t sum = 0;
  for (int i = 0; i < 16; ++i) {
    sum += analogReadMilliVolts(BAT_ADC_PIN);
  }
  uint32_t mv = (sum / 16) * 2;
  const size_t n = sizeof(BatteryCurve) / sizeof(BatteryCurve[0]);
  if (mv >= BatteryCurve[0].millivolts) {
    return 100;
  }
  for (size_t i = 1; i < n; ++i) {
    if (mv >= BatteryCurve[i].millivolts) {
      const BatteryPoint& hi = BatteryCurve[i - 1];
      const BatteryPoint& lo = BatteryCurve[i];
      return lo.percent + (hi.percent - lo.percent) * static_cast<int>(mv - lo.millivolts) /
                              (hi.millivolts - lo.millivolts);
    }
  }
  return 0;
}
