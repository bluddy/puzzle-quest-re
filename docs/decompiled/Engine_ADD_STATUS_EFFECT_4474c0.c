
int __thiscall Engine_ADD_STATUS_EFFECT_4474c0(int param_1,int param_2,int param_3,int param_4)

{
  int iVar1;
  int iVar2;
  int iVar3;
  int iVar4;
  int iVar5;
  int local_14;
  int local_10;
  int local_8;
  int local_4;
  
  iVar1 = param_3;
  FUN_00464430(param_3);
  iVar1 = FUN_00463f10(iVar1);
  iVar5 = 0;
  local_8 = iVar1;
  if (param_4 < 0) {
    iVar2 = FUN_00464430();
    local_4 = *(int *)(iVar1 * 0x44 + *(int *)(iVar2 + 8) + 0x3c);
  }
  else {
    local_4 = param_4;
  }
  iVar2 = FUN_00464430();
  iVar1 = iVar1 * 0x44;
  if (0 < *(int *)(*(int *)(iVar2 + 8) + 0x40 + iVar1)) {
    param_4 = 0;
    param_2 = param_2 * 0xa8;
    local_10 = -1;
    local_14 = local_4;
    while( true ) {
      iVar4 = *(int *)(param_2 + 0x5c + *(int *)(param_1 + 8));
      iVar2 = param_2 + *(int *)(param_1 + 8);
      if (iVar4 == 0) {
        iVar4 = 0;
      }
      else {
        iVar4 = *(int *)(iVar2 + 0x60) - iVar4 >> 3;
      }
      if (iVar4 <= iVar5) break;
      iVar4 = iVar5 * 8;
      iVar2 = *(int *)(iVar4 + *(int *)(iVar2 + 0x5c));
      iVar3 = FUN_00464430();
      if (*(int *)(iVar2 * 0x44 + 4 + *(int *)(iVar3 + 8)) == param_3) {
        param_4 = param_4 + 1;
        if (*(int *)(*(int *)(param_2 + 0x5c + *(int *)(param_1 + 8)) + iVar4 + 4) < local_14) {
          local_14 = *(int *)(*(int *)(param_2 + *(int *)(param_1 + 8) + 0x5c) + iVar4 + 4);
          local_10 = iVar5;
        }
      }
      iVar5 = iVar5 + 1;
    }
    iVar5 = FUN_00464430();
    if (*(int *)(*(int *)(iVar5 + 8) + 0x40 + iVar1) <= param_4) {
      if (local_10 < 0) {
        return *(int *)(iVar5 + 8) + iVar1;
      }
      iVar1 = *(int *)(*(int *)(param_1 + 8) + param_2 + 0x5c);
      *(int *)(iVar1 + 4 + local_10 * 8) = local_4;
      return iVar1;
    }
  }
  iVar1 = FUN_004472e0(&local_8);
  return iVar1;
}

