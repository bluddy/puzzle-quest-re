
void File_Save_4d76e0(undefined4 param_1,undefined4 param_2,undefined4 param_3,undefined4 param_4,
                     int param_5,int param_6,undefined4 param_7,undefined4 param_8,int param_9)

{
  char cVar1;
  undefined1 local_218 [516];
  void *pvStack_14;
  undefined4 local_10;
  void *pvStack_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_0051854b;
  pvStack_c = ExceptionList;
  local_10 = DAT_0057faa0;
  ExceptionList = &pvStack_c;
  FUN_004d7670(param_1,param_2,param_3);
  param_6 = param_6 - param_9;
  param_5 = param_5 + param_9;
  _CRCBlock_8(param_5,param_6);
  _EncryptXORBlock_12(param_5,param_6,param_7);
  _EncryptSubstitutionBlock_12(param_5,param_6,param_7);
  _EncryptTranspositionBlock_12(param_5,param_6,param_7);
  _CRCBlock_8(param_5,param_6);
  FUN_004bf1b0();
  uStack_4 = 0;
  cVar1 = FUN_004bf290(local_218,2);
  if (cVar1 == '\0') {
    pvStack_c = (void *)0xffffffff;
    FUN_004bf310();
  }
  else {
    if (param_9 != 0) {
      FUN_004bf2f0(param_3,param_9);
    }
    FUN_004bf2f0(&stack0xfffffdd8,4);
    FUN_004bf2f0(&stack0xfffffdd4,4);
    FUN_004bf2f0(param_5,param_6);
    FUN_004bf2b0();
    pvStack_c = (void *)0xffffffff;
    FUN_004bf310();
  }
  ExceptionList = pvStack_14;
  FUN_005042e3();
  return;
}

