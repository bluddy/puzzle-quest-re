// refs 0x0043f870 @ 0048d241

undefined4 __thiscall Lua_EVALUATE_BOARD(undefined4 param_1,undefined4 param_2)

{
  int iVar1;
  
  CBattleManager_GetSingleton(param_1);
  iVar1 = CBattleManager_EvaluateBoard();
  FUN_004f7020(param_2,(double)iVar1);
  return 1;
}

