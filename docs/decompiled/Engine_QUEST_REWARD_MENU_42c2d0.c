
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void Engine_QUEST_REWARD_MENU_42c2d0(undefined4 param_1,undefined4 param_2,undefined4 param_3)

{
  int *piVar1;
  
  FUN_00421e30(0x5dc);
  if (DAT_00581e64 == '\0') {
    FUN_004c5e50(L"Assets\\Screens\\QuestRewardMenu.xml");
  }
  piVar1 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_title");
  if (piVar1 != (int *)0x0) {
    (**(code **)(*piVar1 + 0x10))(param_1);
  }
  piVar1 = (int *)Engine_SET_GAMEPAD_OBJECT_4c2a10(L"str_message");
  if (piVar1 != (int *)0x0) {
    (**(code **)(*piVar1 + 0x10))(param_2);
  }
  _DAT_00581eb4 = param_3;
  FUN_004c27d0(0xffffffff,0xffffffff);
  return;
}

