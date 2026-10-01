
void __fastcall Engine_QUEST_ENCOUNTER_ADD_4556f0(undefined4 param_1)

{
  int iVar1;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00512fdb;
  local_c = ExceptionList;
  if (DAT_00582970 == 0) {
    ExceptionList = &local_c;
    iVar1 = FUN_004f0184(0xac,param_1);
    local_4 = 0;
    if (iVar1 != 0) {
      DAT_00582970 = FUN_00455460(iVar1);
      ExceptionList = local_c;
      return;
    }
    DAT_00582970 = 0;
  }
  ExceptionList = local_c;
  return;
}

