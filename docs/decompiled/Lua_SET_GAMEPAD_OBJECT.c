
undefined4 Lua_SET_GAMEPAD_OBJECT(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  int *piVar3;
  char *pcVar4;
  void *local_c;
  undefined1 *puStack_8;
  uint local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00515d40;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
  local_4 = 0;
  iVar1 = FUN_004f6d00(param_1,1);
  if (iVar1 == 0) {
    pcVar4 = "SET_GAMEPAD_OBJECT: arg 1 is not a string";
    Engine_ACTIVATE_COMPANION_483650("SET_GAMEPAD_OBJECT: arg 1 is not a string");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
  }
  else {
    uVar2 = FUN_004f6e50(param_1,1);
    Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
    Engine_ACTIVATE_COMPANION_4be530(&DAT_0051b07c,0xffffffff);
    local_4 = CONCAT31(local_4._1_3_,1);
    iVar1 = FUN_004f6d00(param_1,2);
    if (iVar1 == 0) {
      pcVar4 = "SET_GAMEPAD_OBJECT: arg 2 is not a string";
      Engine_ACTIVATE_COMPANION_483650("SET_GAMEPAD_OBJECT: arg 2 is not a string");
      Engine_ACTIVATE_COMPANION_4836e0(pcVar4);
    }
    else {
      uVar2 = FUN_004f6e50(param_1,2);
      Engine_ACTIVATE_COMPANION_4bf1a0(uVar2);
      piVar3 = (int *)0x0;
      uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
      iVar1 = FUN_004c1dc0(uVar2);
      if (iVar1 != 0) {
        uVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
        piVar3 = (int *)FUN_004c2a10(uVar2);
      }
      if (DAT_0059a534 != (int *)0x0) {
        (**(code **)(*DAT_0059a534 + 0x1c))(0);
      }
      DAT_0059a534 = piVar3;
      if (piVar3 != (int *)0x0) {
        (**(code **)(*piVar3 + 0x1c))(1);
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

