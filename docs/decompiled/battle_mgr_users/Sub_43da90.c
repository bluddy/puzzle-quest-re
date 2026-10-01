// refs 0x0043f870 @ 0043dc99

int FUN_0043da90(int param_1)

{
  int iVar1;
  undefined4 uVar2;
  int iVar3;
  int iVar4;
  int iVar5;
  int iVar6;
  int iVar7;
  int *local_15c;
  int local_150;
  int local_b4;
  int local_a8;
  char local_a2;
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00511f26;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  iVar7 = param_1;
  Engine_ADD_GOLD_447c60(param_1);
  uVar2 = Engine_ADD_GOLD_446200(iVar7);
  Engine_ADD_GOLD_404570(uVar2);
  local_4 = 0;
  if (local_a2 == '\0') {
    iVar4 = *(int *)(local_b4 + 100);
    iVar7 = *(int *)(local_b4 + 0x70);
    iVar3 = Engine_EXTRA_TURN_4646e0();
    iVar7 = ((*(int *)(iVar3 + 0x34) + 0x14) * 0x19 - iVar4) + iVar7;
    if (0 < iVar7) goto LAB_0043dce3;
  }
  else {
    iVar7 = Engine_EXTRA_TURN_4646e0();
    iVar7 = *(int *)(iVar7 + 0x2c);
    iVar4 = Engine_EXTRA_TURN_4646e0();
    iVar7 = (*(int *)(iVar4 + 0x34) + 10) * 0xfa +
            (*(int *)(local_b4 + 0x70) - *(int *)(local_b4 + 100)) * 4 + iVar7 * -0xf;
    iVar3 = 0;
    Engine_ADD_GOLD_447c60();
    iVar4 = FUN_00445db0();
    if (0 < iVar4) {
      do {
        if (iVar3 != param_1) {
          iVar4 = iVar3;
          Engine_ADD_GOLD_447c60(iVar3);
          uVar2 = Engine_ADD_GOLD_446200(iVar4);
          Engine_ADD_GOLD_404570(uVar2);
          local_4._0_1_ = 1;
          if (local_150 != local_a8) {
            iVar4 = local_15c[0x19];
            iVar1 = *(int *)(local_b4 + 100);
            iVar5 = Engine_GET_GAME_ID_4481d0();
            if (*(int *)(iVar5 + 4) == 4) {
              iVar5 = (local_15c[0x1a] - *(int *)(local_b4 + 0x68)) * 0x19;
            }
            else {
              iVar5 = (local_15c[0x1a] - *(int *)(local_b4 + 0x68)) * 0xfa;
            }
            iVar6 = Engine_GET_GAME_ID_4481d0();
            if (*(int *)(iVar6 + 4) == 4) {
              iVar6 = (**(code **)(*local_15c + 0x24))();
              iVar6 = iVar6 * 10;
            }
            else {
              iVar6 = (**(code **)(*local_15c + 0x24))();
              iVar6 = iVar6 * 100;
            }
            iVar7 = ((local_15c[0x1a] <= *(int *)(local_b4 + 0x68)) - 1 & 0x96) +
                    (iVar4 - iVar1) * 3 + iVar7 + iVar5 + iVar6 +
                    ((*(int *)(local_b4 + 0x68) <= local_15c[0x1a]) - 1 & 0xffffff6a);
            iVar4 = Engine_GET_GAME_ID_4481d0();
            if (*(int *)(iVar4 + 4) == 4) {
              iVar7 = iVar7 + local_15c[0x1a] * 10;
            }
            else {
              iVar7 = iVar7 + local_15c[0x1a] * 100;
            }
          }
          local_4 = (uint)local_4._1_3_ << 8;
          Engine_ADD_GOLD_4046a0();
        }
        iVar3 = iVar3 + 1;
        Engine_ADD_GOLD_447c60();
        iVar4 = FUN_00445db0();
      } while (iVar3 < iVar4);
    }
    iVar4 = Engine_GET_GAME_ID_4481d0();
    if (*(int *)(iVar4 + 4) != 4) {
      iVar4 = CBattleManager_GetSingleton();
      if (*(int *)(iVar4 + 0x48) == 0) {
        iVar7 = iVar7 / 3;
      }
      else if (*(int *)(iVar4 + 0x48) == 1) {
        iVar7 = (iVar7 * 2) / 3;
      }
    }
    if (0 < iVar7) {
      if (50000 < iVar7) {
        iVar7 = 50000;
      }
      goto LAB_0043dce3;
    }
  }
  iVar7 = 1;
LAB_0043dce3:
  Engine_ADD_GOLD_4046a0();
  ExceptionList = local_c;
  return iVar7;
}

