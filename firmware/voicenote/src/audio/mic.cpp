#include "mic.h"

#include <Arduino.h>
#include <ESP_I2S.h>
#include <freertos/FreeRTOS.h>
#include <freertos/stream_buffer.h>
#include <freertos/task.h>

#include "../../config.h"
#include "../power/power.h"
#include "adpcm.h"
#include "es8311.h"

namespace {

constexpr size_t QueueBlocks = 64;
constexpr uint32_t ReadTimeoutMs = 100;

I2SClass i2s;
AdpcmEncoder encoder;
StreamBufferHandle_t queue = nullptr;
TaskHandle_t task = nullptr;
volatile bool running = false;
volatile bool stopRequested = false;

void captureTask(void*) {
  static int16_t pcm[ADPCM_BLOCK_SAMPLES];
  static uint8_t block[AdpcmBlockBytes];
  size_t filled = 0;
  while (!stopRequested) {
    const size_t want = sizeof(pcm) - filled;
    const size_t got = i2s.readBytes(reinterpret_cast<char*>(pcm) + filled, want);
    filled += got;
    if (filled < sizeof(pcm)) {
      continue;
    }
    filled = 0;
    encoder.encodeBlock(pcm, block);
    xStreamBufferSend(queue, block, AdpcmBlockBytes, 0);
  }
  running = false;
  vTaskDelete(nullptr);
}

}  // namespace

bool micStart() {
  if (running) {
    return true;
  }
  powerAudioOn();
  i2s.setPins(I2S_BCLK_PIN, I2S_WS_PIN, I2S_DOUT_PIN, I2S_DIN_PIN, I2S_MCLK_PIN);
  if (!i2s.begin(I2S_MODE_STD, SAMPLE_RATE, I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_MONO,
                 I2S_STD_SLOT_LEFT)) {
    powerAudioOff();
    return false;
  }
  i2s.setTimeout(ReadTimeoutMs);
  delay(10);
  if (!es8311Begin(SAMPLE_RATE, SAMPLE_RATE * 256)) {
    i2s.end();
    powerAudioOff();
    return false;
  }
  encoder.reset();
  queue = xStreamBufferCreate(QueueBlocks * AdpcmBlockBytes, 1);
  if (queue == nullptr) {
    i2s.end();
    powerAudioOff();
    return false;
  }
  stopRequested = false;
  running = true;
  if (xTaskCreatePinnedToCore(captureTask, "mic", 6144, nullptr, 5, &task, 0) != pdPASS) {
    running = false;
    vStreamBufferDelete(queue);
    queue = nullptr;
    i2s.end();
    powerAudioOff();
    return false;
  }
  return true;
}

void micStop() {
  if (!running && queue == nullptr) {
    return;
  }
  stopRequested = true;
  const uint32_t start = millis();
  while (running && millis() - start < 500) {
    delay(5);
  }
  i2s.end();
  es8311Standby();
  powerAudioOff();
  if (queue != nullptr) {
    vStreamBufferDelete(queue);
    queue = nullptr;
  }
  task = nullptr;
}

bool micRunning() {
  return running;
}

size_t micReadBlock(uint8_t* out) {
  if (queue == nullptr || xStreamBufferBytesAvailable(queue) < AdpcmBlockBytes) {
    return 0;
  }
  return xStreamBufferReceive(queue, out, AdpcmBlockBytes, 0);
}
