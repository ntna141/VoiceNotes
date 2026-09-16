#include "icons.h"

#include <Preferences.h>
#include <string.h>

#include "mood_icons.h"

namespace {

constexpr char Namespace[] = "voicenote";
constexpr char KeyIcons[] = "icons";
constexpr char IconTag[4] = {'i', 'c', 'o', 0};

IconSet customSet;
bool customLoaded = false;

}  // namespace

bool iconsParse(const uint8_t* data, size_t len, IconSet& set, bool& reset) {
  if (data == nullptr || len < 4 || memcmp(data, IconTag, 4) != 0) {
    return false;
  }
  if (len == 4) {
    reset = true;
    return true;
  }
  if (len != 4 + IconSetBytes) {
    return false;
  }
  memcpy(set.icons, data + 4, IconSetBytes);
  reset = false;
  return true;
}

void iconsSave(const IconSet& set) {
  Preferences prefs;
  if (!prefs.begin(Namespace, false)) {
    return;
  }
  prefs.putBytes(KeyIcons, &set, sizeof(set));
  prefs.end();
  customSet = set;
  customLoaded = true;
}

void iconsReset() {
  Preferences prefs;
  if (prefs.begin(Namespace, false)) {
    prefs.remove(KeyIcons);
    prefs.end();
  }
  customLoaded = false;
}

void iconsLoad() {
  customLoaded = false;
  Preferences prefs;
  if (!prefs.begin(Namespace, true)) {
    return;
  }
  const size_t got = prefs.getBytes(KeyIcons, &customSet, sizeof(customSet));
  prefs.end();
  customLoaded = got == sizeof(customSet);
}

const uint8_t* iconFor(uint8_t mood) {
  if (mood < 1 || mood > PageMoodCount) {
    return nullptr;
  }
  return customLoaded ? customSet.icons[mood - 1] : MoodIcons[mood - 1];
}

uint32_t iconsHash() {
  uint32_t hash = 2166136261u;
  for (uint8_t mood = 1; mood <= PageMoodCount; ++mood) {
    const uint8_t* icon = iconFor(mood);
    for (int i = 0; i < PageIconBytes; ++i) {
      hash ^= icon[i];
      hash *= 16777619u;
    }
  }
  return hash;
}
