#include <Arduino.h>
#include <Wire.h>

#include "config.h"
#include "src/audio/adpcm.h"
#include "src/audio/mic.h"
#include "src/display/screen.h"
#include "src/display/screens.h"
#include "src/clock/clock.h"
#include "src/home/home.h"
#include "src/input/button.h"
#include "src/link/link.h"
#include "src/power/power.h"
#include "src/wallpaper/wallpaper.h"

namespace {

enum class State : uint8_t {
  Home,
  Connecting,
  Recording,
  Ending,
  Done,
  Error,
};

enum class RecordMode : uint8_t {
  None,
  Quick,
  FreeFlow,
};

Button recButton(BTN_REC_PIN);
Button topButton(BTN_TOP_PIN);
HomeData home;
State state = State::Home;
RecordMode recordMode = RecordMode::None;
bool displayReady = false;
uint32_t stateEnteredAt = 0;
uint32_t lastActivityAt = 0;
uint32_t lastScreenTickAt = 0;
uint32_t lastBatteryCheckAt = 0;
int battery = 0;
bool helloNeeded = false;
uint32_t redrawAt = 0;
bool redrawFull = false;
char errorMessage[24];

void ensureDisplay() {
  if (displayReady) {
    return;
  }
  powerDisplayOn();
  screen.begin(true);
  displayReady = true;
}

void restDisplay() {
  if (!displayReady) {
    return;
  }
  screen.sleep();
  powerDisplayOff();
  displayReady = false;
}

void goToSleep() {
  Serial.println("sleep");
  restDisplay();
  linkEnd();
  Serial.flush();
  powerDeepSleep(0);
}

void showHome(bool full = false) {
  ensureDisplay();
  lastActivityAt = millis();
  lastBatteryCheckAt = millis();
  battery = batteryPercent();
  if (wallpaperPresent()) {
    wallpaperDraw();
  } else {
    screensDrawStatus("VoiceNote", "set a wallpaper in the app");
  }
  if (battery < BATTERY_LOW_PERCENT) {
    screen.fillRect(EPD_WIDTH - 8 - 24, EPD_HEIGHT - 8 - 13, 30, 15, SCREEN_WHITE);
    screensDrawLowBattery(EPD_WIDTH - 6 - 22, EPD_HEIGHT - 6 - 11);
  }
  if (full) {
    screen.showFull();
  } else {
    screen.showPartial();
  }
}

void enter(State next) {
  state = next;
  stateEnteredAt = millis();
  lastScreenTickAt = millis();
  ensureDisplay();
  switch (state) {
    case State::Home:
      showHome();
      break;
    case State::Connecting:
      screensDrawStatus("Connecting", linkConnected() ? "waiting for app" : "looking for phone");
      screen.showPartial();
      break;
    case State::Recording:
      screensDrawRecording(0, recordMode == RecordMode::Quick);
      screen.showPartial();
      break;
    case State::Ending:
      break;
    case State::Done:
      screensDrawDone();
      screen.showPartial();
      break;
    case State::Error:
      screensDrawError(errorMessage);
      screen.showPartial();
      break;
  }
}

void voicenoteBusyYield() {
  linkUpdate();
}

void sendHello() {
  if (!linkConnected()) {
    helloNeeded = true;
    return;
  }
  helloNeeded = !linkSendHello(battery);
}

void scheduleRedraw(bool full = false) {
  if (state == State::Home) {
    redrawAt = millis() + 200;
    redrawFull |= full;
  }
}

void maybeRedraw() {
  if (redrawAt == 0 || millis() < redrawAt) {
    return;
  }
  redrawAt = 0;
  if (state == State::Home) {
    showHome(redrawFull);
  }
  redrawFull = false;
}

void fail(const char* message) {
  strncpy(errorMessage, message, sizeof(errorMessage) - 1);
  errorMessage[sizeof(errorMessage) - 1] = '\0';
  Serial.printf("error: %s\n", message);
  enter(State::Error);
}

void handleBattery() {
  if (millis() - lastBatteryCheckAt < BATTERY_CHECK_MS) {
    return;
  }
  lastBatteryCheckAt = millis();
  const int previous = battery;
  batteryLogSample();
  battery = batteryPercent();
  if ((battery < BATTERY_LOW_PERCENT) != (previous < BATTERY_LOW_PERCENT)) {
    Serial.printf("battery %d%%\n", battery);
    scheduleRedraw();
  }
}

void beginConnecting(RecordMode mode) {
  recordMode = mode;
  Serial.printf("connecting mode=%d\n", static_cast<int>(mode));
  enter(State::Connecting);
}

void startRecording() {
  if (!micStart()) {
    linkStreamClose();
    fail("Mic failed");
    return;
  }
  Serial.println("recording");
  enter(State::Recording);
}

void stopRecording() {
  Serial.printf("recorded %lu ms\n", static_cast<unsigned long>(millis() - stateEnteredAt));
  linkStreamClose();
  micStop();
  enter(State::Ending);
}

void cancelRecording() {
  linkStreamClose();
  micStop();
  enter(State::Home);
}

void handleLink() {
  if (linkJustConnected()) {
    Serial.println("phone connected");
    helloNeeded = true;
  }
  if (linkJustDisconnected()) {
    Serial.println("phone disconnected");
  }
  if (helloNeeded) {
    sendHello();
  }

  uint32_t utc = 0;
  int16_t tz = 0;
  if (linkTakeTime(utc, tz)) {
    timeApply(utc, tz);
    Serial.printf("time %lu tz=%d\n", static_cast<unsigned long>(utc), tz);
    sendHello();
  }

  const uint8_t* bits = nullptr;
  bool resetWallpaper = false;
  if (linkTakeWallpaper(bits, resetWallpaper)) {
    if (resetWallpaper) {
      wallpaperReset();
    } else {
      wallpaperSave(bits);
    }
    Serial.printf("wallpaper %s\n", resetWallpaper ? "reset" : "saved");
    scheduleRedraw(true);
    sendHello();
  }

  HomeData incoming;
  if (linkTakeHome(incoming)) {
    home = incoming;
    homeSave(home);
    Serial.printf("home: %u lines\n", home.count);
  }
}

void handleMonitor() {
  if (state != State::Home) {
    return;
  }
  if (linkStreamEnabled()) {
    lastActivityAt = millis();
    if (!micRunning()) {
      micStart();
    }
  } else if (micRunning()) {
    micStop();
  }
}

void drainMic() {
  uint8_t block[AdpcmBlockBytes];
  while (micReadBlock(block) == AdpcmBlockBytes) {
    if (linkStreamEnabled()) {
      linkStreamWrite(block, AdpcmBlockBytes);
    }
  }
}

void loopHome(ButtonEvent rec, ButtonEvent top) {
  if (rec == ButtonEvent::Double) {
    beginConnecting(RecordMode::FreeFlow);
    return;
  }
  if (rec == ButtonEvent::Hold) {
    beginConnecting(RecordMode::Quick);
    return;
  }
  if (top == ButtonEvent::Single) {
    showHome();
    sendHello();
  }
  if (millis() - lastActivityAt >= IDLE_AWAKE_MS && !linkStreamEnabled()) {
    goToSleep();
  }
}

void loopConnecting(ButtonEvent rec) {
  const bool cancelled = recordMode == RecordMode::Quick
                             ? !recButton.pressed()
                             : (rec == ButtonEvent::Single || rec == ButtonEvent::Double);
  if (cancelled) {
    Serial.println("connect cancelled");
    cancelRecording();
    return;
  }
  if (linkStreamEnabled()) {
    startRecording();
    return;
  }
  if (linkConnected() && !linkStreamOpened()) {
    linkStreamOpen();
  }
  if (millis() - stateEnteredAt >= CONNECT_TIMEOUT_MS) {
    linkStreamClose();
    fail(linkConnected() ? "App not ready" : "No phone");
    return;
  }
  if (millis() - lastScreenTickAt >= 1000) {
    lastScreenTickAt = millis();
    screensDrawStatus("Connecting", linkConnected() ? "waiting for app" : "looking for phone");
    screen.showPartial();
  }
}

void loopRecording(ButtonEvent rec) {
  const uint32_t elapsed = millis() - stateEnteredAt;
  if (!linkStreamEnabled()) {
    micStop();
    fail("Disconnected");
    return;
  }
  bool stop = false;
  if (recordMode == RecordMode::Quick) {
    if (rec == ButtonEvent::Release || !recButton.pressed()) {
      if (elapsed < QUICK_REC_MIN_MS) {
        cancelRecording();
        return;
      }
      stop = true;
    }
  } else if (rec == ButtonEvent::Single || rec == ButtonEvent::Double || rec == ButtonEvent::Hold) {
    stop = true;
  }
  if (elapsed >= REC_MAX_MS) {
    stop = true;
  }
  if (stop) {
    stopRecording();
    return;
  }
  if (millis() - lastScreenTickAt >= REC_SCREEN_TICK_MS) {
    lastScreenTickAt = millis();
    screensDrawRecording(elapsed, recordMode == RecordMode::Quick);
    screen.showPartial();
  }
}

void loopEnding() {
  if (!linkConnected()) {
    fail("Disconnected");
    return;
  }
  bool acked = false;
  if (linkTakeStreamClosed(acked)) {
    Serial.printf("stream closed acked=%d\n", acked ? 1 : 0);
    if (acked) {
      enter(State::Done);
    } else {
      fail("Disconnected");
    }
    return;
  }
  if (millis() - stateEnteredAt >= END_ACK_TIMEOUT_MS) {
    fail("No ack");
  }
}

void loopDone() {
  if (millis() - stateEnteredAt >= DONE_SHOW_MS) {
    enter(State::Home);
  }
}

void loopError(ButtonEvent rec, ButtonEvent top) {
  if (top == ButtonEvent::Single || top == ButtonEvent::Double) {
    enter(State::Home);
    return;
  }
  if (rec == ButtonEvent::Double) {
    beginConnecting(RecordMode::FreeFlow);
    return;
  }
  if (rec == ButtonEvent::Hold) {
    beginConnecting(RecordMode::Quick);
    return;
  }
  if (millis() - stateEnteredAt >= ERROR_AWAKE_MS) {
    enter(State::Home);
  }
}

}  // namespace

