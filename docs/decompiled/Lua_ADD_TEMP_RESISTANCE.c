
undefined4 Lua_ADD_TEMP_RESISTANCE(undefined4 param_1)

{
  int *piVar1;
  int iVar2;
  undefined4 uVar3;
  int iVar4;
  int iVar5;
  char *pcVar6;
  
  iVar2 = FUN_004f6ca0(param_1,1);
  if (iVar2 == 0) {
    pcVar6 = "ADD_TEMP_RESISTANCE: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("ADD_TEMP_RESISTANCE: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar6);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar3 = FUN_0050432c();
  iVar2 = FUN_004f6ca0(param_1,2);
  if (iVar2 == 0) {
    pcVar6 = "ADD_TEMP_RESISTANCE: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("ADD_TEMP_RESISTANCE: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar6);
    return 0;
  }
  FUN_004f6db0(param_1,2);
  iVar2 = FUN_0050432c();
  iVar4 = FUN_004f6ca0(param_1,3);
  if (iVar4 == 0) {
    pcVar6 = "ADD_TEMP_RESISTANCE: arg 3 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("ADD_TEMP_RESISTANCE: arg 3 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar6);
    return 0;
  }
  FUN_004f6db0(param_1,3);
  iVar4 = FUN_0050432c();
  Engine_ADD_GOLD_447c60(uVar3);
  iVar5 = Engine_ADD_GOLD_446200(uVar3);
  piVar1 = (int *)(iVar5 + 0x94 + iVar2 * 4);
  *piVar1 = *piVar1 + iVar4;
  return 0;
}

