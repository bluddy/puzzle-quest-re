
undefined4 Lua_HANDLE_SPELL_COST(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  char *pcVar3;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    pcVar3 = "HANDLE_SPELL_COST: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("HANDLE_SPELL_COST: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar3);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  iVar1 = FUN_004622c0();
  iVar1 = *(int *)(iVar1 + 0x18);
  if (iVar1 != 0) {
    Engine_ADD_GOLD_447c60(uVar2);
    Engine_ADD_GOLD_446200(uVar2);
    FUN_0040d080(0,(int)*(short *)(iVar1 + 0x2c));
    FUN_0040d080(1,(int)*(short *)(iVar1 + 0x2e));
    FUN_0040d080(2,(int)*(short *)(iVar1 + 0x30));
    FUN_0040d080(3,(int)*(short *)(iVar1 + 0x32));
  }
  iVar1 = FUN_004622c0();
  *(undefined1 *)(iVar1 + 0x14) = 1;
  return 0;
}

