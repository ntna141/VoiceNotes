#pragma once

#include <stddef.h>
#include <stdint.h>

bool timeParse(const uint8_t* data, size_t len, uint32_t& unixUtc, int16_t& tzMinutes);
void timeApply(uint32_t unixUtc, int16_t tzMinutes);
uint32_t timeNow();
bool timeSynced();
bool timeLocalDate(uint16_t& year, uint8_t& month, uint8_t& day, uint8_t& weekday);
uint32_t timeSecondsUntilLocalMidnight();
