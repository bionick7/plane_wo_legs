@tool
extends EditorScript

func _run():
	print(Basis.looking_at(Vector3.FORWARD, Vector3.UP))
