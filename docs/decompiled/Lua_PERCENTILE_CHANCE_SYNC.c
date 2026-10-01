
undefined4 __thiscall Lua_PERCENTILE_CHANCE_SYNC(undefined4 param_1,undefined4 param_2)

{
  int iVar1;
  
  Engine_ACTIVATE_COMPANION_483650(param_1);
  iVar1 = Engine_GET_RANDOM_4bd280(1,100);
  FUN_004f7020(param_2,(double)iVar1);
  return 1;
}

