
void Engine_QUEST_REWARD_GOLD_42d0c0(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
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
  local_58 = 0;
  local_50 = param_1;
  local_54 = 0;
  FUN_0042cf30(&local_58);
  FUN_0042c5e0();
  iVar1 = Engine_QUEST_ENCOUNTER_ADD_4556f0();
  uVar2 = *(undefined4 *)(iVar1 + 0x40);
  uVar3 = 0;
  Engine_QUEST_ABANDON_44e920(uVar2,0);
  Engine_QUEST_ABANDON_44d8e0(uVar2,uVar3);
  Engine_ADD_GOLD_42bfc0(param_1);
  Engine_QUEST_ADD_ITEM_4b1590();
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return;
}

