
undefined4 Lua_QUEST_COUNT_DONE(undefined4 param_1)

{
  ushort uVar1;
  ushort uVar2;
  ushort uVar3;
  ushort uVar4;
  int iVar5;
  ushort *puVar6;
  ushort *puVar7;
  ushort *puVar8;
  ushort *puVar9;
  int iVar10;
  int iVar11;
  ulonglong uVar12;
  char *pcVar13;
  int iStack_1c;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515e58;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4 = 0;
  iVar5 = FUN_004f6d00(param_1,1);
  if (iVar5 == 0) {
    pcVar13 = "QUEST_COUNT_DONE: arg 1 is not a string";
    Engine_ACTIVATE_COMPANION_483650("QUEST_COUNT_DONE: arg 1 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar13);
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  FUN_004f6e50(param_1,1);
  Engine_ACTIVATE_COMPANION_4bf1a0();
  puVar6 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0();
  puVar7 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0();
  puVar8 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0();
  puVar9 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0();
  uVar1 = *puVar6;
  uVar2 = *puVar7;
  uVar3 = *puVar8;
  uVar4 = *puVar9;
  iStack_1c = 0;
  iVar5 = Engine_QUEST_ENCOUNTER_ADD_4556f0();
  uVar12 = (ulonglong)*(uint *)(iVar5 + 0x40);
  Engine_QUEST_ABANDON_44e920(*(uint *)(iVar5 + 0x40),0);
  iVar5 = Engine_QUEST_ABANDON_44d8e0(uVar12);
  if (*(int *)(iVar5 + 0x108) == 0) {
    iVar11 = 0;
  }
  else {
    iVar11 = *(int *)(iVar5 + 0x10c) - *(int *)(iVar5 + 0x108) >> 3;
  }
  iVar10 = 0;
  if (0 < iVar11) {
    do {
      if (*(uint *)(*(int *)(iVar5 + 0x108) + iVar10 * 8) ==
          ((((uint)uVar1 << 8 | (uint)uVar2) << 8 | (uint)uVar3) << 8 | (uint)uVar4)) {
        iStack_1c = (int)*(short *)(*(int *)(iVar5 + 0x108) + 6 + iVar10 * 8);
        break;
      }
      iVar10 = iVar10 + 1;
    } while (iVar10 < iVar11);
  }
  FUN_004f7020(param_1,(double)iStack_1c);
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 1;
}

