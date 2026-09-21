#pragma once

#include <stddef.h>
#include <stdint.h>

#include "../home/home.h"

bool linkBegin();
void linkEnd();
void linkUpdate();
bool linkConnected();
bool linkJustConnected();
bool linkJustDisconnected();
bool linkTakeActivity();
void linkLowPower(bool enabled);

bool linkSendHello(int batteryPercent);
bool linkTakeHome(HomeData& data);
bool linkTakeTime(uint32_t& unixUtc, int16_t& tzMinutes);
bool linkTakeWallpaper(const uint8_t*& bits, bool& reset);

bool linkStreamOpen();
bool linkStreamOpened();
bool linkStreamEnabled();
void linkStreamWrite(const uint8_t* block, size_t len);
void linkStreamClose();
bool linkTakeStreamClosed(bool& acked);
