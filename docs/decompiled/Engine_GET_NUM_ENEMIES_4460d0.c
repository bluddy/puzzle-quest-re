
uint __thiscall Engine_GET_NUM_ENEMIES_4460d0(int param_1,uint param_2,int param_3)

{
  int iVar1;
  int iVar2;
  int iVar3;
  int *piVar4;
  
  iVar2 = param_2;
  if (param_2 == -1) {
    return 0;
  }
  iVar1 = *(int *)(param_3 * 0xa8 + *(int *)(param_1 + 8) + 0xc);
  param_2 = (uint)(param_2 == 0);
  param_3 = 0;
  piVar4 = (int *)(*(int *)(param_1 + 8) + 0xc);
LAB_00446111:
  if (*(int *)(param_1 + 8) == 0) {
    iVar3 = 0;
  }
  else {
    iVar3 = (*(int *)(param_1 + 0xc) - *(int *)(param_1 + 8)) / 0xa8;
  }
  if (iVar3 <= param_3) {
    return param_2;
  }
  if ((*(char *)((int)piVar4 + 6) != '\0') || (iVar2 == 4)) {
    if (iVar2 == 3) {
      if (*piVar4 != iVar1) goto LAB_004461a1;
      param_2 = param_2 + 1;
      param_3 = param_3 + 1;
      piVar4 = piVar4 + 0x2a;
      goto LAB_00446111;
    }
    if (iVar2 != 2) {
      if ((((iVar2 == 1) || (iVar2 == 4)) && (*piVar4 != iVar1)) && (param_2 == 0)) {
        return 1;
      }
      goto LAB_004461a1;
    }
    if (*piVar4 != iVar1) {
      param_2 = param_2 + 1;
      param_3 = param_3 + 1;
      piVar4 = piVar4 + 0x2a;
      goto LAB_00446111;
    }
  }
LAB_004461a1:
  param_3 = param_3 + 1;
  piVar4 = piVar4 + 0x2a;
  goto LAB_00446111;
}

