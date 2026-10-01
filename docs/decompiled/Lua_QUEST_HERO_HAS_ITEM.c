
undefined4 Lua_QUEST_HERO_HAS_ITEM(undefined4 param_1)

{
  ushort uVar1;
  ushort uVar2;
  ushort uVar3;
  ushort uVar4;
  char cVar5;
  int iVar6;
  undefined4 uVar7;
  ushort *puVar8;
  ushort *puVar9;
  ushort *puVar10;
  ushort *puVar11;
  undefined4 uVar12;
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
  iVar6 = FUN_004f6d00(param_1,1);
  if (iVar6 == 0) {
    Engine_ACTIVATE_COMPANION_483650();
    Engine_ACTIVATE_COMPANION_4836e0();
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  uVar7 = FUN_004f6e50(param_1,1);
  Engine_ACTIVATE_COMPANION_4bf1a0(uVar7);
  puVar8 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(3);
  puVar9 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(2);
  puVar10 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(1);
  puVar11 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(0);
  uVar1 = *puVar8;
  uVar2 = *puVar9;
  uVar3 = *puVar10;
  uVar4 = *puVar11;
  iVar6 = Engine_QUEST_ENCOUNTER_ADD_4556f0();
  uVar7 = *(undefined4 *)(iVar6 + 0x40);
  uVar12 = 0;
  Engine_QUEST_ABANDON_44e920(uVar7,0);
  Engine_QUEST_ABANDON_44d8e0(uVar7,uVar12);
  cVar5 = Engine_QUEST_ADD_ITEM_4686f0
                    ((((uint)uVar1 << 8 | (uint)uVar2) << 8 | (uint)uVar3) << 8 | (uint)uVar4);
  uStack_1c = (uint)(cVar5 != '\0');
  FUN_004f7020(param_1,(double)uStack_1c);
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 1;
}