void setup() {
  Serial.begin(115200);
  powerBegin();
  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN, 400000);
  homeLoad(home);
  wallpaperLoad();
  const WakeCause wake = powerWakeCause();
  recButton.reset(wake == WakeCause::Button);
  topButton.reset(wake == WakeCause::Button);
  batteryLogSample();
  battery = batteryPercent();

  Serial.printf("\nVoiceNote %s wake=%d bat=%d%% %dmV psram=%u KB\n", FW_VERSION, static_cast<int>(wake), battery,
                batteryMillivolts(), static_cast<unsigned>(ESP.getFreePsram() / 1024));
  batteryLogPrint();

  linkBegin();
  if (wake == WakeCause::Cold) {
    enter(State::Home);
  } else {
    state = State::Home;
    lastActivityAt = millis();
  }
}

void loop() {
  linkUpdate();
  const ButtonEvent rec = recButton.update();
  const ButtonEvent top = topButton.update();
  if (rec != ButtonEvent::None || top != ButtonEvent::None || linkTakeActivity()) {
    lastActivityAt = millis();
  }
  const bool busy = state == State::Connecting || state == State::Recording || state == State::Ending || micRunning();
  powerSetBoost(busy);
  linkLowPower(!busy);
  handleLink();
  handleBattery();
  handleMonitor();
  drainMic();

  switch (state) {
    case State::Home:
      loopHome(rec, top);
      break;
    case State::Connecting:
      loopConnecting(rec);
      break;
    case State::Recording:
      loopRecording(rec);
      break;
    case State::Ending:
      loopEnding();
      break;
    case State::Done:
      loopDone();
      break;
    case State::Error:
      loopError(rec, top);
      break;
  }
  maybeRedraw();
  delay(2);
}
