
undefined4 __fastcall FUN_00475220(int param_1)

{
  int iVar1;
  
  iVar1 = *(int *)(param_1 + 4);
  if (iVar1 < 1) {
    return CONCAT31((int3)((uint)iVar1 >> 8),1);
  }
  iVar1 = iVar1 + -1;
  *(int *)(param_1 + 4) = iVar1;
  return CONCAT31((int3)((uint)iVar1 >> 8),0 < iVar1);
}

