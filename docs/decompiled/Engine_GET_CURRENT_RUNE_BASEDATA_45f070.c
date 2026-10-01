
int __thiscall Engine_GET_CURRENT_RUNE_BASEDATA_45f070(int param_1,int param_2)

{
  int iVar1;
  int iVar2;
  
  iVar2 = *(int *)(param_1 + 8);
  iVar1 = 0;
  while( true ) {
    if (iVar2 == *(int *)(param_1 + 0xc)) {
      return 0;
    }
    if (iVar1 == param_2) break;
    iVar2 = iVar2 + 0x3c;
    iVar1 = iVar1 + 1;
  }
  return iVar2;
}

