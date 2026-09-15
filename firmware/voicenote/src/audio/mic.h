#pragma once

#include <stddef.h>
#include <stdint.h>

bool micStart();
void micStop();
bool micRunning();
size_t micReadBlock(uint8_t* out);
