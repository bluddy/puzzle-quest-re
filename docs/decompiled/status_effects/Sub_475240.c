
undefined4 * __fastcall FUN_00475240(undefined4 *param_1)

{
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00514dd1;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  *param_1 = &PTR_FUN_0051ca64;
  FUN_004bdb30();
  local_4 = 0;
  FUN_004bdb30();
  local_4._0_1_ = 1;
  FUN_004bdb30();
  local_4 = CONCAT31(local_4._1_3_,2);
  FUN_004bdb30();
  ExceptionList = local_c;
  return param_1;
}

