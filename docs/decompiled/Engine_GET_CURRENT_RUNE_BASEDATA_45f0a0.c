
int __thiscall Engine_GET_CURRENT_RUNE_BASEDATA_45f0a0(int param_1,int param_2)

{
  int iVar1;
  int iVar2;
  
  if (*(int *)(param_1 + 8) == 0) {
    iVar2 = 0;
  }
  else {
    iVar2 = (*(int *)(param_1 + 0xc) - *(int *)(param_1 + 8)) / 0x3c;
  }
  iVar1 = *(int *)(param_1 + 0x18);
  while( true ) {
    if (iVar1 == *(int *)(param_1 + 0x1c)) {
      return 0;
    }
    if (iVar2 == param_2) break;
    iVar1 = iVar1 + 0x44;
    iVar2 = iVar2 + 1;
  }
  return iVar1;
}

