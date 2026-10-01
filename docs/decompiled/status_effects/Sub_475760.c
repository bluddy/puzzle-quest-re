
undefined1 __thiscall FUN_00475760(int param_1,undefined4 param_2)

{
  char cVar1;
  int iVar2;
  undefined4 uVar3;
  ushort *puVar4;
  ushort *puVar5;
  ushort *puVar6;
  ushort *puVar7;
  undefined4 *puVar8;
  undefined4 uVar9;
  undefined1 *puVar10;
  undefined1 local_65;
  undefined1 local_58 [12];
  undefined1 local_4c [64];
  void *local_c;
  undefined1 *puStack_8;
  uint local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00514e00;
  local_c = ExceptionList;
  ExceptionList = &local_c;
  FUN_004bf9b0();
  local_4 = 0;
  local_65 = 0;
  cVar1 = FUN_004bffe0(param_2);
  if ((cVar1 != '\0') && (cVar1 = FUN_004bfc90(), cVar1 != '\0')) {
    local_65 = 1;
    iVar2 = FUN_004bfa40(L"StatusEffect");
    if (iVar2 != 0) {
      uVar9 = 0xffffffff;
      uVar3 = FUN_004bfb60(iVar2,&DAT_00521458);
      Engine_ACTIVATE_COMPANION_4be530(uVar3,uVar9);
      local_4 = CONCAT31(local_4._1_3_,1);
      puVar4 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(3);
      puVar5 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(2);
      puVar6 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(1);
      puVar7 = (ushort *)Engine_ACTIVATE_COMPANION_4be7e0(0);
      *(uint *)(param_1 + 4) =
           (((uint)*puVar4 << 8 | (uint)*puVar5) << 8 | (uint)*puVar6) << 8 | (uint)*puVar7;
      puVar8 = (undefined4 *)FUN_004bfa60(iVar2);
      while (puVar8 != (undefined4 *)0x0) {
        iVar2 = wcscmp((wchar_t *)*puVar8,L"Text");
        if (iVar2 == 0) {
          uVar9 = 0xffffffff;
          uVar3 = FUN_004bfb60(puVar8,L"name");
          Engine_ACTIVATE_COMPANION_4be530(uVar3,uVar9);
          puVar10 = local_58;
          local_4._0_1_ = 2;
          Engine_GET_TEXT_4b4500(puVar10);
          Engine_GET_TEXT_4b4050(puVar10);
          uVar3 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
          Engine_TUTORIAL_GAME_RUN_4be780(uVar3);
          local_4._0_1_ = 1;
          Engine_ACTIVATE_COMPANION_4bdf40();
          uVar9 = 0xffffffff;
          uVar3 = FUN_004bfb60(puVar8,&PTR_Rsrc_DATA___GDF_THUMBNAIL_407_130740__00521428);
          Engine_ACTIVATE_COMPANION_4be530(uVar3,uVar9);
          puVar10 = local_4c;
          local_4._0_1_ = 3;
          Engine_GET_TEXT_4b4500(puVar10);
          Engine_GET_TEXT_4b4050(puVar10);
          uVar3 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
          Engine_TUTORIAL_GAME_RUN_4be780(uVar3);
          local_4 = CONCAT31(local_4._1_3_,1);
          Engine_ACTIVATE_COMPANION_4bdf40();
        }
        else {
          iVar2 = wcscmp((wchar_t *)*puVar8,L"Data");
          if (iVar2 == 0) {
            uVar3 = FUN_004bfb90(puVar8,L"duration");
            *(undefined4 *)(param_1 + 0x3c) = uVar3;
            uVar3 = FUN_004bfb90(puVar8,L"stack");
            *(undefined4 *)(param_1 + 0x40) = uVar3;
          }
          else {
            iVar2 = wcscmp((wchar_t *)*puVar8,L"Graphics");
            if (iVar2 == 0) {
              uVar3 = FUN_004bfb90(puVar8,L"icon");
              *(undefined4 *)(param_1 + 0x38) = uVar3;
            }
            else {
              iVar2 = wcscmp((wchar_t *)*puVar8,L"Script");
              if (iVar2 == 0) {
                uVar3 = FUN_004bfb60(puVar8,L"file");
                Engine_TUTORIAL_GAME_RUN_4be780(uVar3);
                uVar3 = FUN_004bfb60(puVar8,L"object");
                Engine_TUTORIAL_GAME_RUN_4be780(uVar3);
              }
            }
          }
        }
        puVar8 = (undefined4 *)FUN_004bfa80();
      }
      local_4 = local_4 & 0xffffff00;
      Engine_ACTIVATE_COMPANION_4bdf40();
    }
  }
  local_4 = 0xffffffff;
  FUN_004bff80();
  ExceptionList = local_c;
  return local_65;
}

