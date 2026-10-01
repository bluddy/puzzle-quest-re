# Puzzle Quest: Lua 5.1 C-API Native Bridge Reference

This document catalogs all **191 native C functions** exported to the embedded Lua 5.1 environment in `Puzzle Quest.exe`.
All functions are registered in the global environment (`LUA_GLOBALSINDEX` = `-10002`) inside the initialization function `0x4976FE`–`0x499E89`.

## Global Lua State & Helpers
* `g_L` global pointer address: `0x00583108`
* Registration routine: `0x004976F0`
* `lua_pushstring`: `0x004F7090`
* `lua_pushcclosure`: `0x004F7160`
* `lua_pushnumber`: `0x004F7020`
* `lua_tonumber`: `0x004F6DB0`
* `lua_isnumber`: `0x004F6CA0`
* `lua_settable`: `0x004F7410`

## Board & Match-3 (12 functions)

| Lua Function | Native C Function VA | String VA | Registration Call | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **`ADD_ANIMEFFECT_TO_GRID`** | `0x48bfe0` | `0x5281a0` | `0x497732` | |
| **`ADD_EFFECT_TO_GRID`** | `0x48be40` | `0x528158` | `0x4977d1` | |
| **`ADD_LIGHTNING`** | `0x48c270` | `0x528130` | `0x497873` | |
| **`DELETE_GEM`** | `0x48d110` | `0x527fe8` | `0x497bfc` | |
| **`DESTROY_GEM`** | `0x48d1a0` | `0x527fdc` | `0x497c30` | |
| **`EVALUATE_BOARD`** | `0x48d240` | `0x527fb0` | `0x497c9b` | |
| **`GET_GEM`** | `0x48d680` | `0x527eec` | `0x497ee6` | |
| **`GET_GRID_X`** | `0x48d720` | `0x527ed4` | `0x497f51` | |
| **`GET_GRID_Y`** | `0x48d7e0` | `0x527ec8` | `0x497f85` | |
| **`SET_GEM`** | `0x48ec10` | `0x527ba4` | `0x4988ae` | |
| **`TUTORIAL_GAME_SET_GEMS`** | `0x48f930` | `0x527498` | `0x499b34` | |
| **`TUTORIAL_OPPTUTE_GEM`** | `0x4905f0` | `0x527380` | `0x499dea` | |

## Character, Stats & Mana (80 functions)

