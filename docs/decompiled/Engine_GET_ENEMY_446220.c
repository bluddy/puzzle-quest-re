
int __thiscall Engine_GET_ENEMY_446220(int param_1,int param_2,int param_3,int param_4)

{
  int iVar1;
  int iVar2;
  int iVar3;
  int *piVar4;
  int iVar5;
  bool bVar6;
  
  iVar1 = *(int *)(param_3 * 0xa8 + *(int *)(param_1 + 8) + 0xc);
  iVar5 = 0;
  if ((param_2 != 0) || (param_4 != 0)) {
    iVar3 = 0;
    piVar4 = (int *)(*(int *)(param_1 + 8) + 0xc);
    while( true ) {
      if (*(int *)(param_1 + 8) == 0) {
        iVar2 = 0;
      }
      else {
        iVar2 = (*(int *)(param_1 + 0xc) - *(int *)(param_1 + 8)) / 0xa8;
      }
      if (iVar2 <= iVar3) break;
      if ((*(char *)((int)piVar4 + 6) != '\0') || (param_2 == 4)) {
        if (param_2 == 3) {
          if (*piVar4 == iVar1) {
            iVar2 = iVar5 + 1;
            bVar6 = iVar5 == param_4;
            goto LAB_004462d8;
          }
        }
        else if (param_2 == 2) {
          if (*piVar4 != iVar1) {
            iVar2 = iVar5 + 1;
            bVar6 = iVar5 == param_4;
LAB_004462d8:
            iVar5 = iVar2;
            if (bVar6) {
              return iVar3;
            }
          }
        }
        else if ((((param_2 == 1) || (param_2 == 4)) && (*piVar4 != iVar1)) && (iVar5 == 0)) {
          iVar2 = 1;
          bVar6 = param_4 == 0;
          goto LAB_004462d8;
        }
      }
      iVar3 = iVar3 + 1;
      piVar4 = piVar4 + 0x2a;
    }
    param_3 = 0;
  }
  return param_3;
}

