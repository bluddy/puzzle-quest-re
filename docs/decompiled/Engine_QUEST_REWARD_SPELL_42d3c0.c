
void Engine_QUEST_REWARD_SPELL_42d3c0(undefined4 param_1)

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
  iVar2 = Engine_QUEST_ENCOUNTER_ADD_4556f0();
  uVar3 = *(undefined4 *)(iVar2 + 0x40);
  uVar4 = 0;
  Engine_QUEST_ABANDON_44e920(uVar3,0);
  Engine_QUEST_ABANDON_44d8e0(uVar3,uVar4);
  cVar1 = FUN_00468620(param_1);
  if (cVar1 == '\0') {
    iVar2 = FUN_004685c0();
    uVar3 = param_1;
    Engine_HANDLE_SPELL_COST_4622c0(param_1);
    uVar3 = FUN_00461d30(uVar3);
    FUN_0046c260(uVar3,iVar2 < 6,3);
    Engine_QUEST_ADD_ITEM_4b1590();
    FUN_004bdb30();
    local_4 = 0;
    local_58 = 2;
    local_50 = 1;
    local_54 = param_1;
    FUN_0042cf30(&local_58);
    FUN_0042c5e0();
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
  }
  ExceptionList = local_c;
  return;
}

