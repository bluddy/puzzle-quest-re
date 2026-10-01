
undefined4 Lua_GET_NUM_SPELLS(undefined4 param_1)

{
  int iVar1;
  undefined4 uStack_4;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    Engine_ACTIVATE_COMPANION_483650();
    Engine_ACTIVATE_COMPANION_4836e0();
    return 0;
  }
  FUN_004f6db0(param_1,1);
  FUN_0050432c();
  Engine_ADD_GOLD_447c60();
  iVar1 = Engine_ADD_GOLD_446200();
  if (*(int *)(iVar1 + 0x2c) == 0) {
    uStack_4 = 0;
  }
  else {
    uStack_4 = *(int *)(iVar1 + 0x30) - *(int *)(iVar1 + 0x2c) >> 2;
  }
  FUN_004f7020(param_1,(double)uStack_4);
  return 1;
}

