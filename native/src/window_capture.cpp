#include "window_capture.h"

#include <godot_cpp/core/class_db.hpp>

#include <atomic>
#include <chrono>
#include <cstring>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

using namespace godot;

namespace vrdrum {

// State shared between the capture thread and the main thread.
struct CaptureShared {
	std::mutex mutex;
	std::vector<uint8_t> frame;
	int width = 0;
	int height = 0;
	bool fresh = false;
	std::string status = "Not capturing";

	void set_status(const std::string &p_status) {
		std::lock_guard<std::mutex> lock(mutex);
		status = p_status;
	}
};

} // namespace vrdrum

#ifdef _WIN32
#include "window_capture_windows.inc"
#else

namespace vrdrum {

// Other platforms: capture is unavailable; the game shows a hint instead.
struct WindowCapture::Impl {
	CaptureShared shared;
	Impl() { shared.status = "Window capture needs Windows"; }
	bool start(const std::wstring &, int) { return false; }
	void stop() {}
	bool running() const { return false; }
};

static bool platform_supported() { return false; }
static PackedStringArray platform_list_windows() { return PackedStringArray(); }

} // namespace vrdrum

#endif

namespace vrdrum {

WindowCapture::WindowCapture() :
		impl(std::make_unique<Impl>()) {}

WindowCapture::~WindowCapture() {
	stop();
}

bool WindowCapture::is_supported() {
	return platform_supported();
}

PackedStringArray WindowCapture::list_windows() {
	return platform_list_windows();
}

bool WindowCapture::start(const String &p_title_contains, int p_max_width) {
	stop();
	const char32_t *chars = p_title_contains.ptr();
	std::wstring title;
	for (int64_t i = 0; i < p_title_contains.length(); i++) {
		title.push_back(static_cast<wchar_t>(chars[i]));
	}
	return impl->start(title, p_max_width < 64 ? 64 : p_max_width);
}

void WindowCapture::stop() {
	impl->stop();
}

bool WindowCapture::is_capturing() const {
	return impl->running();
}

String WindowCapture::get_status() const {
	std::lock_guard<std::mutex> lock(impl->shared.mutex);
	return String::utf8(impl->shared.status.c_str());
}

PackedByteArray WindowCapture::fetch_frame() {
	PackedByteArray out;
	std::lock_guard<std::mutex> lock(impl->shared.mutex);
	if (!impl->shared.fresh) {
		return out;
	}
	impl->shared.fresh = false;
	out.resize(int64_t(impl->shared.frame.size()));
	std::memcpy(out.ptrw(), impl->shared.frame.data(), impl->shared.frame.size());
	return out;
}

Vector2i WindowCapture::get_frame_size() const {
	std::lock_guard<std::mutex> lock(impl->shared.mutex);
	return Vector2i(impl->shared.width, impl->shared.height);
}

void WindowCapture::_bind_methods() {
	ClassDB::bind_static_method("WindowCapture", D_METHOD("is_supported"), &WindowCapture::is_supported);
	ClassDB::bind_static_method("WindowCapture", D_METHOD("list_windows"), &WindowCapture::list_windows);
	ClassDB::bind_method(D_METHOD("start", "title_contains", "max_width"), &WindowCapture::start);
	ClassDB::bind_method(D_METHOD("stop"), &WindowCapture::stop);
	ClassDB::bind_method(D_METHOD("is_capturing"), &WindowCapture::is_capturing);
	ClassDB::bind_method(D_METHOD("get_status"), &WindowCapture::get_status);
	ClassDB::bind_method(D_METHOD("fetch_frame"), &WindowCapture::fetch_frame);
	ClassDB::bind_method(D_METHOD("get_frame_size"), &WindowCapture::get_frame_size);
}

} // namespace vrdrum