| Lua Function | Native C Function VA | String VA | Registration Call | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **`ACTIVATE_COMPANION`** | `0x48bc20` | `0x5281b8` | `0x4976fe` | |
| **`ADD_ANIMEFFECT_TO_CHARACTER`** | `0x48c140` | `0x528184` | `0x497769` | |
| **`ADD_EFFECT_TO_CHARACTER`** | `0x48bd30` | `0x52816c` | `0x49779d` | |
| **`ADD_GOLD`** | `0x4975f0` | `0x52814c` | `0x497808` | |
| **`ADD_LIFE`** | `0x4965a0` | `0x528140` | `0x49783c` | |
| **`ADD_MANA_AIR`** | `0x496690` | `0x528120` | `0x4978a7` | |
| **`ADD_MANA_EARTH`** | `0x496780` | `0x528110` | `0x4978de` | |
| **`ADD_MANA_FIRE`** | `0x496870` | `0x528100` | `0x497912` | |
| **`ADD_MANA_WATER`** | `0x496960` | `0x5280f0` | `0x497946` | |
| **`ADD_MAX_LIFE`** | `0x496a50` | `0x5280e0` | `0x49797d` | |
| **`ADD_STATUS_EFFECT`** | `0x48c620` | `0x5280a8` | `0x497a1c` | |
| **`ADD_STATUS_EFFECT_AND_DURATION`** | `0x48c780` | `0x528088` | `0x497a53` | |
| **`ADD_TEMP_SKILL`** | `0x48c470` | `0x5280bc` | `0x4979e8` | |
| **`ADD_TEXT_MESSAGE_TO_CHARACTER`** | `0x48cbf0` | `0x528040` | `0x497af2` | |
| **`ADD_TEXT_MESSAGE_TO_CHARACTER2`** | `0x48cd70` | `0x528020` | `0x497b26` | |
| **`ADD_XP`** | `0x48cf00` | `0x528018` | `0x497b5d` | |
| **`CLEAR_STATUS_EFFECTS`** | `0x48d0c0` | `0x527ff4` | `0x497bc8` | |
| **`GET_CHARACTER_ID`** | `0x48d300` | `0x527f90` | `0x497d06` | |
| **`GET_CHARACTER_X`** | `0x48d490` | `0x527f80` | `0x497d3d` | |
| **`GET_CHARACTER_Y`** | `0x48d500` | `0x527f70` | `0x497d71` | |
| **`GET_CURRENT_RUNE_BASEDATA`** | `0x495ca0` | `0x527f28` | `0x497e10` | |
| **`GET_CURRENT_RUNE_CODE`** | `0x495d70` | `0x527f44` | `0x497ddc` | |
| **`GET_CURRENT_RUNE_POWERDATA`** | `0x495ec0` | `0x527f0c` | `0x497e47` | |
| **`GET_ENEMY`** | `0x48d5a0` | `0x527f00` | `0x497e7b` | |
| **`GET_GOLD`** | `0x48d8f0` | `0x527ee0` | `0x497f1a` | |
| **`GET_ITEM`** | `0x495f90` | `0x527eac` | `0x497ff0` | |
| **`GET_LIFE`** | `0x48d960` | `0x527e94` | `0x49805b` | |
| **`GET_MANA_AIR`** | `0x48da40` | `0x527e84` | `0x49808f` | |
| **`GET_MANA_EARTH`** | `0x48dab0` | `0x527e74` | `0x4980c6` | |
| **`GET_MANA_FIRE`** | `0x48db20` | `0x527e64` | `0x4980fa` | |
| **`GET_MANA_WATER`** | `0x48db90` | `0x527e54` | `0x498131` | |
| **`GET_MAX_LIFE`** | `0x48dc00` | `0x527e44` | `0x498165` | |
| **`GET_MAX_MANA_AIR`** | `0x48dc70` | `0x527e30` | `0x49819c` | |
| **`GET_MAX_MANA_EARTH`** | `0x48dce0` | `0x527e1c` | `0x4981d0` | |
| **`GET_MAX_MANA_FIRE`** | `0x48dd50` | `0x527e08` | `0x498204` | |
| **`GET_MAX_MANA_WATER`** | `0x48ddc0` | `0x527df4` | `0x49823b` | |
| **`GET_NUM_STATUS_EFFECTS`** | `0x494b00` | `0x527db0` | `0x498311` | |
| **`GET_SKILL`** | `0x48e0c0` | `0x527d78` | `0x4983e4` | |
| **`GET_STATUS_EFFECT_DURATION`** | `0x494d20` | `0x527d5c` | `0x49841b` | |
| **`GET_STATUS_EFFECT_INDEX`** | `0x48e170` | `0x527d44` | `0x49844f` | |
| **`GET_STATUS_EFFECT_ON_PLAYER`** | `0x496110` | `0x527d28` | `0x498486` | |
| **`HAS_STATUS_EFFECT`** | `0x48e690` | `0x527cd4` | `0x498590` | |
| **`NOTIFY_OF_ACTIVATED_ITEM`** | `0x48e990` | `0x527c74` | `0x4986ce` | |
| **`QUEST_ADD_COMPANION`** | `0x491820` | `0x527924` | `0x498f8c` | |
| **`QUEST_ADD_ITEM`** | `0x491940` | `0x527914` | `0x498fc3` | |
| **`QUEST_ADD_RUNE`** | `0x491ba0` | `0x5278f4` | `0x49902e` | |
| **`QUEST_ADD_SKILL`** | `0x491cd0` | `0x5278e4` | `0x499062` | |
| **`QUEST_COMPANION_MESSAGE`** | `0x494dc0` | `0x527854` | `0x4991d7` | |
| **`QUEST_COMPANION_MESSAGE_CALLBACK`** | `0x494f40` | `0x527830` | `0x49920b` | |
| **`QUEST_GET_CITY_STATUS`** | `0x4954f0` | `0x5277cc` | `0x499318` | |
| **`QUEST_GET_GOLD`** | `0x492f70` | `0x527790` | `0x4993b7` | |
| **`QUEST_HERO_HAS_COMPANION`** | `0x495740` | `0x52771c` | `0x4994c1` | |
| **`QUEST_HERO_HAS_COMPANION_SELECTED`** | `0x495890` | `0x5276f8` | `0x4994f5` | |
| **`QUEST_HERO_HAS_ITEM`** | `0x493160` | `0x5276e4` | `0x49952c` | |
| **`QUEST_HERO_HAS_RUNE`** | `0x4959f0` | `0x5276d0` | `0x499560` | |
| **`QUEST_REMOVE_COMPANION`** | `0x493c80` | `0x527628` | `0x499740` | |
| **`QUEST_REMOVE_ITEM`** | `0x493da0` | `0x527614` | `0x499777` | |
| **`QUEST_REWARD_GOLD`** | `0x493ed0` | `0x527600` | `0x4997ab` | |
| **`QUEST_REWARD_ITEM`** | `0x493f20` | `0x5275ec` | `0x4997df` | |
| **`QUEST_REWARD_ITEM_WITH_TEXT`** | `0x494030` | `0x5275d0` | `0x499816` | |
| **`QUEST_REWARD_XP`** | `0x4945e0` | `0x52757c` | `0x4998ec` | |
| **`QUEST_SET_CITY_STATUS`** | `0x495b40` | `0x527540` | `0x49998b` | |
| **`QUEST_SPEND_GOLD`** | `0x4948e0` | `0x5274ec` | `0x499a61` | |
| **`SET_ITEM`** | `0x4963e0` | `0x527b88` | `0x498919` | |
| **`SET_MANA_AIR`** | `0x496b60` | `0x527b78` | `0x49894d` | |
| **`SET_MANA_EARTH`** | `0x496c50` | `0x527b68` | `0x498984` | |
| **`SET_MANA_FIRE`** | `0x496d40` | `0x527b58` | `0x4989b8` | |
| **`SET_MANA_WATER`** | `0x496e30` | `0x527b48` | `0x4989ef` | |
| **`SET_MAX_MANA_AIR`** | `0x48ed50` | `0x527b34` | `0x498a23` | |
| **`SET_MAX_MANA_EARTH`** | `0x48ede0` | `0x527b20` | `0x498a5a` | |
| **`SET_MAX_MANA_FIRE`** | `0x48ee70` | `0x527b0c` | `0x498a8e` | |
| **`SET_MAX_MANA_WATER`** | `0x48ef00` | `0x527af8` | `0x498ac2` | |
| **`SET_STATUS_EFFECT_DURATION`** | `0x48ef90` | `0x527adc` | `0x498af9` | |
| **`SUBTRACT_GOLD`** | `0x496f20` | `0x527ab0` | `0x498b64` | |
| **`SUBTRACT_LIFE`** | `0x497010` | `0x527aa0` | `0x498b98` | |
| **`SUBTRACT_MANA_AIR`** | `0x497140` | `0x527a8c` | `0x498bcf` | |
| **`SUBTRACT_MANA_EARTH`** | `0x497230` | `0x527a78` | `0x498c03` | |
| **`SUBTRACT_MANA_FIRE`** | `0x497320` | `0x527a64` | `0x498c37` | |
| **`SUBTRACT_MANA_WATER`** | `0x497410` | `0x527a50` | `0x498c6e` | |
| **`SUBTRACT_XP`** | `0x497500` | `0x527a44` | `0x498ca2` | |

