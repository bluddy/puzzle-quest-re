
undefined4 Lua_TUTORIAL_OPPTUTE_GEM(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  undefined4 uVar4;
  short *psVar5;
  char *pcVar6;
  short sStack_24;
  short sStack_22;
  short sStack_20;
  short sStack_1e;
  undefined4 uStack_1c;
  void *pvStack_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_00515e58;
  pvStack_c = ExceptionList;
  ExceptionList = &pvStack_c;
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar6 = "TUTORIAL_OPPTUTE_GEM: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_OPPTUTE_GEM: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar6);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uStack_1c = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,2);
  if (iVar1 == 0) {
    pcVar6 = "TUTORIAL_OPPTUTE_GEM: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_OPPTUTE_GEM: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar6);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,2);
  uVar2 = FUN_0050432c();
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  uStack_4 = 0;
  iVar1 = FUN_004f6d00(param_1,3);
  if (iVar1 == 0) {
    pcVar6 = "TUTORIAL_OPPTUTE_GEM: arg 3 is not a string";
  }
  else {
    uVar3 = FUN_004f6e50(param_1,3);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar3);
    iVar1 = FUN_004f6ca0(param_1,4);
    if (iVar1 != 0) {
      FUN_004f6db0(param_1,4);
      uVar3 = FUN_0050432c();
      iVar1 = FUN_004f6ca0(param_1,5);
      if (iVar1 == 0) {
        pcVar6 = "TUTORIAL_OPPTUTE_GEM: arg 5 is not an integer";
        Engine_ACTIVATE_COMPANION_483650("TUTORIAL_OPPTUTE_GEM: arg 5 is not an integer");
        Engine_ACTIVATE_COMPANION_4836e0(pcVar6);
      }
      else {
        FUN_004f6db0(param_1,5);
        uVar4 = FUN_0050432c();
        Engine_ADD_EFFECT_TO_GRID_47b3d0(&sStack_24,uStack_1c,uVar2);
        psVar5 = &sStack_20;
        sStack_20 = -1;
        sStack_1e = -1;
        uVar2 = Engine_ADD_EFFECT_TO_GRID_4b51d0(0xffffffff);
        Engine_ADD_EFFECT_TO_GRID_4b59f0(uVar2,psVar5);
        sStack_22 = sStack_22 + sStack_1e;
        sStack_24 = sStack_24 + sStack_20;
        uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uVar3,uVar4);
        FUN_004a6bb0(0,sStack_24 + -0x24,sStack_22 + -0x49,uVar2);
      }
      uStack_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
      ExceptionList = pvStack_c;
      return 0;
    }
    pcVar6 = "TUTORIAL_OPPTUTE_GEM: arg 4 is not an integer";
  }
  Engine_ACTIVATE_COMPANION_483650(pcVar6);
  Engine_ACTIVATE_COMPANION_4836e0(pcVar6);
  uStack_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = pvStack_c;
  return 0;
}

