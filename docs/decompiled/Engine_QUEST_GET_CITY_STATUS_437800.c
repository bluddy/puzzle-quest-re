
int __thiscall Engine_QUEST_GET_CITY_STATUS_437800(int param_1,int param_2)

{
  int iVar1;
  int iVar2;
  int iVar3;
  
  iVar3 = 0;
  iVar2 = 0;
  while( true ) {
    if (*(int *)(param_1 + 0x128) == 0) {
      iVar1 = 0;
    }
    else {
      iVar1 = (*(int *)(param_1 + 300) - *(int *)(param_1 + 0x128)) / 10;
    }
    if (iVar1 <= iVar3) break;
    if (*(int *)(*(int *)(param_1 + 0x128) + iVar2) == param_2) {
      return *(int *)(param_1 + 0x128) + iVar3 * 10;
    }
    iVar3 = iVar3 + 1;
    iVar2 = iVar2 + 10;
  }
  return 0;
}

