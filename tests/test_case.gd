class_name TestCase
extends RefCounted
## Base class for tests run by res://tests/run_tests.gd. Every method whose
## name starts with "test_" is run; failed checks are collected, not fatal.

var tree: SceneTree
var failures: PackedStringArray = []
var current_test := ""

var _nodes: Array[Node] = []


## Adds [param node] to the scene root for the duration of the current test.
func add_node(node: Node) -> Node:
	tree.root.add_child(node)
	_nodes.append(node)
	return node


func cleanup() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()


func check(condition: bool, message: String = "check failed") -> void:
	if not condition:
		failures.append("%s: %s" % [current_test, message])


func check_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	check(actual == expected, "%sexpected %s, got %s" % [_prefix(message), expected, actual])


func check_near(actual: float, expected: float, tolerance: float = 1e-4, message: String = "") -> void:
	check(absf(actual - expected) <= tolerance, "%sexpected %s ± %s, got %s" % [_prefix(message), expected, tolerance, actual])


func _prefix(message: String) -> String:
	return message + ": " if message else ""
