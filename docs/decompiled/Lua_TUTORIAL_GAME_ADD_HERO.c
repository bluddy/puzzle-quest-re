
undefined4 Lua_TUTORIAL_GAME_ADD_HERO(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  undefined4 uVar4;
  undefined4 uVar5;
  undefined4 uVar6;
  undefined4 uVar7;
  undefined4 uVar8;
  undefined4 uVar9;
  undefined4 uVar10;
  undefined4 uVar11;
  undefined4 uVar12;
  undefined4 uVar13;
  undefined4 uVar14;
  undefined4 uVar15;
  undefined4 uVar16;
  char *pcVar17;
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515bf8;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4 = 0;
  iVar1 = FUN_004f6d00(param_1,1);
  if (iVar1 == 0) {
    pcVar17 = "TUTORIAL_GAME_ADD_HERO: arg 1 is not a string";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_ADD_HERO: arg 1 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
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
    pcVar17 = "TUTORIAL_GAME_ADD_HERO: arg 2 is not a string";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_ADD_HERO: arg 2 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
    local_4 = (uint)local_4._1_3_ << 8;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  uVar2 = FUN_004f6e50(param_1,2);
  Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
  iVar1 = FUN_004f6ca0(param_1,3);
  if (iVar1 == 0) {
    pcVar17 = "TUTORIAL_GAME_ADD_HERO: arg 3 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_ADD_HERO: arg 3 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
    local_4 = (uint)local_4._1_3_ << 8;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  FUN_004f6db0(param_1,3);
  uVar2 = FUN_0050432c();
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4._0_1_ = 2;
  iVar1 = FUN_004f6d00(param_1,4);
  if (iVar1 == 0) {
    pcVar17 = "TUTORIAL_GAME_ADD_HERO: arg 4 is not a string";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_ADD_HERO: arg 4 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
    local_4._0_1_ = 1;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = (uint)local_4._1_3_ << 8;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  uVar3 = FUN_004f6e50(param_1,4);
  Engine_ACTIVATE_COMPANION_4bf1a0(uVar3);
  iVar1 = FUN_004f6ca0(param_1,5);
  if (iVar1 == 0) {
    pcVar17 = "TUTORIAL_GAME_ADD_HERO: arg 5 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_ADD_HERO: arg 5 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
    local_4._0_1_ = 1;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = (uint)local_4._1_3_ << 8;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  FUN_004f6db0(param_1,5);
  uVar3 = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,6);
  if (iVar1 == 0) {
    pcVar17 = "TUTORIAL_GAME_ADD_HERO: arg 6 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_ADD_HERO: arg 6 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
    local_4._0_1_ = 1;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = (uint)local_4._1_3_ << 8;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  FUN_004f6db0(param_1,6);
  uVar4 = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,7);
  if (iVar1 == 0) {
    pcVar17 = "TUTORIAL_GAME_ADD_HERO: arg 7 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_ADD_HERO: arg 7 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
    local_4._0_1_ = 1;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = (uint)local_4._1_3_ << 8;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  FUN_004f6db0(param_1,7);
  uVar5 = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,8);
  if (iVar1 == 0) {
    pcVar17 = "TUTORIAL_GAME_ADD_HERO: arg 8 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_ADD_HERO: arg 8 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
    local_4._0_1_ = 1;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = (uint)local_4._1_3_ << 8;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  FUN_004f6db0(param_1,8);
  uVar6 = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,9);
  if (iVar1 == 0) {
    pcVar17 = "TUTORIAL_GAME_ADD_HERO: arg 9 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_ADD_HERO: arg 9 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
    local_4._0_1_ = 1;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = (uint)local_4._1_3_ << 8;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  FUN_004f6db0(param_1,9);
  uVar7 = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,10);
  if (iVar1 == 0) {
    pcVar17 = "TUTORIAL_GAME_ADD_HERO: arg 10 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_ADD_HERO: arg 10 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
    local_4._0_1_ = 1;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = (uint)local_4._1_3_ << 8;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  FUN_004f6db0(param_1,10);
  uVar8 = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,0xb);
  if (iVar1 == 0) {
    pcVar17 = "TUTORIAL_GAME_ADD_HERO: arg 11 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_ADD_HERO: arg 11 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
    local_4._0_1_ = 1;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = (uint)local_4._1_3_ << 8;
    Engine_ACTIVATE_COMPANION_4bdf40();
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
    ExceptionList = local_c;
    return 0;
  }
  FUN_004f6db0(param_1,0xb);
  uVar9 = FUN_0050432c();
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4._0_1_ = 3;
  iVar1 = FUN_004f6d00(param_1,0xc);
  if (iVar1 == 0) {
    pcVar17 = "TUTORIAL_GAME_ADD_HERO: arg 12 is not a string";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_ADD_HERO: arg 12 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
  }
  else {
    uVar10 = FUN_004f6e50(param_1,0xc);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar10);
    Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
    local_4._0_1_ = 4;
    iVar1 = FUN_004f6d00(param_1,0xd);
    if (iVar1 == 0) {
      pcVar17 = "TUTORIAL_GAME_ADD_HERO: arg 13 is not a string";
      Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_ADD_HERO: arg 13 is not a string");
      Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
    }
    else {
      uVar10 = FUN_004f6e50(param_1,0xd);
      Engine_ACTIVATE_COMPANION_4bf1a0(uVar10);
      Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
      local_4._0_1_ = 5;
      iVar1 = FUN_004f6d00(param_1,0xe);
      if (iVar1 == 0) {
        pcVar17 = "TUTORIAL_GAME_ADD_HERO: arg 14 is not a string";
        Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_ADD_HERO: arg 14 is not a string");
        Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
      }
      else {
        uVar10 = FUN_004f6e50(param_1,0xe);
        Engine_ACTIVATE_COMPANION_4bf1a0(uVar10);
        Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
        local_4 = CONCAT31(local_4._1_3_,6);
        iVar1 = FUN_004f6d00(param_1,0xf);
        if (iVar1 == 0) {
          pcVar17 = "TUTORIAL_GAME_ADD_HERO: arg 15 is not a string";
          Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GAME_ADD_HERO: arg 15 is not a string");
          Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
        }
        else {
          uVar10 = FUN_004f6e50(param_1,0xf);
          Engine_ACTIVATE_COMPANION_4bf1a0(uVar10);
          uVar10 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
          uVar11 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uVar10);
          uVar12 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uVar11);
          uVar13 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uVar12);
          uVar14 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0
                             (uVar3,uVar4,uVar5,uVar6,uVar7,uVar8,uVar9,uVar13);
          uVar15 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uVar2,uVar14);
          uVar16 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uVar15);
          Engine_GET_GAME_ID_4481d0(uVar16);
          FUN_004487e0(uVar16,uVar15,uVar2,uVar14,uVar3,uVar4,uVar5,uVar6,uVar7,uVar8,uVar9,uVar13,
                       uVar12,uVar11,uVar10);
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

