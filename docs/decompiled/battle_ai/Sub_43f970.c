
int __thiscall FUN_0043f970(int param_1,int param_2)

{
  int iVar1;
  int *piVar2;
  int iVar3;
  int iVar4;
  int iVar5;
  int iVar6;
  undefined4 uVar7;
  undefined4 uVar8;
  
  iVar1 = *(int *)(param_2 + 0xc);
  iVar5 = *(int *)(param_2 + 0x14) * *(int *)(param_1 + 4) + iVar1 * 3 + *(int *)(param_2 + 4) +
          *(int *)(param_2 + 0x110) * *(int *)(param_1 + 0x28) +
          *(int *)(param_2 + 0xf4) * *(int *)(param_1 + 0x24) +
          *(int *)(param_2 + 0xd8) * *(int *)(param_1 + 0x20) +
          *(int *)(param_2 + 0xbc) * *(int *)(param_1 + 0x1c) +
          *(int *)(param_2 + 0xa0) * *(int *)(param_1 + 0x18) +
          *(int *)(param_2 + 0x84) * *(int *)(param_1 + 0x14) +
          *(int *)(param_2 + 0x68) * *(int *)(param_1 + 0x10) +
          *(int *)(param_2 + 0x4c) * *(int *)(param_1 + 0xc) +
          *(int *)(param_2 + 0x30) * *(int *)(param_1 + 8);
  if (3 < iVar1) {
    iVar5 = iVar5 + 0x1e;
  }
  if (4 < iVar1) {
    iVar5 = iVar5 + 0x1e;
  }
  if (*(int *)(param_1 + 0x48) == 0) {
    uVar8 = 0x32;
    uVar7 = 0xffffffce;
LAB_0043fa2b:
    iVar1 = Engine_GET_RANDOM_4bd280(uVar7,uVar8);
    iVar5 = iVar5 + iVar1;
  }
  else if ((*(int *)(param_1 + 0x48) == 1) && (iVar1 = FUN_004bd1f0(1,100,0), iVar1 < 0x28)) {
    uVar8 = 0x14;
    uVar7 = 0xffffffec;
    goto LAB_0043fa2b;
  }
  uVar7 = 0;
  Engine_ADD_GOLD_447c60(0);
  piVar2 = (int *)Engine_ADD_GOLD_446200(uVar7);
  if ((char)piVar2[4] == '\0') {
    iVar1 = -1;
  }
  else {
    iVar1 = (int)*(short *)(*piVar2 + 0x1c1);
  }
  if (1 < *(int *)(param_1 + 0x48)) {
    return iVar5;
  }
  if (iVar1 < 0) {
    return iVar5;
  }
  iVar4 = 0;
  if ((char)piVar2[4] == '\0') {
    iVar6 = -1;
  }
  else {
    iVar6 = (int)*(short *)(*piVar2 + 0x1bf);
  }
  if (iVar1 < 5) {
    iVar1 = 5 - iVar1;
  }
  else {
    iVar3 = (int)(iVar6 + (iVar6 >> 0x1f & 3U)) >> 2;
    if (iVar1 < iVar3) {
      iVar4 = (iVar3 - iVar1) * 0x14 + 0x1e;
      goto LAB_0043fad6;
    }
    if (iVar1 < iVar6 / 2) {
      iVar4 = (iVar6 / 2 - iVar1) * 0xf + 0x14;
      goto LAB_0043fad6;
    }
    iVar6 = (int)(iVar6 * 3 + (iVar6 * 3 >> 0x1f & 3U)) >> 2;
    if (iVar6 <= iVar1) goto LAB_0043fad6;
    iVar1 = (iVar6 - iVar1) + 1;
  }
  iVar4 = iVar1 * 10;
LAB_0043fad6:
  iVar1 = Engine_GET_RANDOM_4bd280(-iVar4,iVar4);
  return iVar5 + iVar1;
}

