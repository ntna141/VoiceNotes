#include "wallpaper.h"

#include <LittleFS.h>
#include <string.h>

#include "../display/screen.h"

namespace {

constexpr char Path[] = "/wallpaper.bin";
constexpr char WallpaperTag[4] = {'w', 'a', 'l', 0};

uint8_t current[WallpaperBytes];
bool present = false;
bool mounted = false;

bool mount() {
  if (!mounted) {
    mounted = LittleFS.begin(true);
  }
  return mounted;
}

}  // namespace

bool wallpaperParse(const uint8_t* data, size_t len, const uint8_t*& bits, bool& reset) {
  if (data == nullptr || len < 4 || memcmp(data, WallpaperTag, 4) != 0) {
    return false;
  }
  if (len == 4) {
    reset = true;
    bits = nullptr;
    return true;
  }
  if (len != 4 + WallpaperBytes) {
    return false;
  }
  reset = false;
  bits = data + 4;
  return true;
}

void wallpaperLoad() {
  present = false;
  if (!mount()) {
    return;
  }
  File file = LittleFS.open(Path, FILE_READ);
  if (!file) {
    return;
  }
  const size_t got = file.read(current, WallpaperBytes);
  file.close();
  present = got == WallpaperBytes;
}

void wallpaperSave(const uint8_t* bits) {
  memcpy(current, bits, WallpaperBytes);
  present = true;
  if (!mount()) {
    return;
  }
  File file = LittleFS.open(Path, FILE_WRITE);
  if (!file) {
    return;
  }
  file.write(current, WallpaperBytes);
  file.close();
}

void wallpaperReset() {
  present = false;
  if (mount()) {
    LittleFS.remove(Path);
  }
}

bool wallpaperPresent() {
  return present;
}

uint32_t wallpaperHash() {
  if (!present) {
    return 0;
  }
  uint32_t hash = 2166136261u;
  for (size_t i = 0; i < WallpaperBytes; ++i) {
    hash ^= current[i];
    hash *= 16777619u;
  }
  return hash;
}

void wallpaperDraw() {
  screen.clear();
  if (!present) {
    return;
  }
  for (int16_t y = 0; y < EPD_HEIGHT; ++y) {
    const uint8_t* row = current + y * WallpaperStride;
    for (int16_t x = 0; x < EPD_WIDTH; ++x) {
      if (row[x / 8] & (0x80 >> (x % 8))) {
        screen.drawPixel(x, y, SCREEN_BLACK);
      }
    }
  }
}
