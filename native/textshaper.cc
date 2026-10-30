// Copyright (c) 2026 Hugo Delaunay. MIT license.
// The only exported ABI owns no persistent handles: calls are independent and
// HarfBuzz retains its normal threading support. Coordinates are y-down pixels.
#include "hb.h"
#include "hb-ot.h"
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

#if defined(_WIN32)
#define TS_EXPORT extern "C" __declspec(dllexport)
#else
#define TS_EXPORT extern "C" __attribute__((visibility("default")))
#endif

namespace {
constexpr size_t maximum_output = 16 * 1024 * 1024;
constexpr size_t maximum_commands = 262144;

// Resource destruction stays on the native side, including all early returns.
template<class T, void (*destroy)(T*)> using owned = std::unique_ptr<T, decltype(destroy)>;

char* copy_result(const std::string& value) {
  char* result = static_cast<char*>(std::malloc(value.size() + 1));
  if (result) std::memcpy(result, value.c_str(), value.size() + 1);
  return result;
}

// Formatting uses a fixed decimal point even when the process locale changes.
void number(std::string& output, double value) {
  char buffer[64];
  std::snprintf(buffer, sizeof(buffer), "%.9f", value == 0 ? 0 : value);
  for (char* p = buffer; *p; ++p) if (*p == ',') *p = '.';
  output += buffer;
}

struct Pen {
  std::string path;
  double scale;
  size_t commands = 0;
  bool failed = false;
  void point(double x, double y) {
    if (!std::isfinite(x) || !std::isfinite(y) || std::abs(x) > 1e10 || std::abs(y) > 1e10) { failed = true; return; }
    number(path, x * scale); path += ' '; number(path, -y * scale); path += ' ';
  }
  void verb(char value) {
    if (++commands > maximum_commands || path.size() > maximum_output) { failed = true; return; }
    path += value;
  }
};
void move(hb_draw_funcs_t*, void* data, hb_draw_state_t*, float x, float y, void*) {
  auto& pen = *static_cast<Pen*>(data); if (pen.failed) return; pen.verb('M'); pen.point(x, y);
}
void line(hb_draw_funcs_t*, void* data, hb_draw_state_t*, float x, float y, void*) {
  auto& pen = *static_cast<Pen*>(data); if (pen.failed) return; pen.verb('L'); pen.point(x, y);
}
void quadratic(hb_draw_funcs_t*, void* data, hb_draw_state_t*, float x1, float y1, float x2, float y2, void*) {
  auto& pen = *static_cast<Pen*>(data); if (pen.failed) return; pen.verb('Q'); pen.point(x1, y1); pen.point(x2, y2);
}
void cubic(hb_draw_funcs_t*, void* data, hb_draw_state_t*, float x1, float y1, float x2, float y2, float x3, float y3, void*) {
  auto& pen = *static_cast<Pen*>(data); if (pen.failed) return; pen.verb('C'); pen.point(x1, y1); pen.point(x2, y2); pen.point(x3, y3);
}
void close(hb_draw_funcs_t*, void* data, hb_draw_state_t*, void*) {
  auto& pen = *static_cast<Pen*>(data); if (!pen.failed) pen.verb('Z');
}
bool has_table(hb_face_t* face, hb_tag_t tag) {
  owned<hb_blob_t, hb_blob_destroy> table(hb_face_reference_table(face, tag), hb_blob_destroy);
  return hb_blob_get_length(table.get()) != 0;
}
// Lists are ASCII, validated by Dart, and bounded again at the native boundary.
template<class T, hb_bool_t (*parse)(const char*, int, T*)>
std::vector<T> parse_list(const char* text) {
  std::vector<T> result;
  if (!text) return result;
  const char* start = text;
  while (*start && result.size() < 128) {
    const char* end = std::strchr(start, ',');
    if (!end) end = start + std::strlen(start);
    T item;
    if (parse(start, static_cast<int>(end - start), &item)) result.push_back(item);
    start = *end ? end + 1 : end;
  }
  return result;
}
}

TS_EXPORT const char* textshaper_version() { return HB_VERSION_STRING; }
TS_EXPORT void textshaper_free(void* value) { std::free(value); }

