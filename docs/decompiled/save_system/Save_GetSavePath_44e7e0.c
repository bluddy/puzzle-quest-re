
void __thiscall Save_GetSavePath_44e7e0(int param_1,undefined4 param_2,int param_3)

{
  int iVar1;
  int iVar2;
  int *piVar3;
  undefined4 uVar4;
  undefined4 *puVar5;
  undefined1 local_18 [12];
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  iVar2 = param_3;
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00512d68;
  local_c = ExceptionList;
  iVar1 = *(int *)(param_1 + 8 + param_3 * 0xc);
  ExceptionList = &local_c;
  piVar3 = (int *)FUN_0044d470(&param_3,&param_2);
  if (*piVar3 != iVar1) {
    FUN_004bdb30();
    local_4 = 0;
    FUN_0044e390(&param_2);
    FUN_00467e00(local_18);
    uVar4 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0(L"pqhero",iVar2);
    FUN_004d78d0(L"Saves",uVar4);
    puVar5 = (undefined4 *)FUN_0044d470(&param_3,&param_2);
    FUN_0044dc00(&param_2,*puVar5);
    local_4 = 0xffffffff;
    Engine_ACTIVATE_COMPANION_4bdf40();
  }
  ExceptionList = local_c;
  return;
}

