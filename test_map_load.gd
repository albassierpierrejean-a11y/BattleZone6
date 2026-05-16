extends SceneTree

func _init():
    print("Testing map load...")
    var scene = load("res://scenes/maps/TestMap.tscn")
    if scene:
        print("TestMap loaded OK")
        var inst = scene.instantiate()
        print("TestMap instantiated OK")
        root.add_child(inst)
        print("TestMap added to tree OK")
    else:
        print("FAILED to load TestMap.tscn")
    quit()
