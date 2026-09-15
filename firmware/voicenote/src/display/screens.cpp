#include "screens.h"

#include <Fonts/FreeSans9pt7b.h>
#include <Fonts/FreeSansBold12pt7b.h>
#include <Fonts/FreeSansBold24pt7b.h>
#include <stdio.h>
#include <string.h>

#include "../../config.h"
#include "../page/icons.h"
#include "screen.h"

namespace {

constexpr int16_t Margin = 6;
constexpr int16_t ListStartY = 22;
constexpr int16_t LineHeight = 21;

void setFont(const GFXfont* font) {
  screen.setFont(font);
  screen.setTextColor(SCREEN_BLACK);
  screen.setTextWrap(false);
}

int16_t textWidth(const char* text) {
  int16_t x1, y1;
  uint16_t w, h;
  screen.getTextBounds(text, 0, 0, &x1, &y1, &w, &h);
  return static_cast<int16_t>(w);
}

void drawCentered(const char* text, int16_t baselineY) {
  int16_t x = (EPD_WIDTH - textWidth(text)) / 2;
  screen.setCursor(x < 0 ? 0 : x, baselineY);
  screen.print(text);
}

void drawFitted(const char* text, int16_t x, int16_t baselineY, int16_t maxWidth) {
  char buf[HOME_MAX_LINE_CHARS + 1];
  strncpy(buf, text, sizeof(buf) - 1);
  buf[sizeof(buf) - 1] = '\0';
  size_t len = strlen(buf);
  while (len > 0 && textWidth(buf) > maxWidth) {
    buf[--len] = '\0';
  }
  screen.setCursor(x, baselineY);
  screen.print(buf);
}

void drawList(const HomeData& data, int16_t startY, uint8_t maxLines) {
  setFont(&FreeSans9pt7b);
  uint8_t count = data.count < maxLines ? data.count : maxLines;
  for (uint8_t i = 0; i < count; ++i) {
    drawFitted(data.lines[i], Margin, startY + i * LineHeight, EPD_WIDTH - 2 * Margin);
  }
}

}  // namespace

void screensDrawLowBattery(int16_t x, int16_t y) {
  screensDrawBattery(x, y, 0);
}

void screensDrawBattery(int16_t x, int16_t y, int percent) {
  const int16_t w = 22;
  const int16_t h = 11;
  screen.drawRect(x, y, w, h, SCREEN_BLACK);
  screen.fillRect(x + w, y + 3, 2, h - 6, SCREEN_BLACK);
  int16_t fill = static_cast<int16_t>((w - 2) * percent / 100);
  if (fill > 0) {
    if (fill > w - 2) {
      fill = w - 2;
    }
    screen.fillRect(x + 1, y + 1, fill, h - 2, SCREEN_BLACK);
  }
}

void screensDrawHome(const HomeData& data, int batteryPercent) {
  screen.clear();
  drawList(data, ListStartY, HOME_MAX_LINES);
  if (batteryPercent < 20) {
    screensDrawLowBattery(EPD_WIDTH - Margin - 22, EPD_HEIGHT - Margin - 11);
  }
}

void screensDrawRecording(uint32_t elapsedMs, bool quick) {
  screen.clear();
  screen.fillCircle(28, 26, 7, SCREEN_BLACK);
  setFont(&FreeSansBold12pt7b);
  screen.setCursor(44, 33);
  screen.print("REC");

  char clock[8];
  uint32_t seconds = elapsedMs / 1000;
  snprintf(clock, sizeof(clock), "%lu:%02lu", static_cast<unsigned long>(seconds / 60),
           static_cast<unsigned long>(seconds % 60));
  setFont(&FreeSansBold24pt7b);
  drawCentered(clock, 118);

  setFont(&FreeSans9pt7b);
  drawCentered(quick ? "release to stop" : "click to stop", 180);
}

void screensDrawStatus(const char* title, const char* subtitle) {
  screen.clear();
  setFont(&FreeSansBold12pt7b);
  drawCentered(title, 96);
  if (subtitle != nullptr) {
    setFont(&FreeSans9pt7b);
    drawCentered(subtitle, 124);
  }
}

void screensDrawDone() {
  screen.clear();
  for (int16_t i = -2; i <= 2; ++i) {
    screen.drawLine(60, 90 + i, 88, 118 + i, SCREEN_BLACK);
    screen.drawLine(88, 118 + i, 142, 62 + i, SCREEN_BLACK);
  }
  setFont(&FreeSansBold12pt7b);
  drawCentered("Sent", 160);
}

void screensDrawError(const char* message) {
  screen.clear();
  screen.drawCircle(100, 60, 26, SCREEN_BLACK);
  screen.drawCircle(100, 60, 25, SCREEN_BLACK);
  screen.fillRect(97, 44, 6, 20, SCREEN_BLACK);
  screen.fillRect(97, 69, 6, 6, SCREEN_BLACK);
  setFont(&FreeSansBold12pt7b);
  drawCentered(message, 122);
  setFont(&FreeSans9pt7b);
  drawCentered("top button to dismiss", 176);
}

void screensDrawMoodPick(uint8_t selected) {
  screen.clear();
  setFont(&FreeSansBold12pt7b);
  drawCentered("Today", 40);
  const int16_t gap = 8;
  const int16_t total = PageMoodCount * PageIconSize + (PageMoodCount - 1) * gap;
  const int16_t originX = (EPD_WIDTH - total) / 2;
  const int16_t y = (EPD_HEIGHT - PageIconSize) / 2;
  for (uint8_t mood = 1; mood <= PageMoodCount; ++mood) {
    const int16_t x = originX + (mood - 1) * (PageIconSize + gap);
    pageBlitIcon(x, y, iconFor(mood));
    if (mood == selected) {
      screen.drawRect(x - 4, y - 4, PageIconSize + 8, PageIconSize + 8, SCREEN_BLACK);
      screen.drawRect(x - 3, y - 3, PageIconSize + 6, PageIconSize + 6, SCREEN_BLACK);
    }
  }
  setFont(&FreeSans9pt7b);
  drawCentered("rec: next  top: set", 176);
}
