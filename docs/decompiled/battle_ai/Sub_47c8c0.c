
char __thiscall FUN_0047c8c0(int param_1,int param_2,int param_3,char param_4,int *param_5)

{
  uint uVar1;
  int *piVar2;
  char cVar3;
  int iVar4;
  int iVar5;
  uint *puVar6;
  uint uVar7;
  uint *puVar8;
  int iVar9;
  int iVar10;
  undefined8 uVar11;
  longlong lVar12;
  undefined4 uVar13;
  undefined4 uVar14;
  char local_9;
  int local_8;
  
  piVar2 = param_5;
  iVar10 = param_3 + param_2 * 9;
  uVar1 = *(uint *)(param_1 + 4 + iVar10 * 8);
  iVar10 = param_1 + iVar10 * 8;
  local_9 = '\0';
  iVar9 = 1;
  local_8 = 8;
  if (param_4 == '\0') {
    iVar5 = 9;
    iVar4 = param_3;
  }
  else {
    iVar5 = 8;
    iVar4 = param_2;
  }
  if (iVar5 - iVar4 < 9) {
    local_8 = iVar5 - iVar4;
  }
  puVar8 = (uint *)(iVar10 + 0xc);
  puVar6 = (uint *)(iVar10 + 0x4c);
  uVar7 = uVar1;
  while (((((((uVar1 == 8 || (uVar1 == 9)) || (uVar1 == 10)) || ((uVar1 == 0xb || (uVar1 == 0xc))))
           || (uVar1 == 0xd)) || (uVar1 == 0xe)) &&
         (((((uVar7 == 8 || (uVar7 == 9)) ||
            ((uVar7 == 10 || (((uVar7 == 0xb || (uVar7 == 0xc)) || (uVar7 == 0xd)))))) ||
           (uVar7 == 0xe)) && (iVar9 < local_8))))) {
    iVar9 = iVar9 + 1;
    if (param_4 == '\0') {
      uVar7 = *puVar8;
      puVar6 = puVar6 + 0x12;
      puVar8 = puVar8 + 2;
    }
    else {
      uVar7 = *puVar6;
      puVar6 = puVar6 + 0x12;
      puVar8 = puVar8 + 2;
    }
  }
  if (((((uVar1 == 8) || (uVar1 == 9)) || ((uVar1 == 10 || ((uVar1 == 0xb || (uVar1 == 0xc)))))) ||
      ((uVar1 == 0xd || (uVar1 == 0xe)))) &&
     ((((uVar7 != 1 && (uVar7 != 2)) && (uVar7 != 3)) && (uVar7 != 4)))) {
    return '\0';
  }
  param_5[5] = 0;
  param_5[0xc] = 0;
  param_5[0x13] = 0;
  param_5[0x1a] = 0;
  param_5[0x21] = 0;
  param_5[0x28] = 0;
  param_5[0x2f] = 0;
  param_5[0x36] = 0;
  param_5[0x3d] = 0;
  param_5[0x44] = 0;
  param_5[1] = param_3;
  lVar12 = (ulonglong)uVar7 << 0x20;
  *param_5 = param_2;
  *(char *)(param_5 + 2) = param_4;
  if (param_4 == '\0') {
    if (param_3 != 0) {
      lVar12 = FUN_0047aff0(*(undefined4 *)(iVar10 + -4),uVar7);
      if ((char)lVar12 != '\0') goto LAB_0047cc39;
    }
    if (8 < param_3 + 1) goto LAB_0047cc39;
    uVar11 = FUN_0047aff0(*(undefined4 *)(iVar10 + 0xc),(int)((ulonglong)lVar12 >> 0x20));
    if (((char)uVar11 == '\0') || (8 < param_3 + 2)) goto LAB_0047cc39;
    uVar11 = FUN_0047aff0(*(undefined4 *)(iVar10 + 0x14),(int)((ulonglong)uVar11 >> 0x20));
    if ((char)uVar11 == '\0') goto LAB_0047cc39;
    if (param_3 + 3 < 9) {
      uVar11 = FUN_0047aff0(*(undefined4 *)(iVar10 + 0x1c),(int)((ulonglong)uVar11 >> 0x20));
      if ((char)uVar11 != '\0') {
        if (param_3 + 4 < 9) {
          uVar11 = FUN_0047aff0(*(undefined4 *)(iVar10 + 0x24),(int)((ulonglong)uVar11 >> 0x20));
          if ((char)uVar11 != '\0') {
            if (param_3 + 5 < 9) {
              uVar11 = FUN_0047aff0(*(undefined4 *)(iVar10 + 0x2c),(int)((ulonglong)uVar11 >> 0x20))
              ;
              if ((char)uVar11 != '\0') {
                if (param_3 + 6 < 9) {
                  uVar11 = FUN_0047aff0(*(undefined4 *)(iVar10 + 0x34),
                                        (int)((ulonglong)uVar11 >> 0x20));
                  uVar13 = (undefined4)((ulonglong)uVar11 >> 0x20);
                  if ((char)uVar11 != '\0') {
                    if (param_3 + 7 < 9) {
                      uVar14 = *(undefined4 *)(iVar10 + 0x3c);
                      goto LAB_0047cbf5;
                    }
                    goto LAB_0047cc09;
                  }
                }
                goto LAB_0047cc12;
              }
            }
            goto LAB_0047cc1b;
          }
        }
        goto LAB_0047cc24;
      }
    }
    goto LAB_0047cc2d;
  }
  if (param_2 != 0) {
    uVar11 = FUN_0047aff0(*(undefined4 *)(iVar10 + -0x44),uVar7);
    uVar7 = (uint)((ulonglong)uVar11 >> 0x20);
    if ((char)uVar11 != '\0') goto LAB_0047cc39;
  }
  if (7 < param_2 + 1) goto LAB_0047cc39;
  uVar11 = FUN_0047aff0(*(undefined4 *)(iVar10 + 0x4c),uVar7);
  if (((char)uVar11 == '\0') || (7 < param_2 + 2)) goto LAB_0047cc39;
  uVar11 = FUN_0047aff0(*(undefined4 *)(iVar10 + 0x94),(int)((ulonglong)uVar11 >> 0x20));
  if ((char)uVar11 == '\0') goto LAB_0047cc39;
  if (param_2 + 3 < 8) {
    uVar11 = FUN_0047aff0(*(undefined4 *)(iVar10 + 0xdc),(int)((ulonglong)uVar11 >> 0x20));
    if ((char)uVar11 == '\0') goto LAB_0047cc2d;
    if (param_2 + 4 < 8) {
      uVar11 = FUN_0047aff0(*(undefined4 *)(iVar10 + 0x124),(int)((ulonglong)uVar11 >> 0x20));
      if ((char)uVar11 == '\0') goto LAB_0047cc24;
      if (param_2 + 5 < 8) {
        uVar11 = FUN_0047aff0(*(undefined4 *)(iVar10 + 0x16c),(int)((ulonglong)uVar11 >> 0x20));
        if ((char)uVar11 == '\0') goto LAB_0047cc1b;
        if (param_2 + 6 < 8) {
          uVar11 = FUN_0047aff0(*(undefined4 *)(iVar10 + 0x1b4),(int)((ulonglong)uVar11 >> 0x20));
          uVar13 = (undefined4)((ulonglong)uVar11 >> 0x20);
          if ((char)uVar11 == '\0') goto LAB_0047cc12;
          if (param_2 + 7 < 8) {
            uVar14 = *(undefined4 *)(iVar10 + 0x1fc);
LAB_0047cbf5:
            cVar3 = FUN_0047aff0(uVar14,uVar13);
            if (cVar3 == '\0') goto LAB_0047cc09;
            piVar2[3] = 8;
          }
          else {
LAB_0047cc09:
            piVar2[3] = 7;
          }
        }
        else {
LAB_0047cc12:
          piVar2[3] = 6;
        }
      }
      else {
LAB_0047cc1b:
        piVar2[3] = 5;
      }
    }
    else {
LAB_0047cc24:
      piVar2[3] = 4;
    }
  }
  else {
LAB_0047cc2d:
    piVar2[3] = 3;
  }
  local_9 = '\x01';
LAB_0047cc39:
  param_4 = '\0';
  if (local_9 != '\0') {
    iVar9 = 0;
    param_5 = (int *)0x1;
    iVar10 = 1;
    if (0 < piVar2[3]) {
      iVar10 = param_3;
      do {
        iVar4 = (param_2 - param_3) + iVar10;
        iVar5 = param_3;
        if ((char)piVar2[2] == '\0') {
          iVar4 = param_2;
          iVar5 = iVar10;
        }
        FUN_0047b0c0(*(undefined4 *)(param_1 + 4 + (iVar5 + iVar4 * 9) * 8),iVar4,iVar5,piVar2,
                     &param_4,&param_5);
        iVar9 = iVar9 + 1;
        iVar10 = iVar10 + 1;
      } while (iVar9 < piVar2[3]);
      iVar10 = (int)param_5;
      if (param_4 != '\0') {
        uVar14 = 0;
        uVar13 = 0;
        Engine_ADD_GOLD_447c60(0,0);
        FUN_00446a60(uVar13,uVar14);
        FUN_00465fe0(6,0);
        iVar10 = FUN_0050432c();
      }
    }
    piVar2[5] = piVar2[5] * iVar10;
    piVar2[0xc] = piVar2[0xc] * iVar10;
    piVar2[0x13] = piVar2[0x13] * iVar10;
    piVar2[0x1a] = piVar2[0x1a] * iVar10;
    piVar2[0x21] = piVar2[0x21] * iVar10;
    piVar2[0x28] = piVar2[0x28] * iVar10;
    piVar2[0x2f] = piVar2[0x2f] * iVar10;
    piVar2[0x36] = piVar2[0x36] * iVar10;
    piVar2[0x3d] = piVar2[0x3d] * iVar10;
    piVar2[0x44] = piVar2[0x44] * iVar10;
  }
  return local_9;
}

