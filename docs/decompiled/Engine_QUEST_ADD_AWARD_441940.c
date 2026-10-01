
void Engine_QUEST_ADD_AWARD_441940(undefined4 param_1,undefined4 param_2)

{
  int iVar1;
  undefined4 uVar2;
  
  iVar1 = FUN_004192d0(param_2);
  if (iVar1 != 0) {
    uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(L"OnAddAward");
    FUN_00483b30(uVar2);
    uVar2 = 0;
    Engine_QUEST_ABANDON_44e920(param_1,0);
    Engine_QUEST_ABANDON_44d8e0(param_1,uVar2);
    FUN_0046cb40(param_2);
    FUN_004b1590();
  }
  return;
}

