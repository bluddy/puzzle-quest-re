
int __thiscall Engine_SET_ITEM_41f6e0(int param_1,int param_2)

{
  int iVar1;
  int iVar2;
  int iVar3;
  
  iVar1 = 0;
  iVar3 = 0;
  while( true ) {
    if (*(int *)(param_1 + 8) == 0) {
      iVar2 = 0;
    }
    else {
      iVar2 = *(int *)(param_1 + 0xc) - *(int *)(param_1 + 8) >> 6;
    }
    if (iVar2 <= iVar1) break;
    if (*(int *)(*(int *)(param_1 + 8) + 4 + iVar3) == param_2) {
      return iVar1;
    }
    iVar1 = iVar1 + 1;
    iVar3 = iVar3 + 0x40;
  }
  return -1;
}

