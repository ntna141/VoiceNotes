#pragma once

#include <stdint.h>

bool es8311Begin(uint32_t sampleRate, uint32_t mclkHz);
void es8311SetMicGainStep(uint8_t step);
void es8311Standby();
