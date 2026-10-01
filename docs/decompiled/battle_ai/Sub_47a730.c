
undefined4 * __fastcall FUN_0047a730(undefined4 *param_1)

{
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_0051522c;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  *param_1 = &PTR_FUN_0052322c;
  FUN_004bdb30();
  local_4 = 0;
  FUN_004bd170();
  local_4 = CONCAT31(local_4._1_3_,1);
  FUN_004bd170();
  param_1[0x91] = 0;
  param_1[0xf2] = 0;
  *(undefined1 *)(param_1 + 0xda) = 0;
  param_1[0xe1] = 0;
  ExceptionList = local_c;
  return param_1;
}

