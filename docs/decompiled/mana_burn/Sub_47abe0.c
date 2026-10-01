
void __thiscall FUN_0047abe0(int param_1,int param_2,int param_3,int param_4,int param_5)

{
  int iVar1;
  
  iVar1 = param_1 + param_3 * 8 + param_2 * 0x48;
  param_5 = param_5 + param_4 * 9;
  *(undefined4 *)(param_1 + 4 + param_5 * 8) = *(undefined4 *)(iVar1 + 4);
  *(undefined4 *)(param_1 + 8 + param_5 * 8) = *(undefined4 *)(iVar1 + 8);
  *(undefined4 *)(iVar1 + 4) = 0;
  *(undefined1 *)(iVar1 + 9) = 0;
  *(undefined1 *)(iVar1 + 8) = 0;
  return;
}

