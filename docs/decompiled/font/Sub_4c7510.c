
undefined4 * __fastcall FUN_004c7510(undefined4 *param_1)

{
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00517e0b;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  *param_1 = &PTR_FUN_0052bc10;
  FUN_004bdb30();
  local_4 = 0;
  FUN_004bdb30();
  *(undefined1 *)(param_1 + 0x10) = 0xff;
  *(undefined1 *)((int)param_1 + 0x41) = 0xff;
  *(undefined1 *)((int)param_1 + 0x42) = 0xff;
  *(undefined1 *)((int)param_1 + 0x43) = 0xff;
  param_1[7] = 0;
  param_1[0xf] = 0;
  param_1[8] = 0;
  param_1[9] = 0;
  param_1[10] = 0;
  param_1[0xb] = 0;
  param_1[0xc] = 0;
  param_1[0xd] = 0;
  param_1[0xe] = 0;
  param_1[0x10] = 0xffffffff;
  *(undefined2 *)(param_1 + 0x11) = 0x2a;
  ExceptionList = local_c;
  return param_1;
}

