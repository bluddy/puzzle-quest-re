
undefined4 Lua_QUEST_COMPLETE_PART(undefined4 param_1)

{
  ushort uVar1;
  ushort uVar2;
  ushort uVar3;
  ushort uVar4;
  ushort uVar5;
  ushort uVar6;
  ushort uVar7;
  ushort uVar8;
  undefined1 uVar9;
  int iVar10;
  undefined4 uVar11;
  ushort *puVar12;
  ushort *puVar13;
  ushort *puVar14;
  ushort *puVar15;
  undefined4 uVar16;
  char *pcVar17;
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515d40;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4 = 0;
  iVar10 = FUN_004f6d00(param_1,1);
  if (iVar10 == 0) {
    pcVar17 = "QUEST_COMPLETE_PART: arg 1 is not a string";
    Engine_ACTIVATE_COMPANION_483650("QUEST_COMPLETE_PART: arg 1 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  uVar11 = FUN_004f6e50(param_1,1);
  Engine_ACTIVATE_COMPANION_4bf1a0(uVar11);
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4._0_1_ = 1;
  iVar10 = FUN_004f6d00(param_1,2);
  if (iVar10 == 0) {
    pcVar17 = "QUEST_COMPLETE_PART: arg 2 is not a string";
    Engine_ACTIVATE_COMPANION_483650("QUEST_COMPLETE_PART: arg 2 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
    local_4 = (uint)local_4._1_3_ << 8;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  uVar11 = FUN_004f6e50(param_1,2);
  Engine_ACTIVATE_COMPANION_4bf1a0(uVar11);
  iVar10 = FUN_004f6ca0(param_1,3);
  if (iVar10 == 0) {
    pcVar17 = "QUEST_COMPLETE_PART: arg 3 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("QUEST_COMPLETE_PART: arg 3 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
    local_4 = (uint)local_4._1_3_ << 8;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  FUN_004f6db0(param_1,3);
  uVar9 = FUN_0050432c();
  puVar12 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(3);
  puVar13 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(2);
  puVar14 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(1);
  puVar15 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(0);
  uVar1 = *puVar12;
  uVar2 = *puVar13;
  uVar3 = *puVar14;
  uVar4 = *puVar15;
  puVar12 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(3);
  puVar13 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(2);
  puVar14 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(1);
  puVar15 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(0);
  uVar5 = *puVar12;
  uVar6 = *puVar13;
  uVar7 = *puVar14;
  uVar8 = *puVar15;
  iVar10 = Engine_QUEST_ENCOUNTER_ADD_4556f0();
  uVar11 = *(undefined4 *)(iVar10 + 0x40);
  uVar16 = 0;
  Engine_QUEST_ABANDON_44e920(uVar11,0);
  iVar10 = Engine_QUEST_ABANDON_44d8e0(uVar11,uVar16);
  *(uint *)(iVar10 + 0x1e8) =
       (((uint)uVar1 << 8 | (uint)uVar2) << 8 | (uint)uVar3) << 8 | (uint)uVar4;
  *(uint *)(iVar10 + 0x1ec) =
       (((uint)uVar5 << 8 | (uint)uVar6) << 8 | (uint)uVar7) << 8 | (uint)uVar8;
  *(undefined1 *)(iVar10 + 0x1f0) = uVar9;
  *(undefined1 *)(iVar10 + 0xbc) = 1;
  FUN_00469310();
  uVar11 = 1;
  Engine_QUEST_ENCOUNTER_ADD_4556f0(1);
  FUN_004507a0(uVar11);
  local_4 = (uint)local_4._1_3_ << 8;
  Engine_ACTIVATE_COMPANION_4bdf40();
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 0;
}

