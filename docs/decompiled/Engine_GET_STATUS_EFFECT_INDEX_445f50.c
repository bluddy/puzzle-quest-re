
int __thiscall Engine_GET_STATUS_EFFECT_INDEX_445f50(int param_1,int param_2,int param_3)

{
  int iVar1;
  int iVar2;
  int iVar3;
  
  iVar3 = 0;
  while( true ) {
    iVar2 = *(int *)(*(int *)(param_1 + 8) + 0x5c + param_2 * 0xa8);
    iVar1 = *(int *)(param_1 + 8) + param_2 * 0xa8;
    if (iVar2 == 0) {
      iVar2 = 0;
    }
    else {
      iVar2 = *(int *)(iVar1 + 0x60) - iVar2 >> 3;
    }
    if (iVar2 <= iVar3) break;
    iVar2 = *(int *)(*(int *)(iVar1 + 0x5c) + iVar3 * 8);
    iVar1 = FUN_00464430();
    if (*(int *)(iVar2 * 0x44 + 4 + *(int *)(iVar1 + 8)) == param_3) {
      return iVar3;
    }
    iVar3 = iVar3 + 1;
  }
  return -1;
}

