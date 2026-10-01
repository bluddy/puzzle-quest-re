
undefined4 Lua_DESTROY_GEM(undefined4 param_1)

{
  int iVar1;
  int iVar2;
  undefined4 uVar3;
  char *pcVar4;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar4 = "DESTROY_GEM: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("DESTROY_GEM: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  iVar1 = FUN_0050432c();
  iVar2 = FUN_004f6ca0(param_1,2);
  if (iVar2 == 0) {
    pcVar4 = "DESTROY_GEM: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("DESTROY_GEM: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    return 0;
  }
  FUN_004f6db0(param_1,2);
  uVar3 = FUN_0050432c();
  iVar1 = iVar1 + -1;
  Engine_ADD_ANIMEFFECT_TO_GRID_47a820(iVar1,uVar3);
  FUN_0047e000(iVar1,uVar3);
  return 0;
}

