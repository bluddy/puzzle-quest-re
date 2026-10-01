
void __thiscall FUN_0043f920(int param_1,undefined2 *param_2,short *param_3)

{
  *param_2 = *(undefined2 *)(param_1 + 0x30);
  param_2[1] = *(undefined2 *)(param_1 + 0x34);
  if (*(char *)(param_1 + 0x38) != '\0') {
    *param_3 = *(short *)(param_1 + 0x30) + 1;
    param_3[1] = *(short *)(param_1 + 0x34);
    return;
  }
  *param_3 = *(short *)(param_1 + 0x30);
  param_3[1] = *(short *)(param_1 + 0x34) + 1;
  return;
}

