// Windows implementation of WindowCapture (included from window_capture.cpp).
//
// DXGI Desktop Duplication on the monitor that shows the target window,
// cropped to the window's client area. Needs the window to be visible on a
// monitor attached to a GPU that supports duplication.

#include <windows.h>

#include <d3d11.h>
#include <dwmapi.h>
#include <dxgi1_2.h>

#include <algorithm>
#include <cwctype>

namespace vrdrum {

namespace win {

// Minimal COM smart pointer (avoids depending on WRL).
template <typename T>
struct Com {
	T *p = nullptr;
	Com() = default;
	~Com() { reset(); }
	Com(const Com &) = delete;
	Com &operator=(const Com &) = delete;
	void reset() {
		if (p) {
			p->Release();
			p = nullptr;
		}
	}
	T **put() {
		reset();
		return &p;
	}
	void **put_void() { return reinterpret_cast<void **>(put()); }
	T *operator->() const { return p; }
	explicit operator bool() const { return p != nullptr; }
};

} // namespace win

using win::Com;

namespace {

std::wstring lower(std::wstring p_text) {
	for (wchar_t &c : p_text) {
		c = static_cast<wchar_t>(std::towlower(c));
	}
	return p_text;
}

std::string narrow(const std::wstring &p_text) {
	if (p_text.empty()) {
		return std::string();
	}
	const int size = WideCharToMultiByte(CP_UTF8, 0, p_text.data(), int(p_text.size()), nullptr, 0, nullptr, nullptr);
	std::string out(size_t(size), '\0');
	WideCharToMultiByte(CP_UTF8, 0, p_text.data(), int(p_text.size()), out.data(), size, nullptr, nullptr);
	return out;
}

std::wstring window_title(HWND p_hwnd) {
	const int length = GetWindowTextLengthW(p_hwnd);
	if (length <= 0) {
		return std::wstring();
	}
	std::wstring title(size_t(length) + 1, L'\0');
	GetWindowTextW(p_hwnd, title.data(), length + 1);
	title.resize(size_t(length));
	return title;
}

// Visible top-level windows of other applications.
bool is_candidate(HWND p_hwnd) {
	if (!IsWindowVisible(p_hwnd) || GetWindow(p_hwnd, GW_OWNER) != nullptr || GetWindowTextLengthW(p_hwnd) <= 0) {
		return false;
	}
	DWORD pid = 0;
	GetWindowThreadProcessId(p_hwnd, &pid);
	if (pid == GetCurrentProcessId()) {
		return false;
	}
	BOOL cloaked = FALSE;
	DwmGetWindowAttribute(p_hwnd, DWMWA_CLOAKED, &cloaked, sizeof(cloaked));
	return !cloaked;
}

struct FindData {
	std::wstring needle;
	HWND found = nullptr;
};

BOOL CALLBACK find_window_proc(HWND p_hwnd, LPARAM p_param) {
	FindData *data = reinterpret_cast<FindData *>(p_param);
	if (is_candidate(p_hwnd) && lower(window_title(p_hwnd)).find(data->needle) != std::wstring::npos) {
		data->found = p_hwnd;
		return FALSE;
	}
	return TRUE;
}

BOOL CALLBACK list_windows_proc(HWND p_hwnd, LPARAM p_param) {
	if (is_candidate(p_hwnd)) {
		reinterpret_cast<std::vector<std::wstring> *>(p_param)->push_back(window_title(p_hwnd));
	}
	return TRUE;
}

void sleep_ms(int p_ms) {
	std::this_thread::sleep_for(std::chrono::milliseconds(p_ms));
}

} // namespace

static bool platform_supported() {
	return true;
}

static PackedStringArray platform_list_windows() {
	std::vector<std::wstring> titles;
	EnumWindows(list_windows_proc, reinterpret_cast<LPARAM>(&titles));
	PackedStringArray out;
	for (const std::wstring &title : titles) {
		out.push_back(String::utf8(narrow(title).c_str()));
	}
	return out;
}

struct WindowCapture::Impl {
	CaptureShared shared;
	std::thread worker;
	std::atomic<bool> quit{ false };
	std::wstring needle;
	int max_width = 1280;

	// Direct3D state for the monitor being duplicated.
	Com<ID3D11Device> device;
	Com<ID3D11DeviceContext> context;
	Com<IDXGIOutputDuplication> duplication;
	Com<ID3D11Texture2D> staging;
	HMONITOR monitor = nullptr;
	RECT desktop{};
	int staging_width = 0;
	int staging_height = 0;

