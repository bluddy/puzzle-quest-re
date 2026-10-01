
undefined4 Lua_QUEST_SPEND_GOLD(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  char *pcVar4;
  undefined4 uVar5;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar4 = "QUEST_SPEND_GOLD: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("QUEST_SPEND_GOLD: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  iVar1 = Engine_QUEST_ENCOUNTER_ADD_4556f0();
  uVar3 = *(undefined4 *)(iVar1 + 0x40);
  uVar5 = 0;
  Engine_QUEST_ABANDON_44e920(uVar3,0);
  Engine_QUEST_ABANDON_44d8e0(uVar3,uVar5);
  Engine_SUBTRACT_GOLD_401110(uVar2);
  return 0;
}

