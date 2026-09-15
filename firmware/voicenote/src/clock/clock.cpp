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

uint32_t timeSecondsToMidnight() {
  if (!timeSynced()) {
    return 0;
  }
  const time_t local = static_cast<time_t>(timeNow()) + static_cast<time_t>(storedTz) * 60;
  struct tm parts = {};
  gmtime_r(&local, &parts);
  const int elapsed = parts.tm_hour * 3600 + parts.tm_min * 60 + parts.tm_sec;
  const uint32_t left = static_cast<uint32_t>(86400 - elapsed);
  return left == 0 ? 86400 : left;
}

bool timeSynced() {
  return timeMagic == Magic;
}
