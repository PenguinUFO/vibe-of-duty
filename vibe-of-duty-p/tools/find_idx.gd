extends SceneTree
func _init():
    for i in WeaponDB.DEFS.size():
        var d = WeaponDB.get_def(i)
        if d.id == "mk14":
            print("MK14 index: ", i)
    quit()
