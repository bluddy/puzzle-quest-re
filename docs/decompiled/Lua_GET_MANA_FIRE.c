
undefined4 Lua_GET_MANA_FIRE(undefined4 param_1)

{
  int iVar1;
  int *piVar2;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    Engine_ACTIVATE_COMPANION_483650();
    Engine_ACTIVATE_COMPANION_4836e0();
    return 0;
  }
  FUN_004f6db0(param_1,1);
  FUN_0050432c();
  Engine_ADD_GOLD_447c60();
  piVar2 = (int *)Engine_ADD_GOLD_446200();
  FUN_004f7020(param_1,(double)*(int *)(*piVar2 + 0x78));
  return 1;
}

