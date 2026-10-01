
undefined4 Lua_QUEST_COMPANION_MESSAGE(undefined4 param_1)

{
  bool bVar1;
  int iVar2;
  undefined4 uVar3;
  short *psVar4;
  ushort *puVar5;
  ushort *puVar6;
  ushort *puVar7;
  ushort *puVar8;
  undefined4 uVar9;
  uint uVar10;
  undefined4 uVar11;
  char *pcVar12;
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
    pcVar12 = "QUEST_COMPANION_MESSAGE: arg 1 is not a string";
    Engine_ACTIVATE_COMPANION_483650("QUEST_COMPANION_MESSAGE: arg 1 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar12);
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  uVar3 = FUN_004f6e50(param_1,1);
  Engine_ACTIVATE_COMPANION_4bf1a0(uVar3);
  psVar4 = (short *)Engine_ACTIVATE_COMPANION_4be7e0(0);
  if (*psVar4 == 0) {
    uVar10 = 0;
  }
  else {
    puVar5 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(3);
    puVar6 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(2);
    puVar7 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(1);
    puVar8 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(0);
    uVar10 = (((uint)*puVar5 << 8 | (uint)*puVar6) << 8 | (uint)*puVar7) << 8 | (uint)*puVar8;
  }
  iVar2 = Engine_QUEST_ENCOUNTER_ADD_4556f0();
  uVar3 = *(undefined4 *)(iVar2 + 0x40);
  uVar11 = 0;
  uVar9 = uVar3;
  Engine_QUEST_ABANDON_44e920(uVar3,0);
  Engine_QUEST_ABANDON_44d8e0(uVar9,uVar11);
  bVar1 = false;
  iVar2 = FUN_00408b90(uVar10);
  if ((iVar2 != 0) && (*(char *)(iVar2 + 6) != '\0')) {
    bVar1 = true;
  }
  uVar9 = 0;
  iVar2 = FUN_00419060();
  if ((7 < iVar2) && (!bVar1)) {
    uVar9 = 1;
  }
  FUN_004086d0(uVar3,uVar10,uVar9,0);
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 0;
}

