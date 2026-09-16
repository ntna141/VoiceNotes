#include "page.h"

#include <Arduino.h>
#include <Preferences.h>
#include <string.h>

#include "../../config.h"
#include "../clock/clock.h"
#include "../display/screen.h"
#include "../display/screens.h"
#include "icons.h"

namespace {

constexpr char Namespace[] = "voicenote";
constexpr char KeyPage[] = "page";
constexpr char PageTag[4] = {'p', 'a', 'g', 0};
constexpr char MoodTag[4] = {'m', 'o', 'd', 0};

uint32_t readU32(const uint8_t* p) {
  return static_cast<uint32_t>(p[0]) | (static_cast<uint32_t>(p[1]) << 8) |
         (static_cast<uint32_t>(p[2]) << 16) | (static_cast<uint32_t>(p[3]) << 24);
}

uint16_t readU16(const uint8_t* p) {
  return static_cast<uint16_t>(p[0]) | (static_cast<uint16_t>(p[1]) << 8);
}

int16_t readI16(const uint8_t* p) {
  return static_cast<int16_t>(readU16(p));
}

uint8_t monthLength(uint16_t year, uint8_t month) {
  static const uint8_t days[] = {0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
  if (month < 1 || month > 12) {
    return 0;
  }
  if (month == 2 && ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0)) {
    return 29;
  }
  return days[month];
}

bool iconBit(const uint8_t* icon, int x, int y) {
  const int byteIndex = y * PageIconStride + (x / 8);
  const int bit = 7 - (x % 8);
  return (icon[byteIndex] & (1 << bit)) != 0;
}

void drawDot(int16_t x, int16_t y) {
  screen.fillRect(x + 12, y + 12, 2, 2, SCREEN_BLACK);
}

void drawToday(int16_t x, int16_t y) {
  screen.fillRect(x + 6, y + PageIconSize + 1, 14, 2, SCREEN_BLACK);
}

}  // namespace

void pageBlitIcon(int16_t x, int16_t y, const uint8_t* icon) {
  if (icon == nullptr) {
    return;
  }
  for (int row = 0; row < PageIconSize; ++row) {
    for (int col = 0; col < PageIconSize; ++col) {
      if (iconBit(icon, col, row)) {
        screen.drawPixel(x + col, y + row, SCREEN_BLACK);
      }
    }
  }
}

bool pageParse(const uint8_t* data, size_t len, Page& page, uint32_t& unixUtc, int16_t& tzMinutes, bool& force) {
  if (data == nullptr || len != PageWireBytes || memcmp(data, PageTag, 4) != 0) {
    return false;
  }
  unixUtc = readU32(data + 4);
  tzMinutes = readI16(data + 8);
  pageClear(page);
  page.year = readU16(data + 10);
  page.month = data[12];
  page.today = data[13];
  page.firstWeekday = data[14];
  page.daysInMonth = data[15];
  force = (data[16] & 0x01) != 0;
  memcpy(page.moods, data + 17, PageMaxDays);
  if (!pageValid(page) || unixUtc == 0) {
    pageClear(page);
    return false;
  }
  for (int i = 0; i < PageMaxDays; ++i) {
    if (page.moods[i] > PageMoodCount) {
      page.moods[i] = 0;
    }
  }
  return true;
}

void pageMerge(Page& page, const Page& incoming, bool force) {
  Page merged = incoming;
  merged.dirty = 0;
  if (!force && pageValid(page) && page.year == incoming.year && page.month == incoming.month) {
    for (int i = 0; i < PageMaxDays; ++i) {
      const uint32_t bit = 1u << i;
      if ((page.dirty & bit) != 0 && page.moods[i] != incoming.moods[i]) {
        merged.moods[i] = page.moods[i];
        merged.dirty |= bit;
      }
    }
  }
  page = merged;
}

bool moodParse(const uint8_t* data, size_t len, uint16_t& year, uint8_t& month, uint8_t& day, uint8_t& mood) {
  if (data == nullptr || len != MoodWireBytes || memcmp(data, MoodTag, 4) != 0) {
    return false;
  }
  year = readU16(data + 4);
  month = data[6];
  day = data[7];
  mood = data[8];
  return month >= 1 && month <= 12 && day >= 1 && day <= PageMaxDays && mood <= PageMoodCount;
}

bool pageSetMood(Page& page, uint16_t year, uint8_t month, uint8_t day, uint8_t mood) {
  if (!pageValid(page) || page.year != year || page.month != month || day < 1 || day > page.daysInMonth ||
      mood > PageMoodCount) {
    return false;
  }
  page.moods[day - 1] = mood;
  page.dirty &= ~(1u << (day - 1));
  return true;
}

