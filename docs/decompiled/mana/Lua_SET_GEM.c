
undefined4 Lua_SET_GEM(undefined4 param_1)

{
  int iVar1;
  int iVar2;
  int iVar3;
  undefined4 uVar4;
  char *pcVar5;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar5 = "SET_GEM: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("SET_GEM: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar5);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  iVar1 = FUN_0050432c();
  iVar2 = FUN_004f6ca0(param_1,2);
  if (iVar2 == 0) {
    pcVar5 = "SET_GEM: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("SET_GEM: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar5);
    return 0;
  }
  FUN_004f6db0(param_1,2);
  iVar2 = FUN_0050432c();
  iVar3 = FUN_004f6ca0(param_1,3);
  if (iVar3 == 0) {
    pcVar5 = "SET_GEM: arg 3 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("SET_GEM: arg 3 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar5);
    return 0;
  }
  FUN_004f6db0(param_1,3);
  uVar4 = FUN_0050432c();
  iVar3 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  *(undefined4 *)(iVar3 + -0x44 + (iVar2 + iVar1 * 8 + iVar1) * 8) = uVar4;
  return 0;
}

