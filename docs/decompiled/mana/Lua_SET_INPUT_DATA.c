
undefined4 Lua_SET_INPUT_DATA(undefined4 param_1)

{
  int iVar1;
  int iVar2;
  undefined4 uVar3;
  char *pcVar4;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar4 = "SET_INPUT_DATA: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("SET_INPUT_DATA: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  iVar1 = FUN_0050432c();
  iVar2 = FUN_004f6ca0(param_1,2);
  if (iVar2 == 0) {
    pcVar4 = "SET_INPUT_DATA: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("SET_INPUT_DATA: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    return 0;
  }
  FUN_004f6db0(param_1,2);
  uVar3 = FUN_0050432c();
  *(undefined4 *)(&DAT_00580e18 + iVar1 * 4) = uVar3;
  return 0;
}

