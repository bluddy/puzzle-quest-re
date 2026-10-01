
void FUN_00480050(undefined4 *param_1,undefined4 *param_2,undefined4 *param_3)

{
  undefined4 *puVar1;
  
  if (param_1 != param_2) {
    do {
      *param_1 = *param_3;
      param_1[1] = param_3[1];
      param_1[2] = param_3[2];
      puVar1 = param_1 + 4;
      param_1[3] = param_3[3];
      param_1 = puVar1;
    } while (puVar1 != param_2);
  }
  return;
}

