
int __thiscall Engine_ACTIVATE_COMPANION_4be7e0(int *param_1,int param_2)

{
  if (param_2 < 0) {
    return *param_1;
  }
  if (param_1[2] <= param_2) {
    FUN_004be260(param_2 + 2);
    return *param_1 + param_2 * 2;
  }
  return *param_1 + param_2 * 2;
}

