
void Engine_QUEST_REWARD_XP_42d170(undefined4 param_1)

{
  char cVar1;
  int iVar2;
  undefined4 uVar3;
  undefined4 uVar4;
  undefined4 local_58;
  undefined4 local_54;
  undefined4 local_50;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00511118;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  FUN_004bdb30();
  local_4 = 0;
  local_58 = 1;
  local_50 = param_1;
  local_54 = 0;
  FUN_0042cf30(&local_58);
  FUN_0042c5e0();
  iVar2 = Engine_QUEST_ENCOUNTER_ADD_4556f0();
  uVar3 = *(undefined4 *)(iVar2 + 0x40);
  uVar4 = 0;
  Engine_QUEST_ABANDON_44e920(uVar3,0);
  Engine_QUEST_ABANDON_44d8e0(uVar3,uVar4);
  Engine_ADD_XP_42c030(param_1);
  cVar1 = FUN_0046ecd0();
  if (cVar1 != '\0') {
    FUN_00422d60();
  }
  Engine_QUEST_ADD_ITEM_4b1590();
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return;
}

