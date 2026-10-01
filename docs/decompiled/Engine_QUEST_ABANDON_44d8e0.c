
undefined4 __thiscall Engine_QUEST_ABANDON_44d8e0(int param_1,undefined4 param_2,int param_3)

{
  int *piVar1;
  int iVar2;
  int *piVar3;
  undefined4 uVar4;
  
  iVar2 = param_3 * 0xc;
  FUN_0044d470(&param_3,&param_2);
  if (param_3 == *(int *)(param_1 + iVar2 + 8)) {
    return 0;
  }
  piVar3 = *(int **)(param_3 + 0x14);
  uVar4 = *(undefined4 *)(param_3 + 0x10);
  if (piVar3 != (int *)0x0) {
    piVar1 = piVar3 + 1;
    LOCK();
    *piVar1 = *piVar1 + 1;
    UNLOCK();
    LOCK();
    iVar2 = *piVar1;
    *piVar1 = iVar2 + -1;
    UNLOCK();
    if (iVar2 + -1 == 0) {
      (**(code **)(*piVar3 + 4))();
      LOCK();
      iVar2 = piVar3[2] + -1;
      piVar3[2] = iVar2;
      UNLOCK();
      if (iVar2 == 0) {
        (**(code **)(*piVar3 + 8))();
      }
    }
  }
  return uVar4;
}

