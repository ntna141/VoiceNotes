#pragma once

#include <Adafruit_GFX.h>

#include "../bsp/epaper_driver_bsp.h"

constexpr uint16_t SCREEN_BLACK = 0;
constexpr uint16_t SCREEN_WHITE = 1;

class Screen : public Adafruit_GFX {
 public:
  Screen();
  void begin(bool restorePrevious);
  void drawPixel(int16_t x, int16_t y, uint16_t color) override;
  void clear();
  void showPartial();
  void showFull();
  void sleep();

 private:
  void save();
  epaper_driver_display* _epd = nullptr;
};

extern Screen screen;
