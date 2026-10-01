// refs 0x0043f870 @ 0043e540

void FUN_0043e400(int param_1,int *param_2,int *param_3)

{
  undefined4 uVar1;
  int iVar2;
  int local_160;
  int *local_15c;
  int local_150;
  int local_b4;
  int local_a8;
  char local_a2;
  void *pvStack_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00511f26;
  pvStack_c = ExceptionList;
  ExceptionList = &pvStack_c;
  *param_2 = 0;
  *param_3 = 0;
  iVar2 = param_1;
  Engine_ADD_GOLD_447c60(param_1);
  uVar1 = Engine_ADD_GOLD_446200(iVar2);
  Engine_ADD_GOLD_404570(uVar1);
  local_4 = 0;
  if (local_a2 != '\0') {
    local_160 = 0;
    Engine_ADD_GOLD_447c60();
    iVar2 = FUN_00445db0();
    if (0 < iVar2) {
      do {
        if (local_160 != param_1) {
          iVar2 = local_160;
          Engine_ADD_GOLD_447c60(local_160);
          uVar1 = Engine_ADD_GOLD_446200(iVar2);
          Engine_ADD_GOLD_404570(uVar1);
          local_4._0_1_ = 1;
          if (local_150 != local_a8) {
            iVar2 = (**(code **)(*local_15c + 0x38))();
            *param_2 = iVar2;
            iVar2 = (**(code **)(*local_15c + 0x34))();
            *param_3 = iVar2;
            FUN_0043d4c0(*(undefined4 *)(local_b4 + 0x68),local_15c[0x1a],param_2,param_3);
            iVar2 = Engine_EXTRA_TURN_4646e0();
            iVar2 = *(int *)(iVar2 + 0x34) * 5;
            *param_2 = (*param_2 * iVar2) / 100 + *param_2;
            *param_3 = (*param_3 * iVar2) / 100 + *param_3;
            iVar2 = Engine_GET_GAME_ID_4481d0();
            if (*(int *)(iVar2 + 4) != 4) {
              iVar2 = CBattleManager_GetSingleton();
              if (*(int *)(iVar2 + 0x48) == 0) {
                iVar2 = *param_2 * 3;
LAB_0043e55d:
                *param_2 = (int)(iVar2 + (iVar2 >> 0x1f & 3U)) >> 2;
              }
              else if (*(int *)(iVar2 + 0x48) == 2) {
                iVar2 = *param_2 * 5;
                goto LAB_0043e55d;
              }
              iVar2 = CBattleManager_GetSingleton();
              if (*(int *)(iVar2 + 0x48) == 0) {
                iVar2 = *param_3 * 3;
              }
              else {
                if (*(int *)(iVar2 + 0x48) != 2) goto LAB_0043e590;
                iVar2 = *param_3 * 5;
              }
              *param_3 = (int)(iVar2 + (iVar2 >> 0x1f & 3U)) >> 2;
            }
          }
LAB_0043e590:
          local_4 = (uint)local_4._1_3_ << 8;
          Engine_ADD_GOLD_4046a0();
        }
        local_160 = local_160 + 1;
        Engine_ADD_GOLD_447c60();
        iVar2 = FUN_00445db0();
      } while (local_160 < iVar2);
    }
  }
  Engine_ADD_GOLD_4046a0();
  ExceptionList = pvStack_c;
  return;
}

