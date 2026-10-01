
undefined4 __thiscall FUN_00464c30(int param_1,int param_2,undefined1 *param_3)

{
  *param_3 = 0;
  if (*(char *)(param_1 + 0x41) == '\0') {
    param_2 = *(int *)(param_1 + 0x38) - param_2;
    if (param_2 < 0) {
      param_2 = 0;
    }
    if (*(char *)(param_1 + 0x40) != '\0') {
      if (*(int *)(param_1 + 0x3c) / 1000 != param_2 / 1000) {
        *param_3 = 1;
      }
      *(int *)(param_1 + 0x3c) = param_2;
    }
  }
  return *(undefined4 *)(param_1 + 0x3c);
}

