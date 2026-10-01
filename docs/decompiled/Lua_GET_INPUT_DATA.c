
undefined4 Lua_GET_INPUT_DATA(undefined4 param_1)

{
  int iVar1;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    Engine_ACTIVATE_COMPANION_483650();
    Engine_ACTIVATE_COMPANION_4836e0();
    return 0;
  }
  FUN_004f6db0(param_1,1);
  iVar1 = FUN_0050432c();
  FUN_004f7020(param_1,(double)*(int *)(&DAT_00580e18 + iVar1 * 4));
  return 1;
}