## Quests & Story Encounters (43 functions)

| Lua Function | Native C Function VA | String VA | Registration Call | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **`QUEST_ABANDON`** | `0x490cb0` | `0x527948` | `0x498f21` | |
| **`QUEST_ADD_AWARD`** | `0x491700` | `0x527938` | `0x498f58` | |
| **`QUEST_ADD_RUIN`** | `0x491a80` | `0x527904` | `0x498ff7` | |
| **`QUEST_BATTLE`** | `0x491d90` | `0x5278d4` | `0x499096` | |
| **`QUEST_BATTLE_CUSTOM`** | `0x491f00` | `0x5278c0` | `0x4990cd` | |
| **`QUEST_BATTLE_NOCAPTURE`** | `0x4924d0` | `0x5278a8` | `0x499101` | |
| **`QUEST_COMPLETE`** | `0x4927f0` | `0x527820` | `0x499242` | |
| **`QUEST_COMPLETE_PART`** | `0x492920` | `0x52780c` | `0x499276` | |
| **`QUEST_CONVERSATION`** | `0x492640` | `0x527894` | `0x499138` | |
| **`QUEST_COUNT_DONE`** | `0x4951f0` | `0x527880` | `0x49916c` | |
| **`QUEST_COUNT_TRIES`** | `0x495370` | `0x52786c` | `0x4991a3` | |
| **`QUEST_CUTSCENE`** | `0x492bb0` | `0x5277fc` | `0x4992ad` | |
| **`QUEST_CUTSCENE_CALLBACK`** | `0x492c90` | `0x5277e4` | `0x4992e1` | |
| **`QUEST_ENCOUNTER_ADD`** | `0x490dd0` | `0x5279f4` | `0x498dac` | |
| **`QUEST_ENCOUNTER_BATTLE`** | `0x490ef0` | `0x5279dc` | `0x498de3` | |
| **`QUEST_ENCOUNTER_CONTINUE`** | `0x491140` | `0x5279c0` | `0x498e17` | |
| **`QUEST_ENCOUNTER_GET_AT`** | `0x491160` | `0x5279a8` | `0x498e4e` | |
| **`QUEST_ENCOUNTER_REMOVE`** | `0x4913e0` | `0x527990` | `0x498e82` | |
| **`QUEST_ENCOUNTER_REMOVE_AT`** | `0x491500` | `0x527974` | `0x498eb9` | |
| **`QUEST_ENCOUNTER_TURNBACK`** | `0x4916e0` | `0x527958` | `0x498eed` | |
| **`QUEST_GET_CURRENT_LOCATION`** | `0x492e30` | `0x5277b0` | `0x49934c` | |
| **`QUEST_GET_DATE`** | `0x492f30` | `0x5277a0` | `0x499380` | |
| **`QUEST_GET_PROFESSION`** | `0x493070` | `0x527750` | `0x499456` | |
| **`QUEST_GET_REALDATE`** | `0x492fb0` | `0x52777c` | `0x4993eb` | |
| **`QUEST_GET_REALTIME`** | `0x493010` | `0x527768` | `0x499422` | |
| **`QUEST_HERO_HAS_AWARD`** | `0x4955f0` | `0x527738` | `0x49948d` | |
| **`QUEST_HERO_LEVEL`** | `0x4932b0` | `0x5276bc` | `0x499597` | |
| **`QUEST_IS_ACTIVE`** | `0x4932f0` | `0x5276ac` | `0x4995cb` | |
| **`QUEST_IS_VISIBLE`** | `0x493450` | `0x527698` | `0x499602` | |
| **`QUEST_LOAD_INT`** | `0x493580` | `0x527688` | `0x499636` | |
| **`QUEST_MESSAGE`** | `0x4935b0` | `0x527678` | `0x49966a` | |
| **`QUEST_MESSAGE_CALLBACK`** | `0x4937a0` | `0x527660` | `0x4996a1` | |
| **`QUEST_MOVE`** | `0x493a50` | `0x527654` | `0x4996d5` | |
| **`QUEST_REMOVE_AWARD`** | `0x493b60` | `0x527640` | `0x49970c` | |
| **`QUEST_REWARD_MENU`** | `0x4941b0` | `0x5275bc` | `0x49984a` | |
| **`QUEST_REWARD_MENU_CALLBACK`** | `0x4942e0` | `0x5275a0` | `0x499881` | |
| **`QUEST_REWARD_SPELL`** | `0x4944d0` | `0x52758c` | `0x4998b5` | |
| **`QUEST_ROLL_CREDITS`** | `0x494630` | `0x527568` | `0x499920` | |
| **`QUEST_SAVE_INT`** | `0x494640` | `0x527558` | `0x499954` | |
| **`QUEST_SET_RUIN_DONE`** | `0x494690` | `0x52752c` | `0x4999bf` | |
| **`QUEST_SET_VISIBILITY`** | `0x4947a0` | `0x527514` | `0x4999f6` | |
| **`QUEST_STOP_MOVEMENT`** | `0x494940` | `0x527500` | `0x499a2a` | |
| **`QUEST_UPDATE_MAP`** | `0x494950` | `0x5274d8` | `0x499a95` | |

