#include "link.h"

#include <Arduino.h>
#include <EasyBLE.h>
#include <stdio.h>
#include <string.h>

#include "../../config.h"
#include "../clock/clock.h"
#include "../wallpaper/wallpaper.h"

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
bool activity = false;
bool homePending = false;
HomeData pendingHome;
bool timePending = false;
uint32_t pendingTimeUtc = 0;
int16_t pendingTimeTz = 0;
bool wallpaperPending = false;
bool wallpaperResetPending = false;
uint8_t pendingWallpaper[WallpaperBytes];
bool closedPending = false;
bool closedAcked = false;

void onConnect() {
  justConnected = true;
  activity = true;
}

void onDisconnect() {
  justDisconnected = true;
}

void onStreamClosed(bool acked) {
  closedPending = true;
  closedAcked = acked;
}

void onReceive(const EasyBLEMessage& message) {
  activity = true;
  if (message.type == EasyBLEMessageType::Image) {
    uint32_t utc = 0;
    int16_t tz = 0;
    if (timeParse(message.data, message.length, utc, tz)) {
      pendingTimeUtc = utc;
      pendingTimeTz = tz;
      timePending = true;
      return;
    }
    const uint8_t* bits = nullptr;
    bool reset = false;
    if (wallpaperParse(message.data, message.length, bits, reset)) {
      if (!reset) {
        memcpy(pendingWallpaper, bits, WallpaperBytes);
      }
      wallpaperResetPending = reset;
      wallpaperPending = true;
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

bool onStream(const EasyBLEStreamEvent&) {
  activity = true;
  return false;
}

void onStreamRequested() {
  linkStreamOpen();
}

}  // namespace

bool linkBegin() {
  EasyBLE.onConnect(onConnect);
  EasyBLE.onDisconnect(onDisconnect);
  EasyBLE.onReceive(onReceive);
  EasyBLE.onStream(onStream);
  EasyBLE.channel().onRequested(onStreamRequested);
  EasyBLE.channel().onClosed(onStreamClosed);
  return EasyBLE.begin(DEVICE_NAME, LINK_MAX_MESSAGE_BYTES);
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

bool linkTakeActivity() {
  if (!activity && !EasyBLE.isSending()) {
    return false;
  }
  activity = false;
  return true;
}

void linkLowPower(bool enabled) {
  EasyBLE.setLowPower(enabled);
}

bool linkSendHello(int batteryPercent) {
  char text[64];
  const int n = snprintf(text, sizeof(text), "hello\n%d\n%s\n%lu\n%u\n", batteryPercent, FW_VERSION,
                         static_cast<unsigned long>(wallpaperHash()), static_cast<unsigned>(LINK_PROTOCOL_VERSION));
  if (n < 0 || n >= static_cast<int>(sizeof(text))) {
    return false;
  }
  const bool sent = EasyBLE.sendText(text);
  activity |= sent;
  return sent;
}

bool linkTakeHome(HomeData& data) {
  if (!homePending) {
    return false;
  }
  homePending = false;
  data = pendingHome;
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

bool linkTakeWallpaper(const uint8_t*& bits, bool& reset) {
  if (!wallpaperPending) {
    return false;
  }
  wallpaperPending = false;
  reset = wallpaperResetPending;
  bits = reset ? nullptr : pendingWallpaper;
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
