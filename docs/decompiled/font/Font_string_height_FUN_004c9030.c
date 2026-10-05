
undefined4 __thiscall FUN_004c9030(int param_1,short param_2,int param_3)

{
  if ((param_3 != 0) && (-1 < param_2)) {
    _param_2 = (int)param_2;
    FUN_004c88f0(&param_3,&param_2);
    if ((param_3 != *(int *)(param_1 + 4)) && (param_3 != -0x10)) {
      return *(undefined4 *)
              (*(int *)(*(int *)(param_1 + 0x10) + *(int *)(param_3 + 0x2c) * 8) + 0x28);
    }
  }
  return 0;
}

