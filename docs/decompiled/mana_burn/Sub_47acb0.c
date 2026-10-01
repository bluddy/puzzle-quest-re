
uint __fastcall FUN_0047acb0(int param_1)

{
  uint uVar1;
  int *piVar2;
  int *piVar3;
  int iVar4;
  
  iVar4 = 0;
  piVar3 = (int *)(param_1 + 4);
  do {
    uVar1 = 0;
    piVar2 = piVar3;
    do {
      if (*piVar2 != 0) {
        return uVar1 & 0xffffff00;
      }
      uVar1 = uVar1 + 1;
      piVar2 = piVar2 + 0x12;
    } while ((int)uVar1 < 8);
    iVar4 = iVar4 + 1;
    piVar3 = piVar3 + 2;
  } while (iVar4 < 9);
  return CONCAT31((int3)(uVar1 >> 8),1);
}

