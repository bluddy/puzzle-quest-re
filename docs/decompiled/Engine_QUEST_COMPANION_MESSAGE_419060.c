
int __fastcall Engine_QUEST_COMPANION_MESSAGE_419060(int param_1)

{
  int iVar1;
  int iVar2;
  int iVar3;
  undefined4 local_4;
  
  iVar2 = 0;
  local_4 = 0;
  iVar3 = 0;
  while( true ) {
    if (*(int *)(param_1 + 0x178) == 0) {
      iVar1 = 0;
    }
    else {
      iVar1 = (*(int *)(param_1 + 0x17c) - *(int *)(param_1 + 0x178)) / 7;
    }
    if (iVar1 <= iVar3) break;
    if (*(char *)(*(int *)(param_1 + 0x178) + 6 + iVar2) != '\0') {
      local_4 = local_4 + 1;
    }
    iVar3 = iVar3 + 1;
    iVar2 = iVar2 + 7;
  }
  return local_4;
}

