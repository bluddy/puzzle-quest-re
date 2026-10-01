
void FUN_00475120(undefined4 param_1)

{
  undefined4 uVar1;
  int iVar2;
  int iVar3;
  undefined4 uVar4;
  int *piVar5;
  int *local_b4;
  void *pvStack_1c;
  void *pvStack_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00514da6;
  pvStack_c = ExceptionList;
  ExceptionList = &pvStack_c;
  uVar1 = param_1;
  Engine_ADD_GOLD_447c60(param_1);
  uVar1 = Engine_ADD_GOLD_446200(uVar1);
  Engine_ADD_GOLD_404570(uVar1);
  piVar5 = (int *)0x0;
  local_4 = 0;
  (**(code **)(*local_b4 + 0x20))(6,param_1,0,0);
  uVar4 = 2;
  iVar3 = 0;
  uVar1 = param_1;
  Engine_ADD_GOLD_447c60(2,param_1);
  iVar2 = Engine_GET_NUM_ENEMIES_4460d0(uVar4,uVar1);
  if (0 < iVar2) {
    do {
      uVar4 = 2;
      uVar1 = param_1;
      iVar2 = iVar3;
      Engine_ADD_GOLD_447c60(2,param_1,iVar3);
      uVar4 = Engine_GET_ENEMY_446220(uVar4,uVar1,iVar2);
      uVar1 = uVar4;
      Engine_ADD_GOLD_447c60(uVar4);
      uVar1 = Engine_ADD_GOLD_446200(uVar1);
      Engine_ADD_GOLD_404570(uVar1);
      (**(code **)(*piVar5 + 0x20))(7,uVar4,param_1,0);
      Engine_ADD_GOLD_4046a0();
      uVar4 = 2;
      iVar3 = iVar3 + 1;
      uVar1 = param_1;
      Engine_ADD_GOLD_447c60(2,param_1);
      iVar2 = Engine_GET_NUM_ENEMIES_4460d0(uVar4,uVar1);
    } while (iVar3 < iVar2);
  }
  Engine_ADD_GOLD_4046a0();
  ExceptionList = pvStack_1c;
  return;
}

