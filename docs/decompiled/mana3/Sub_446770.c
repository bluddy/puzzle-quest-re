
void __thiscall FUN_00446770(int param_1,int param_2,uint param_3,undefined4 *param_4)

{
  void *pvVar1;
  undefined1 *puVar2;
  uint uVar3;
  int iVar4;
  undefined4 uVar5;
  int extraout_ECX;
  int iVar6;
  int iVar7;
  undefined4 local_20;
  undefined4 local_1c;
  int local_18;
  undefined1 *local_14;
  void *local_10;
  undefined1 *puStack_c;
  undefined4 local_8;
  
  local_8 = 0xffffffff;
  puStack_c = &LAB_00512720;
  local_10 = ExceptionList;
  local_1c = param_4[1];
  local_20 = *param_4;
  iVar4 = *(int *)(param_1 + 4);
  local_14 = &stack0xffffffd4;
  if (iVar4 == 0) {
    uVar3 = 0;
  }
  else {
    uVar3 = *(int *)(param_1 + 0xc) - iVar4 >> 3;
  }
  if (param_3 != 0) {
    if (iVar4 == 0) {
      iVar6 = 0;
    }
    else {
      iVar6 = *(int *)(param_1 + 8) - iVar4 >> 3;
    }
    ExceptionList = &local_10;
    puVar2 = &stack0xffffffd4;
    if (0x1fffffffU - iVar6 < param_3) {
      ExceptionList = &local_10;
      uVar3 = FUN_004041a0();
      iVar4 = extraout_ECX;
      puVar2 = local_14;
    }
    local_14 = puVar2;
    if (iVar4 == 0) {
      iVar6 = 0;
    }
    else {
      iVar6 = *(int *)(param_1 + 8) - iVar4 >> 3;
    }
    if (uVar3 < iVar6 + param_3) {
      if (0x1fffffff - (uVar3 >> 1) < uVar3) {
        uVar3 = 0;
      }
      else {
        uVar3 = uVar3 + (uVar3 >> 1);
      }
      if (iVar4 == 0) {
        iVar6 = 0;
      }
      else {
        iVar6 = *(int *)(param_1 + 8) - iVar4 >> 3;
      }
      if (uVar3 < iVar6 + param_3) {
        if (iVar4 == 0) {
          iVar4 = 0;
        }
        else {
          iVar4 = *(int *)(param_1 + 8) - iVar4 >> 3;
        }
        uVar3 = iVar4 + param_3;
      }
      iVar4 = FUN_004f0184(uVar3 * 8);
      local_8 = 0;
      local_18 = iVar4;
      iVar6 = FUN_0044d0e0(*(undefined4 *)(param_1 + 4),param_2,iVar4,param_1,param_2);
      FUN_00468210(iVar6,param_3,&local_20,param_1,param_2);
      FUN_0044d0e0(param_2,*(undefined4 *)(param_1 + 8),iVar6 + param_3 * 8,param_1,param_2);
      pvVar1 = *(void **)(param_1 + 4);
      if (pvVar1 == (void *)0x0) {
        iVar6 = 0;
      }
      else {
        iVar6 = *(int *)(param_1 + 8) - (int)pvVar1 >> 3;
      }
      if (pvVar1 != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
        operator_delete(pvVar1);
      }
      *(uint *)(param_1 + 0xc) = uVar3 * 8 + iVar4;
      *(uint *)(param_1 + 8) = iVar4 + (param_3 + iVar6) * 8;
      *(int *)(param_1 + 4) = iVar4;
      ExceptionList = local_10;
      return;
    }
    iVar6 = *(int *)(param_1 + 8);
    iVar4 = param_3 * 8;
    if ((uint)(iVar6 - param_2 >> 3) < param_3) {
      FUN_0044d0e0(param_2,iVar6,iVar4 + param_2,param_1,iVar4);
      local_8 = 2;
      FUN_00451860(*(int *)(param_1 + 8),param_3 - (*(int *)(param_1 + 8) - param_2 >> 3),&local_20)
      ;
      iVar4 = *(int *)(param_1 + 8) + iVar4;
      *(int *)(param_1 + 8) = iVar4;
      FUN_00445d80(param_2,iVar4 + param_3 * -8,&local_20);
      ExceptionList = local_10;
      return;
    }
    iVar7 = iVar6 + param_3 * -8;
    uVar5 = FUN_0044d0e0(iVar7,iVar6,iVar6,param_1,iVar4);
    *(undefined4 *)(param_1 + 8) = uVar5;
    FUN_00468060(param_2,iVar7,iVar6);
    FUN_00445d80(param_2,iVar4 + param_2,&local_20);
  }
  ExceptionList = local_10;
  return;
}

