
undefined4 Lua_CHECK_TYPE(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  undefined8 uVar4;
  char *pcVar5;
  void *pvStack_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_00515e58;
  pvStack_c = ExceptionList;
  ExceptionList = &pvStack_c;
  iVar1 = FUN_004f6ca0();
  if (iVar1 == 0) {
    pcVar5 = "CHECK_TYPE: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("CHECK_TYPE: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar5);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  uStack_4 = 0;
  iVar1 = FUN_004f6d00(param_1,2);
  if (iVar1 == 0) {
    Engine_ACTIVATE_COMPANION_483650();
    Engine_ACTIVATE_COMPANION_4836e0();
    uStack_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6e50(param_1,2);
  Engine_ACTIVATE_COMPANION_4bf1a0();
  uVar3 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
  uVar4 = CONCAT44(uVar3,uVar2);
  Engine_ADD_GOLD_447c60(uVar2,uVar3);
  iVar1 = FUN_004461d0(uVar4);
  FUN_004f7020(param_1,(double)iVar1);
  uStack_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = pvStack_c;
  return 1;
}

