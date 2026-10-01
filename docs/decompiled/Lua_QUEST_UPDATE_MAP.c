
undefined4 Lua_QUEST_UPDATE_MAP(void)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  
  iVar1 = Engine_QUEST_ENCOUNTER_ADD_4556f0();
  uVar3 = *(undefined4 *)(iVar1 + 0x40);
  uVar2 = 0;
  Engine_QUEST_ABANDON_44e920(uVar3,0);
  Engine_QUEST_ABANDON_44d8e0(uVar3,uVar2);
  Engine_QUEST_COMPLETE_PART_469310();
  uVar3 = 1;
  Engine_QUEST_ENCOUNTER_ADD_4556f0(1);
  Engine_QUEST_COMPLETE_PART_4507a0(uVar3);
  return 0;
}

