extends SceneTree

const Bench := preload(
    "res://scripts/tools/v075/v075_monster_autonomy_trample_bench.gd"
)


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var result := Bench.run_case("flying_no_trample")
    var passed := bool(result.get("passed", false))
    print("V075_MONSTER_FLYING_NO_TRAMPLE_TEST|status=%s|result=%s" % [
        "PASS" if passed else "FAIL",
        JSON.stringify(result),
    ])
    quit(0 if passed else 1)