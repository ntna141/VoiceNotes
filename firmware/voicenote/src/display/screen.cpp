#include "screen.h"

#include <Arduino.h>
#include <string.h>

#include "../../config.h"

namespace {

constexpr int FrameBytes = EPD_WIDTH * EPD_HEIGHT / 8;

}  // namespace

Screen screen;

Screen::Screen() : Adafruit_GFX(EPD_WIDTH, EPD_HEIGHT) {}

void Screen::begin() {
  if (_epd == nullptr) {
    custom_lcd_spi_t cfg = {};
    cfg.cs = EPD_CS_PIN;
    cfg.dc = EPD_DC_PIN;
    cfg.rst = EPD_RST_PIN;
    cfg.busy = EPD_BUSY_PIN;
    cfg.mosi = EPD_MOSI_PIN;
    cfg.scl = EPD_SCK_PIN;
    cfg.spi_host = EPD_SPI_HOST;
    cfg.buffer_len = FrameBytes;
    _epd = new epaper_driver_display(EPD_WIDTH, EPD_HEIGHT, cfg);
  }
  _epd->EPD_Init();
  _epd->EPD_Clear();
}

void Screen::loadBase() {
  _epd->EPD_LoadBaseImage();
  _epd->EPD_Init_Partial();
}

void Screen::drawPixel(int16_t x, int16_t y, uint16_t color) {
  if (x < 0 || y < 0 || x >= _width || y >= _height) {
    return;
  }
  int16_t t;
  switch (rotation) {
    case 1:
      t = x;
      x = WIDTH - 1 - y;
      y = t;
      break;
    case 2:
      x = WIDTH - 1 - x;
      y = HEIGHT - 1 - y;
      break;
    case 3:
      t = x;
      x = y;
      y = HEIGHT - 1 - t;
      break;
  }
  _epd->EPD_DrawColorPixel(x, y, color == SCREEN_WHITE ? DRIVER_COLOR_WHITE : DRIVER_COLOR_BLACK);
}

void Screen::clear() {
  _epd->EPD_Clear();
}

void Screen::showPartial() {
  _epd->EPD_DisplayPart();
}

void Screen::showFull() {
  _epd->EPD_Init();
  _epd->EPD_DisplayPartBaseImage();
  _epd->EPD_Init_Partial();
}

void Screen::sleep() {
  _epd->EPD_Sleep();
}
