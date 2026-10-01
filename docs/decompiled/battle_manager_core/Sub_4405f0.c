
void __thiscall FUN_004405f0(int param_1,int *param_2,int param_3,undefined4 param_4)

{
  int iVar1;
  
  iVar1 = *(int *)(param_1 + 4);
  if (iVar1 != 0) {
    if ((*(int *)(param_1 + 8) - iVar1) / 0x148 != 0) {
      iVar1 = (param_3 - iVar1) / 0x148;
      goto LAB_00440635;
    }
  }
  iVar1 = 0;
LAB_00440635:
  FUN_004400b0(param_3,1,param_4);
  *param_2 = iVar1 * 0x148 + *(int *)(param_1 + 4);
  return;
}

