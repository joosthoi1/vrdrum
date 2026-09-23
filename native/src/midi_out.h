#pragma once

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include <memory>

class RtMidiOut;

namespace vrdrum {

// Sends MIDI messages to an output port (a virtual cable such as loopMIDI on
// Windows, or a virtual ALSA port on Linux). Never throws: failures are
// reported through return values and get_last_error().
class MidiOut : public godot::RefCounted {
	GDCLASS(MidiOut, godot::RefCounted)

public:
	MidiOut();
	~MidiOut() override;

	static godot::PackedStringArray get_port_names();
	bool open_port(int p_index);
	bool open_virtual_port(const godot::String &p_name);
	void close();
	bool is_open() const;
	bool send(int p_status, int p_data1, int p_data2);
	godot::String get_port_name() const;
	godot::String get_last_error() const;

protected:
	static void _bind_methods();

private:
	bool ensure_client();

	std::unique_ptr<RtMidiOut> midi;
	godot::String port_name;
	godot::String last_error;
};

} // namespace vrdrum
