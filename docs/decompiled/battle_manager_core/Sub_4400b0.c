
void __thiscall FUN_004400b0(int param_1,int param_2,uint param_3,undefined4 *param_4)

{
  int iVar1;
  undefined4 uVar2;
  int iVar3;
  uint uVar4;
  uint extraout_ECX;
  undefined4 *puVar5;
  undefined4 local_15c [82];
  undefined1 *local_14;
  void *local_10;
  undefined1 *puStack_c;
  undefined4 local_8;
  
  local_8 = 0xffffffff;
  puStack_c = &LAB_00512130;
  local_10 = ExceptionList;
  puVar5 = local_15c;
  for (iVar3 = 0x52; iVar3 != 0; iVar3 = iVar3 + -1) {
    *puVar5 = *param_4;
    param_4 = param_4 + 1;
    puVar5 = puVar5 + 1;
  }
  iVar3 = *(int *)(param_1 + 4);
  if (iVar3 == 0) {
    uVar4 = 0;
  }
  else {
    uVar4 = (*(int *)(param_1 + 0xc) - iVar3) / 0x148;
  }
  if (param_3 != 0) {
    if (iVar3 == 0) {
      iVar1 = 0;
    }
    else {
      iVar1 = (*(int *)(param_1 + 8) - iVar3) / 0x148;
    }
    ExceptionList = &local_10;
    local_14 = &stack0xfffffe98;
    if (0xc7ce0cU - iVar1 < param_3) {
      ExceptionList = &local_10;
      local_14 = &stack0xfffffe98;
      FUN_0043fb60();
      uVar4 = extraout_ECX;
    }
    if (iVar3 == 0) {
      iVar1 = 0;
    }
    else {
      iVar1 = (*(int *)(param_1 + 8) - iVar3) / 0x148;
    }
    if (uVar4 < iVar1 + param_3) {
      if (0xc7ce0c - (uVar4 >> 1) < uVar4) {
        uVar4 = 0;
      }
      else {
        uVar4 = uVar4 + (uVar4 >> 1);
      }
      if (iVar3 == 0) {
        iVar3 = 0;
      }
      else {
        iVar3 = (*(int *)(param_1 + 8) - iVar3) / 0x148;
      }
      if (uVar4 < iVar3 + param_3) {
        iVar3 = FUN_0043fb40();
        uVar4 = iVar3 + param_3;
      }
      iVar1 = FUN_004f0184(uVar4 * 0x148);
      local_8 = 0;
      iVar3 = FUN_0043fdc0(*(undefined4 *)(param_1 + 4),param_2,iVar1,param_1,param_2);
      FUN_0043fe00(iVar3,param_3,local_15c,param_1,param_2);
      FUN_0043fdc0(param_2,*(undefined4 *)(param_1 + 8),iVar3 + param_3 * 0x148,param_1,param_2);
      iVar3 = *(int *)(param_1 + 4);
      if (iVar3 != 0) {
        iVar3 = (*(int *)(param_1 + 8) - iVar3) / 0x148;
      }
      if (*(void **)(param_1 + 4) != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
        operator_delete(*(void **)(param_1 + 4));
      }
      *(uint *)(param_1 + 0xc) = uVar4 * 0x148 + iVar1;
      *(uint *)(param_1 + 8) = (param_3 + iVar3) * 0x148 + iVar1;
      *(int *)(param_1 + 4) = iVar1;
      ExceptionList = local_10;
      return;
    }
    iVar3 = *(int *)(param_1 + 8);
    if ((uint)((iVar3 - param_2) / 0x148) < param_3) {
      iVar1 = param_3 * 0x148;
      FUN_0043fdc0(param_2,iVar3,iVar1 + param_2,param_1,iVar1);
      local_8 = 2;
      FUN_00440050(*(int *)(param_1 + 8),param_3 - (*(int *)(param_1 + 8) - param_2) / 0x148,
                   local_15c);
      iVar1 = *(int *)(param_1 + 8) + iVar1;
      *(int *)(param_1 + 8) = iVar1;
      FUN_0043fbe0(param_2,iVar1 + param_3 * -0x148,local_15c);
      ExceptionList = local_10;
      return;
    }
    iVar1 = iVar3 + param_3 * -0x148;
    uVar2 = FUN_0043fdc0(iVar1,iVar3,iVar3,param_1,iVar1);
    *(undefined4 *)(param_1 + 8) = uVar2;
    FUN_0043fd80(param_2,iVar1,iVar3);
    FUN_0043fbe0(param_2,param_3 * 0x148 + param_2,local_15c);
  }
  ExceptionList = local_10;
  return;
}

