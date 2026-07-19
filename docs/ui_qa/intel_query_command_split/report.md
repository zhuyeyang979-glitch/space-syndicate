# Intel Query / Command Split QA

- Passed: 15/15
- Formal typed open: 447ms
- Driver scene: `res://scenes/tools/IntelDossierPublicSnapshotCutoverBench.tscn`

| Case | Result | Notes |
| --- | --- | --- |
| formal_assets_load | PASS | formal main, query, command, controller, and board scenes load |
| scene_owned_composition | PASS | one formal scene-owned Flow, Query, Command, Controller, WorldSession, and annotation owner |
| dedicated_application_boundary | PASS | typed focus crosses ApplicationFlowPort exactly once and never emits generic action_requested |
| authorized_query_zero_mutation | PASS | authorized viewer query returns detached data and mutates no owner |
| public_world_categories | PASS | public region, facility, product/demand, route, weather, and monster-attraction evidence is present |
| public_facility_privacy | PASS | audited public facility ownership remains visible; inventory and hidden owner stay absent |
| viewer_private_guess | PASS | WorldSession receipt=city_owner_guess_set; target=region.000; projection={"authorized_reveal":false,"confidence":2,"district_index":0,"reason_id":"card","reason_kind":"manual","region_id":"region.000","suspected_player_index":1} |
| viewer_isolation | PASS | viewer B mutation changes only B revision; viewer A snapshot and query remain isolated |
| authorized_reveal | PASS | WorldSession receipt=authorized_city_reveal_set; confidence=100; locked=true |
| card_annotation_delegation | PASS | typed card note delegates to CardHistoryPrivateAnnotationService |
| typed_public_links | PASS | typed kinds=["focus_history","open_card","open_economy","open_monster","open_product","open_region"]; subjects={"focus_history":"card-history:90701","open_card":"城市融资1","open_economy":"economy","open_monster":"monster:0","open_product":"寒冠冰糖","open_region":"region:0"}; monster owner=monster_owner_save_applied |
| controller_exact_once | PASS | one typed application intent produces one open, query, and apply |
| final_settlement_real_owner | PASS | bridge active=[0]; owner reason=last_survivor; winners=[0]; present delta=1 |
| main_routes_retired | PASS | Main contains no executable typed Intel route, dossier builder, or dead city-query wrapper |
| bounded_capture_manifest | PASS | single bounded driver records five formal UI evidence stages and a 15-case manifest |
