
void __thiscall FUN_004650f0(int param_1,int param_2,uint param_3,undefined4 *param_4)

{
  int iVar1;
  undefined4 uVar2;
  int iVar3;
  uint uVar4;
  uint extraout_ECX;
  undefined4 *puVar5;
  undefined4 local_470 [278];
  undefined4 local_18;
  undefined1 *local_14;
  void *local_10;
  undefined1 *puStack_c;
  undefined4 local_8;
  
  local_8 = 0xffffffff;
  puStack_c = &LAB_00514340;
  local_10 = ExceptionList;
  puVar5 = local_470;
  for (iVar3 = 0x116; iVar3 != 0; iVar3 = iVar3 + -1) {
    *puVar5 = *param_4;
    param_4 = param_4 + 1;
    puVar5 = puVar5 + 1;
  }
  iVar3 = *(int *)(param_1 + 4);
  local_18 = DAT_0057faa0;
  if (iVar3 == 0) {
    uVar4 = 0;
  }
  else {
    uVar4 = (*(int *)(param_1 + 0xc) - iVar3) / 0x458;
  }
  local_14 = &stack0xfffffb7c;
  if (param_3 != 0) {
    if (iVar3 == 0) {
      iVar1 = 0;
    }
    else {
      iVar1 = (*(int *)(param_1 + 8) - iVar3) / 0x458;
    }
    ExceptionList = &local_10;
    local_14 = &stack0xfffffb7c;
    if (0x3aef6cU - iVar1 < param_3) {
      ExceptionList = &local_10;
      local_14 = &stack0xfffffb7c;
      FUN_00464fa0();
      uVar4 = extraout_ECX;
    }
    if (iVar3 == 0) {
      iVar1 = 0;
    }
    else {
      iVar1 = (*(int *)(param_1 + 8) - iVar3) / 0x458;
    }
    if (uVar4 < iVar1 + param_3) {
      if (0x3aef6c - (uVar4 >> 1) < uVar4) {
        uVar4 = 0;
      }
      else {
        uVar4 = uVar4 + (uVar4 >> 1);
      }
      if (iVar3 == 0) {
        iVar3 = 0;
      }
      else {
        iVar3 = (*(int *)(param_1 + 8) - iVar3) / 0x458;
      }
      if (uVar4 < iVar3 + param_3) {
        iVar3 = FUN_0045c940();
        uVar4 = iVar3 + param_3;
      }
      iVar1 = FUN_004f0184(uVar4 * 0x458);
      local_8 = 0;
      iVar3 = FUN_0045ca00(*(undefined4 *)(param_1 + 4),param_2,iVar1,param_1,param_2);
      FUN_00465090(iVar3,param_3,local_470,param_1,param_2);
      FUN_0045ca00(param_2,*(undefined4 *)(param_1 + 8),iVar3 + param_3 * 0x458,param_1,param_2);
      iVar3 = *(int *)(param_1 + 4);
      if (iVar3 != 0) {
        iVar3 = (*(int *)(param_1 + 8) - iVar3) / 0x458;
      }
      if (*(void **)(param_1 + 4) != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
        operator_delete(*(void **)(param_1 + 4));
      }
      *(uint *)(param_1 + 0xc) = uVar4 * 0x458 + iVar1;
      *(uint *)(param_1 + 8) = (param_3 + iVar3) * 0x458 + iVar1;
      *(int *)(param_1 + 4) = iVar1;
    }
    else {
      iVar3 = *(int *)(param_1 + 8);
      if ((uint)((iVar3 - param_2) / 0x458) < param_3) {
        iVar1 = param_3 * 0x458;
        FUN_0045ca00(param_2,iVar3,iVar1 + param_2,param_1,iVar1);
        local_8 = 2;
        FUN_004650c0(*(int *)(param_1 + 8),param_3 - (*(int *)(param_1 + 8) - param_2) / 0x458,
                     local_470);
        iVar1 = *(int *)(param_1 + 8) + iVar1;
        *(int *)(param_1 + 8) = iVar1;
        FUN_00465020(param_2,iVar1 + param_3 * -0x458,local_470);
      }
      else {
        iVar1 = iVar3 + param_3 * -0x458;
        uVar2 = FUN_0045ca00(iVar1,iVar3,iVar3,param_1,iVar1);
        *(undefined4 *)(param_1 + 8) = uVar2;
        FUN_00465050(param_2,iVar1,iVar3);
        FUN_00465020(param_2,param_3 * 0x458 + param_2,local_470);
      }
    }
  }
  ExceptionList = local_10;
  FUN_005042e3();
  return;
}

