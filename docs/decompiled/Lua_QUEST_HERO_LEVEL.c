
undefined4 Lua_QUEST_HERO_LEVEL(undefined4 param_1)

{
  int iVar1;
  ulonglong uVar2;
  
  iVar1 = Engine_QUEST_ENCOUNTER_ADD_4556f0();
  uVar2 = (ulonglong)*(uint *)(iVar1 + 0x40);
  Engine_QUEST_ABANDON_44e920(*(uint *)(iVar1 + 0x40),0);
  iVar1 = Engine_QUEST_ABANDON_44d8e0(uVar2);
  FUN_004f7020(param_1,(double)*(int *)(iVar1 + 0x68));
  return 1;
}