void pageSave(const Page& page) {
  Preferences prefs;
  if (!prefs.begin(Namespace, false)) {
    return;
  }
  prefs.putBytes(KeyPage, &page, sizeof(page));
  prefs.end();
}

bool pageLoad(Page& page) {
  pageClear(page);
  Preferences prefs;
  if (!prefs.begin(Namespace, true)) {
    return false;
  }
  const size_t got = prefs.getBytes(KeyPage, &page, sizeof(page));
  prefs.end();
  if (got != sizeof(page) || !pageValid(page)) {
    pageClear(page);
    return false;
  }
  return true;
}

void pageClear(Page& page) {
  memset(&page, 0, sizeof(page));
}

bool pageFromClock(Page& page) {
  uint16_t year = 0;
  uint8_t month = 0;
  uint8_t day = 0;
  uint8_t weekday = 0;
  if (!timeLocalDate(year, month, day, weekday)) {
    return false;
  }
  pageClear(page);
  page.year = year;
  page.month = month;
  page.today = day;
  page.daysInMonth = monthLength(year, month);
  int first = static_cast<int>(weekday) - (static_cast<int>(day) - 1);
  first %= 7;
  if (first < 0) {
    first += 7;
  }
  page.firstWeekday = static_cast<uint8_t>(first);
  return pageValid(page);
}

void pageDraw(const Page& page, int batteryPercent) {
  screen.clear();
  if (!pageValid(page)) {
    return;
  }
  const int rows = (page.firstWeekday + page.daysInMonth + 6) / 7;
  const int16_t gapX = (EPD_WIDTH - 7 * PageIconSize) / 6;
  int16_t gapY = 8;
  int16_t gridH = rows * PageIconSize + (rows - 1) * gapY;
  while (gridH > EPD_HEIGHT - 16 && gapY > gapX) {
    gapY--;
    gridH = rows * PageIconSize + (rows - 1) * gapY;
  }
  const int16_t originX = (EPD_WIDTH - 7 * PageIconSize - 6 * gapX) / 2;
  const int16_t originY = (EPD_HEIGHT - gridH) / 2;
  const int16_t stepX = PageIconSize + gapX;
  const int16_t stepY = PageIconSize + gapY;
  for (uint8_t day = 1; day <= page.daysInMonth; ++day) {
    const int slot = page.firstWeekday + day - 1;
    const int col = slot % 7;
    const int row = slot / 7;
    if (row > 5) {
      continue;
    }
    const int16_t x = originX + col * stepX;
    const int16_t y = originY + row * stepY;
    const uint8_t mood = day <= page.today ? page.moods[day - 1] : 0;
    if (mood != 0) {
      pageBlitIcon(x, y, iconFor(mood));
    } else if (day != page.today) {
      drawDot(x, y);
    }
    if (day == page.today) {
      drawToday(x, y);
    }
  }
  if (batteryPercent < BATTERY_LOW_PERCENT) {
    screensDrawLowBattery(EPD_WIDTH - 6 - 22, EPD_HEIGHT - 6 - 11);
  }
}

bool pageAdvanceDay(Page& page) {
  if (!pageValid(page)) {
    return false;
  }
  page.today++;
  if (page.today <= page.daysInMonth) {
    return true;
  }
  page.firstWeekday = static_cast<uint8_t>((page.firstWeekday + page.daysInMonth) % 7);
  page.month++;
  if (page.month > 12) {
    page.month = 1;
    page.year++;
  }
  page.daysInMonth = monthLength(page.year, page.month);
  page.today = 1;
  memset(page.moods, 0, sizeof(page.moods));
  page.dirty = 0;
  return pageValid(page);
}

uint8_t pageTodayMood(const Page& page) {
  if (!pageValid(page)) {
    return 0;
  }
  return page.moods[page.today - 1];
}

void pageSetTodayMood(Page& page, uint8_t mood) {
  if (!pageValid(page) || mood > PageMoodCount) {
    return;
  }
  page.moods[page.today - 1] = mood;
  page.dirty |= 1u << (page.today - 1);
}

bool pageValid(const Page& page) {
  if (page.month < 1 || page.month > 12 || page.firstWeekday > 6) {
    return false;
  }
  const uint8_t days = monthLength(page.year, page.month);
  return days >= 28 && page.daysInMonth == days && page.today >= 1 && page.today <= days;
}
