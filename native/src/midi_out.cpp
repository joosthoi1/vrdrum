#include "midi_out.h"

#include <godot_cpp/core/class_db.hpp>

#include "RtMidi.h"

using namespace godot;

namespace vrdrum {

namespace {

const char *CLIENT_NAME = "VR Drums";

// Keeps RtMidi from printing to stderr or throwing after construction.
void store_error(RtMidiError::Type p_type, const std::string &p_text, void *p_user) {
	if (p_user && p_type != RtMidiError::WARNING && p_type != RtMidiError::DEBUG_WARNING) {
		*static_cast<String *>(p_user) = String::utf8(p_text.c_str());
	}
}

} // namespace

MidiOut::MidiOut() {}

MidiOut::~MidiOut() {
	close();
}

PackedStringArray MidiOut::get_port_names() {
	PackedStringArray names;
	try {
		RtMidiOut probe(RtMidi::UNSPECIFIED, CLIENT_NAME);
		probe.setErrorCallback(store_error, nullptr);
		const unsigned int count = probe.getPortCount();
		for (unsigned int i = 0; i < count; i++) {
			names.push_back(String::utf8(probe.getPortName(i).c_str()));
		}
	} catch (const std::exception &) {
		// No MIDI system available: report no ports.
	}
	return names;
}

bool MidiOut::ensure_client() {
	if (midi) {
		return true;
	}
	try {
		midi = std::make_unique<RtMidiOut>(RtMidi::UNSPECIFIED, CLIENT_NAME);
		midi->setErrorCallback(store_error, &last_error);
		return true;
	} catch (const std::exception &e) {
		last_error = String::utf8(e.what());
		return false;
	}
}

bool MidiOut::open_port(int p_index) {
	close();
	last_error = String();
	if (!ensure_client()) {
		return false;
	}
	try {
		if (p_index < 0 || p_index >= int(midi->getPortCount())) {
			last_error = "No MIDI output port " + String::num_int64(p_index);
			return false;
		}
		port_name = String::utf8(midi->getPortName(p_index).c_str());
		midi->openPort(p_index, CLIENT_NAME);
	} catch (const std::exception &e) {
		last_error = String::utf8(e.what());
	}
	if (!midi->isPortOpen()) {
		if (last_error.is_empty()) {
			last_error = "Could not open " + port_name;
		}
		port_name = String();
		return false;
	}
	return true;
}

bool MidiOut::open_virtual_port(const String &p_name) {
	close();
	last_error = String();
	if (!ensure_client()) {
		return false;
	}
	if (midi->getCurrentApi() == RtMidi::WINDOWS_MM) {
		last_error = "Windows can't create virtual MIDI ports; use loopMIDI and pick its port";
		return false;
	}
	try {
		midi->openVirtualPort(p_name.utf8().get_data());
	} catch (const std::exception &e) {
		last_error = String::utf8(e.what());
		return false;
	}
	if (!last_error.is_empty()) {
		return false;
	}
	port_name = p_name;
	return true;
}

void MidiOut::close() {
	if (midi) {
		try {
			midi->closePort();
		} catch (const std::exception &) {
		}
	}
	port_name = String();
}

bool MidiOut::is_open() const {
	return midi && !port_name.is_empty();
}

bool MidiOut::send(int p_status, int p_data1, int p_data2) {
	if (!is_open()) {
		return false;
	}
	const unsigned char message[3] = {
		static_cast<unsigned char>(p_status & 0xFF),
		static_cast<unsigned char>(p_data1 & 0x7F),
		static_cast<unsigned char>(p_data2 & 0x7F),
	};
	try {
		midi->sendMessage(message, 3);
	} catch (const std::exception &e) {
		last_error = String::utf8(e.what());
		return false;
	}
	return true;
}

String MidiOut::get_port_name() const {
	return port_name;
}

String MidiOut::get_last_error() const {
	return last_error;
}

void MidiOut::_bind_methods() {
	ClassDB::bind_static_method("MidiOut", D_METHOD("get_port_names"), &MidiOut::get_port_names);
	ClassDB::bind_method(D_METHOD("open_port", "index"), &MidiOut::open_port);
	ClassDB::bind_method(D_METHOD("open_virtual_port", "name"), &MidiOut::open_virtual_port);
	ClassDB::bind_method(D_METHOD("close"), &MidiOut::close);
	ClassDB::bind_method(D_METHOD("is_open"), &MidiOut::is_open);
	ClassDB::bind_method(D_METHOD("send", "status", "data1", "data2"), &MidiOut::send);
	ClassDB::bind_method(D_METHOD("get_port_name"), &MidiOut::get_port_name);
	ClassDB::bind_method(D_METHOD("get_last_error"), &MidiOut::get_last_error);
}

} // namespace vrdrum
