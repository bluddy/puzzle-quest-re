
undefined4 Lua_SUBTRACT_XP(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  char *pcVar4;
  void *pvStack_c;
  undefined *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &DAT_00515e7b;
  pvStack_c = ExceptionList;
  ExceptionList = &pvStack_c;
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar4 = "SUBTRACT_XP: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("SUBTRACT_XP: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,2);
  if (iVar1 == 0) {
    pcVar4 = "SUBTRACT_XP: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("SUBTRACT_XP: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
  }
  else {
    FUN_004f6db0(param_1,2);
    uVar3 = FUN_0050432c();
    Engine_ADD_GOLD_447c60(uVar2);
    uVar2 = Engine_ADD_GOLD_446200(uVar2);
    Engine_ADD_GOLD_404570(uVar2);
    uStack_4 = 0;
    FUN_00483a40(uVar3);
    Engine_ADD_GOLD_4046a0();
  }
  ExceptionList = pvStack_c;
  return 0;
}

