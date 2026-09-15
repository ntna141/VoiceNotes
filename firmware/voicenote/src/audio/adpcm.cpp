#include "adpcm.h"

namespace {

const int8_t IndexTable[16] = {-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8};

const int16_t StepTable[89] = {
    7,     8,     9,     10,    11,    12,    13,    14,    16,    17,    19,    21,    23,
    25,    28,    31,    34,    37,    41,    45,    50,    55,    60,    66,    73,    80,
    88,    97,    107,   118,   130,   143,   157,   173,   190,   209,   230,   253,   279,
    307,   337,   371,   408,   449,   494,   544,   598,   658,   724,   796,   876,   963,
    1060,  1166,  1282,  1411,  1552,  1707,  1878,  2066,  2272,  2499,  2749,  3024,  3327,
    3660,  4026,  4428,  4871,  5358,  5894,  6484,  7132,  7845,  8630,  9493,  10442, 11487,
    12635, 13899, 15289, 16818, 18500, 20350, 22385, 24623, 27086, 29794, 32767};

}  // namespace

void AdpcmEncoder::reset() {
  _predictor = 0;
  _stepIndex = 0;
  _dcOffset = 0;
}

void AdpcmEncoder::condition(int16_t* pcm) {
  for (size_t i = 0; i < ADPCM_BLOCK_SAMPLES; ++i) {
    const int32_t x = pcm[i];
    _dcOffset += (x - _dcOffset) >> 8;
    int32_t y = (x - _dcOffset) * MIC_DIGITAL_GAIN;
    if (y > 32767) {
      y = 32767;
    } else if (y < -32768) {
      y = -32768;
    }
    pcm[i] = static_cast<int16_t>(y);
  }
}

uint8_t AdpcmEncoder::encodeSample(int16_t sample) {
  int32_t step = StepTable[_stepIndex];
  int32_t diff = sample - _predictor;
  uint8_t code = 0;
  if (diff < 0) {
    code = 8;
    diff = -diff;
  }
  int32_t delta = step >> 3;
  if (diff >= step) {
    code |= 4;
    diff -= step;
    delta += step;
  }
  step >>= 1;
  if (diff >= step) {
    code |= 2;
    diff -= step;
    delta += step;
  }
  step >>= 1;
  if (diff >= step) {
    code |= 1;
    delta += step;
  }
  _predictor += (code & 8) ? -delta : delta;
  if (_predictor > 32767) {
    _predictor = 32767;
  } else if (_predictor < -32768) {
    _predictor = -32768;
  }
  _stepIndex += IndexTable[code];
  if (_stepIndex < 0) {
    _stepIndex = 0;
  } else if (_stepIndex > 88) {
    _stepIndex = 88;
  }
  return code;
}

void AdpcmEncoder::encodeBlock(int16_t* pcm, uint8_t* out) {
  condition(pcm);
  out[0] = static_cast<uint8_t>(_predictor);
  out[1] = static_cast<uint8_t>(_predictor >> 8);
  out[2] = static_cast<uint8_t>(_stepIndex);
  out[3] = 0;
  for (size_t i = 0; i < ADPCM_BLOCK_SAMPLES; i += 2) {
    const uint8_t low = encodeSample(pcm[i]);
    const uint8_t high = encodeSample(pcm[i + 1]);
    out[AdpcmBlockHeaderBytes + i / 2] = low | (high << 4);
  }
}
