
void FUN_004800e0(undefined4 *param_1,undefined4 *param_2,undefined4 *param_3)

{
  undefined4 *puVar1;
  
  if (param_1 != param_2) {
    do {
      puVar1 = param_2 + -4;
      param_3[-4] = *puVar1;
      param_3[-3] = param_2[-3];
      param_3[-2] = param_2[-2];
      param_3[-1] = param_2[-1];
      param_3 = param_3 + -4;
      param_2 = puVar1;
    } while (puVar1 != param_1);
  }
  return;
}

