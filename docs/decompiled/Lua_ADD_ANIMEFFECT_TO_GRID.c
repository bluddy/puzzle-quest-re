
undefined4 Lua_ADD_ANIMEFFECT_TO_GRID(undefined4 param_1)

{
  int iVar1;
  int iVar2;
  undefined4 uVar3;
  undefined4 uVar4;
  undefined4 *puVar5;
  undefined4 *puVar6;
  char *pcVar7;
  undefined4 uStack_20;
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
    pcVar7 = "ADD_ANIMEFFECT_TO_GRID: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("ADD_ANIMEFFECT_TO_GRID: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar7);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,1);
  iVar1 = FUN_0050432c();
  iVar2 = FUN_004f6ca0(param_1,2);
  if (iVar2 == 0) {
    pcVar7 = "ADD_ANIMEFFECT_TO_GRID: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("ADD_ANIMEFFECT_TO_GRID: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar7);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,2);
  uVar3 = FUN_0050432c();
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  uStack_4 = 0;
  iVar2 = FUN_004f6d00(param_1,3);
  if (iVar2 == 0) {
    pcVar7 = "ADD_ANIMEFFECT_TO_GRID: arg 3 is not a string";
    Engine_ACTIVATE_COMPANION_483650("ADD_ANIMEFFECT_TO_GRID: arg 3 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar7);
  }
  else {
    uVar4 = FUN_004f6e50(param_1,3);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar4);
    puVar6 = &uStack_20;
    puVar5 = auStack_1c;
    iVar1 = iVar1 + -1;
    FUN_0047a820(iVar1,uVar3,puVar5,puVar6);
    FUN_0047b3a0(iVar1,uVar3,puVar5,puVar6);
    uVar3 = FUN_004bddc0(auStack_1c[0],uStack_20);
    FUN_00483380(uVar3);
    FUN_00483560(uVar3,auStack_1c[0],uStack_20);
  }
  uStack_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = pvStack_c;
  return 0;
}

