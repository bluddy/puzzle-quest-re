
int __thiscall Engine_GET_CURRENT_RUNE_BASEDATA_45f240(int param_1,int param_2,short param_3)

{
  int iVar1;
  int iVar2;
  
  iVar1 = 0;
  if (param_2 == 0) {
    iVar2 = *(int *)(param_1 + 8);
    if (iVar2 != *(int *)(param_1 + 0xc)) {
      do {
        if (*(short *)(iVar2 + 0x1c) == param_3) {
          return iVar1;
        }
        iVar2 = iVar2 + 0x3c;
        iVar1 = iVar1 + 1;
      } while (iVar2 != *(int *)(param_1 + 0xc));
      return 0;
    }
  }
  else if (param_2 == 1) {
    iVar1 = *(int *)(param_1 + 8);
    if (iVar1 != 0) {
      iVar1 = (*(int *)(param_1 + 0xc) - iVar1) / 0x3c;
    }
    iVar2 = *(int *)(param_1 + 0x18);
    if (iVar2 != *(int *)(param_1 + 0x1c)) {
      do {
        if (*(short *)(iVar2 + 0x1c) == param_3) {
          return iVar1;
        }
        iVar2 = iVar2 + 0x44;
        iVar1 = iVar1 + 1;
      } while (iVar2 != *(int *)(param_1 + 0x1c));
      return 0;
    }
  }
  else if (param_2 == 2) {
    if (*(int *)(param_1 + 8) == 0) {
      iVar1 = 0;
    }
    else {
      iVar1 = (*(int *)(param_1 + 0xc) - *(int *)(param_1 + 8)) / 0x3c;
    }
    iVar2 = *(int *)(param_1 + 0x18);
    if (iVar2 != 0) {
      iVar2 = (*(int *)(param_1 + 0x1c) - iVar2) / 0x44;
    }
    iVar2 = iVar2 + iVar1;
    for (iVar1 = *(int *)(param_1 + 0x28); iVar1 != *(int *)(param_1 + 0x2c); iVar1 = iVar1 + 0x44)
    {
      if (*(short *)(iVar1 + 0x1c) == param_3) {
        return iVar2;
      }
      iVar2 = iVar2 + 1;
    }
  }
  return 0;
}

