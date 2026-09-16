#pragma once

#include <stdint.h>

enum class WakeCause : uint8_t {
  Cold,
  Button,
  Timer,
};

void powerBegin();
WakeCause powerWakeCause();
void powerDeepSleep(uint32_t timerSeconds);
void powerDisplayOn();
void powerDisplayOff();
void powerAudioOn();
void powerAudioOff();
void powerSetBoost(bool boost);

int batteryMillivolts();
int batteryPercent();
void batteryLogSample();
void batteryLogPrint();
