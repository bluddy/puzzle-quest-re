
undefined4 * __thiscall Engine_IS_SPELL_CASTABLE_40d4d0(undefined4 *param_1,int param_2)

{
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_0050fdd6;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  *param_1 = &PTR_FUN_0051c760;
  param_1[1] = *(undefined4 *)(param_2 + 4);
  FUN_004beb40(param_2 + 8);
  local_4 = 0;
  FUN_004beb40(param_2 + 0x14);
  local_4 = CONCAT31(local_4._1_3_,1);
  FUN_004beb40(param_2 + 0x20);
  param_1[0xb] = *(undefined4 *)(param_2 + 0x2c);
  param_1[0xc] = *(undefined4 *)(param_2 + 0x30);
  param_1[0xd] = *(undefined4 *)(param_2 + 0x34);
  param_1[0xe] = *(undefined4 *)(param_2 + 0x38);
  param_1[0xf] = *(undefined4 *)(param_2 + 0x3c);
  param_1[0x10] = *(undefined4 *)(param_2 + 0x40);
  param_1[0x11] = *(undefined4 *)(param_2 + 0x44);
  ExceptionList = local_c;
  return param_1;
}

