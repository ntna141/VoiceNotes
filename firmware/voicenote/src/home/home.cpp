#include "home.h"

#include <Preferences.h>
#include <string.h>

namespace {

constexpr char Namespace[] = "voicenote";
constexpr char KeyLines[] = "lines";

const char* nextLine(const char* p, char* out, size_t outSize) {
  if (p == nullptr || *p == '\0') {
    return nullptr;
  }
  const char* end = strchr(p, '\n');
  size_t len = end ? static_cast<size_t>(end - p) : strlen(p);
  if (len >= outSize) {
    len = outSize - 1;
  }
  memcpy(out, p, len);
  out[len] = '\0';
  return end ? end + 1 : p + strlen(p);
}

void splitLines(const char* p, HomeData& data) {
  data.count = 0;
  while (p != nullptr && data.count < HOME_MAX_LINES) {
    p = nextLine(p, data.lines[data.count], sizeof(data.lines[0]));
    if (p == nullptr) {
      break;
    }
    if (data.lines[data.count][0] != '\0') {
      data.count++;
    }
  }
}

}  // namespace

void homeLoad(HomeData& data) {
  memset(&data, 0, sizeof(data));
  Preferences prefs;
  if (!prefs.begin(Namespace, true)) {
    return;
  }
  String lines = prefs.getString(KeyLines, "");
  prefs.end();
  splitLines(lines.c_str(), data);
}

void homeSave(const HomeData& data) {
  Preferences prefs;
  if (!prefs.begin(Namespace, false)) {
    return;
  }
  String joined;
  for (uint8_t i = 0; i < data.count; ++i) {
    joined += data.lines[i];
    joined += '\n';
  }
  prefs.putString(KeyLines, joined);
  prefs.end();
}

bool homeParse(const char* text, HomeData& data) {
  char field[HOME_MAX_LINE_CHARS + 1];
  const char* p = nextLine(text, field, sizeof(field));
  if (p == nullptr || strcmp(field, "home") != 0) {
    return false;
  }
  splitLines(p, data);
  return true;
}
