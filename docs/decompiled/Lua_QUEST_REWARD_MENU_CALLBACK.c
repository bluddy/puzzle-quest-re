
undefined4 Lua_QUEST_REWARD_MENU_CALLBACK(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  char *pcVar3;
  undefined1 local_24 [12];
  undefined1 local_18 [12];
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515d70;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4 = 0;
  iVar1 = FUN_004f6d00(param_1,1);
  if (iVar1 == 0) {
    pcVar3 = "QUEST_REWARD_MENU_CALLBACK: arg 1 is not a string";
    Engine_ACTIVATE_COMPANION_483650("QUEST_REWARD_MENU_CALLBACK: arg 1 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar3);
  }
  else {
    uVar2 = FUN_004f6e50(param_1,1);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
    Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
    local_4._0_1_ = 1;
    iVar1 = FUN_004f6d00(param_1,2);
    if (iVar1 == 0) {
      pcVar3 = "QUEST_REWARD_MENU_CALLBACK: arg 2 is not a string";
      Engine_ACTIVATE_COMPANION_483650("QUEST_REWARD_MENU_CALLBACK: arg 2 is not a string");
      Engine_ACTIVATE_COMPANION_4836e0(pcVar3);
    }
    else {
      uVar2 = FUN_004f6e50(param_1,2);
      Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
      Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
      local_4._0_1_ = 2;
      iVar1 = FUN_004f6d00(param_1,3);
      if (iVar1 == 0) {
        pcVar3 = "QUEST_REWARD_MENU_CALLBACK: arg 3 is not a string";
        Engine_ACTIVATE_COMPANION_483650("QUEST_REWARD_MENU_CALLBACK: arg 3 is not a string");
        Engine_ACTIVATE_COMPANION_4836e0(pcVar3);
      }
      else {
        uVar2 = FUN_004f6e50(param_1,3);
        Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
        Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
        local_4 = CONCAT31(local_4._1_3_,3);
        iVar1 = FUN_004f6d00(param_1,4);
        if (iVar1 == 0) {
          pcVar3 = "QUEST_REWARD_MENU_CALLBACK: arg 4 is not a string";
          Engine_ACTIVATE_COMPANION_483650("QUEST_REWARD_MENU_CALLBACK: arg 4 is not a string");
          Engine_ACTIVATE_COMPANION_4836e0(pcVar3);
        }
        else {
          uVar2 = FUN_004f6e50(param_1,4);
          Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
          Engine_QUEST_COMPANION_MESSAGE_CALLBACK_4becb0(local_24);
          Engine_QUEST_COMPANION_MESSAGE_CALLBACK_4becb0(local_18);
          uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(&LAB_004942c0);
          uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uVar2);
          Engine_QUEST_REWARD_MENU_42c2d0(uVar2);
        }
        local_4._0_1_ = 2;
        Engine_ACTIVATE_COMPANION_4bdf40();
      }
      local_4._0_1_ = 1;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
    local_4 = (uint)local_4._1_3_ << 8;
    Engine_ACTIVATE_COMPANION_4bdf40();
  }
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 0;
}

