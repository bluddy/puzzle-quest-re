
void __thiscall Save_HeroFile_44ea10(int param_1,int param_2)

{
  int *piVar1;
  int *piVar2;
  int *piVar3;
  char cVar4;
  int iVar5;
  int iVar6;
  undefined4 *puVar7;
  int *piVar8;
  int *piVar9;
  int *piVar10;
  undefined1 local_48 [4];
  undefined1 local_44 [4];
  int local_40;
  int *local_3c;
  int local_38;
  int *local_34;
  undefined1 local_30 [4];
  int local_2c;
  undefined4 local_28;
  int *local_20;
  undefined1 local_18 [12];
  void *local_c;
  undefined1 *puStack_8;
  undefined4 local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00512dfb;
  local_c = ExceptionList;
  if ((-1 < param_2) && (param_2 != 0)) {
    return;
  }
  ExceptionList = &local_c;
  local_2c = FUN_0044d0a0();
  *(undefined1 *)(local_2c + 0x19) = 1;
  *(int *)(local_2c + 4) = local_2c;
  *(int *)local_2c = local_2c;
  *(int *)(local_2c + 8) = local_2c;
  local_28 = 0;
  local_4 = 0;
  FUN_0044e460((undefined1 *)(param_1 + 4));
  local_4._0_1_ = 1;
  FUN_0044df20(*(undefined4 *)(*(int *)(param_1 + 8) + 4));
  *(int *)(*(int *)(param_1 + 8) + 4) = *(int *)(param_1 + 8);
  *(undefined4 *)(param_1 + 0xc) = 0;
  *(undefined4 *)*(undefined4 *)(param_1 + 8) = *(undefined4 *)(param_1 + 8);
  *(int *)(*(int *)(param_1 + 8) + 8) = *(int *)(param_1 + 8);
  iVar5 = FUN_004d7f40(L"Saves",L"pqhero",0);
  param_2 = 0;
  while (iVar5 != 0) {
    local_40 = 0;
    local_3c = (int *)0x0;
    local_4._0_1_ = 2;
    iVar6 = FUN_004f0184(0x254);
    local_4._0_1_ = 3;
    if (iVar6 == 0) {
      local_38 = 0;
    }
    else {
      local_38 = FUN_0046fbb0();
    }
    local_4._0_1_ = 2;
    FUN_0044cff0(local_38);
    piVar10 = local_34;
    local_40 = local_38;
    piVar8 = (int *)0x0;
    if (local_34 != (int *)0x0) {
      LOCK();
      local_34[1] = local_34[1] + 1;
      UNLOCK();
      local_3c = local_34;
      piVar8 = local_34;
    }
    local_4._0_1_ = 2;
    if (local_34 != (int *)0x0) {
      LOCK();
      iVar6 = local_34[1] + -1;
      local_34[1] = iVar6;
      UNLOCK();
      if (iVar6 == 0) {
        (**(code **)(*local_34 + 4))();
        piVar9 = piVar10 + 2;
        LOCK();
        iVar6 = *piVar9 + -1;
        *piVar9 = iVar6;
        UNLOCK();
        if (iVar6 == 0) {
          (**(code **)(*piVar10 + 8))();
        }
      }
    }
    Engine_ACTIVATE_COMPANION_4be530(iVar5,0xffffffff);
    local_4._0_1_ = 5;
    cVar4 = FUN_0046e6c0(local_18,0,0);
    local_4 = CONCAT31(local_4._1_3_,2);
    Engine_ACTIVATE_COMPANION_4bdf40();
    piVar10 = piVar8;
    if (cVar4 != '\0') {
      piVar9 = (int *)*local_20;
      piVar2 = local_20;
      iVar6 = local_2c;
      if (piVar9 != local_20) {
        do {
          cVar4 = FUN_004bddd0(iVar5);
          piVar2 = local_20;
          iVar6 = local_2c;
          if (cVar4 != '\0') {
            if (piVar9 != local_20) {
              param_2 = piVar9[3];
              local_40 = piVar9[4];
              piVar9 = (int *)piVar9[5];
              piVar1 = local_3c;
              if (piVar9 != piVar8) {
                if (piVar9 != (int *)0x0) {
                  LOCK();
                  piVar9[1] = piVar9[1] + 1;
                  UNLOCK();
                }
                piVar10 = piVar9;
                piVar1 = piVar9;
                if (piVar8 != (int *)0x0) {
                  LOCK();
                  iVar5 = piVar8[1] + -1;
                  piVar8[1] = iVar5;
                  UNLOCK();
                  if (iVar5 == 0) {
                    (**(code **)(*piVar8 + 4))();
                    LOCK();
                    iVar5 = piVar8[2] + -1;
                    piVar8[2] = iVar5;
                    UNLOCK();
                    if (iVar5 == 0) {
                      (**(code **)(*piVar8 + 8))();
                    }
                  }
                }
              }
              goto LAB_0044ec33;
            }
            break;
          }
          if (*(char *)((int)piVar9 + 0x19) == '\0') {
            piVar1 = (int *)piVar9[2];
            if (*(char *)((int)piVar1 + 0x19) == '\0') {
              cVar4 = *(char *)(*piVar1 + 0x19);
              piVar9 = piVar1;
              piVar1 = (int *)*piVar1;
              while (cVar4 == '\0') {
                cVar4 = *(char *)(*piVar1 + 0x19);
                piVar9 = piVar1;
                piVar1 = (int *)*piVar1;
              }
            }
            else {
              cVar4 = *(char *)(piVar9[1] + 0x19);
              piVar3 = (int *)piVar9[1];
              piVar1 = piVar9;
              while ((piVar9 = piVar3, cVar4 == '\0' && (piVar1 == (int *)piVar9[2]))) {
                cVar4 = *(char *)(piVar9[1] + 0x19);
                piVar3 = (int *)piVar9[1];
                piVar1 = piVar9;
              }
            }
          }
        } while (piVar9 != local_20);
      }
      while ((puVar7 = (undefined4 *)FUN_0044d470(local_48,&param_2), (int *)*puVar7 != piVar2 ||
             (piVar8 = (int *)FUN_0044d470(local_44,&param_2), piVar1 = local_3c, *piVar8 != iVar6))
            ) {
        param_2 = param_2 + 1;
      }
LAB_0044ec33:
      local_3c = piVar1;
      piVar8 = (int *)FUN_0044e390(&param_2);
      *piVar8 = local_40;
      if (piVar10 != (int *)piVar8[1]) {
        if (piVar10 != (int *)0x0) {
          LOCK();
          piVar10[1] = piVar10[1] + 1;
          UNLOCK();
        }
        piVar9 = (int *)piVar8[1];
        if (piVar9 != (int *)0x0) {
          LOCK();
          iVar5 = piVar9[1] + -1;
          piVar9[1] = iVar5;
          UNLOCK();
          if (iVar5 == 0) {
            (**(code **)(*piVar9 + 4))();
            LOCK();
            iVar5 = piVar9[2] + -1;
            piVar9[2] = iVar5;
            UNLOCK();
            if (iVar5 == 0) {
              (**(code **)(*piVar9 + 8))();
            }
          }
        }
        piVar8[1] = (int)piVar10;
      }
      puVar7 = (undefined4 *)FUN_0044e390(&param_2);
      (**(code **)(*(int *)*puVar7 + 0x40))();
    }
    iVar5 = FUN_004d7fb0();
    local_4._0_1_ = 1;
    if (piVar10 != (int *)0x0) {
      LOCK();
      iVar6 = piVar10[1] + -1;
      piVar10[1] = iVar6;
      UNLOCK();
      if (iVar6 == 0) {
        (**(code **)(*piVar10 + 4))();
        LOCK();
        iVar6 = piVar10[2] + -1;
        piVar10[2] = iVar6;
        UNLOCK();
        if (iVar6 == 0) {
          (**(code **)(*piVar10 + 8))();
        }
      }
    }
  }
  FUN_004d8010();
  piVar10 = (int *)*local_20;
  if (piVar10 != local_20) {
    do {
      iVar5 = FUN_004cd860(0);
      if (iVar5 == -1) break;
      piVar8 = (int *)piVar10[5];
      param_2 = piVar10[3];
      iVar5 = piVar10[4];
      if (piVar8 != (int *)0x0) {
        LOCK();
        piVar8[1] = piVar8[1] + 1;
        UNLOCK();
      }
      local_4 = CONCAT31(local_4._1_3_,6);
      local_38 = iVar5;
      local_34 = piVar8;
      cVar4 = FUN_00468180();
      if ((cVar4 == '\0') || (cVar4 = FUN_004bdb40(), cVar4 != '\0')) {
        piVar9 = (int *)FUN_0044e390(&param_2);
        *piVar9 = iVar5;
        if (piVar8 != (int *)piVar9[1]) {
          if (piVar8 != (int *)0x0) {
            LOCK();
            piVar8[1] = piVar8[1] + 1;
            UNLOCK();
          }
          piVar2 = (int *)piVar9[1];
          if (piVar2 != (int *)0x0) {
            LOCK();
            iVar5 = piVar2[1] + -1;
            piVar2[1] = iVar5;
            UNLOCK();
            if (iVar5 == 0) {
              (**(code **)(*piVar2 + 4))();
              LOCK();
              iVar5 = piVar2[2] + -1;
              piVar2[2] = iVar5;
              UNLOCK();
              if (iVar5 == 0) {
                (**(code **)(*piVar2 + 8))();
              }
            }
          }
          piVar9[1] = (int)piVar8;
        }
      }
      local_4._0_1_ = 1;
      if (piVar8 != (int *)0x0) {
        LOCK();
        iVar5 = piVar8[1] + -1;
        piVar8[1] = iVar5;
        UNLOCK();
        if (iVar5 == 0) {
          (**(code **)(*piVar8 + 4))();
          LOCK();
          iVar5 = piVar8[2] + -1;
          piVar8[2] = iVar5;
          UNLOCK();
          if (iVar5 == 0) {
            (**(code **)(*piVar8 + 8))();
          }
        }
      }
      if (*(char *)((int)piVar10 + 0x19) == '\0') {
        piVar8 = (int *)piVar10[2];
        if (*(char *)((int)piVar8 + 0x19) == '\0') {
          cVar4 = *(char *)(*piVar8 + 0x19);
          piVar10 = piVar8;
          piVar8 = (int *)*piVar8;
          while (cVar4 == '\0') {
            cVar4 = *(char *)(*piVar8 + 0x19);
            piVar10 = piVar8;
            piVar8 = (int *)*piVar8;
          }
        }
        else {
          cVar4 = *(char *)(piVar10[1] + 0x19);
          piVar9 = (int *)piVar10[1];
          piVar8 = piVar10;
          while ((piVar10 = piVar9, cVar4 == '\0' && (piVar8 == (int *)piVar10[2]))) {
            cVar4 = *(char *)(piVar10[1] + 0x19);
            piVar9 = (int *)piVar10[1];
            piVar8 = piVar10;
          }
        }
      }
    } while (piVar10 != local_20);
  }
  if ((undefined1 *)(param_1 + 4) != local_30) {
    FUN_0044e240(&param_2,**(undefined4 **)(param_1 + 8),*(undefined4 **)(param_1 + 8));
    FUN_0044e300(local_30);
  }
  local_4._0_1_ = 0;
  FUN_0044e240(&param_2,*local_20,local_20);
                    /* WARNING: Subroutine does not return */
  operator_delete(local_20);
}

