
undefined4 Lua_SET_MAX_MANA_AIR(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  char *pcVar4;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar4 = "SET_MAX_MANA_AIR: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("SET_MAX_MANA_AIR: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,2);
  if (iVar1 == 0) {
    pcVar4 = "SET_MAX_MANA_AIR: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("SET_MAX_MANA_AIR: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    return 0;
  }
  FUN_004f6db0(param_1,2);
  uVar3 = FUN_0050432c();
  Engine_ADD_GOLD_447c60(uVar2);
  Engine_ADD_GOLD_446200(uVar2);
  Engine_ADD_TEMP_SKILL_4839f0(2,uVar3);
  return 0;
}

