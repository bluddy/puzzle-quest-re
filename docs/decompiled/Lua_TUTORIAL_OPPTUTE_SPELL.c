
undefined4 Lua_TUTORIAL_OPPTUTE_SPELL(undefined4 param_1)

{
  short sVar1;
  int iVar2;
  undefined4 uVar3;
  undefined4 uVar4;
  undefined4 uVar5;
  short sVar6;
  undefined4 *puVar7;
  char *pcVar8;
  undefined4 uStack_1c;
  void *pvStack_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_00515e58;
  pvStack_c = ExceptionList;
  ExceptionList = &pvStack_c;
  iVar2 = FUN_004f6ca0(param_1,1);
  if (iVar2 == 0) {
    pcVar8 = "TUTORIAL_OPPTUTE_SPELL: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_OPPTUTE_SPELL: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar8);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,1);
  sVar1 = FUN_0050432c();
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  uStack_4 = 0;
  iVar2 = FUN_004f6d00(param_1,2);
  if (iVar2 == 0) {
    pcVar8 = "TUTORIAL_OPPTUTE_SPELL: arg 2 is not a string";
  }
  else {
    uVar3 = FUN_004f6e50(param_1,2);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar3);
    iVar2 = FUN_004f6ca0(param_1,3);
    if (iVar2 != 0) {
      FUN_004f6db0(param_1,3);
      uVar3 = FUN_0050432c();
      iVar2 = FUN_004f6ca0(param_1,4);
      if (iVar2 == 0) {
        pcVar8 = "TUTORIAL_OPPTUTE_SPELL: arg 4 is not an integer";
        Engine_ACTIVATE_COMPANION_483650("TUTORIAL_OPPTUTE_SPELL: arg 4 is not an integer");
        Engine_ACTIVATE_COMPANION_4836e0(pcVar8);
      }
      else {
        FUN_004f6db0(param_1,4);
        uVar4 = FUN_0050432c();
        puVar7 = &uStack_1c;
        uStack_1c = 0xffffffff;
        uVar5 = Engine_ADD_EFFECT_TO_GRID_4b51d0(0xffffffff);
        Engine_ADD_EFFECT_TO_GRID_4b59f0(uVar5,puVar7);
        sVar6 = sVar1 * 0x29 + 0x1ce + uStack_1c._2_2_;
        sVar1 = (short)uStack_1c;
        uVar3 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(uVar3,uVar4);
        Engine_TUTORIAL_OPPTUTE_GEM_4a6bb0(0,(int)(short)(sVar1 + 100),(int)sVar6,uVar3);
      }
      uStack_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
      ExceptionList = pvStack_c;
      return 0;
    }
    pcVar8 = "TUTORIAL_OPPTUTE_SPELL: arg 3 is not an integer";
  }
  Engine_ACTIVATE_COMPANION_483650(pcVar8);
  Engine_ACTIVATE_COMPANION_4836e0(pcVar8);
  uStack_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = pvStack_c;
  return 0;
}

