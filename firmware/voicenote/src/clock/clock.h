#pragma once

#include <stddef.h>
#include <stdint.h>

bool timeParse(const uint8_t* data, size_t len, uint32_t& unixUtc, int16_t& tzMinutes);
void timeApply(uint32_t unixUtc, int16_t tzMinutes);
uint32_t timeNow();
uint32_t timeSecondsToMidnight();
bool timeSynced();
