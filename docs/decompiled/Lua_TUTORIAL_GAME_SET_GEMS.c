
undefined4 Lua_TUTORIAL_GAME_SET_GEMS(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  char *pcVar4;
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515bb0;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4 = 0;
  iVar1 = FUN_004f6d00(param_1,1);
  if (iVar1 == 0) {
    pcVar4 = "TUTORIAL_GAME_SET_GEMS: arg 1 is not a string";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_SET_GEMS: arg 1 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  uVar2 = FUN_004f6e50(param_1,1);
  Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4._0_1_ = 1;
  iVar1 = FUN_004f6d00(param_1,2);
  if (iVar1 == 0) {
    pcVar4 = "TUTORIAL_GAME_SET_GEMS: arg 2 is not a string";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_SET_GEMS: arg 2 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    local_4 = (uint)local_4._1_3_ << 8;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  uVar2 = FUN_004f6e50(param_1,2);
  Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4._0_1_ = 2;
  iVar1 = FUN_004f6d00(param_1,3);
  if (iVar1 == 0) {
    pcVar4 = "TUTORIAL_GAME_SET_GEMS: arg 3 is not a string";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_SET_GEMS: arg 3 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    local_4._0_1_ = 1;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = (uint)local_4._1_3_ << 8;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  uVar2 = FUN_004f6e50(param_1,3);
  Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4._0_1_ = 3;
  iVar1 = FUN_004f6d00(param_1,4);
  if (iVar1 == 0) {
    pcVar4 = "TUTORIAL_GAME_SET_GEMS: arg 4 is not a string";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_SET_GEMS: arg 4 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
  }
  else {
    uVar2 = FUN_004f6e50(param_1,4);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
    Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
    local_4._0_1_ = 4;
    iVar1 = FUN_004f6d00(param_1,5);
    if (iVar1 == 0) {
      pcVar4 = "TUTORIAL_GAME_SET_GEMS: arg 5 is not a string";
      Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_SET_GEMS: arg 5 is not a string");
      Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    }
    else {
      uVar2 = FUN_004f6e50(param_1,5);
      Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
      Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
      local_4._0_1_ = 5;
      iVar1 = FUN_004f6d00(param_1,6);
      if (iVar1 == 0) {
        pcVar4 = "TUTORIAL_GAME_SET_GEMS: arg 6 is not a string";
        Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_SET_GEMS: arg 6 is not a string");
        Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
      }
      else {
        uVar2 = FUN_004f6e50(param_1,6);
        Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
        Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
        local_4._0_1_ = 6;
        iVar1 = FUN_004f6d00(param_1,7);
        if (iVar1 == 0) {
          pcVar4 = "TUTORIAL_GAME_SET_GEMS: arg 7 is not a string";
          Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_SET_GEMS: arg 7 is not a string");
          Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
        }
        else {
          uVar2 = FUN_004f6e50(param_1,7);
          Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
          Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
          local_4 = CONCAT31(local_4._1_3_,7);
          iVar1 = FUN_004f6d00(param_1,8);
          if (iVar1 == 0) {
            pcVar4 = "TUTORIAL_GAME_SET_GEMS: arg 8 is not a string";
            Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_SET_GEMS: arg 8 is not a string");
            Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
          }
          else {
            uVar2 = FUN_004f6e50(param_1,8);
            Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
            uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
            uVar3 = 7;
            Engine_ADD_ANIMEFFECT_TO_GRID_47a820(7,uVar2);
            FUN_0047aab0(uVar3,uVar2);
            uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
            uVar3 = 6;
            Engine_ADD_ANIMEFFECT_TO_GRID_47a820(6,uVar2);
            FUN_0047aab0(uVar3,uVar2);
            uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
            uVar3 = 5;
            Engine_ADD_ANIMEFFECT_TO_GRID_47a820(5,uVar2);
            FUN_0047aab0(uVar3,uVar2);
            uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
            uVar3 = 4;
            Engine_ADD_ANIMEFFECT_TO_GRID_47a820(4,uVar2);
            FUN_0047aab0(uVar3,uVar2);
            uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
            uVar3 = 3;
            Engine_ADD_ANIMEFFECT_TO_GRID_47a820(3,uVar2);
            FUN_0047aab0(uVar3,uVar2);
            uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
            uVar3 = 2;
            Engine_ADD_ANIMEFFECT_TO_GRID_47a820(2,uVar2);
            FUN_0047aab0(uVar3,uVar2);
            uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
            uVar3 = 1;
            Engine_ADD_ANIMEFFECT_TO_GRID_47a820(1,uVar2);
            FUN_0047aab0(uVar3,uVar2);
            uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
            uVar3 = 0;
            Engine_ADD_ANIMEFFECT_TO_GRID_47a820(0,uVar2);
            FUN_0047aab0(uVar3,uVar2);
          }
          local_4._0_1_ = 6;
          Engine_ACTIVATE_COMPANION_4bdf40();
        }
        local_4._0_1_ = 5;
        Engine_ACTIVATE_COMPANION_4bdf40();
      }
      local_4._0_1_ = 4;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
    local_4._0_1_ = 3;
    Engine_ACTIVATE_COMPANION_4bdf40();
  }
  local_4._0_1_ = 2;
  Engine_ACTIVATE_COMPANION_4bdf40();
  local_4._0_1_ = 1;
  Engine_ACTIVATE_COMPANION_4bdf40();
  local_4 = (uint)local_4._1_3_ << 8;
  Engine_ACTIVATE_COMPANION_4bdf40();
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 0;
}

