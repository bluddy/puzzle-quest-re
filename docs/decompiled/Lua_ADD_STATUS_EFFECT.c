
undefined4 Lua_ADD_STATUS_EFFECT(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  ushort *puVar4;
  ushort *puVar5;
  ushort *puVar6;
  ushort *puVar7;
  uint uVar8;
  char *pcVar9;
  void *pvStack_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_00515e58;
  pvStack_c = ExceptionList;
  ExceptionList = &pvStack_c;
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar9 = "ADD_STATUS_EFFECT: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("ADD_STATUS_EFFECT: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar9);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  uStack_4 = 0;
  iVar1 = FUN_004f6d00(param_1,2);
  if (iVar1 == 0) {
    pcVar9 = "ADD_STATUS_EFFECT: arg 2 is not a string";
    Engine_ACTIVATE_COMPANION_483650("ADD_STATUS_EFFECT: arg 2 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar9);
    uStack_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = pvStack_c;
    return 0;
  }
  uVar3 = FUN_004f6e50(param_1,2);
  Engine_ACTIVATE_COMPANION_4bf1a0(uVar3);
  puVar4 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(3);
  puVar5 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(2);
  puVar6 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(1);
  puVar7 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(0);
  uVar8 = (((uint)*puVar4 << 8 | (uint)*puVar5) << 8 | (uint)*puVar6) << 8 | (uint)*puVar7;
  uVar3 = 0xffffffff;
  Engine_ADD_GOLD_447c60(uVar2,uVar8,0xffffffff);
  FUN_004474c0(uVar2,uVar8,uVar3);
  uStack_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = pvStack_c;
  return 0;
}

