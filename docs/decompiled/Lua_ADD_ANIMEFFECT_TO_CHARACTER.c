
undefined4 Lua_ADD_ANIMEFFECT_TO_CHARACTER(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  int iVar4;
  undefined4 *puVar5;
  int *piVar6;
  char *pcVar7;
  short sStack_24;
  short sStack_22;
  int iStack_20;
  undefined4 auStack_1c [4];
  void *pvStack_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_00515e58;
  pvStack_c = ExceptionList;
  ExceptionList = &pvStack_c;
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar7 = "ADD_ANIMEFFECT_TO_CHARACTER: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("ADD_ANIMEFFECT_TO_CHARACTER: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar7);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  uStack_4 = 0;
  iVar1 = FUN_004f6d00(param_1,2);
  if (iVar1 == 0) {
    pcVar7 = "ADD_ANIMEFFECT_TO_CHARACTER: arg 2 is not a string";
    Engine_ACTIVATE_COMPANION_483650("ADD_ANIMEFFECT_TO_CHARACTER: arg 2 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar7);
  }
  else {
    uVar3 = FUN_004f6e50(param_1,2);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar3);
    FUN_00475a10(&sStack_24,uVar2);
    iVar1 = (int)sStack_22;
    piVar6 = &iStack_20;
    iVar4 = (int)sStack_24;
    puVar5 = auStack_1c;
    Engine_ADD_ANIMEFFECT_TO_GRID_47a820(iVar4,iVar1,puVar5,piVar6);
    FUN_0047b370(iVar4,iVar1,puVar5,piVar6);
    iVar1 = iStack_20 + 0x49;
    iStack_20 = iVar1;
    uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(auStack_1c[0],iVar1);
    Engine_ADD_ANIMEFFECT_TO_GRID_483380(uVar2);
    Engine_ADD_ANIMEFFECT_TO_GRID_483560(uVar2,auStack_1c[0],iVar1);
  }
  uStack_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = pvStack_c;
  return 0;
}

