
undefined4 Lua_QUEST_ADD_ITEM(undefined4 param_1)

{
  char cVar1;
  int iVar2;
  undefined4 uVar3;
  ushort *puVar4;
  ushort *puVar5;
  ushort *puVar6;
  ushort *puVar7;
  uint uVar8;
  undefined4 uVar9;
  char *pcVar10;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515e58;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4 = 0;
  iVar2 = FUN_004f6d00(param_1,1);
  if (iVar2 == 0) {
    pcVar10 = "QUEST_ADD_ITEM: arg 1 is not a string";
    Engine_ACTIVATE_COMPANION_483650("QUEST_ADD_ITEM: arg 1 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar10);
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  uVar3 = FUN_004f6e50(param_1,1);
  Engine_ACTIVATE_COMPANION_4bf1a0(uVar3);
  puVar4 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(3);
  puVar5 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(2);
  puVar6 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(1);
  puVar7 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(0);
  uVar8 = (((uint)*puVar4 << 8 | (uint)*puVar5) << 8 | (uint)*puVar6) << 8 | (uint)*puVar7;
  iVar2 = Engine_QUEST_ENCOUNTER_ADD_4556f0();
  uVar3 = *(undefined4 *)(iVar2 + 0x40);
  uVar9 = 0;
  Engine_QUEST_ABANDON_44e920(uVar3,0);
  Engine_QUEST_ABANDON_44d8e0(uVar3,uVar9);
  cVar1 = FUN_004686f0(uVar8);
  if (cVar1 == '\0') {
    FUN_0046c820(uVar8);
    FUN_004b1590();
  }
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 0;
}

