
undefined4 Lua_QUEST_REWARD_ITEM_WITH_TEXT(undefined4 param_1)

{
  ushort uVar1;
  ushort uVar2;
  ushort uVar3;
  ushort uVar4;
  int iVar5;
  undefined4 uVar6;
  ushort *puVar7;
  ushort *puVar8;
  ushort *puVar9;
  ushort *puVar10;
  char *pcVar11;
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515d40;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4 = 0;
  iVar5 = FUN_004f6d00(param_1,1);
  if (iVar5 == 0) {
    pcVar11 = "QUEST_REWARD_ITEM_WITH_TEXT: arg 1 is not a string";
    Engine_ACTIVATE_COMPANION_483650("QUEST_REWARD_ITEM_WITH_TEXT: arg 1 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar11);
  }
  else {
    uVar6 = FUN_004f6e50(param_1,1);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar6);
    Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
    local_4._0_1_ = 1;
    iVar5 = FUN_004f6d00(param_1,2);
    if (iVar5 != 0) {
      uVar6 = FUN_004f6e50(param_1,2);
      Engine_ACTIVATE_COMPANION_4bf1a0(uVar6);
      puVar7 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(3);
      puVar8 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(2);
      puVar9 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(1);
      puVar10 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(0);
      uVar1 = *puVar7;
      uVar2 = *puVar8;
      uVar3 = *puVar9;
      uVar4 = *puVar10;
      uVar6 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      FUN_0042d2f0((((uint)uVar1 << 8 | (uint)uVar2) << 8 | (uint)uVar3) << 8 | (uint)uVar4,uVar6);
      local_4 = (uint)local_4._1_3_ << 8;
      Engine_ACTIVATE_COMPANION_4bdf40();
      local_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
      ExceptionList = local_c;
      return 0;
    }
    pcVar11 = "QUEST_REWARD_ITEM_WITH_TEXT: arg 2 is not a string";
    Engine_ACTIVATE_COMPANION_483650("QUEST_REWARD_ITEM_WITH_TEXT: arg 2 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar11);
    local_4 = (uint)local_4._1_3_ << 8;
    Engine_ACTIVATE_COMPANION_4bdf40();
  }
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 0;
}

