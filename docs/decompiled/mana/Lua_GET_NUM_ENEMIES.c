
undefined4 Lua_GET_NUM_ENEMIES(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined8 uVar3;
  
  iVar1 = FUN_004f6ca0(param_1,1);
  if (iVar1 == 0) {
    Engine_ACTIVATE_COMPANION_483650();
    Engine_ACTIVATE_COMPANION_4836e0();
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  uVar3 = CONCAT44(uVar2,2);
  Engine_ADD_GOLD_447c60(2,uVar2);
  iVar1 = Engine_GET_NUM_ENEMIES_4460d0(uVar3);
  FUN_004f7020(param_1,(double)iVar1);
  return 1;
}

