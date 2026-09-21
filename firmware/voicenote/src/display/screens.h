#pragma once

#include <stdint.h>

#include "../home/home.h"

void screensDrawHome(const HomeData& data, int batteryPercent);
void screensDrawLowBattery(int16_t x, int16_t y);
void screensDrawBattery(int16_t x, int16_t y, int percent);
void screensDrawRecording(uint32_t elapsedMs, bool quick);
void screensDrawStatus(const char* title, const char* subtitle);
void screensDrawDone();
void screensDrawError(const char* message);
