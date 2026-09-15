#pragma once

#include <stddef.h>
#include <stdint.h>

constexpr int PageIconSize = 26;
constexpr int PageIconGap = 2;
constexpr int PageIconStride = (PageIconSize + 7) / 8;
constexpr int PageIconBytes = PageIconStride * PageIconSize;
constexpr int PageMaxDays = 31;
constexpr int PageMoodCount = 5;
constexpr size_t PageWireBytes = 16 + PageMaxDays;

struct Page {
  uint16_t year;
  uint8_t month;
  uint8_t today;
  uint8_t firstWeekday;
  uint8_t daysInMonth;
  uint8_t moods[PageMaxDays];
} __attribute__((packed));

bool pageParse(const uint8_t* data, size_t len, Page& page, uint32_t& unixUtc, int16_t& tzMinutes);
void pageSave(const Page& page);
bool pageLoad(Page& page);
void pageClear(Page& page);
void pageDraw(const Page& page, int batteryPercent);
bool pageAdvanceDay(Page& page);
bool pageValid(const Page& page);
uint8_t pageTodayMood(const Page& page);
void pageSetTodayMood(Page& page, uint8_t mood);
void pageBlitIcon(int16_t x, int16_t y, const uint8_t* icon);
