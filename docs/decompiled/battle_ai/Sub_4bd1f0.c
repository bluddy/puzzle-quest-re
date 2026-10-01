
int __thiscall FUN_004bd1f0(int param_1,int param_2,int param_3,int param_4)

{
  uint uVar1;
  int iVar2;
  uint uVar3;
  int iVar4;
  int iVar5;
  int iVar6;
  
  iVar2 = param_3;
  iVar5 = 0;
  iVar6 = param_2;
  if (param_2 < 1) {
    return param_4;
  }
  do {
    if (*(int *)(param_1 + 0xc) == 0) {
      uVar1 = *(uint *)(param_1 + 4);
      uVar3 = uVar1 + *(uint *)(param_1 + 8);
      if ((uVar3 < uVar1) || (uVar3 < *(uint *)(param_1 + 8))) {
        uVar3 = uVar3 + 1;
      }
      *(uint *)(param_1 + 4) = uVar3;
      *(uint *)(param_1 + 8) = uVar1;
      uVar3 = uVar3 >> 0x10;
    }
    else {
      param_2 = 0xffff;
      uVar3 = FUN_004bce30(&param_2);
    }
    iVar4 = (uVar3 * iVar2) / 0xffff + 1;
    if (iVar4 == 0) {
      iVar4 = 1;
    }
    if (iVar2 < iVar4) {
      iVar4 = iVar2;
    }
    iVar5 = iVar5 + iVar4;
    iVar6 = iVar6 + -1;
  } while (iVar6 != 0);
  return iVar5 + param_4;
}

