
undefined4 Lua_QUEST_ADD_SKILL(undefined4 param_1)

{
  int iVar1;
  int iVar2;
  int iVar3;
  int iVar4;
  undefined4 uVar5;
  undefined4 uVar6;
  int iVar7;
  char *pcVar8;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar8 = "QUEST_ADD_SKILL: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("QUEST_ADD_SKILL: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar8);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  iVar1 = FUN_0050432c();
  iVar2 = FUN_004f6ca0(param_1,2);
  if (iVar2 == 0) {
    pcVar8 = "QUEST_ADD_SKILL: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("QUEST_ADD_SKILL: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar8);
    return 0;
  }
  FUN_004f6db0(param_1,2);
  iVar3 = FUN_0050432c();
  iVar2 = Engine_QUEST_ENCOUNTER_ADD_4556f0();
  uVar5 = *(undefined4 *)(iVar2 + 0x40);
  uVar6 = 0;
  Engine_QUEST_ABANDON_44e920(uVar5,0);
  iVar4 = Engine_QUEST_ABANDON_44d8e0(uVar5,uVar6);
  iVar2 = iVar4 + 0x48;
  iVar7 = iVar2;
  Engine_ADD_MAX_LIFE_445030(iVar2);
  Engine_ADD_MAX_LIFE_444d40(iVar7);
  *(int *)(iVar4 + 0x48 + iVar1 * 4) = *(int *)(iVar4 + 0x48 + iVar1 * 4) + iVar3;
  Engine_ADD_MAX_LIFE_445030(iVar2);
  Engine_ADD_MAX_LIFE_444d80(iVar2);
  Engine_QUEST_ADD_ITEM_4b1590();
  return 0;
}

