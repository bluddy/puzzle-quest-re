
undefined4 Lua_GET_STATUS_EFFECT_DURATION(undefined4 param_1)

{
  int iVar1;
  int iVar2;
  undefined4 uVar3;
  undefined4 uVar4;
  char *pcVar5;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar5 = "GET_STATUS_EFFECT_DURATION: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("GET_STATUS_EFFECT_DURATION: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar5);
    return 0;
  }
  uVar4 = 1;
  uVar3 = param_1;
  FUN_004f6db0();
  FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,2,uVar3,uVar4);
  if (iVar1 == 0) {
    pcVar5 = "GET_STATUS_EFFECT_DURATION: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("GET_STATUS_EFFECT_DURATION: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar5);
    return 0;
  }
  FUN_004f6db0(param_1,2);
  iVar1 = FUN_0050432c();
  Engine_ADD_GOLD_447c60();
  iVar2 = Engine_ADD_GOLD_446200();
  FUN_004f7020(param_1,(double)*(int *)(*(int *)(iVar2 + 0x5c) + 4 + iVar1 * 8));
  return 1;
}

