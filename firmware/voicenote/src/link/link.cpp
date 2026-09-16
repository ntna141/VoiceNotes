#include "link.h"

#include <Arduino.h>
#include <EasyBLE.h>
#include <stdio.h>
#include <string.h>

#include "../../config.h"
#include "../clock/clock.h"

namespace {

const uint8_t StreamDescriptor[] = {
    1,
    1,
    static_cast<uint8_t>(SAMPLE_RATE),
    static_cast<uint8_t>(SAMPLE_RATE >> 8),
    static_cast<uint8_t>(SAMPLE_RATE >> 16),
    static_cast<uint8_t>(SAMPLE_RATE >> 24),
    static_cast<uint8_t>(ADPCM_BLOCK_SAMPLES),
    static_cast<uint8_t>(ADPCM_BLOCK_SAMPLES >> 8),
};

bool justConnected = false;
bool justDisconnected = false;
bool homePending = false;
HomeData pendingHome;
bool pagePending = false;
Page pendingPage;
uint32_t pendingPageUtc = 0;
int16_t pendingPageTz = 0;
bool pendingPageForce = false;
bool moodPending = false;
uint16_t pendingMoodYear = 0;
uint8_t pendingMoodMonth = 0;
uint8_t pendingMoodDay = 0;
uint8_t pendingMoodValue = 0;
bool timePending = false;
uint32_t pendingTimeUtc = 0;
int16_t pendingTimeTz = 0;
bool iconsPending = false;
bool iconsResetPending = false;
IconSet pendingIcons;
bool closedPending = false;
bool closedAcked = false;

void onConnect() {
  justConnected = true;
}

void onDisconnect() {
  justDisconnected = true;
}

void onStreamClosed(bool acked) {
  closedPending = true;
  closedAcked = acked;
}

void onReceive(const EasyBLEMessage& message) {
  if (message.type == EasyBLEMessageType::Image) {
    Page parsed;
    uint32_t utc = 0;
    int16_t tz = 0;
    bool force = false;
    if (pageParse(message.data, message.length, parsed, utc, tz, force)) {
      pendingPage = parsed;
      pendingPageUtc = utc;
      pendingPageTz = tz;
      pendingPageForce = force;
      pagePending = true;
      return;
    }
    if (moodParse(message.data, message.length, pendingMoodYear, pendingMoodMonth, pendingMoodDay, pendingMoodValue)) {
      moodPending = true;
      return;
    }
    if (timeParse(message.data, message.length, utc, tz)) {
      pendingTimeUtc = utc;
      pendingTimeTz = tz;
      timePending = true;
      return;
    }
    bool reset = false;
    if (iconsParse(message.data, message.length, pendingIcons, reset)) {
      iconsResetPending = reset;
      iconsPending = true;
    }
    return;
  }
  if (message.type != EasyBLEMessageType::Text) {
    return;
  }
  const char* text = reinterpret_cast<const char*>(message.data);
  if (strncmp(text, "home\n", 5) == 0) {
    HomeData data;
    if (homeParse(text, data)) {
      pendingHome = data;
      homePending = true;
    }
  }
}

void onStreamRequested() {
  linkStreamOpen();
}

}  // namespace

bool linkBegin() {
  EasyBLE.onConnect(onConnect);
  EasyBLE.onDisconnect(onDisconnect);
  EasyBLE.onReceive(onReceive);
  EasyBLE.channel().onRequested(onStreamRequested);
  EasyBLE.channel().onClosed(onStreamClosed);
  return EasyBLE.begin(DEVICE_NAME);
}

void linkEnd() {
  EasyBLE.end();
}

void linkUpdate() {
  EasyBLE.update();
}

bool linkConnected() {
  return EasyBLE.isConnected();
}

bool linkJustConnected() {
  if (!justConnected) {
    return false;
  }
  justConnected = false;
  return true;
}

bool linkJustDisconnected() {
  if (!justDisconnected) {
    return false;
  }
  justDisconnected = false;
  return true;
}

void linkLowPower(bool enabled) {
  EasyBLE.setLowPower(enabled);
}

bool linkSendHello(int batteryPercent, const Page& page) {
  char text[128];
  const bool valid = pageValid(page);
  int n = snprintf(text, sizeof(text), "hello\n%d\n%s\n%u\n%u\n%u\n", batteryPercent, FW_VERSION,
                   valid ? page.year : 0, valid ? page.month : 0, valid ? page.today : 0);
  if (n < 0 || n + PageMaxDays + 24 > static_cast<int>(sizeof(text))) {
    return false;
  }
  if (valid) {
    for (int i = 0; i < PageMaxDays; ++i) {
      const uint8_t mood = page.moods[i] > PageMoodCount ? 0 : page.moods[i];
      text[n++] = static_cast<char>('0' + mood);
    }
  }
  n += snprintf(text + n, sizeof(text) - n, "\n%lu\n%lu\n", static_cast<unsigned long>(valid ? page.dirty : 0),
                static_cast<unsigned long>(iconsHash()));
  return EasyBLE.sendText(text);
}

bool linkTakeIcons(IconSet& set, bool& reset) {
  if (!iconsPending) {
    return false;
  }
  iconsPending = false;
  set = pendingIcons;
  reset = iconsResetPending;
  return true;
}

bool linkTakeHome(HomeData& data) {
  if (!homePending) {
    return false;
  }
  homePending = false;
  data = pendingHome;
  return true;
}

bool linkTakePage(Page& page, uint32_t& unixUtc, int16_t& tzMinutes, bool& force) {
  if (!pagePending) {
    return false;
  }
  pagePending = false;
  page = pendingPage;
  unixUtc = pendingPageUtc;
  tzMinutes = pendingPageTz;
  force = pendingPageForce;
  return true;
}

bool linkTakeMood(uint16_t& year, uint8_t& month, uint8_t& day, uint8_t& mood) {
  if (!moodPending) {
    return false;
  }
  moodPending = false;
  year = pendingMoodYear;
  month = pendingMoodMonth;
  day = pendingMoodDay;
  mood = pendingMoodValue;
  return true;
}

bool linkTakeTime(uint32_t& unixUtc, int16_t& tzMinutes) {
  if (!timePending) {
    return false;
  }
  timePending = false;
  unixUtc = pendingTimeUtc;
  tzMinutes = pendingTimeTz;
  return true;
}

bool linkStreamOpen() {
  if (EasyBLE.channel().isOpen()) {
    return true;
  }
  return EasyBLE.channel().open(StreamDescriptor, sizeof(StreamDescriptor));
}

bool linkStreamOpened() {
  return EasyBLE.channel().isOpen();
}

bool linkStreamEnabled() {
  return EasyBLE.channel().isEnabled();
}

void linkStreamWrite(const uint8_t* block, size_t len) {
  EasyBLE.channel().write(block, len);
}

void linkStreamClose() {
  closedPending = false;
  EasyBLE.channel().close();
}

bool linkTakeStreamClosed(bool& acked) {
  if (!closedPending) {
    return false;
  }
  closedPending = false;
  acked = closedAcked;
  return true;
}
