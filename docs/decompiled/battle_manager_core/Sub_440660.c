
void __thiscall FUN_00440660(int param_1,undefined4 param_2)

{
  int iVar1;
  
  iVar1 = *(int *)(param_1 + 4);
  if ((iVar1 != 0) &&
     ((uint)((*(int *)(param_1 + 8) - iVar1) / 0x148) <
      (uint)((*(int *)(param_1 + 0xc) - iVar1) / 0x148))) {
    iVar1 = *(int *)(param_1 + 8);
    FUN_0043fe00(iVar1,1,param_2,param_1,param_2);
    *(int *)(param_1 + 8) = iVar1 + 0x148;
    return;
  }
  FUN_004405f0(&param_2,*(undefined4 *)(param_1 + 8),param_2);
  return;
}

