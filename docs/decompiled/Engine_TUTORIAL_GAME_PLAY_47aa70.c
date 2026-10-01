
void __fastcall Engine_TUTORIAL_GAME_PLAY_47aa70(int param_1)

{
  undefined4 *puVar1;
  int iVar2;
  undefined4 *puVar3;
  int iVar4;
  
  FUN_0047a8b0();
  puVar3 = (undefined4 *)(param_1 + 0x24c);
  iVar4 = 8;
  do {
    iVar2 = 8;
    puVar1 = puVar3;
    do {
      *puVar1 = 0;
      puVar1 = puVar1 + 8;
      iVar2 = iVar2 + -1;
    } while (iVar2 != 0);
    puVar3 = puVar3 + 1;
    iVar4 = iVar4 + -1;
  } while (iVar4 != 0);
  return;
}