## Tutorial & UI (19 functions)

| Lua Function | Native C Function VA | String VA | Registration Call | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **`IS_GAMEPAD_MODE`** | `0x48f0d0` | `0x527a2c` | `0x498d0d` | |
| **`IS_MENU_OPEN`** | `0x4949a0` | `0x527a08` | `0x498d78` | |
| **`SET_GAMEPAD_OBJECT`** | `0x48f100` | `0x527a18` | `0x498d44` | |
| **`TUTORIAL_ACTIVE`** | `0x48f370` | `0x527398` | `0x499db3` | |
| **`TUTORIAL_CLOSE`** | `0x48f240` | `0x527418` | `0x499c75` | |
| **`TUTORIAL_GAME_ADD_HERO`** | `0x48fd90` | `0x52746c` | `0x499b9f` | |
| **`TUTORIAL_GAME_ADD_MONSTER`** | `0x4904d0` | `0x527450` | `0x499bd6` | |
| **`TUTORIAL_GAME_OPEN`** | `0x48f750` | `0x527484` | `0x499b6b` | |
| **`TUTORIAL_GAME_PLAY`** | `0x48f880` | `0x5274b0` | `0x499b00` | |
| **`TUTORIAL_GAME_RUN`** | `0x48f760` | `0x5274c4` | `0x499ac9` | |
| **`TUTORIAL_GET_HERO`** | `0x48f340` | `0x5273ec` | `0x499ce0` | |
| **`TUTORIAL_GET_INV_MODE`** | `0x4905b0` | `0x527438` | `0x499c0a` | |
| **`TUTORIAL_GLOW_RECT`** | `0x48f3a0` | `0x5273d8` | `0x499d14` | |
| **`TUTORIAL_GLOW_WIDGET`** | `0x48f490` | `0x5273c0` | `0x499d4b` | |
| **`TUTORIAL_OPEN`** | `0x48f6a0` | `0x527428` | `0x499c3e` | |
| **`TUTORIAL_OPEN_INVENTORY`** | `0x4905d0` | `0x5273a8` | `0x499d7f` | |
| **`TUTORIAL_OPPTUTE_SPELL`** | `0x490800` | `0x527368` | `0x499e1e` | |
| **`TUTORIAL_OPPTUTE_SWAP`** | `0x4909c0` | `0x527350` | `0x499e55` | |
| **`TUTORIAL_PRESS_BUTTON`** | `0x48f250` | `0x527400` | `0x499ca9` | |

