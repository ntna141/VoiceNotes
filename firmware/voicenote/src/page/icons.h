#pragma once

#include <stddef.h>
#include <stdint.h>

#include "page.h"

constexpr size_t IconSetBytes = PageMoodCount * PageIconBytes;

struct IconSet {
  uint8_t icons[PageMoodCount][PageIconBytes];
} __attribute__((packed));

bool iconsParse(const uint8_t* data, size_t len, IconSet& set, bool& reset);
void iconsSave(const IconSet& set);
void iconsReset();
void iconsLoad();
const uint8_t* iconFor(uint8_t mood);
uint32_t iconsHash();
