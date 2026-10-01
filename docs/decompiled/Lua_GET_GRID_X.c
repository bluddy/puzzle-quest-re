
undefined4 Lua_GET_GRID_X(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  short unaff_SI;
  short unaff_DI;
  int *piVar3;
  char *pcVar4;
  int local_c;
  undefined1 local_8 [8];
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar4 = "GET_GRID_X: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("GET_GRID_X: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  iVar1 = FUN_0050432c();
  Engine_ADD_EFFECT_TO_GRID_47b3d0(local_8,iVar1 + -1,0);
  piVar3 = &local_c;
  local_c = -1;
  uVar2 = Engine_ADD_EFFECT_TO_GRID_4b51d0(0xffffffff);
  Engine_ADD_EFFECT_TO_GRID_4b59f0(uVar2,piVar3);
  local_c = (short)(unaff_SI + unaff_DI) + 0x24;
  FUN_004f7020(param_1,(double)local_c);
  return 1;
}

