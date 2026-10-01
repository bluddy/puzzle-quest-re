
undefined4 Lua_TUTORIAL_GLOW_WIDGET(undefined4 param_1)

{
  short sVar1;
  short sVar2;
  int iVar3;
  undefined4 uVar4;
  int iVar5;
  int iVar6;
  int iVar7;
  int iVar8;
  char *pcVar9;
  void *local_c;
  undefined1 *puStack_8;
  uint local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515d40;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4 = 0;
  iVar3 = FUN_004f6d00(param_1,1);
  if (iVar3 == 0) {
    pcVar9 = "TUTORIAL_GLOW_WIDGET: arg 1 is not a string";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GLOW_WIDGET: arg 1 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar9);
  }
  else {
    uVar4 = FUN_004f6e50(param_1,1);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar4);
    Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
    local_4 = CONCAT31(local_4._1_3_,1);
    iVar3 = FUN_004f6d00(param_1,2);
    if (iVar3 == 0) {
      pcVar9 = "TUTORIAL_GLOW_WIDGET: arg 2 is not a string";
      Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GLOW_WIDGET: arg 2 is not a string");
      Engine_ACTIVATE_COMPANION_4836e0(pcVar9);
    }
    else {
      uVar4 = FUN_004f6e50(param_1,2);
      Engine_ACTIVATE_COMPANION_4bf1a0(uVar4);
      iVar3 = FUN_004f6ca0(param_1,3);
      if (iVar3 == 0) {
        pcVar9 = "TUTORIAL_GLOW_WIDGET: arg 3 is not an integer";
        Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GLOW_WIDGET: arg 3 is not an integer");
        Engine_ACTIVATE_COMPANION_4836e0(pcVar9);
      }
      else {
        FUN_004f6db0(param_1,3);
        iVar3 = FUN_0050432c();
        iVar5 = FUN_004f6ca0(param_1,4);
        if (iVar5 == 0) {
          pcVar9 = "TUTORIAL_GLOW_WIDGET: arg 4 is not an integer";
          Engine_ACTIVATE_COMPANION_483650("TUTORIAL_GLOW_WIDGET: arg 4 is not an integer");
          Engine_ACTIVATE_COMPANION_4836e0(pcVar9);
        }
        else {
          FUN_004f6db0(param_1,4);
          iVar5 = FUN_0050432c();
          uVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
          iVar6 = Engine_SET_GAMEPAD_OBJECT_4c1dc0(uVar4);
          if (iVar6 != 0) {
            uVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
            iVar6 = Engine_SET_GAMEPAD_OBJECT_4c2a10(uVar4);
            if (iVar6 != 0) {
              iVar7 = (int)DAT_0059a4c8;
              iVar8 = (int)DAT_0059a4ca;
              sVar1 = Engine_ADD_TEXT_MESSAGE_4bc4c0();
              sVar2 = Engine_ADD_TEXT_MESSAGE_4bc490();
              Engine_TUTORIAL_GLOW_RECT_483a90
                        (((int)sVar1 - (iVar7 + -0x400) / 2) - iVar3,
                         ((int)sVar2 - (iVar8 + -0x300) / 2) - iVar5,
                         (int)*(short *)(iVar6 + 0x10) + iVar3 * 2,
                         (int)*(short *)(iVar6 + 0x12) + iVar5 * 2);
            }
          }
        }
      }
    }
    local_4 = local_4 & 0xffffff00;
    Engine_ACTIVATE_COMPANION_4bdf40();
  }
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 0;
}

