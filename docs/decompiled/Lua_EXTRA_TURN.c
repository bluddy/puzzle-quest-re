
undefined4 Lua_EXTRA_TURN(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  char *pcVar4;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar4 = "EXTRA_TURN: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("EXTRA_TURN: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,2);
  if (iVar1 == 0) {
    pcVar4 = "EXTRA_TURN: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("EXTRA_TURN: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    return 0;
  }
  FUN_004f6db0(param_1,2);
  uVar3 = FUN_0050432c();
  FUN_004646e0(uVar2,uVar3);
  FUN_00464cb0(uVar2,uVar3);
  return 0;
}

