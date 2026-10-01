
undefined4 Lua_QUEST_BATTLE(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
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
  iVar1 = FUN_004f6d00(param_1,1);
  if (iVar1 == 0) {
    pcVar10 = "QUEST_BATTLE: arg 1 is not a string";
  }
  else {
    uVar2 = FUN_004f6e50(param_1,1);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
    iVar1 = FUN_004f6ca0(param_1,2);
    if (iVar1 == 0) {
      pcVar10 = "QUEST_BATTLE: arg 2 is not an integer";
    }
    else {
      FUN_004f6db0(param_1,2);
      uVar2 = FUN_0050432c();
      iVar1 = FUN_004f6ca0(param_1,3);
      if (iVar1 != 0) {
        FUN_004f6db0(param_1,3);
        uVar3 = FUN_0050432c();
        puVar4 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(3);
        puVar5 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(2);
        puVar6 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(1);
        puVar7 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(0);
        uVar9 = 1;
        uVar8 = (((uint)*puVar4 << 8 | (uint)*puVar5) << 8 | (uint)*puVar6) << 8 | (uint)*puVar7;
        Engine_QUEST_ENCOUNTER_ADD_4556f0(uVar8,uVar2,uVar3,1);
        FUN_0044ff50(uVar8,uVar2,uVar3,uVar9);
        local_4 = 0xffffffff;
        Engine_ACTIVATE_COMPANION_4bdf40();
        ExceptionList = local_c;
        return 0;
      }
      pcVar10 = "QUEST_BATTLE: arg 3 is not an integer";
    }
  }
  Engine_ACTIVATE_COMPANION_483650(pcVar10);
  Engine_ACTIVATE_COMPANION_4836e0(pcVar10);
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 0;
}

