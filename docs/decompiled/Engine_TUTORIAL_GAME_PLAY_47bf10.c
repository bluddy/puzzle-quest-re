
void __fastcall Engine_TUTORIAL_GAME_PLAY_47bf10(int param_1)

{
  undefined1 *puVar1;
  int iVar2;
  undefined1 *puVar3;
  int iVar4;
  
  *(undefined4 *)(param_1 + 0x34c) = 2;
  FUN_0047bed0();
  puVar3 = (undefined1 *)(param_1 + 8);
  iVar4 = 9;
  do {
    iVar2 = 8;
    puVar1 = puVar3;
    do {
      *puVar1 = 0;
      puVar1 = puVar1 + 0x48;
      iVar2 = iVar2 + -1;
    } while (iVar2 != 0);
    puVar3 = puVar3 + 8;
    iVar4 = iVar4 + -1;
  } while (iVar4 != 0);
  return;
}

