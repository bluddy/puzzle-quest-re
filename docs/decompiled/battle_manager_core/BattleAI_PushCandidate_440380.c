
void __thiscall
BattleAI_PushCandidate_440380(int param_1,int param_2,uint param_3,undefined4 *param_4)

{
  void *pvVar1;
  undefined1 *puVar2;
  int iVar3;
  uint uVar4;
  undefined4 uVar5;
  int iVar6;
  int iVar7;
  undefined8 uVar8;
  undefined4 local_24;
  undefined4 local_20;
  undefined4 local_1c;
  undefined4 local_18;
  undefined1 *local_14;
  void *local_10;
  undefined1 *puStack_c;
  undefined4 local_8;
  
  local_8 = 0xffffffff;
  puStack_c = &LAB_00512140;
  local_10 = ExceptionList;
  local_24 = *param_4;
  local_20 = param_4[1];
  local_1c = param_4[2];
  local_18 = param_4[3];
  iVar6 = *(int *)(param_1 + 4);
  local_14 = &stack0xffffffd0;
  if (iVar6 == 0) {
    iVar3 = 0;
  }
  else {
    iVar3 = *(int *)(param_1 + 0xc) - iVar6 >> 4;
  }
  uVar8 = CONCAT44(iVar6,iVar3);
  if (param_3 != 0) {
    if (iVar6 == 0) {
      iVar6 = 0;
    }
    else {
      iVar6 = *(int *)(param_1 + 8) - iVar6 >> 4;
    }
    ExceptionList = &local_10;
    puVar2 = &stack0xffffffd0;
    if (0xfffffffU - iVar6 < param_3) {
      ExceptionList = &local_10;
      uVar8 = FUN_0043fb60();
      puVar2 = local_14;
    }
    local_14 = puVar2;
    iVar6 = (int)((ulonglong)uVar8 >> 0x20);
    uVar4 = (uint)uVar8;
    if (iVar6 == 0) {
      iVar3 = 0;
    }
    else {
      iVar3 = *(int *)(param_1 + 8) - iVar6 >> 4;
    }
    if (uVar4 < iVar3 + param_3) {
      if (0xfffffff - (uVar4 >> 1) < uVar4) {
        uVar4 = 0;
      }
      else {
        uVar4 = uVar4 + (uVar4 >> 1);
      }
      if (iVar6 == 0) {
        iVar3 = 0;
      }
      else {
        iVar3 = *(int *)(param_1 + 8) - iVar6 >> 4;
      }
      if (uVar4 < iVar3 + param_3) {
        if (iVar6 == 0) {
          iVar6 = 0;
        }
        else {
          iVar6 = *(int *)(param_1 + 8) - iVar6 >> 4;
        }
        uVar4 = iVar6 + param_3;
      }
      iVar6 = FUN_004f0184(uVar4 * 0x10);
      local_8 = 0;
      iVar3 = FUN_004802f0(*(undefined4 *)(param_1 + 4),param_2,iVar6,param_1,param_2);
      BattleAI_CandidatePush_480470(iVar3,param_3,&local_24,param_1,param_2);
      FUN_004802f0(param_2,*(undefined4 *)(param_1 + 8),iVar3 + param_3 * 0x10,param_1,param_2);
      pvVar1 = *(void **)(param_1 + 4);
      if (pvVar1 == (void *)0x0) {
        iVar3 = 0;
      }
      else {
        iVar3 = *(int *)(param_1 + 8) - (int)pvVar1 >> 4;
      }
      if (pvVar1 != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
        operator_delete(pvVar1);
      }
      *(uint *)(param_1 + 0xc) = uVar4 * 0x10 + iVar6;
      *(uint *)(param_1 + 8) = (param_3 + iVar3) * 0x10 + iVar6;
      *(int *)(param_1 + 4) = iVar6;
      ExceptionList = local_10;
      return;
    }
    iVar6 = *(int *)(param_1 + 8);
    if ((uint)(iVar6 - param_2 >> 4) < param_3) {
      iVar3 = param_3 * 0x10;
      FUN_004802f0(param_2,iVar6,iVar3 + param_2,param_1,iVar3);
      local_8 = 2;
      FUN_00440080(*(int *)(param_1 + 8),param_3 - (*(int *)(param_1 + 8) - param_2 >> 4),&local_24)
      ;
      iVar3 = *(int *)(param_1 + 8) + iVar3;
      *(int *)(param_1 + 8) = iVar3;
      FUN_00480050(param_2,iVar3 + param_3 * -0x10,&local_24);
      ExceptionList = local_10;
      return;
    }
    iVar3 = param_3 * 0x10;
    iVar7 = iVar6 + param_3 * -0x10;
    uVar5 = FUN_004802f0(iVar7,iVar6,iVar6,param_1,iVar3);
    *(undefined4 *)(param_1 + 8) = uVar5;
    FUN_004800e0(param_2,iVar7,iVar6,iVar3);
    FUN_00480050(param_2,iVar3 + param_2,&local_24);
  }
  ExceptionList = local_10;
  return;
}

