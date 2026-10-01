
undefined4 Lua_SET_STATUS_EFFECT_DURATION(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  undefined4 uVar4;
  char *pcVar5;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar5 = "SET_STATUS_EFFECT_DURATION: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("SET_STATUS_EFFECT_DURATION: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar5);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,2);
  if (iVar1 == 0) {
    pcVar5 = "SET_STATUS_EFFECT_DURATION: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("SET_STATUS_EFFECT_DURATION: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar5);
    return 0;
  }
  FUN_004f6db0(param_1,2);
  uVar3 = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,3);
  if (iVar1 == 0) {
    pcVar5 = "SET_STATUS_EFFECT_DURATION: arg 3 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("SET_STATUS_EFFECT_DURATION: arg 3 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar5);
    return 0;
  }
  FUN_004f6db0(param_1,3);
  uVar4 = FUN_0050432c();
  Engine_ADD_GOLD_447c60(uVar2,uVar3,uVar4);
  FUN_00445fc0(uVar2,uVar3,uVar4);
  return 0;
}

