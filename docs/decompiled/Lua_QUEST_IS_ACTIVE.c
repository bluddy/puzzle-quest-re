
undefined4 Lua_QUEST_IS_ACTIVE(undefined4 param_1)

{
  ushort uVar1;
  ushort uVar2;
  ushort uVar3;
  ushort uVar4;
  char cVar5;
  int iVar6;
  ushort *puVar7;
  ushort *puVar8;
  ushort *puVar9;
  ushort *puVar10;
  uint *puVar11;
  int iVar12;
  ulonglong uVar13;
  char *pcVar14;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515e58;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4 = 0;
  iVar6 = FUN_004f6d00(param_1,1);
  if (iVar6 == 0) {
    pcVar14 = "QUEST_IS_ACTIVE: arg 1 is not a string";
    Engine_ACTIVATE_COMPANION_483650("QUEST_IS_ACTIVE: arg 1 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar14);
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  FUN_004f6e50(param_1,1);
  Engine_ACTIVATE_COMPANION_4bf1a0();
  puVar7 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0();
  puVar8 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0();
  puVar9 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0();
  puVar10 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0();
  uVar1 = *puVar7;
  uVar2 = *puVar8;
  uVar3 = *puVar9;
  uVar4 = *puVar10;
  iVar6 = Engine_QUEST_ENCOUNTER_ADD_4556f0();
  uVar13 = (ulonglong)*(uint *)(iVar6 + 0x40);
  Engine_QUEST_ABANDON_44e920(*(uint *)(iVar6 + 0x40),0);
  iVar6 = Engine_QUEST_ABANDON_44d8e0(uVar13);
  iVar12 = 0;
  if (0 < *(int *)(iVar6 + 0x1cc)) {
    puVar11 = (uint *)(iVar6 + 0x1d0);
    do {
      if (*puVar11 == ((((uint)uVar1 << 8 | (uint)uVar2) << 8 | (uint)uVar3) << 8 | (uint)uVar4)) {
        cVar5 = '\x01';
        goto LAB_00493403;
      }
      iVar12 = iVar12 + 1;
      puVar11 = (uint *)((int)puVar11 + 6);
    } while (iVar12 < *(int *)(iVar6 + 0x1cc));
  }
  cVar5 = '\0';
LAB_00493403:
  FUN_004f7020(param_1,(double)(int)cVar5);
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 1;
}

