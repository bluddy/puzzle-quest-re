
undefined4 Lua_SET_ITEM(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
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
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar10 = "SET_ITEM: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("SET_ITEM: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar10);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,2);
  if (iVar1 == 0) {
    pcVar10 = "SET_ITEM: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("SET_ITEM: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar10);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,2);
  uVar3 = FUN_0050432c();
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  uStack_4 = 0;
  iVar1 = FUN_004f6d00(param_1,3);
  if (iVar1 == 0) {
    pcVar10 = "SET_ITEM: arg 3 is not a string";
    Engine_ACTIVATE_COMPANION_483650("SET_ITEM: arg 3 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar10);
    uStack_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = pvStack_c;
    return 0;
  }
  uVar4 = FUN_004f6e50(param_1,3);
  Engine_ACTIVATE_COMPANION_4bf1a0(uVar4);
  puVar5 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(3);
  puVar6 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(2);
  puVar7 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(1);
  puVar8 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(0);
  uVar9 = (((uint)*puVar5 << 8 | (uint)*puVar6) << 8 | (uint)*puVar7) << 8 | (uint)*puVar8;
  Engine_GET_CURRENT_RUNE_CODE_44f8e0(uVar9);
  uVar4 = FUN_0041f6e0(uVar9);
  Engine_ADD_GOLD_447c60(uVar2);
  Engine_ADD_GOLD_446200(uVar2);
  FUN_00447da0(uVar3,uVar4);
  uStack_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = pvStack_c;
  return 0;
}

