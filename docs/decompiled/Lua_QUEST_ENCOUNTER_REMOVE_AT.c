
undefined4 Lua_QUEST_ENCOUNTER_REMOVE_AT(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  ushort *puVar3;
  ushort *puVar4;
  ushort *puVar5;
  ushort *puVar6;
  uint uVar7;
  uint uVar8;
  undefined4 uVar9;
  char *pcVar10;
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515d40;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4 = 0;
  iVar1 = FUN_004f6d00(param_1,1);
  if (iVar1 == 0) {
    pcVar10 = "QUEST_ENCOUNTER_REMOVE_AT: arg 1 is not a string";
    Engine_ACTIVATE_COMPANION_483650("QUEST_ENCOUNTER_REMOVE_AT: arg 1 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar10);
  }
  else {
    uVar2 = FUN_004f6e50(param_1,1);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
    Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
    local_4._0_1_ = 1;
    iVar1 = FUN_004f6d00(param_1,2);
    if (iVar1 == 0) {
      pcVar10 = "QUEST_ENCOUNTER_REMOVE_AT: arg 2 is not a string";
      Engine_ACTIVATE_COMPANION_483650("QUEST_ENCOUNTER_REMOVE_AT: arg 2 is not a string");
      Engine_ACTIVATE_COMPANION_4836e0(pcVar10);
      local_4 = (uint)local_4._1_3_ << 8;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
    else {
      uVar2 = FUN_004f6e50(param_1,2);
      Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
      puVar3 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(3);
      puVar4 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(2);
      puVar5 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(1);
      puVar6 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(0);
      uVar8 = (((uint)*puVar3 << 8 | (uint)*puVar4) << 8 | (uint)*puVar5) << 8 | (uint)*puVar6;
      puVar3 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(3);
      puVar4 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(2);
      puVar5 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(1);
      puVar6 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(0);
      uVar7 = (((uint)*puVar3 << 8 | (uint)*puVar4) << 8 | (uint)*puVar5) << 8 | (uint)*puVar6;
      Engine_QUEST_ENCOUNTER_ADD_4556f0(uVar8,uVar7);
      iVar1 = Engine_QUEST_ENCOUNTER_GET_AT_451180(uVar8,uVar7);
      if (iVar1 != 0) {
        uVar2 = *(undefined4 *)(iVar1 + 4);
        uVar9 = 1;
        Engine_QUEST_ENCOUNTER_ADD_4556f0(1,uVar2);
        Engine_QUEST_ENCOUNTER_ADD_4511f0(uVar9,uVar2);
        uVar2 = *(undefined4 *)(iVar1 + 4);
        Engine_QUEST_ENCOUNTER_ADD_4556f0(uVar2);
        Engine_QUEST_ENCOUNTER_REMOVE_4531f0(uVar2);
      }
      local_4 = (uint)local_4._1_3_ << 8;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
  }
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 0;
}

