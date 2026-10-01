
undefined4 Lua_TUTORIAL_OPEN(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  char *pcVar3;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515e58;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4 = 0;
  iVar1 = FUN_004f6d00(param_1,1);
  if (iVar1 == 0) {
    pcVar3 = "TUTORIAL_OPEN: arg 1 is not a string";
    Engine_ACTIVATE_COMPANION_483650("TUTORIAL_OPEN: arg 1 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar3);
  }
  else {
    uVar2 = FUN_004f6e50(param_1,1);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
    uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
    FUN_004a8600(uVar2);
    FUN_004a8400(uVar2);
  }
  local_4 = 0xffffffff;
  Engine_ACTIVATE_COMPANION_4bdf40();
  ExceptionList = local_c;
  return 0;
}

