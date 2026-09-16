#include "clock.h"

#include <Arduino.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>

namespace {

constexpr uint32_t Magic = 0x54494D45;
constexpr char TimeTag[4] = {'t', 'i', 'm', 0};

RTC_DATA_ATTR uint32_t timeMagic = 0;
RTC_DATA_ATTR int16_t storedTz = 0;

uint32_t readU32(const uint8_t* p) {
  return static_cast<uint32_t>(p[0]) | (static_cast<uint32_t>(p[1]) << 8) |
         (static_cast<uint32_t>(p[2]) << 16) | (static_cast<uint32_t>(p[3]) << 24);
}

int16_t readI16(const uint8_t* p) {
  return static_cast<int16_t>(static_cast<uint16_t>(p[0]) | (static_cast<uint16_t>(p[1]) << 8));
}

}  // namespace

bool timeParse(const uint8_t* data, size_t len, uint32_t& unixUtc, int16_t& tzMinutes) {
  if (data == nullptr || len < 10 || memcmp(data, TimeTag, 4) != 0) {
    return false;
  }
  unixUtc = readU32(data + 4);
  tzMinutes = readI16(data + 8);
  return unixUtc > 0;
}

void timeApply(uint32_t unixUtc, int16_t tzMinutes) {
  timeval tv = {};
  tv.tv_sec = static_cast<time_t>(unixUtc);
  settimeofday(&tv, nullptr);
  storedTz = tzMinutes;
  timeMagic = Magic;
}

uint32_t timeNow() {
  return static_cast<uint32_t>(time(nullptr));
}

bool timeSynced() {
  return timeMagic == Magic;
}

bool timeLocalDate(uint16_t& year, uint8_t& month, uint8_t& day, uint8_t& weekday) {
  if (!timeSynced()) {
    return false;
  }
  const time_t local = static_cast<time_t>(timeNow()) + static_cast<time_t>(storedTz) * 60;
  struct tm parts = {};
  gmtime_r(&local, &parts);
  year = static_cast<uint16_t>(parts.tm_year + 1900);
  month = static_cast<uint8_t>(parts.tm_mon + 1);
  day = static_cast<uint8_t>(parts.tm_mday);
  weekday = static_cast<uint8_t>(parts.tm_wday);
  return month >= 1 && month <= 12 && day >= 1 && day <= 31;
}

uint32_t timeSecondsUntilLocalMidnight() {
  if (!timeSynced()) {
    return 0;
  }
  const uint32_t local = timeNow() + static_cast<int32_t>(storedTz) * 60;
  return 86400UL - (local % 86400UL) + 1;
}