// Returns bounded JSON; the caller releases it through textshaper_free.
TS_EXPORT char* textshaper_shape(const char* bytes, unsigned byte_count,
    unsigned face_index, const uint16_t* text, unsigned text_length,
    unsigned start, unsigned end, double size, const char* features,
    const char* variations, const char* direction, const char* script,
    const char* language, int draw) {
  if (!bytes || byte_count == 0 || byte_count > 16 * 1024 * 1024 || !text ||
      text_length > 65536 || start > end || end > text_length ||
      !std::isfinite(size) || size <= 0 || size > 10000)
    return copy_result("{\"error\":\"limits\"}");
  owned<hb_blob_t, hb_blob_destroy> blob(hb_blob_create(bytes, byte_count, HB_MEMORY_MODE_READONLY, nullptr, nullptr), hb_blob_destroy);
  owned<hb_face_t, hb_face_destroy> face(hb_face_create(blob.get(), face_index), hb_face_destroy);
  const unsigned units = hb_face_get_upem(face.get());
  if (hb_face_get_glyph_count(face.get()) == 0 || units < 16 || units > 16384 || face_index >= hb_face_count(blob.get()))
    return copy_result("{\"error\":\"font\"}");
  owned<hb_font_t, hb_font_destroy> font(hb_font_create(face.get()), hb_font_destroy);
  owned<hb_buffer_t, hb_buffer_destroy> buffer(hb_buffer_create(), hb_buffer_destroy);
  hb_ot_font_set_funcs(font.get());
  hb_font_set_scale(font.get(), units * 64, units * 64);
  const auto axes = parse_list<hb_variation_t, hb_variation_from_string>(variations);
  hb_font_set_variations(font.get(), axes.data(), axes.size());
  hb_buffer_add_utf16(buffer.get(), text, text_length, start, end - start);
  if (direction && *direction) hb_buffer_set_direction(buffer.get(), hb_direction_from_string(direction, -1));
  if (script && *script) hb_buffer_set_script(buffer.get(), hb_script_from_string(script, -1));
  if (language && *language) hb_buffer_set_language(buffer.get(), hb_language_from_string(language, -1));
  hb_buffer_guess_segment_properties(buffer.get());
  const auto settings = parse_list<hb_feature_t, hb_feature_from_string>(features);
  if (!hb_shape_full(font.get(), buffer.get(), settings.data(), settings.size(), nullptr) || !hb_buffer_allocation_successful(buffer.get()))
    return copy_result("{\"error\":\"shape\"}");
  unsigned count = hb_buffer_get_length(buffer.get());
  if (count > 131072) return copy_result("{\"error\":\"limits\"}");
  const bool monochrome = !has_table(face.get(), HB_TAG('C','O','L','R')) && !has_table(face.get(), HB_TAG('C','B','D','T')) &&
      !has_table(face.get(), HB_TAG('s','b','i','x')) && !has_table(face.get(), HB_TAG('S','V','G',' '));
  owned<hb_draw_funcs_t, hb_draw_funcs_destroy> functions(hb_draw_funcs_create(), hb_draw_funcs_destroy);
  hb_draw_funcs_set_move_to_func(functions.get(), move, nullptr, nullptr);
  hb_draw_funcs_set_line_to_func(functions.get(), line, nullptr, nullptr);
  hb_draw_funcs_set_quadratic_to_func(functions.get(), quadratic, nullptr, nullptr);
  hb_draw_funcs_set_cubic_to_func(functions.get(), cubic, nullptr, nullptr);
  hb_draw_funcs_set_close_path_func(functions.get(), close, nullptr, nullptr);
  hb_glyph_info_t* infos = hb_buffer_get_glyph_infos(buffer.get(), nullptr);
  hb_glyph_position_t* positions = hb_buffer_get_glyph_positions(buffer.get(), nullptr);
  const double scale = size / (units * 64);
  hb_font_extents_t extents{};
  hb_font_get_h_extents(font.get(), &extents);
  std::string result = "{\"version\":1,\"monochrome\":";
  result += monochrome ? "true" : "false";
  result += ",\"weight\":"; number(result, hb_style_get_value(font.get(), HB_STYLE_TAG_WEIGHT));
  result += ",\"italic\":"; result += hb_style_get_value(font.get(), HB_STYLE_TAG_ITALIC) > 0.5 ? "true" : "false";
  result += ",\"ascender\":"; number(result, extents.ascender * scale);
  result += ",\"descender\":"; number(result, -extents.descender * scale);
  for (const auto metric : {HB_OT_METRICS_TAG_UNDERLINE_OFFSET, HB_OT_METRICS_TAG_UNDERLINE_SIZE, HB_OT_METRICS_TAG_STRIKEOUT_OFFSET, HB_OT_METRICS_TAG_STRIKEOUT_SIZE}) {
    hb_position_t value = 0;
    hb_ot_metrics_get_position_with_fallback(font.get(), metric, &value);
    result += metric == HB_OT_METRICS_TAG_UNDERLINE_OFFSET ? ",\"underlinePosition\":" : metric == HB_OT_METRICS_TAG_UNDERLINE_SIZE ? ",\"underlineThickness\":" : metric == HB_OT_METRICS_TAG_STRIKEOUT_OFFSET ? ",\"strikePosition\":" : ",\"strikeThickness\":";
    number(result, value * scale * ((metric == HB_OT_METRICS_TAG_UNDERLINE_OFFSET || metric == HB_OT_METRICS_TAG_STRIKEOUT_OFFSET) ? -1 : 1));
  }
  result += ",\"glyphs\":[";
  Pen pen; pen.scale = scale;
  for (unsigned i = 0; i < count; ++i) {
    if (i) result += ',';
    result += '[' + std::to_string(infos[i].codepoint) + ',' + std::to_string(infos[i].cluster);
    const auto& position = positions[i];
    for (double coordinate : {position.x_advance * scale, -position.y_advance * scale, position.x_offset * scale, -position.y_offset * scale}) {
      result += ','; number(result, coordinate);
    }
    result += ',';
    pen.path.clear();
    const bool outlined = draw && monochrome && infos[i].codepoint != 0 && hb_font_draw_glyph_or_fail(font.get(), infos[i].codepoint, functions.get(), &pen);
    if (pen.failed || result.size() + pen.path.size() > maximum_output) return copy_result("{\"error\":\"limits\"}");
    if (outlined) { result += '"'; result += pen.path; result += '"'; }
    else result += "null";
    result += ']';
  }
  result += "]}";
  return copy_result(result);
}