	std::vector<uint8_t> scratch;

	~Impl() { stop(); }

	bool start(const std::wstring &p_title, int p_max_width) {
		needle = lower(p_title);
		max_width = p_max_width;
		quit = false;
		shared.set_status("Looking for the window");
		worker = std::thread([this]() { run(); });
		return true;
	}

	void stop() {
		quit = true;
		if (worker.joinable()) {
			worker.join();
		}
		shared.set_status("Not capturing");
	}

	bool running() const { return worker.joinable() && !quit; }

	void release_d3d() {
		staging.reset();
		duplication.reset();
		context.reset();
		device.reset();
		monitor = nullptr;
		staging_width = 0;
		staging_height = 0;
	}

	bool init_duplication(HMONITOR p_monitor) {
		release_d3d();
		Com<IDXGIFactory1> factory;
		if (FAILED(CreateDXGIFactory1(__uuidof(IDXGIFactory1), factory.put_void()))) {
			shared.set_status("Could not start DXGI");
			return false;
		}
		for (UINT a = 0;; a++) {
			Com<IDXGIAdapter1> adapter;
			if (factory->EnumAdapters1(a, adapter.put()) == DXGI_ERROR_NOT_FOUND) {
				break;
			}
			for (UINT o = 0;; o++) {
				Com<IDXGIOutput> output;
				if (adapter->EnumOutputs(o, output.put()) == DXGI_ERROR_NOT_FOUND) {
					break;
				}
				DXGI_OUTPUT_DESC desc;
				if (FAILED(output->GetDesc(&desc)) || desc.Monitor != p_monitor) {
					continue;
				}
				Com<IDXGIOutput1> output1;
				if (FAILED(output->QueryInterface(__uuidof(IDXGIOutput1), output1.put_void()))) {
					shared.set_status("Desktop capture is not supported on this system");
					return false;
				}
				D3D_FEATURE_LEVEL level;
				if (FAILED(D3D11CreateDevice(adapter.p, D3D_DRIVER_TYPE_UNKNOWN, nullptr, 0, nullptr, 0,
							D3D11_SDK_VERSION, device.put(), &level, context.put()))) {
					shared.set_status("Could not create a Direct3D 11 device");
					return false;
				}
				const HRESULT hr = output1->DuplicateOutput(device.p, duplication.put());
				if (FAILED(hr)) {
					if (hr == E_ACCESSDENIED) {
						shared.set_status("Desktop capture is blocked right now (lock screen or UAC prompt)");
					} else if (hr == DXGI_ERROR_NOT_CURRENTLY_AVAILABLE) {
						shared.set_status("Too many apps are capturing this monitor");
					} else {
						shared.set_status("This monitor can't be captured (try the Desktop+ overlay)");
					}
					release_d3d();
					return false;
				}
				monitor = p_monitor;
				desktop = desc.DesktopCoordinates;
				return true;
			}
		}
		shared.set_status("Could not find the monitor showing the window");
		return false;
	}

	bool ensure_staging(ID3D11Texture2D *p_source, int p_width, int p_height) {
		if (staging && staging_width == p_width && staging_height == p_height) {
			return true;
		}
		D3D11_TEXTURE2D_DESC source_desc;
		p_source->GetDesc(&source_desc);
		D3D11_TEXTURE2D_DESC desc{};
		desc.Width = UINT(p_width);
		desc.Height = UINT(p_height);
		desc.MipLevels = 1;
		desc.ArraySize = 1;
		desc.Format = source_desc.Format;
		desc.SampleDesc.Count = 1;
		desc.Usage = D3D11_USAGE_STAGING;
		desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
		if (FAILED(device->CreateTexture2D(&desc, nullptr, staging.put()))) {
			return false;
		}
		staging_width = p_width;
		staging_height = p_height;
		return true;
	}

