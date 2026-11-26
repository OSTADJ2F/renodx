/*
 * Copyright (C) 2024 Carlos Lopez
 * SPDX-License-Identifier: MIT
 */

#pragma once

#include <algorithm>
#include <cstdint>

#include <deps/imgui/imgui.h>

// Devil May Cry 4 crimson and gunmetal panel colors for the settings in addon.cpp.
namespace dmc4_ui {

// Accent used for every setting tint and active status markers.
constexpr ImU32 CRIMSON_GLOW = IM_COL32(214, 30, 42, 255);
constexpr ImU32 OFF_WHITE = IM_COL32(246, 238, 234, 255);
// Dark steel for inactive status markers.
constexpr ImU32 GUNMETAL = IM_COL32(98, 108, 122, 255);

// 0xRRGGBB value for Setting::tint, which recolors sliders, buttons and section headers to the accent hue.
constexpr uint32_t TINT_CRIMSON = 0xB3121D;

inline ImU32 WithAlpha(ImU32 color, float alpha) {
  const float scaled = static_cast<float>((color >> IM_COL32_A_SHIFT) & 0xFF) * std::clamp(alpha, 0.f, 1.f);
  return (color & ~IM_COL32_A_MASK) | (static_cast<ImU32>(scaled) << IM_COL32_A_SHIFT);
}

}  // namespace dmc4_ui
