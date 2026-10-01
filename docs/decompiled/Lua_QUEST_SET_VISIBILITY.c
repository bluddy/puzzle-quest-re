
undefined4 Lua_QUEST_SET_VISIBILITY(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  ushort *puVar3;
  ushort *puVar4;
  ushort *puVar5;
  ushort *puVar6;
  uint uVar7;
  char *pcVar8;
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
    pcVar8 = "QUEST_SET_VISIBILITY: arg 1 is not a string";
  }
  else {
    uVar2 = FUN_004f6e50(param_1,1);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
    iVar1 = FUN_004f6ca0(param_1,2);
    if (iVar1 != 0) {
      FUN_004f6db0(param_1,2);
      uVar2 = FUN_0050432c();
      puVar3 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(3);
      puVar4 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(2);
      puVar5 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(1);
      puVar6 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(0);
      uVar7 = (((uint)*puVar3 << 8 | (uint)*puVar4) << 8 | (uint)*puVar5) << 8 | (uint)*puVar6;
      Engine_QUEST_ENCOUNTER_ADD_4556f0(uVar7,uVar2);
      FUN_00450e40(uVar7,uVar2);
      local_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
      ExceptionList = local_c;
      return 0;
    }
    pcVar8 = "QUEST_SET_VISIBILITY: arg 2 is not an integer";
  }
  Engine_ACTIVATE_COMPANION_483650(pcVar8);
  Engine_ACTIVATE_COMPANION_4836e0(pcVar8);
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 0;
}

