
int __thiscall FUN_004469e0(int param_1,int param_2)

{
  int iVar1;
  int iVar2;
  int *piVar3;
  int iVar4;
  
  iVar1 = *(int *)(param_1 + 8);
  iVar4 = 0;
  piVar3 = (int *)(iVar1 + 0xc);
  while( true ) {
    if (iVar1 == 0) {
      iVar2 = 0;
    }
    else {
      iVar2 = (*(int *)(param_1 + 0xc) - iVar1) / 0xa8;
    }
    if (iVar2 <= iVar4) break;
    if (*piVar3 != *(int *)(param_2 * 0xa8 + iVar1 + 0xc)) {
      return iVar4 * 0xa8 + iVar1;
    }
    iVar4 = iVar4 + 1;
    piVar3 = piVar3 + 0x2a;
  }
  return iVar1;
}

