
undefined4 Lua_HAS_STATUS_EFFECT(undefined4 param_1)

{
  char cVar1;
  int iVar2;
  undefined4 uVar3;
  undefined4 uVar4;
  ushort *puVar5;
  ushort *puVar6;
  ushort *puVar7;
  ushort *puVar8;
  uint uVar9;
  char *pcVar10;
  void *pvStack_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_00515e58;
  pvStack_c = ExceptionList;
  ExceptionList = &pvStack_c;
  iVar2 = FUN_004f6ca0(param_1,1);
  if (iVar2 == 0) {
    pcVar10 = "HAS_STATUS_EFFECT: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("HAS_STATUS_EFFECT: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar10);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar3 = FUN_0050432c();
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  uStack_4 = 0;
  iVar2 = FUN_004f6d00(param_1,2);
  if (iVar2 == 0) {
    pcVar10 = "HAS_STATUS_EFFECT: arg 2 is not a string";
    Engine_ACTIVATE_COMPANION_483650("HAS_STATUS_EFFECT: arg 2 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar10);
    uStack_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = pvStack_c;
    return 0;
  }
  uVar4 = FUN_004f6e50(param_1,2);
  Engine_ACTIVATE_COMPANION_4bf1a0(uVar4);
  puVar5 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(3);
  puVar6 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(2);
  puVar7 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(1);
  puVar8 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(0);
  uVar9 = (((uint)*puVar5 << 8 | (uint)*puVar6) << 8 | (uint)*puVar7) << 8 | (uint)*puVar8;
  Engine_ADD_GOLD_447c60(uVar3,uVar9);
  cVar1 = FUN_00445ee0(uVar3,uVar9);
  FUN_004f71f0(param_1,(int)cVar1);
  uStack_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = pvStack_c;
  return 1;
}

