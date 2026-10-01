
undefined4 Lua_SET_DAMAGE_MULTIPLIER_ENABLED(undefined4 param_1)

{
  undefined1 uVar1;
  int iVar2;
  char *pcVar3;
  
  iVar2 = FUN_004f6ca0(param_1,1);
  if (iVar2 == 0) {
    pcVar3 = "SET_DAMAGE_MULTIPLIER_ENABLED: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("SET_DAMAGE_MULTIPLIER_ENABLED: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar3);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar1 = FUN_0050432c();
  iVar2 = Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  *(undefined1 *)(iVar2 + 0x392) = uVar1;
  return 0;
}

