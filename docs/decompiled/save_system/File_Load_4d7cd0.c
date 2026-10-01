
/* WARNING: Function: __chkstk replaced with injection: alloca_probe */
/* WARNING: Removing unreachable block (ram,0x004d7e63) */
/* WARNING: Removing unreachable block (ram,0x004d7ebc) */
/* WARNING: Removing unreachable block (ram,0x004d7edc) */

void File_Load_4d7cd0(undefined4 param_1,undefined4 param_2,undefined4 param_3,uint *param_4)

{
  char cVar1;
  int iVar2;
  HGLOBAL pvVar3;
  int *piVar4;
  uint uVar5;
  uint uVar6;
  int iVar7;
  int *unaff_EBP;
  int *piVar8;
  undefined1 local_2240 [504];
  int aiStack_2048 [4];
  undefined1 auStack_2038 [12];
  int iStack_202c;
  undefined4 local_10;
  void *local_c;
  undefined1 *puStack_8;
  undefined4 uStack_4;
  
  uStack_4 = 0xffffffff;
  puStack_8 = &LAB_0051858b;
  local_c = ExceptionList;
  local_10 = DAT_0057faa0;
  iVar7 = 0;
  ExceptionList = &local_c;
  FUN_004d7670(param_1,param_2);
  iVar2 = FUN_004d79a0(local_2240);
  if (iVar2 != 0) {
    *param_4 = iVar2 - 8U;
    pvVar3 = GlobalAlloc(0,iVar2 - 8U);
    piVar4 = (int *)GlobalLock(pvVar3);
    if (piVar4 != (int *)0x0) {
      uVar6 = *param_4;
      piVar8 = piVar4;
      for (uVar5 = uVar6 >> 2; uVar5 != 0; uVar5 = uVar5 - 1) {
        *piVar8 = 0;
        piVar8 = piVar8 + 1;
      }
      for (uVar6 = uVar6 & 3; uVar6 != 0; uVar6 = uVar6 - 1) {
        *(undefined1 *)piVar8 = 0;
        piVar8 = (int *)((int)piVar8 + 1);
      }
      FUN_004bf1b0();
      uStack_4 = 0;
      cVar1 = FUN_004bf290(local_2240,1);
      if (cVar1 == '\0') {
        pvVar3 = GlobalHandle(piVar4);
        GlobalUnlock(pvVar3);
        pvVar3 = GlobalHandle(piVar4);
        GlobalFree(pvVar3);
        uStack_4 = 0xffffffff;
        FUN_004bf310();
      }
      else {
        FUN_004bf2e0(auStack_2038,0x2028);
        if (aiStack_2048[2] == 0x484d4752) {
          iVar7 = iStack_202c + 0x2028;
          FUN_004bf2c0(iVar7,0);
          piVar4 = aiStack_2048;
          piVar8 = unaff_EBP;
          for (iVar2 = 0x80a; iVar2 != 0; iVar2 = iVar2 + -1) {
            *piVar8 = *piVar4;
            piVar4 = piVar4 + 1;
            piVar8 = piVar8 + 1;
          }
        }
        else {
          FUN_004bf2d0();
          unaff_EBP = piVar4;
        }
        FUN_004bf2e0(&stack0xffffdda4,4);
        FUN_004bf2e0(&stack0xffffdda0,4);
        FUN_004bf2e0((undefined1 *)((int)unaff_EBP + iVar7),*param_4 - iVar7);
        FUN_004bf2b0();
        uStack_4 = 0xffffffff;
        FUN_004bf310();
      }
    }
  }
  ExceptionList = local_c;
  FUN_005042e3();
  return;
}

