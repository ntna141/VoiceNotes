#include "es8311.h"

#include <Arduino.h>
#include <Wire.h>

#include "../../config.h"

namespace {

constexpr uint8_t RegReset = 0x00;
constexpr uint8_t RegClkMgr1 = 0x01;
constexpr uint8_t RegClkMgr2 = 0x02;
constexpr uint8_t RegClkMgr3 = 0x03;
constexpr uint8_t RegClkMgr4 = 0x04;
constexpr uint8_t RegClkMgr5 = 0x05;
constexpr uint8_t RegClkMgr6 = 0x06;
constexpr uint8_t RegClkMgr7 = 0x07;
constexpr uint8_t RegClkMgr8 = 0x08;
constexpr uint8_t RegSdpIn = 0x09;
constexpr uint8_t RegSdpOut = 0x0A;
constexpr uint8_t RegSystem0D = 0x0D;
constexpr uint8_t RegSystem0E = 0x0E;
constexpr uint8_t RegSystem12 = 0x12;
constexpr uint8_t RegSystem13 = 0x13;
constexpr uint8_t RegSystem14 = 0x14;
constexpr uint8_t RegAdc16 = 0x16;
constexpr uint8_t RegAdc17 = 0x17;
constexpr uint8_t RegAdc1C = 0x1C;
constexpr uint8_t RegDac37 = 0x37;
constexpr uint8_t RegChipId1 = 0xFD;

bool writeReg(uint8_t reg, uint8_t value) {
  Wire.beginTransmission(ES8311_ADDR);
  Wire.write(reg);
  Wire.write(value);
  return Wire.endTransmission() == 0;
}

bool readReg(uint8_t reg, uint8_t& value) {
  Wire.beginTransmission(ES8311_ADDR);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) {
    return false;
  }
  if (Wire.requestFrom(ES8311_ADDR, 1) != 1) {
    return false;
  }
  value = Wire.read();
  return true;
}

bool updateReg(uint8_t reg, uint8_t mask, uint8_t bits) {
  uint8_t v;
  if (!readReg(reg, v)) {
    return false;
  }
  return writeReg(reg, (v & mask) | bits);
}

}  // namespace

bool es8311Begin(uint32_t sampleRate, uint32_t mclkHz) {
  if (mclkHz != sampleRate * 256) {
    return false;
  }
  uint8_t id;
  if (!readReg(RegChipId1, id) || id != 0x83) {
    return false;
  }

  bool ok = writeReg(RegReset, 0x1F);
  delay(20);
  ok &= writeReg(RegReset, 0x00);
  ok &= writeReg(RegReset, 0x80);

  ok &= writeReg(RegClkMgr1, 0x3F);
  ok &= updateReg(RegClkMgr6, 0xC0, 0x03);
  ok &= updateReg(RegClkMgr2, 0x07, 0x00);
  ok &= writeReg(RegClkMgr3, 0x10);
  ok &= writeReg(RegClkMgr4, 0x10);
  ok &= writeReg(RegClkMgr5, 0x00);
  ok &= updateReg(RegClkMgr7, 0xC0, 0x00);
  ok &= writeReg(RegClkMgr8, 0xFF);

  ok &= updateReg(RegReset, 0xBF, 0x00);
  ok &= writeReg(RegSdpIn, 0x0C);
  ok &= writeReg(RegSdpOut, 0x0C);

  ok &= writeReg(RegSystem0D, 0x01);
  ok &= writeReg(RegSystem0E, 0x02);
  ok &= writeReg(RegSystem12, 0x02);
  ok &= writeReg(RegSystem13, 0x00);
  ok &= writeReg(RegAdc1C, 0x6A);
  ok &= writeReg(RegDac37, 0x08);

  ok &= writeReg(RegAdc17, 0xC8);
  ok &= writeReg(RegSystem14, 0x1A);
  es8311SetMicGainStep(MIC_ANALOG_GAIN_STEP);
  return ok;
}

void es8311SetMicGainStep(uint8_t step) {
  if (step > 7) {
    step = 7;
  }
  writeReg(RegAdc16, step);
}

void es8311Standby() {
  writeReg(RegAdc17, 0x00);
  writeReg(RegSystem0E, 0xFF);
  writeReg(RegSystem12, 0x02);
  writeReg(RegSystem14, 0x00);
  writeReg(RegSystem0D, 0xFA);
  writeReg(RegClkMgr1, 0x00);
}
