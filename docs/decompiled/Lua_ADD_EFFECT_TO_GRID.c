
undefined4 Lua_ADD_EFFECT_TO_GRID(undefined4 param_1)

{
  int iVar1;
  int iVar2;
  int iVar3;
  undefined4 uVar4;
  short *psVar5;
  char *pcVar6;
  short sStack_20;
  short sStack_1e;
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
    pcVar6 = "ADD_EFFECT_TO_GRID: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("ADD_EFFECT_TO_GRID: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar6);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,1);
  iVar1 = FUN_0050432c();
  iVar2 = FUN_004f6ca0(param_1,2);
  if (iVar2 == 0) {
    pcVar6 = "ADD_EFFECT_TO_GRID: arg 2 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("ADD_EFFECT_TO_GRID: arg 2 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar6);
    ExceptionList = pvStack_c;
    return 0;
  }
  FUN_004f6db0(param_1,2);
  iVar2 = FUN_0050432c();
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  uStack_4 = 0;
  iVar3 = FUN_004f6d00(param_1,3);
  if (iVar3 == 0) {
    pcVar6 = "ADD_EFFECT_TO_GRID: arg 3 is not a string";
    Engine_ACTIVATE_COMPANION_483650("ADD_EFFECT_TO_GRID: arg 3 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar6);
  }
  else {
    uVar4 = FUN_004f6e50(param_1,3);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar4);
    FUN_0047b3d0(&sStack_1c,iVar1 + -1,iVar2 + -1);
    psVar5 = &sStack_20;
    sStack_20 = -1;
    sStack_1e = -1;
    uVar4 = FUN_004b51d0(0xffffffff);
    FUN_004b59f0(uVar4,psVar5);
    sStack_1a = sStack_1a + sStack_1e;
    sStack_1c = sStack_1c + sStack_20;
    iVar2 = sStack_1a + 0x24;
    iVar1 = sStack_1c + 0x24;
    uVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(iVar1,iVar2);
    Engine_ADD_EFFECT_TO_CHARACTER_4b0690(uVar4,iVar1,iVar2);
  }
  uStack_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = pvStack_c;
  return 0;
}

