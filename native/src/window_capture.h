#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include <memory>

namespace vrdrum {

// Captures another application's window (e.g. Clone Hero) as it appears on
// screen, on a worker thread. Windows only: uses DXGI Desktop Duplication on
// the monitor showing the window and crops to its client area, so the window
// has to be visible on a monitor. Frames are BGRA8, top row first.
class WindowCapture : public godot::RefCounted {
	GDCLASS(WindowCapture, godot::RefCounted)

public:
	WindowCapture();
	~WindowCapture() override;

	static bool is_supported();
	static godot::PackedStringArray list_windows();

	// Starts capturing the first visible window whose title contains
	// p_title_contains (case-insensitive), scaled down to at most
	// p_max_width pixels wide. Keeps looking if it isn't open yet.
	bool start(const godot::String &p_title_contains, int p_max_width);
	void stop();
	bool is_capturing() const;
	godot::String get_status() const;

	// The newest frame if it arrived since the last call, else empty.
	godot::PackedByteArray fetch_frame();
	godot::Vector2i get_frame_size() const;

	struct Impl;

protected:
	static void _bind_methods();

private:
	std::unique_ptr<Impl> impl;
};

} // namespace vrdrum