	// Downscales by a whole factor (box filter) to fit max_width, then hands
	// the frame to the main thread.
	void publish(const uint8_t *p_pixels, UINT p_pitch, int p_width, int p_height) {
		const int factor = std::max(1, (p_width + max_width - 1) / max_width);
		const int out_width = p_width / factor;
		const int out_height = p_height / factor;
		scratch.resize(size_t(out_width) * size_t(out_height) * 4);
		const int area = factor * factor;
		for (int y = 0; y < out_height; y++) {
			uint8_t *dst = scratch.data() + size_t(y) * out_width * 4;
			if (factor == 1) {
				std::memcpy(dst, p_pixels + size_t(y) * p_pitch, size_t(out_width) * 4);
				continue;
			}
			for (int x = 0; x < out_width; x++) {
				int sum[3] = { 0, 0, 0 };
				for (int dy = 0; dy < factor; dy++) {
					const uint8_t *src = p_pixels + size_t(y * factor + dy) * p_pitch + size_t(x * factor) * 4;
					for (int dx = 0; dx < factor; dx++) {
						sum[0] += src[dx * 4 + 0];
						sum[1] += src[dx * 4 + 1];
						sum[2] += src[dx * 4 + 2];
					}
				}
				dst[x * 4 + 0] = uint8_t(sum[0] / area);
				dst[x * 4 + 1] = uint8_t(sum[1] / area);
				dst[x * 4 + 2] = uint8_t(sum[2] / area);
				dst[x * 4 + 3] = 255;
			}
		}
		std::lock_guard<std::mutex> lock(shared.mutex);
		shared.frame.swap(scratch);
		if (shared.width != out_width || shared.height != out_height) {
			shared.width = out_width;
			shared.height = out_height;
		}
		shared.fresh = true;
		shared.status = "Capturing (" + std::to_string(out_width) + "x" + std::to_string(out_height) + ")";
	}

	void run() {
		using Clock = std::chrono::steady_clock;
		Clock::time_point last_frame = Clock::now() - std::chrono::seconds(1);
		while (!quit) {
			FindData find;
			find.needle = needle;
			EnumWindows(find_window_proc, reinterpret_cast<LPARAM>(&find));
			const HWND hwnd = find.found;
			if (!hwnd) {
				shared.set_status("Waiting for a window titled \"" + narrow(needle) + "\"");
				release_d3d();
				sleep_ms(500);
				continue;
			}
			if (IsIconic(hwnd)) {
				shared.set_status("The window is minimized");
				sleep_ms(250);
				continue;
			}
			const HMONITOR window_monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
			if (!duplication || window_monitor != monitor) {
				if (!init_duplication(window_monitor)) {
					sleep_ms(1000);
					continue;
				}
			}

			// The window's client area, relative to this monitor, clamped to it.
			RECT client;
			GetClientRect(hwnd, &client);
			POINT top_left{ client.left, client.top };
			ClientToScreen(hwnd, &top_left);
			const int left = std::max<int>(top_left.x, desktop.left) - desktop.left;
			const int top = std::max<int>(top_left.y, desktop.top) - desktop.top;
			const int right = std::min<int>(top_left.x + (client.right - client.left), desktop.right) - desktop.left;
			const int bottom = std::min<int>(top_left.y + (client.bottom - client.top), desktop.bottom) - desktop.top;
			const int width = right - left;
			const int height = bottom - top;
			if (width < 16 || height < 16) {
				shared.set_status("The window is off screen");
				sleep_ms(250);
				continue;
			}

			DXGI_OUTDUPL_FRAME_INFO info;
			Com<IDXGIResource> resource;
			const HRESULT hr = duplication->AcquireNextFrame(100, &info, resource.put());
			if (hr == DXGI_ERROR_WAIT_TIMEOUT) {
				continue; // nothing changed on screen
			}
			if (FAILED(hr)) {
				release_d3d(); // access lost (mode change, fullscreen switch...): start over
				sleep_ms(hr == DXGI_ERROR_ACCESS_LOST ? 10 : 500);
				continue;
			}
			bool copied = false;
			if (info.LastPresentTime.QuadPart != 0) { // the image changed, not just the cursor
				Com<ID3D11Texture2D> texture;
				if (SUCCEEDED(resource->QueryInterface(__uuidof(ID3D11Texture2D), texture.put_void())) &&
						ensure_staging(texture.p, width, height)) {
					D3D11_BOX box{ UINT(left), UINT(top), 0, UINT(right), UINT(bottom), 1 };
					context->CopySubresourceRegion(staging.p, 0, 0, 0, 0, texture.p, 0, &box);
					copied = true;
				}
			}
			duplication->ReleaseFrame();
			// At most ~60 frames per second reach the game.
			if (!copied || Clock::now() - last_frame < std::chrono::milliseconds(15)) {
				continue;
			}
			D3D11_MAPPED_SUBRESOURCE mapped;
			if (FAILED(context->Map(staging.p, 0, D3D11_MAP_READ, 0, &mapped))) {
				continue;
			}
			publish(static_cast<const uint8_t *>(mapped.pData), mapped.RowPitch, width, height);
			context->Unmap(staging.p, 0);
			last_frame = Clock::now();
		}
		release_d3d();
	}
};

} // namespace vrdrum
