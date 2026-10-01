
undefined4 Lua_GET_CURRENT_PLAYER(undefined4 param_1)

{
  int iVar1;
  
  iVar1 = Engine_EXTRA_TURN_4646e0();
  FUN_004f7020(param_1,(double)*(int *)(iVar1 + 4 + *(int *)(iVar1 + 0x28) * 4));
  return 1;
}

