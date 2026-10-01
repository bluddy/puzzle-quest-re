
undefined4 Lua_QUEST_BATTLE_CUSTOM(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  undefined4 uVar4;
  ushort *puVar5;
  ushort *puVar6;
  ushort *puVar7;
  ushort *puVar8;
  undefined4 uVar9;
  undefined4 uVar10;
  undefined4 uVar11;
  undefined4 uVar12;
  undefined4 uVar13;
  undefined4 uVar14;
  undefined4 uVar15;
  uint uVar16;
  char *pcVar17;
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515c88;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4 = 0;
  iVar1 = FUN_004f6d00(param_1,1);
  if (iVar1 == 0) {
    pcVar17 = "QUEST_BATTLE_CUSTOM: arg 1 is not a string";
    Engine_ACTIVATE_COMPANION_483650("QUEST_BATTLE_CUSTOM: arg 1 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
  }
  else {
    uVar2 = FUN_004f6e50(param_1,1);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
    iVar1 = FUN_004f6ca0(param_1,2);
    if (iVar1 == 0) {
      pcVar17 = "QUEST_BATTLE_CUSTOM: arg 2 is not an integer";
      Engine_ACTIVATE_COMPANION_483650("QUEST_BATTLE_CUSTOM: arg 2 is not an integer");
      Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
      local_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
    else {
      FUN_004f6db0(param_1,2);
      uVar2 = FUN_0050432c();
      iVar1 = FUN_004f6ca0(param_1,3);
      if (iVar1 == 0) {
        pcVar17 = "QUEST_BATTLE_CUSTOM: arg 3 is not an integer";
        Engine_ACTIVATE_COMPANION_483650("QUEST_BATTLE_CUSTOM: arg 3 is not an integer");
        Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
        local_4 = 0xffffffff;
        Engine_ACTIVATE_COMPANION_4bdf40();
      }
      else {
        FUN_004f6db0(param_1,3);
        uVar3 = FUN_0050432c();
        Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
        local_4._0_1_ = 1;
        iVar1 = FUN_004f6d00(param_1,4);
        if (iVar1 == 0) {
          pcVar17 = "QUEST_BATTLE_CUSTOM: arg 4 is not a string";
          Engine_ACTIVATE_COMPANION_483650("QUEST_BATTLE_CUSTOM: arg 4 is not a string");
          Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
        }
        else {
          uVar4 = FUN_004f6e50(param_1,4);
          Engine_ACTIVATE_COMPANION_4bf1a0(uVar4);
          Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
          local_4._0_1_ = 2;
          iVar1 = FUN_004f6d00(param_1,5);
          if (iVar1 == 0) {
            pcVar17 = "QUEST_BATTLE_CUSTOM: arg 5 is not a string";
            Engine_ACTIVATE_COMPANION_483650("QUEST_BATTLE_CUSTOM: arg 5 is not a string");
            Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
          }
          else {
            uVar4 = FUN_004f6e50(param_1,5);
            Engine_ACTIVATE_COMPANION_4bf1a0(uVar4);
            Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
            local_4._0_1_ = 3;
            iVar1 = FUN_004f6d00(param_1,6);
            if (iVar1 == 0) {
              pcVar17 = "QUEST_BATTLE_CUSTOM: arg 6 is not a string";
              Engine_ACTIVATE_COMPANION_483650("QUEST_BATTLE_CUSTOM: arg 6 is not a string");
              Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
            }
            else {
              uVar4 = FUN_004f6e50(param_1,6);
              Engine_ACTIVATE_COMPANION_4bf1a0(uVar4);
              Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
              local_4._0_1_ = 4;
              iVar1 = FUN_004f6d00(param_1,7);
              if (iVar1 == 0) {
                pcVar17 = "QUEST_BATTLE_CUSTOM: arg 7 is not a string";
                Engine_ACTIVATE_COMPANION_483650("QUEST_BATTLE_CUSTOM: arg 7 is not a string");
                Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
              }
              else {
                uVar4 = FUN_004f6e50(param_1,7);
                Engine_ACTIVATE_COMPANION_4bf1a0(uVar4);
                Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
                local_4._0_1_ = 5;
                iVar1 = FUN_004f6d00(param_1,8);
                if (iVar1 == 0) {
                  pcVar17 = "QUEST_BATTLE_CUSTOM: arg 8 is not a string";
                  Engine_ACTIVATE_COMPANION_483650("QUEST_BATTLE_CUSTOM: arg 8 is not a string");
                  Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
                }
                else {
                  uVar4 = FUN_004f6e50(param_1,8);
                  Engine_ACTIVATE_COMPANION_4bf1a0(uVar4);
                  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
                  local_4._0_1_ = 6;
                  iVar1 = FUN_004f6d00(param_1,9);
                  if (iVar1 == 0) {
                    pcVar17 = "QUEST_BATTLE_CUSTOM: arg 9 is not a string";
                    Engine_ACTIVATE_COMPANION_483650("QUEST_BATTLE_CUSTOM: arg 9 is not a string");
                    Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
                  }
                  else {
                    uVar4 = FUN_004f6e50(param_1,9);
                    Engine_ACTIVATE_COMPANION_4bf1a0(uVar4);
                    Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
                    local_4._0_1_ = 7;
                    iVar1 = FUN_004f6d00(param_1,10);
                    if (iVar1 == 0) {
                      pcVar17 = "QUEST_BATTLE_CUSTOM: arg 10 is not a string";
                      Engine_ACTIVATE_COMPANION_483650
                                ("QUEST_BATTLE_CUSTOM: arg 10 is not a string");
                      Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
                    }
                    else {
                      uVar4 = FUN_004f6e50(param_1,10);
                      Engine_ACTIVATE_COMPANION_4bf1a0(uVar4);
                      Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
                      local_4._0_1_ = 8;
                      iVar1 = FUN_004f6d00(param_1,0xb);
                      if (iVar1 != 0) {
                        uVar4 = FUN_004f6e50(param_1,0xb);
                        Engine_ACTIVATE_COMPANION_4bf1a0(uVar4);
                        puVar5 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(3);
                        puVar6 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(2);
                        puVar7 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(1);
                        puVar8 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(0);
                        uVar16 = (((uint)*puVar5 << 8 | (uint)*puVar6) << 8 | (uint)*puVar7) << 8 |
                                 (uint)*puVar8;
                        Engine_ACTIVATE_COMPANION_4be7e0(3);
                        Engine_ACTIVATE_COMPANION_4be7e0(2);
                        Engine_ACTIVATE_COMPANION_4be7e0(1);
                        Engine_ACTIVATE_COMPANION_4be7e0(0);
                        uVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
                        uVar9 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uVar4);
                        uVar10 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uVar9);
                        uVar11 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uVar10);
                        uVar12 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uVar11);
                        uVar13 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uVar12);
                        uVar14 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uVar13);
                        uVar15 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uVar14);
                        Engine_QUEST_ENCOUNTER_ADD_4556f0(uVar16,uVar2,uVar3,uVar15);
                        FUN_0044ffd0(uVar16,uVar2,uVar3,uVar15,uVar14,uVar13,uVar12,uVar11,uVar10,
                                     uVar9,uVar4);
                        local_4._0_1_ = 7;
                        Engine_ACTIVATE_COMPANION_4bdf40();
                        local_4._0_1_ = 6;
                        Engine_ACTIVATE_COMPANION_4bdf40();
                        local_4._0_1_ = 5;
                        Engine_ACTIVATE_COMPANION_4bdf40();
                        local_4._0_1_ = 4;
                        Engine_ACTIVATE_COMPANION_4bdf40();
                        local_4._0_1_ = 3;
                        Engine_ACTIVATE_COMPANION_4bdf40();
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
                      pcVar17 = "QUEST_BATTLE_CUSTOM: arg 11 is not a string";
                      Engine_ACTIVATE_COMPANION_483650
                                ("QUEST_BATTLE_CUSTOM: arg 11 is not a string");
                      Engine_ACTIVATE_COMPANION_4836e0(pcVar17);
                      local_4._0_1_ = 7;
                      Engine_ACTIVATE_COMPANION_4bdf40();
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
          }
          local_4._0_1_ = 1;
          Engine_ACTIVATE_COMPANION_4bdf40();
        }
        local_4 = (uint)local_4._1_3_ << 8;
        Engine_ACTIVATE_COMPANION_4bdf40();
        local_4 = 0xffffffff;
        Engine_ACTIVATE_COMPANION_4bdf40();
      }
    }
  }
  ExceptionList = local_c;
  return 0;
}

