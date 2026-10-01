
undefined4 Lua_ADD_EFFECT_TO_CHARACTER(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  int iVar4;
  char *pcVar5;
  short sStack_1c;
  short sStack_1a;
  void *pvStack_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_00515e58;
  pvStack_c = ExceptionList;
  ExceptionList = &pvStack_c;
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar5 = "ADD_EFFECT_TO_CHARACTER: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("ADD_EFFECT_TO_CHARACTER: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar5);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  uStack_4 = 0;
  iVar1 = FUN_004f6d00(param_1,2);
  if (iVar1 == 0) {
    pcVar5 = "ADD_EFFECT_TO_CHARACTER: arg 2 is not a string";
    Engine_ACTIVATE_COMPANION_483650("ADD_EFFECT_TO_CHARACTER: arg 2 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar5);
  }
  else {
    uVar3 = FUN_004f6e50(param_1,2);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar3);
    Engine_ADD_ANIMEFFECT_TO_CHARACTER_475a10(&sStack_1c,uVar2);
    iVar1 = (int)sStack_1a;
    iVar4 = (int)sStack_1c;
    uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(iVar4,iVar1);
    FUN_004b0690(uVar2,iVar4,iVar1);
  }
  uStack_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = pvStack_c;
  return 0;
}

