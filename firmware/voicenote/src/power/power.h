#pragma once

#include <stdint.h>

void powerBegin();
void powerDisplayOn();
void powerDisplayOff();
void powerAudioOn();
void powerAudioOff();
void powerSetBoost(bool boost);

int batteryMillivolts();
int batteryPercent();
void batteryLogSample();
void batteryLogPrint();
