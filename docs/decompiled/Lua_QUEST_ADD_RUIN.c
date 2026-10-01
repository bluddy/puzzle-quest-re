
undefined4 Lua_QUEST_ADD_RUIN(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  ushort *puVar3;
  ushort *puVar4;
  ushort *puVar5;
  ushort *puVar6;
  uint uVar7;
  uint uVar8;
  char *pcVar9;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515e58;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4 = 0;
  iVar1 = FUN_004f6d00(param_1,1);
  if (iVar1 == 0) {
    pcVar9 = "QUEST_ADD_RUIN: arg 1 is not a string";
    Engine_ACTIVATE_COMPANION_483650("QUEST_ADD_RUIN: arg 1 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar9);
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  uVar2 = FUN_004f6e50(param_1,1);
  Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
  puVar3 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(3);
  puVar4 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(2);
  puVar5 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(1);
  puVar6 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(0);
  uVar7 = (((uint)*puVar3 << 8 | (uint)*puVar4) << 8 | (uint)*puVar5) << 8 | (uint)*puVar6;
  uVar8 = uVar7;
  Engine_QUEST_ENCOUNTER_ADD_4556f0(uVar7);
  FUN_00452010(uVar8);
  uVar2 = 0;
  Engine_QUEST_ENCOUNTER_ADD_4556f0(0,uVar7);
  FUN_004510a0(uVar2,uVar7);
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 0;
}

