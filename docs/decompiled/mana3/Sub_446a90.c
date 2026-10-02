
int __thiscall FUN_00446a90(int param_1,int param_2)

{
  void *pvVar1;
  char cVar2;
  undefined4 uVar3;
  uint uVar4;
  uint uVar5;
  int iVar6;
  
  if (param_1 == param_2) {
    return param_1;
  }
  iVar6 = *(int *)(param_2 + 4);
  if (iVar6 != 0) {
    uVar4 = *(int *)(param_2 + 8) - iVar6 >> 3;
    if (uVar4 != 0) {
      pvVar1 = *(void **)(param_1 + 4);
      if (pvVar1 == (void *)0x0) {
        uVar5 = 0;
      }
      else {
        uVar5 = *(int *)(param_1 + 8) - (int)pvVar1 >> 3;
      }
      if (uVar4 <= uVar5) {
        FUN_00445dd0(iVar6,*(int *)(param_2 + 8),pvVar1);
        if (*(int *)(param_2 + 4) == 0) {
          *(undefined4 *)(param_1 + 8) = *(undefined4 *)(param_1 + 4);
          return param_1;
        }
        *(int *)(param_1 + 8) =
             *(int *)(param_1 + 4) + (*(int *)(param_2 + 8) - *(int *)(param_2 + 4) >> 3) * 8;
        return param_1;
      }
      if (pvVar1 == (void *)0x0) {
        uVar5 = 0;
      }
      else {
        uVar5 = *(int *)(param_1 + 0xc) - (int)pvVar1 >> 3;
      }
      if (uVar5 < uVar4) {
        if (pvVar1 != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
          operator_delete(pvVar1);
        }
        if (*(int *)(param_2 + 4) == 0) {
          iVar6 = 0;
        }
        else {
          iVar6 = *(int *)(param_2 + 8) - *(int *)(param_2 + 4) >> 3;
        }
        cVar2 = FUN_00404460(iVar6);
        if (cVar2 == '\0') {
          return param_1;
        }
        uVar3 = FUN_00450b40(*(undefined4 *)(param_2 + 4),*(undefined4 *)(param_2 + 8),
                             *(undefined4 *)(param_1 + 4));
        *(undefined4 *)(param_1 + 8) = uVar3;
        return param_1;
      }
      if (pvVar1 == (void *)0x0) {
        iVar6 = 0;
      }
      else {
        iVar6 = *(int *)(param_1 + 8) - (int)pvVar1 >> 3;
      }
      iVar6 = *(int *)(param_2 + 4) + iVar6 * 8;
      FUN_00445dd0(*(int *)(param_2 + 4),iVar6,pvVar1);
      uVar3 = FUN_0044d0e0(iVar6,*(undefined4 *)(param_2 + 8),*(undefined4 *)(param_1 + 8),param_1,
                           param_2);
      *(undefined4 *)(param_1 + 8) = uVar3;
      return param_1;
    }
  }
  if (*(void **)(param_1 + 4) != (void *)0x0) {
                    /* WARNING: Subroutine does not return */
    operator_delete(*(void **)(param_1 + 4));
  }
  *(undefined4 *)(param_1 + 4) = 0;
  *(undefined4 *)(param_1 + 8) = 0;
  *(undefined4 *)(param_1 + 0xc) = 0;
  return param_1;
}

