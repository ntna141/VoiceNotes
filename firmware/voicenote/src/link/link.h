#pragma once

#include <stddef.h>
#include <stdint.h>

#include "../home/home.h"
#include "../page/icons.h"
#include "../page/page.h"

bool linkBegin();
void linkEnd();
void linkUpdate();
bool linkConnected();
bool linkJustConnected();
bool linkJustDisconnected();
bool linkTakeActivity();
void linkLowPower(bool enabled);

bool linkSendHello(int batteryPercent, const Page& page);
bool linkTakeHome(HomeData& data);
bool linkTakePage(Page& page, uint32_t& unixUtc, int16_t& tzMinutes, bool& force);
bool linkTakeMood(uint16_t& year, uint8_t& month, uint8_t& day, uint8_t& mood);
bool linkTakeTime(uint32_t& unixUtc, int16_t& tzMinutes);
bool linkTakeIcons(IconSet& set, bool& reset);

bool linkStreamOpen();
bool linkStreamOpened();
bool linkStreamEnabled();
void linkStreamWrite(const uint8_t* block, size_t len);
void linkStreamClose();
bool linkTakeStreamClosed(bool& acked);
