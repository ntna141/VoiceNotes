#pragma once

#include <stdint.h>

#include "../../config.h"

struct HomeData {
  char lines[HOME_MAX_LINES][HOME_MAX_LINE_CHARS + 1];
  uint8_t count;
};

void homeLoad(HomeData& data);
void homeSave(const HomeData& data);
bool homeParse(const char* text, HomeData& data);
