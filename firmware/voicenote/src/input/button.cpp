#include "button.h"

#include <Arduino.h>

#include "../../config.h"

Button::Button(uint8_t pin) : _pin(pin) {}

bool Button::isDown() const {
  return digitalRead(_pin) == LOW;
}

void Button::reset(bool wakePress) {
  _down = isDown();
  _holdFired = _down && !wakePress;
  _pressedAt = 0;
  _clicks = 0;
  _changedAt = millis();
}

ButtonEvent Button::update() {
  const uint32_t now = millis();
  const bool raw = isDown();

  if (raw != _down && now - _changedAt >= BTN_DEBOUNCE_MS) {
    _down = raw;
    _changedAt = now;
    if (_down) {
      _pressedAt = now;
      _holdFired = false;
    } else {
      if (_holdFired) {
        return ButtonEvent::Release;
      }
      _clicks++;
      _releasedAt = now;
      if (_clicks >= 2) {
        _clicks = 0;
        return ButtonEvent::Double;
      }
    }
  }

  if (_down && !_holdFired && now - _pressedAt >= BTN_HOLD_MS) {
    _holdFired = true;
    _clicks = 0;
    return ButtonEvent::Hold;
  }

  if (!_down && _clicks == 1 && now - _releasedAt >= BTN_DOUBLE_MS) {
    _clicks = 0;
    return ButtonEvent::Single;
  }

  return ButtonEvent::None;
}
