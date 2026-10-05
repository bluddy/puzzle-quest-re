
void __fastcall FUN_004c91a0(int param_1)

{
  undefined1 uVar1;
  undefined1 uVar2;
  undefined1 uVar3;
  undefined1 uVar4;
  int iVar5;
  int iVar6;
  int *piVar7;
  int iVar8;
  char cVar9;
  int iVar10;
  undefined1 uStack_38;
  undefined1 uStack_37;
  undefined1 uStack_36;
  undefined1 uStack_35;
  int local_34;
  int local_30;
  int local_2c;
  int local_28;
  undefined4 local_24;
  undefined4 uStack_20;
  int *piStack_1c;
  undefined1 auStack_18 [12];
  void *local_c;
  undefined1 *puStack_8;
  int iStack_4;
  
  iStack_4 = 0xffffffff;
  puStack_8 = &LAB_00517fc0;
  local_c = ExceptionList;
  if (*(short *)(param_1 + 0x1c) != 0) {
    ExceptionList = &local_c;
    local_34 = param_1;
    cVar9 = FUN_004b3c90();
    if (cVar9 != '\0') {
      FUN_004b3c80();
    }
    local_2c = 0;
    if (0 < *(short *)(param_1 + 0x1c)) {
      do {
        iVar10 = (short)local_2c * 0x314;
        local_30 = (int)*(short *)(iVar10 + 0x220 + param_1);
        iVar10 = iVar10 + param_1;
        FUN_004c88f0(&local_28,&local_30);
        iVar8 = local_28;
        if ((local_28 != *(int *)(param_1 + 4)) && (local_28 != -0x10)) {
          local_24 = *(undefined4 *)(iVar10 + 0x224);
          uVar1 = *(undefined1 *)(iVar10 + 0x22d);
          uVar2 = *(undefined1 *)(iVar10 + 0x22c);
          iVar5 = *(int *)(iVar10 + 0x228);
          iVar6 = *(int *)(local_28 + 0x34);
          uVar3 = *(undefined1 *)(iVar10 + 0x22e);
          uVar4 = *(undefined1 *)(iVar10 + 0x22f);
          if (*(char *)(iVar10 + 0x230) == '\0') {
            local_30 = 0;
          }
          else {
            local_30 = iVar10 + 0x231;
          }
          wcslen((wchar_t *)(iVar10 + 0x20));
          piVar7 = *(int **)(*(int *)(local_34 + 0x10) + 4 + *(int *)(iVar8 + 0x2c) * 8);
          uStack_20 = *(undefined4 *)(*(int *)(local_34 + 0x10) + *(int *)(iVar8 + 0x2c) * 8);
          if (piVar7 != (int *)0x0) {
            LOCK();
            piVar7[1] = piVar7[1] + 1;
            UNLOCK();
          }
          iStack_4 = 0;
          piStack_1c = piVar7;
          Engine_ACTIVATE_COMPANION_4be530((wchar_t *)(iVar10 + 0x20),0xffffffff);
          iStack_4._0_1_ = 1;
          uStack_38 = uVar1;
          uStack_37 = uVar3;
          uStack_36 = uVar4;
          uStack_35 = uVar2;
          FUN_004c7720(local_24,iVar5 + iVar6,auStack_18,&uStack_38,local_30);
          iStack_4 = (uint)iStack_4._1_3_ << 8;
          Engine_ACTIVATE_COMPANION_4bdf40();
          iStack_4 = 0xffffffff;
          param_1 = local_34;
          if (piVar7 != (int *)0x0) {
            LOCK();
            iVar10 = piVar7[1] + -1;
            piVar7[1] = iVar10;
            UNLOCK();
            if (iVar10 == 0) {
              (**(code **)(*piVar7 + 4))();
              LOCK();
              iVar10 = piVar7[2] + -1;
              piVar7[2] = iVar10;
              UNLOCK();
              param_1 = local_34;
              if (iVar10 == 0) {
                (**(code **)(*piVar7 + 8))();
                param_1 = local_34;
              }
            }
          }
        }
        local_2c = local_2c + 1;
      } while ((short)local_2c < *(short *)(param_1 + 0x1c));
    }
    *(undefined2 *)(param_1 + 0x1c) = 0;
    if (cVar9 != '\0') {
      FUN_004b3c70();
    }
  }
  ExceptionList = local_c;
  return;
}

