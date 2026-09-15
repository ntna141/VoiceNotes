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
#include "src/page/icons.h"
#include "src/page/page.h"
#include "src/power/power.h"

namespace {

enum class State : uint8_t {
  Home,
  Connecting,
  Recording,
  Ending,
  Done,
  Error,
  MoodPick,
};

enum class RecordMode : uint8_t {
  None,
  Quick,
  FreeFlow,
};

Button recButton(BTN_REC_PIN);
Button topButton(BTN_TOP_PIN);
HomeData home;
Page page;
State state = State::Home;
RecordMode recordMode = RecordMode::None;
bool displayReady = false;
uint32_t stateEnteredAt = 0;
uint32_t lastActivityAt = 0;
uint32_t lastScreenTickAt = 0;
int battery = 0;
uint8_t moodSelection = 3;
char errorMessage[24];

void ensureDisplay() {
  if (displayReady) {
    return;
  }
  powerDisplayOn();
  screen.begin(true);
  displayReady = true;
}

void showHome() {
  ensureDisplay();
  battery = batteryPercent();
  if (pageValid(page)) {
    pageDraw(page, battery);
  } else {
    screensDrawHome(home, battery);
  }
  screen.showPartial();
}

void enter(State next) {
  state = next;
  stateEnteredAt = millis();
  lastScreenTickAt = millis();
  ensureDisplay();
  switch (state) {
    case State::Home:
      lastActivityAt = millis();
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
    case State::MoodPick:
      screensDrawMoodPick(moodSelection);
      screen.showPartial();
      break;
  }
}

void sendHello() {
  if (linkConnected()) {
    linkSendHello(battery, page);
  }
}

bool beginMoodPick() {
  if (!pageValid(page)) {
    return false;
  }
  const uint8_t current = pageTodayMood(page);
  moodSelection = current == 0 ? 3 : current;
  enter(State::MoodPick);
  return true;
}

void fail(const char* message) {
  strncpy(errorMessage, message, sizeof(errorMessage) - 1);
  errorMessage[sizeof(errorMessage) - 1] = '\0';
  Serial.printf("error: %s\n", message);
  enter(State::Error);
}

void goToSleep(uint32_t timerSeconds) {
  Serial.printf("sleep timer=%lus\n", static_cast<unsigned long>(timerSeconds));
  Serial.flush();
#if DEV_NO_SLEEP
  lastActivityAt = millis();
  return;
#endif
  micStop();
  linkEnd();
  if (displayReady) {
    screen.sleep();
  }
  powerDisplayOff();
  powerDeepSleep(timerSeconds);
}

void onTimerWake() {
  if (pageAdvanceDay(page)) {
    pageSave(page);
  }
  ensureDisplay();
  battery = batteryPercent();
  if (pageValid(page)) {
    pageDraw(page, battery);
  } else {
    screensDrawHome(home, battery);
  }
  screen.showFull();
  goToSleep(timeSecondsToMidnight());
}

RecordMode detectWakeGesture() {
  if (powerWakeReason() != WakeReason::RecButton) {
    return RecordMode::None;
  }
  while (recButton.isDown()) {
    if (millis() >= BTN_HOLD_MS) {
      return RecordMode::Quick;
    }
    delay(5);
  }
  const uint32_t releasedAt = millis();
  while (millis() - releasedAt < WAKE_GESTURE_WINDOW_MS) {
    if (recButton.isDown()) {
      delay(BTN_DEBOUNCE_MS);
      if (recButton.isDown()) {
        return RecordMode::FreeFlow;
      }
    }
    delay(5);
  }
  return RecordMode::None;
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
    sendHello();
    if (state == State::Home) {
      showHome();
    }
  }

  Page incomingPage;
  uint32_t utc = 0;
  int16_t tz = 0;
  if (linkTakePage(incomingPage, utc, tz)) {
    page = incomingPage;
    pageSave(page);
    timeApply(utc, tz);
    Serial.printf("page %u-%u-%u mood=%u\n", page.year, page.month, page.today, pageTodayMood(page));
    if (state == State::Home) {
      showHome();
    }
  }

  if (linkTakeTime(utc, tz)) {
    timeApply(utc, tz);
    Serial.printf("time %lu tz=%d\n", static_cast<unsigned long>(utc), tz);
  }

  IconSet incomingIcons;
  bool resetIcons = false;
  if (linkTakeIcons(incomingIcons, resetIcons)) {
    if (resetIcons) {
      iconsReset();
    } else {
      iconsSave(incomingIcons);
    }
    Serial.printf("icons %s\n", resetIcons ? "reset" : "saved");
    if (state == State::Home) {
      showHome();
    } else if (state == State::MoodPick) {
      screensDrawMoodPick(moodSelection);
      screen.showPartial();
    }
  }

  HomeData incoming;
  if (linkTakeHome(incoming)) {
    home = incoming;
    homeSave(home);
    Serial.printf("home: %u lines\n", home.count);
    if (state == State::Home && !pageValid(page)) {
      showHome();
    }
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
  if (top == ButtonEvent::Hold && beginMoodPick()) {
    return;
  }
  if (top == ButtonEvent::Single) {
    showHome();
    sendHello();
  }
  if (millis() - lastActivityAt >= IDLE_AWAKE_MS && !linkStreamEnabled()) {
    goToSleep(timeSecondsToMidnight());
  }
}

void loopMoodPick(ButtonEvent rec, ButtonEvent top) {
  if (top == ButtonEvent::Hold || millis() - stateEnteredAt >= MOOD_PICK_MS) {
    enter(State::Home);
    return;
  }
  if (top == ButtonEvent::Single) {
    pageSetTodayMood(page, moodSelection);
    pageSave(page);
    Serial.printf("mood set %u\n", moodSelection);
    sendHello();
    enter(State::Home);
    return;
  }
  uint8_t next = moodSelection;
  if (rec == ButtonEvent::Single) {
    next = moodSelection == PageMoodCount ? 1 : moodSelection + 1;
  } else if (rec == ButtonEvent::Double) {
    next = moodSelection == 1 ? PageMoodCount : moodSelection - 1;
  }
  if (next != moodSelection) {
    moodSelection = next;
    screensDrawMoodPick(moodSelection);
    screen.showPartial();
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
  if (top == ButtonEvent::Hold && beginMoodPick()) {
    return;
  }
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
  pageLoad(page);
  iconsLoad();

  if (powerWakeReason() == WakeReason::Timer) {
    onTimerWake();
  }

  const RecordMode gesture = detectWakeGesture();
  recButton.reset();
  topButton.reset();
  battery = batteryPercent();

  Serial.printf("\nVoiceNote %s wake=%d bat=%d%% psram=%u KB\n", FW_VERSION,
                static_cast<int>(powerWakeReason()), battery,
                static_cast<unsigned>(ESP.getFreePsram() / 1024));

  linkBegin();
  if (gesture != RecordMode::None) {
    beginConnecting(gesture);
  } else {
    enter(State::Home);
  }
}

void loop() {
  linkUpdate();
  const ButtonEvent rec = recButton.update();
  const ButtonEvent top = topButton.update();
  if (rec != ButtonEvent::None || top != ButtonEvent::None) {
    lastActivityAt = millis();
  }
  handleLink();
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
    case State::MoodPick:
      loopMoodPick(rec, top);
      break;
  }
  delay(2);
}
