
undefined4 Lua_GET_GRID_Y(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 unaff_ESI;
  undefined4 unaff_EDI;
  int *piVar3;
  char *pcVar4;
  short sVar5;
  int local_c;
  undefined1 local_8 [8];
  
  sVar5 = (short)((uint)unaff_EDI >> 0x10);
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar4 = "GET_GRID_Y: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("GET_GRID_Y: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  iVar1 = FUN_0050432c();
  Engine_ADD_EFFECT_TO_GRID_47b3d0(local_8,0,iVar1 + -1);
  piVar3 = &local_c;
  local_c = -1;
  uVar2 = Engine_ADD_EFFECT_TO_GRID_4b51d0(0xffffffff);
  Engine_ADD_EFFECT_TO_GRID_4b59f0(uVar2,piVar3);
  local_c = (short)((short)((uint)unaff_ESI >> 0x10) + sVar5) + 0x24;
  FUN_004f7020(param_1,(double)local_c);
  return 1;
}

