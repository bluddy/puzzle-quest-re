
undefined4 * __thiscall Engine_ADD_GOLD_404570(undefined4 *param_1,undefined4 *param_2)

{
  int iVar1;
  undefined4 *puVar2;
  undefined4 *puVar3;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_0050f6d1;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  *param_1 = *param_2;
  param_1[1] = param_2[1];
  param_1[2] = param_2[2];
  param_1[3] = param_2[3];
  *(undefined1 *)(param_1 + 4) = *(undefined1 *)(param_2 + 4);
  *(undefined1 *)((int)param_1 + 0x11) = *(undefined1 *)((int)param_2 + 0x11);
  *(undefined1 *)((int)param_1 + 0x12) = *(undefined1 *)((int)param_2 + 0x12);
  *(undefined1 *)((int)param_1 + 0x13) = *(undefined1 *)((int)param_2 + 0x13);
  *(undefined1 *)(param_1 + 5) = *(undefined1 *)(param_2 + 5);
  param_1[6] = param_2[6];
  param_1[7] = param_2[7];
  param_1[8] = param_2[8];
  *(undefined1 *)(param_1 + 9) = *(undefined1 *)(param_2 + 9);
  FUN_00401b30(param_2 + 10);
  local_4 = 0;
  FUN_00401b30(param_2 + 0xe);
  local_4._0_1_ = 1;
  FUN_00401b30(param_2 + 0x12);
  local_4 = CONCAT31(local_4._1_3_,2);
  FUN_004044b0(param_2 + 0x16);
  puVar2 = param_2 + 0x1a;
  puVar3 = param_1 + 0x1a;
  for (iVar1 = 7; iVar1 != 0; iVar1 = iVar1 + -1) {
    *puVar3 = *puVar2;
    puVar2 = puVar2 + 1;
    puVar3 = puVar3 + 1;
  }
  param_1[0x21] = param_2[0x21];
  param_1[0x22] = param_2[0x22];
  param_1[0x23] = param_2[0x23];
  param_1[0x24] = param_2[0x24];
  param_1[0x25] = param_2[0x25];
  param_1[0x26] = param_2[0x26];
  param_1[0x27] = param_2[0x27];
  param_1[0x28] = param_2[0x28];
  param_1[0x29] = param_2[0x29];
  ExceptionList = local_c;
  return param_1;
}

