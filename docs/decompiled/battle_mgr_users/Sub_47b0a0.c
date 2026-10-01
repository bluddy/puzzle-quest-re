// refs 0x0043f870 @ 0047b0a1

undefined1 FUN_0047b0a0(void)

{
  int iVar1;
  
  iVar1 = CBattleManager_GetSingleton();
  CBattleManager_EvaluateBoard();
  return *(undefined1 *)(iVar1 + 0x2c);
}

