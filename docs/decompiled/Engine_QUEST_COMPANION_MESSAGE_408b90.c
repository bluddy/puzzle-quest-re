
int __thiscall Engine_QUEST_COMPANION_MESSAGE_408b90(int param_1,int param_2)

{
  int iVar1;
  int iVar2;
  int iVar3;
  
  iVar2 = 0;
  iVar3 = 0;
  while( true ) {
    if (*(int *)(param_1 + 0x178) == 0) {
      iVar1 = 0;
    }
    else {
      iVar1 = (*(int *)(param_1 + 0x17c) - *(int *)(param_1 + 0x178)) / 7;
    }
    if (iVar1 <= iVar3) break;
    if (*(int *)(*(int *)(param_1 + 0x178) + iVar2) == param_2) {
      return iVar3 * 7 + *(int *)(param_1 + 0x178);
    }
    iVar3 = iVar3 + 1;
    iVar2 = iVar2 + 7;
  }
  return 0;
}

