
undefined4 Lua_QUEST_HERO_HAS_COMPANION(undefined4 param_1)

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
  undefined4 uVar11;
  uint uStack_1c;
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
    Engine_ACTIVATE_COMPANION_483650();
    Engine_ACTIVATE_COMPANION_4836e0();
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  uVar6 = FUN_004f6e50(param_1,1);
  Engine_ACTIVATE_COMPANION_4bf1a0(uVar6);
  puVar7 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(3);
  puVar8 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(2);
  puVar9 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(1);
  puVar10 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(0);
  uVar1 = *puVar7;
  uVar2 = *puVar8;
  uVar3 = *puVar9;
  uVar4 = *puVar10;
  iVar5 = Engine_QUEST_ENCOUNTER_ADD_4556f0();
  uVar6 = *(undefined4 *)(iVar5 + 0x40);
  uVar11 = 0;
  Engine_QUEST_ABANDON_44e920(uVar6,0);
  Engine_QUEST_ABANDON_44d8e0(uVar6,uVar11);
  iVar5 = Engine_QUEST_COMPANION_MESSAGE_408b90
                    ((((uint)uVar1 << 8 | (uint)uVar2) << 8 | (uint)uVar3) << 8 | (uint)uVar4);
  uStack_1c = (uint)(iVar5 != 0);
  FUN_004f7020(param_1,(double)uStack_1c);
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 1;
}

