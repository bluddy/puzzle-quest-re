
undefined4 Lua_GET_CHARACTER_X(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  short local_8 [2];
  int local_4;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    Engine_ACTIVATE_COMPANION_483650();
    Engine_ACTIVATE_COMPANION_4836e0();
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  Engine_ADD_ANIMEFFECT_TO_CHARACTER_475a10(local_8,uVar2);
  local_4 = (int)local_8[0];
  FUN_004f7020(param_1,(double)local_4);
  return 1;
}

