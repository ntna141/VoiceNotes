#pragma once

#include <stddef.h>
#include <stdint.h>

constexpr int PageIconSize = 26;
constexpr int PageIconGap = 2;
constexpr int PageIconStride = (PageIconSize + 7) / 8;
constexpr int PageIconBytes = PageIconStride * PageIconSize;
constexpr int PageMaxDays = 31;
constexpr int PageMoodCount = 5;
constexpr size_t PageWireBytes = 17 + PageMaxDays;
constexpr size_t MoodWireBytes = 9;

struct Page {
  uint16_t year;
  uint8_t month;
  uint8_t today;
  uint8_t firstWeekday;
  uint8_t daysInMonth;
  uint8_t moods[PageMaxDays];
  uint32_t dirty;
} __attribute__((packed));

bool pageParse(const uint8_t* data, size_t len, Page& page, uint32_t& unixUtc, int16_t& tzMinutes, bool& force);
void pageMerge(Page& page, const Page& incoming, bool force);
bool moodParse(const uint8_t* data, size_t len, uint16_t& year, uint8_t& month, uint8_t& day, uint8_t& mood);
bool pageSetMood(Page& page, uint16_t year, uint8_t month, uint8_t day, uint8_t mood);
void pageSave(const Page& page);
bool pageLoad(Page& page);
void pageClear(Page& page);
bool pageFromClock(Page& page);
void pageDraw(const Page& page, int batteryPercent);
bool pageAdvanceDay(Page& page);
bool pageValid(const Page& page);
uint8_t pageTodayMood(const Page& page);
void pageSetTodayMood(Page& page, uint8_t mood);
void pageBlitIcon(int16_t x, int16_t y, const uint8_t* icon);
