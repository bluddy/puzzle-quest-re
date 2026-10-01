
int __thiscall FUN_00464c10(int param_1,int param_2)

{
  if (*(char *)(param_1 + 0x41) == '\0') {
    if (*(char *)(param_1 + 0x40) == '\0') {
      return *(int *)(param_1 + 0x3c);
    }
    *(int *)(param_1 + 0x38) = *(int *)(param_1 + 0x3c) + param_2;
  }
  return *(int *)(param_1 + 0x3c);
}

