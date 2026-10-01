
undefined4 __fastcall FUN_004648f0(int param_1)

{
  char extraout_AL;
  char cVar1;
  int iVar2;
  int iVar3;
  int *piVar4;
  undefined4 uVar5;
  int iVar6;
  int iVar7;
  int iVar8;
  undefined1 *puVar9;
  undefined1 local_2a;
  int local_28;
  undefined1 local_24 [12];
  undefined1 local_18 [12];
  void *local_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_005142f0;
  local_c = ExceptionList;
  iVar7 = -1;
  iVar6 = -1;
  local_2a = 0;
  local_28 = -1;
  if (DAT_005860ce == '\0') {
    ExceptionList = &local_c;
    iVar2 = Engine_GET_GAME_ID_4481d0();
    if (*(int *)(iVar2 + 0x20) != 2) {
      iVar2 = FUN_004d1e20();
      iVar2 = *(int *)(iVar2 + 0x7c);
      iVar8 = 0;
      Engine_ADD_GOLD_447c60();
      iVar3 = FUN_00445db0();
      if (0 < iVar3) {
        do {
          iVar3 = iVar8;
          Engine_ADD_GOLD_447c60(iVar8);
          iVar3 = Engine_ADD_GOLD_446200(iVar3);
          if (((*(char *)(iVar3 + 0x11) != '\0') && (*(char *)(iVar3 + 0x10) != '\0')) &&
             (((iVar2 == 5 && (*(int *)(iVar3 + 8) == 0)) || (iVar7 < 0)))) {
            iVar7 = iVar8;
            local_28 = iVar8;
          }
          if (*(char *)(iVar3 + 0x12) != '\0') {
            if (iVar6 < 0) {
              iVar6 = *(int *)(iVar3 + 0xc);
              if (iVar8 == iVar7) {
                local_2a = 1;
              }
            }
            else if (iVar6 != *(int *)(iVar3 + 0xc)) {
              ExceptionList = local_c;
              return 0;
            }
          }
          iVar8 = iVar8 + 1;
          Engine_ADD_GOLD_447c60();
          iVar3 = FUN_00445db0();
        } while (iVar8 < iVar3);
      }
      FUN_004c6320();
      *(undefined1 *)(param_1 + 0x30) = local_2a;
      *(undefined1 *)(param_1 + 0x31) = 1;
      FUN_0040f560();
      Engine_ADD_GOLD_447c60(iVar7);
      piVar4 = (int *)Engine_ADD_GOLD_446200(iVar7);
      iVar6 = *(int *)(*piVar4 + 0x6c);
      iVar7 = *(int *)(*piVar4 + 0x94);
      Engine_ADD_GOLD_447c60();
      FUN_00445ff0();
      iVar2 = *(int *)(*piVar4 + 0x6c);
      iVar3 = *(int *)(*piVar4 + 0x94);
      iVar8 = Engine_GET_GAME_ID_4481d0();
      if (*(int *)(iVar8 + 4) == 9) {
        Engine_ACTIVATE_COMPANION_4be530(L"[TUTDONE_TEXT]",0xffffffff);
        local_4 = 0;
        Engine_ACTIVATE_COMPANION_4be530(L"[TUTDONE_HEADING]",0xffffffff);
        puVar9 = local_18;
        local_4._0_1_ = 1;
        Engine_GET_TEXT_4b4500(puVar9,&LAB_004646d0);
        Engine_GET_TEXT_4b4050(puVar9);
        uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
        puVar9 = local_24;
        Engine_GET_TEXT_4b4500(puVar9,uVar5);
        Engine_GET_TEXT_4b4050(puVar9);
        uVar5 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
        FUN_00427850(uVar5);
        local_4 = (uint)local_4._1_3_ << 8;
        Engine_ACTIVATE_COMPANION_4bdf40();
        local_4 = 0xffffffff;
        Engine_ACTIVATE_COMPANION_4bdf40();
        Engine_ADD_GOLD_447c60();
        FUN_00446060();
        ExceptionList = local_c;
        return 1;
      }
      FUN_0043d400(local_28,0,iVar2 - iVar6,iVar3 - iVar7);
      ExceptionList = local_c;
      return 1;
    }
    if (*(char *)(param_1 + 0x31) == '\0') {
      Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
      FUN_0047b0a0();
      if (extraout_AL == '\0') {
        Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
        cVar1 = FUN_0047acb0();
        *(bool *)(param_1 + 0x30) = cVar1 != '\0';
        *(undefined1 *)(param_1 + 0x31) = 1;
        FUN_004c6320();
        Engine_ADD_GOLD_447c60();
        FUN_00446060();
        FUN_00404710();
        ExceptionList = local_c;
        return 1;
      }
    }
  }
  ExceptionList = local_c;
  return 0;
}