## General / System (37 functions)

| Lua Function | Native C Function VA | String VA | Registration Call | Notes |
| :--- | :--- | :--- | :--- | :--- |
| **`ADD_TEMP_RESISTANCE`** | `0x48c3b0` | `0x5280cc` | `0x4979b1` | |
| **`ADD_TEXT_MESSAGE`** | `0x48c910` | `0x528074` | `0x497a87` | |
| **`ADD_TEXT_MESSAGE2`** | `0x48ca80` | `0x528060` | `0x497abb` | |
| **`CHECK_TYPE`** | `0x48cf90` | `0x52800c` | `0x497b91` | |
| **`DISALLOW_SPELLS_THIS_TURN`** | `0x48d230` | `0x527fc0` | `0x497c67` | |
| **`EXTRA_TURN`** | `0x48d270` | `0x527fa4` | `0x497cd2` | |
| **`GET_CURRENT_PLAYER`** | `0x48d570` | `0x527f5c` | `0x497da5` | |
| **`GET_GAME_ID`** | `0x48d650` | `0x527ef4` | `0x497eb2` | |
| **`GET_INPUT_DATA`** | `0x48d8a0` | `0x527eb8` | `0x497fbc` | |
| **`GET_LEVEL`** | `0x48d9d0` | `0x527ea0` | `0x498027` | |
| **`GET_MOUNT`** | `0x494b80` | `0x527de8` | `0x49826f` | |
| **`GET_NUM_ENEMIES`** | `0x48de30` | `0x527dd8` | `0x4982a6` | |
| **`GET_NUM_SPELLS`** | `0x494a80` | `0x527dc8` | `0x4982da` | |
| **`GET_PLATFORM`** | `0x494980` | `0x527340` | `0x499e89` | |
| **`GET_RANDOM`** | `0x48dea0` | `0x527da4` | `0x498345` | |
| **`GET_RANDOM_SYNC`** | `0x48df40` | `0x527d94` | `0x498379` | |
| **`GET_RESISTANCE`** | `0x48dff0` | `0x527d84` | `0x4983b0` | |
| **`GET_TEXT`** | `0x48e2f0` | `0x527d1c` | `0x4984ba` | |
| **`GET_TEXT_FORMAT_INT`** | `0x48e410` | `0x527d08` | `0x4984ee` | |
| **`GET_TURN`** | `0x48e5c0` | `0x527cfc` | `0x498525` | |
| **`HANDLE_SPELL_COST`** | `0x48e5f0` | `0x527ce8` | `0x498559` | |
| **`IS_DEMO`** | `0x48f0a0` | `0x527a3c` | `0x498cd9` | |
| **`IS_GAME_OVER`** | `0x48e800` | `0x527cb8` | `0x4985fb` | |
| **`IS_HERO`** | `0x48e820` | `0x527cb0` | `0x49862f` | |
| **`IS_MONSTER`** | `0x48e890` | `0x527cc8` | `0x4985c4` | |
| **`IS_SPELL_CASTABLE`** | `0x496280` | `0x527c9c` | `0x498663` | |
| **`MISS_TURNS`** | `0x48e900` | `0x527c90` | `0x49869a` | |
| **`NOTIFY_OF_FREE_SPELL`** | `0x48e9a0` | `0x527c5c` | `0x498705` | |
| **`PERCENTILE_CHANCE`** | `0x48e9b0` | `0x527c48` | `0x498739` | |
| **`PERCENTILE_CHANCE_SYNC`** | `0x48e9e0` | `0x527c30` | `0x498770` | |
| **`PLAY_SOUND`** | `0x48ea20` | `0x527c24` | `0x4987a4` | |
| **`SET_45_PATTERN_ENABLED`** | `0x48ead0` | `0x527c0c` | `0x4987d8` | |
| **`SET_DAMAGE_MULTIPLIER_ENABLED`** | `0x48eb70` | `0x527bcc` | `0x498843` | |
| **`SET_EXTRATURN_CHANCE_ENABLED`** | `0x48ebc0` | `0x527bac` | `0x49887a` | |
| **`SET_ILLEGAL_MOVE_DAMAGE_ENABLED`** | `0x48eb20` | `0x527bec` | `0x49880f` | |
| **`SET_INPUT_DATA`** | `0x48ecd0` | `0x527b94` | `0x4988e5` | |
| **`SET_WILDCARD_CHANCE_ENABLED`** | `0x48f050` | `0x527ac0` | `0x498b2d` | |
