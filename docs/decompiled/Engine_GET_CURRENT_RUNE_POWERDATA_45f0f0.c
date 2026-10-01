
int __thiscall Engine_GET_CURRENT_RUNE_POWERDATA_45f0f0(int param_1,int param_2)

{
  int iVar1;
  int iVar2;
  int iVar3;
  
  if (*(int *)(param_1 + 8) == 0) {
    iVar3 = 0;
  }
  else {
    iVar3 = (*(int *)(param_1 + 0xc) - *(int *)(param_1 + 8)) / 0x3c;
  }
  iVar1 = *(int *)(param_1 + 0x18);
  if (iVar1 != 0) {
    iVar1 = (*(int *)(param_1 + 0x1c) - iVar1) / 0x44;
  }
  iVar2 = *(int *)(param_1 + 0x28);
  iVar3 = iVar1 + iVar3;
  while( true ) {
    if (iVar2 == *(int *)(param_1 + 0x2c)) {
      return 0;
    }
    if (iVar3 == param_2) break;
    iVar2 = iVar2 + 0x44;
    iVar3 = iVar3 + 1;
  }
  return iVar2;
}

