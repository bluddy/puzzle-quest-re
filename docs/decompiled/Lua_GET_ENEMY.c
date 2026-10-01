
undefined4 Lua_GET_ENEMY(undefined4 param_1)

{
  int iVar1;
  undefined4 uVar2;
  undefined4 uVar3;
  undefined4 uVar4;
  undefined8 uVar5;
  char *pcVar6;
  
  iVar1 = FUN_004f6ca0();
  if (iVar1 == 0) {
    pcVar6 = "GET_ENEMY: arg 1 is not an integer";
    Engine_ACTIVATE_COMPANION_483650("GET_ENEMY: arg 1 is not an integer");
    Engine_ACTIVATE_COMPANION_4836e0(pcVar6);
    return 0;
  }
  FUN_004f6db0(param_1,1);
  uVar2 = FUN_0050432c();
  iVar1 = FUN_004f6ca0(param_1,2);
  if (iVar1 == 0) {
    Engine_ACTIVATE_COMPANION_483650();
    Engine_ACTIVATE_COMPANION_4836e0();
    return 0;
  }
  FUN_004f6db0(param_1,2);
  uVar3 = FUN_0050432c();
  uVar5 = CONCAT44(uVar3,uVar2);
  uVar4 = 2;
  Engine_ADD_GOLD_447c60(2,uVar2,uVar3);
  iVar1 = FUN_00446220(uVar4,uVar5);
  FUN_004f7020(param_1,(double)iVar1);
  return 1;
}

