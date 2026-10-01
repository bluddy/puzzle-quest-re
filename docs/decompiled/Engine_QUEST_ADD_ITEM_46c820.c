
void __thiscall Engine_QUEST_ADD_ITEM_46c820(int param_1,int param_2)

{
  char cVar1;
  int iVar2;
  undefined4 uVar3;
  int iVar4;
  int iVar5;
  int local_94;
  undefined1 local_90;
  int local_64;
  int local_24;
  void *local_c;
  undefined1 *puStack_8;
  uint local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_005147d3;
  local_c = ExceptionList;
  iVar4 = 0;
  iVar5 = 0;
  while( true ) {
    if (*(int *)(param_1 + 0xf8) == 0) {
      iVar2 = 0;
    }
    else {
      iVar2 = (*(int *)(param_1 + 0xfc) - *(int *)(param_1 + 0xf8)) / 5;
    }
    if (iVar2 <= iVar4) break;
    if (*(int *)(*(int *)(param_1 + 0xf8) + iVar5) == param_2) {
      return;
    }
    iVar4 = iVar4 + 1;
    iVar5 = iVar5 + 5;
  }
  local_94 = param_2;
  local_90 = 0;
  ExceptionList = &local_c;
  iVar4 = param_2;
  Engine_GET_CURRENT_RUNE_CODE_44f8e0(param_2);
  uVar3 = FUN_0041f980(iVar4);
  FUN_00418930(uVar3);
  iVar5 = 0;
  local_4 = 0;
  iVar4 = 0;
  while( true ) {
    iVar2 = *(int *)(param_1 + 0xf8);
    if (iVar2 != 0) {
      iVar2 = (*(int *)(param_1 + 0xfc) - iVar2) / 5;
    }
    if (iVar2 <= iVar4) break;
    if (*(char *)(iVar5 + 4 + *(int *)(param_1 + 0xf8)) != '\0') {
      uVar3 = *(undefined4 *)(iVar5 + *(int *)(param_1 + 0xf8));
      Engine_GET_CURRENT_RUNE_CODE_44f8e0(uVar3);
      uVar3 = FUN_0041f980(uVar3);
      FUN_00418930(uVar3);
      local_4 = local_4 & 0xffffff00;
      if (local_64 == local_24) {
        FUN_0046ff80();
        goto LAB_0046c94e;
      }
      FUN_0046ff80();
    }
    iVar4 = iVar4 + 1;
    iVar5 = iVar5 + 5;
  }
  cVar1 = FUN_0046b0d0(param_2);
  if (cVar1 != '\0') {
    local_90 = 1;
  }
LAB_0046c94e:
  FUN_0046bb10(&local_94);
  *(undefined1 *)(param_1 + 0xbc) = 1;
  local_4 = 0xffffffff;
  FUN_0046ff80();
  ExceptionList = local_c;
  return;
}

