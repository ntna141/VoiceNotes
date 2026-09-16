#include "power.h"

#include <Arduino.h>
#include <Preferences.h>
#include <driver/gpio.h>
#include <driver/rtc_io.h>
#include <esp_sleep.h>
#include <string.h>

#include "../../config.h"
#include "../bsp/board_power_bsp.h"
#include "../clock/clock.h"

namespace {

const gpio_num_t HeldPins[] = {VBAT_HOLD_PIN, EPD_PWR_PIN, AUDIO_PWR_PIN};
const gpio_num_t WakePins[] = {BTN_REC_PIN, BTN_TOP_PIN};

RTC_DATA_ATTR uint32_t lastBatterySampleUtc = 0;

constexpr char LogNamespace[] = "batlog";
constexpr char LogKey[] = "log";
constexpr size_t LogSize = 288;

struct BatteryLog {
  uint16_t count;
  uint16_t next;
  uint16_t mv[LogSize];
};

board_power_bsp_t* board = nullptr;
BatteryLog batteryLog;

struct BatteryPoint {
  uint16_t millivolts;
  uint8_t percent;
};

const BatteryPoint BatteryCurve[] = {
    {4200, 100}, {4100, 90}, {4000, 78}, {3900, 62}, {3800, 45},
    {3700, 28},  {3600, 14}, {3500, 6},  {3400, 2},  {3300, 0},
};

void batteryLogLoad() {
  memset(&batteryLog, 0, sizeof(batteryLog));
  Preferences prefs;
  if (!prefs.begin(LogNamespace, true)) {
    return;
  }
  if (prefs.getBytes(LogKey, &batteryLog, sizeof(batteryLog)) != sizeof(batteryLog) ||
      batteryLog.count > LogSize || batteryLog.next >= LogSize) {
    memset(&batteryLog, 0, sizeof(batteryLog));
  }
  prefs.end();
}

}  // namespace

void powerBegin() {
  gpio_deep_sleep_hold_dis();
  for (gpio_num_t pin : HeldPins) {
    gpio_hold_dis(pin);
  }
  gpio_set_level(VBAT_HOLD_PIN, 1);
  gpio_set_level(EPD_PWR_PIN, 1);
  gpio_set_level(AUDIO_PWR_PIN, 1);
  board = new board_power_bsp_t(EPD_PWR_PIN, AUDIO_PWR_PIN, VBAT_HOLD_PIN);
  board->VBAT_POWER_ON();
  board->POWEER_EPD_OFF();
  board->POWEER_Audio_OFF();
  pinMode(PA_CTRL_PIN, OUTPUT);
  digitalWrite(PA_CTRL_PIN, LOW);
  pinMode(BTN_REC_PIN, INPUT_PULLUP);
  pinMode(BTN_TOP_PIN, INPUT_PULLUP);
  powerSetBoost(false);
  batteryLogLoad();
}

WakeCause powerWakeCause() {
  switch (esp_sleep_get_wakeup_cause()) {
    case ESP_SLEEP_WAKEUP_EXT1:
      return WakeCause::Button;
    case ESP_SLEEP_WAKEUP_TIMER:
      return WakeCause::Timer;
    default:
      return WakeCause::Cold;
  }
}

void powerDeepSleep(uint32_t timerSeconds) {
  uint64_t mask = 0;
  for (gpio_num_t pin : WakePins) {
    rtc_gpio_pullup_en(pin);
    rtc_gpio_pulldown_dis(pin);
    mask |= 1ULL << pin;
  }
  esp_sleep_enable_ext1_wakeup(mask, ESP_EXT1_WAKEUP_ANY_LOW);
  if (timerSeconds > 0) {
    esp_sleep_enable_timer_wakeup(static_cast<uint64_t>(timerSeconds) * 1000000ULL);
  }
  for (gpio_num_t pin : HeldPins) {
    gpio_hold_en(pin);
  }
  gpio_deep_sleep_hold_en();
  esp_deep_sleep_start();
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

void powerSetBoost(bool boost) {
  const uint32_t target = boost ? CPU_BOOST_MHZ : CPU_IDLE_MHZ;
  if (getCpuFrequencyMhz() != target) {
    setCpuFrequencyMhz(target);
  }
}

int batteryMillivolts() {
  analogSetPinAttenuation(BAT_ADC_PIN, ADC_11db);
  uint32_t sum = 0;
  for (int i = 0; i < 16; ++i) {
    sum += analogReadMilliVolts(BAT_ADC_PIN);
  }
  return static_cast<int>((sum / 16) * 2);
}

int batteryPercent() {
  const int mv = batteryMillivolts();
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

void batteryLogSample() {
  const uint32_t now = timeNow();
  if (lastBatterySampleUtc != 0 && now - lastBatterySampleUtc < BATTERY_CHECK_MS / 1000UL) {
    return;
  }
  lastBatterySampleUtc = now;
  batteryLog.mv[batteryLog.next] = static_cast<uint16_t>(batteryMillivolts());
  batteryLog.next = (batteryLog.next + 1) % LogSize;
  if (batteryLog.count < LogSize) {
    batteryLog.count++;
  }
  Preferences prefs;
  if (prefs.begin(LogNamespace, false)) {
    prefs.putBytes(LogKey, &batteryLog, sizeof(batteryLog));
    prefs.end();
  }
}

void batteryLogPrint() {
  Serial.printf("batlog %u samples, %lu min apart, oldest first:", batteryLog.count,
                static_cast<unsigned long>(BATTERY_CHECK_MS / 60000UL));
  for (uint16_t i = 0; i < batteryLog.count; ++i) {
    const size_t index = (batteryLog.next + LogSize - batteryLog.count + i) % LogSize;
    Serial.printf(" %u", batteryLog.mv[index]);
  }
  Serial.println();
}
