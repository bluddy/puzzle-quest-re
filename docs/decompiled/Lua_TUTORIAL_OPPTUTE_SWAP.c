
undefined4 Lua_TUTORIAL_OPPTUTE_SWAP(undefined4 param_1)

{
  int iVar1;
  int iVar2;
  int iVar3;
  int iVar4;
  undefined4 uVar5;
  undefined4 uVar6;
  short *psVar7;
  char *pcVar8;
  short sStack_2c;
  short sStack_2a;
  short sStack_28;
  short sStack_26;
  undefined4 uStack_24;
  undefined4 uStack_20;
  int iStack_1c;
  void *pvStack_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_00515e58;
  pvStack_c = ExceptionList;
  ExceptionList = &pvStack_c;
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar8 = "TUTORIAL_OPPTUTE_SWAP: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_OPPTUTE_SWAP: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar8);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,1);
  iStack_1c = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,2);
  if (iVar1 == 0) {
    pcVar8 = "TUTORIAL_OPPTUTE_SWAP: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_OPPTUTE_SWAP: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar8);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,2);
  iVar1 = FUN_0050432c();
  iVar2 = FUN_004f6ca0(param_1,3);
  if (iVar2 == 0) {
    pcVar8 = "TUTORIAL_OPPTUTE_SWAP: arg 3 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_OPPTUTE_SWAP: arg 3 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar8);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,3);
  iVar2 = FUN_0050432c();
  iVar3 = FUN_004f6ca0(param_1,4);
  if (iVar3 == 0) {
    pcVar8 = "TUTORIAL_OPPTUTE_SWAP: arg 4 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_OPPTUTE_SWAP: arg 4 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar8);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,4);
  iVar3 = FUN_0050432c();
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  uStack_4 = 0;
  iVar4 = FUN_004f6d00(param_1,5);
  if (iVar4 == 0) {
    pcVar8 = "TUTORIAL_OPPTUTE_SWAP: arg 5 is not a string";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_OPPTUTE_SWAP: arg 5 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar8);
  }
  else {
    uVar5 = FUN_004f6e50(param_1,5);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar5);
    iVar4 = FUN_004f6ca0(param_1,6);
    if (iVar4 == 0) {
      pcVar8 = "TUTORIAL_OPPTUTE_SWAP: arg 6 is not an integer";
      Engine_ACTIVATE_COMPANION_483650("TUTORIAL_OPPTUTE_SWAP: arg 6 is not an integer");
      Engine_ACTIVATE_COMPANION_4836e0(pcVar8);
    }
    else {
      FUN_004f6db0(param_1,6);
      uStack_20 = FUN_0050432c();
      iVar4 = FUN_004f6ca0(param_1,7);
      if (iVar4 == 0) {
        pcVar8 = "TUTORIAL_OPPTUTE_SWAP: arg 7 is not an integer";
        Engine_ACTIVATE_COMPANION_483650("TUTORIAL_OPPTUTE_SWAP: arg 7 is not an integer");
        Engine_ACTIVATE_COMPANION_4836e0(pcVar8);
      }
      else {
        FUN_004f6db0(param_1,7);
        uStack_24 = FUN_0050432c();
        iVar4 = iStack_1c;
        if (iVar3 <= iVar1) {
          iVar1 = iVar3;
        }
        iVar3 = iStack_1c;
        if (iVar2 <= iStack_1c) {
          iVar3 = iVar2;
        }
        Engine_ADD_EFFECT_TO_GRID_47b3d0(&sStack_2c,iVar3,iVar1);
        psVar7 = &sStack_28;
        sStack_28 = -1;
        sStack_26 = -1;
        uVar5 = Engine_ADD_EFFECT_TO_GRID_4b51d0(0xffffffff);
        Engine_ADD_EFFECT_TO_GRID_4b59f0(uVar5,psVar7);
        sStack_2c = sStack_2c + sStack_28;
        sStack_2a = sStack_2a + sStack_26;
        if (iVar4 == iVar2) {
          uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uStack_20,uStack_24);
          iVar1 = sStack_2a + -0x24;
          iVar2 = sStack_2c + -0x49;
          uVar6 = 2;
        }
        else {
          uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uStack_20,uStack_24);
          iVar1 = sStack_2a + -0x49;
          iVar2 = sStack_2c + -0x24;
          uVar6 = 1;
        }
        Engine_TUTORIAL_OPPTUTE_GEM_4a6bb0(uVar6,iVar2,iVar1,uVar5);
      }
    }
  }
  uStack_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = pvStack_c;
  return 0;
}

