#pragma once

#include <stddef.h>
#include <stdint.h>

#include "../../config.h"

constexpr size_t AdpcmBlockHeaderBytes = 4;
constexpr size_t AdpcmBlockBytes = AdpcmBlockHeaderBytes + ADPCM_BLOCK_SAMPLES / 2;

class AdpcmEncoder {
 public:
  void reset();
  void encodeBlock(int16_t* pcm, uint8_t* out);

 private:
  uint8_t encodeSample(int16_t sample);
  void condition(int16_t* pcm);

  int32_t _predictor = 0;
  int8_t _stepIndex = 0;
  int32_t _dcOffset = 0;
};
