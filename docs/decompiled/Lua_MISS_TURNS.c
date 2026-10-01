
undefined4 Lua_MISS_TURNS(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  char *pcVar4;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar4 = "MISS_TURNS: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("MISS_TURNS: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,2);
  if (iVar1 == 0) {
    pcVar4 = "MISS_TURNS: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("MISS_TURNS: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    return 0;
  }
  FUN_004f6db0(param_1,2);
  uVar3 = FUN_0050432c();
  Engine_EXTRA_TURN_4646e0(uVar2,uVar3);
  FUN_00464ba0(uVar2,uVar3);
  return 0;
}

