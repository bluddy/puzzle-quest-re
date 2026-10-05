
undefined4 __thiscall FUN_004c9090(int param_1,short param_2,int param_3)

{
  int iVar1;
  undefined4 uVar2;
  undefined1 local_18 [12];
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  iVar1 = param_3;
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00517f98;
  local_c = ExceptionList;
  if ((param_3 != 0) && (-1 < param_2)) {
    _param_2 = (int)param_2;
    ExceptionList = &local_c;
    FUN_004c88f0(&param_3,&param_2);
    if ((param_3 != *(int *)(param_1 + 4)) && (param_3 != -0x10)) {
      Engine_ACTIVATE_COMPANION_4be530(iVar1,0xffffffff);
      local_4 = 0;
      uVar2 = FUN_004c7650(local_18);
      local_4 = 0xffffffff;
      Engine_ACTIVATE_COMPANION_4bdf40();
      ExceptionList = local_c;
      return uVar2;
    }
  }
  ExceptionList = local_c;
  return 0;
}

