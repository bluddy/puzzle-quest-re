
undefined4 Lua_GET_GEM(undefined4 param_1)

{
  int iVar1;
  int iVar2;
  int iVar3;
  undefined4 uVar4;
  undefined4 uVar5;
  char *pcVar6;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar6 = "GET_GEM: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("GET_GEM: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar6);
    return 0;
  }
  uVar5 = 1;
  uVar4 = param_1;
  FUN_004f6db0();
  iVar1 = FUN_0050432c();
  iVar2 = FUN_004f6ca0(param_1,2,uVar4,uVar5);
  if (iVar2 == 0) {
    pcVar6 = "GET_GEM: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("GET_GEM: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar6);
    return 0;
  }
  FUN_004f6db0(param_1,2);
  iVar2 = FUN_0050432c();
  iVar3 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  FUN_004f7020(param_1,(double)*(int *)(iVar3 + -0x44 + (iVar2 + iVar1 * 8 + iVar1) * 8));
  return 1;
}

