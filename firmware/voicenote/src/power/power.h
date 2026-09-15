#pragma once

#include <stdint.h>

enum class WakeReason : uint8_t {
  PowerOn,
  RecButton,
  TopButton,
  Timer,
};

void powerBegin();
WakeReason powerWakeReason();
void powerDisplayOn();
void powerDisplayOff();
void powerAudioOn();
void powerAudioOff();
void powerDeepSleep(uint32_t timerSeconds);

int batteryPercent();
