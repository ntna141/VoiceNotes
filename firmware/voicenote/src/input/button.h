#pragma once

#include <stdint.h>

enum class ButtonEvent : uint8_t {
  None,
  Single,
  Double,
  Hold,
  Release,
};

class Button {
 public:
  explicit Button(uint8_t pin);
  ButtonEvent update();
  bool isDown() const;
  bool pressed() const { return _down; }
  void reset();

 private:
  uint8_t _pin;
  bool _down = false;
  bool _holdFired = false;
  uint8_t _clicks = 0;
  uint32_t _changedAt = 0;
  uint32_t _pressedAt = 0;
  uint32_t _releasedAt = 0;
};
