
undefined4 __thiscall FUN_004c9150(int param_1,short param_2)

{
  int local_4;
  
  if (-1 < param_2) {
    _param_2 = (int)param_2;
    local_4 = param_1;
    FUN_004c88f0(&local_4,&param_2);
    if ((local_4 != *(int *)(param_1 + 4)) && (local_4 != -0x10)) {
      return *(undefined4 *)(local_4 + 0x30);
    }
  }
  return 0;
}

