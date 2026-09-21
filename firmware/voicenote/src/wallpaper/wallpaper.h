#pragma once

#include <stddef.h>
#include <stdint.h>

#include "../../config.h"

constexpr size_t WallpaperStride = (EPD_WIDTH + 7) / 8;
constexpr size_t WallpaperBytes = WallpaperStride * EPD_HEIGHT;

bool wallpaperParse(const uint8_t* data, size_t len, const uint8_t*& bits, bool& reset);
void wallpaperLoad();
void wallpaperSave(const uint8_t* bits);
void wallpaperReset();
bool wallpaperPresent();
uint32_t wallpaperHash();
void wallpaperDraw();
