
undefined4 Lua_GET_RANDOM(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  char *pcVar4;
  
  iVar1 = FUN_004f6ca0();
  if (iVar1 == 0) {
    pcVar4 = "GET_RANDOM: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("GET_RANDOM: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,2);
  if (iVar1 == 0) {
    Engine_ACTIVATE_COMPANION_483650();
    Engine_ACTIVATE_COMPANION_4836e0();
    return 0;
  }
  FUN_004f6db0(param_1,2);
  uVar3 = FUN_0050432c();
  iVar1 = Engine_GET_RANDOM_4bd280(uVar2,uVar3);
  FUN_004f7020(param_1,(double)iVar1);
  return 1;
}

