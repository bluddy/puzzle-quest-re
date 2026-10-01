
undefined4 __thiscall FUN_004b2ba0(int param_1,int param_2)

{
  int *piVar1;
  int local_4;
  
  if (param_2 != 0) {
    local_4 = param_1;
    piVar1 = (int *)FUN_004b28c0(&local_4,&param_2);
    if (*piVar1 != *(int *)(param_1 + 8)) {
      return *(undefined4 *)(*piVar1 + 0x10);
    }
  }
  return 0;
}

