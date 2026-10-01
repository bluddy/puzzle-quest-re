
void __fastcall Engine_TUTORIAL_GAME_PLAY_47bd80(int param_1)

{
  bool bVar1;
  char cVar2;
  undefined4 uVar3;
  undefined4 *puVar4;
  undefined4 extraout_EDX;
  undefined4 extraout_EDX_00;
  int iVar5;
  undefined4 *puVar6;
  int iVar7;
  int local_8;
  int local_4;
  
  FUN_0047a8b0();
  puVar4 = (undefined4 *)(param_1 + 0x24c);
  iVar5 = 8;
  do {
    iVar7 = 8;
    puVar6 = puVar4;
    do {
      uVar3 = FUN_0047bb00();
      *puVar6 = uVar3;
      puVar6 = puVar6 + 8;
      iVar7 = iVar7 + -1;
    } while (iVar7 != 0);
    puVar4 = puVar4 + 1;
    iVar5 = iVar5 + -1;
  } while (iVar5 != 0);
LAB_0047bdc0:
  do {
    bVar1 = false;
    puVar4 = (undefined4 *)(param_1 + 0x24c);
    local_8 = 0;
    do {
      if (bVar1) break;
      iVar5 = 0;
      puVar6 = puVar4;
      do {
        if (bVar1) break;
        cVar2 = FUN_0047aff0(*puVar6,puVar6[8]);
        if ((cVar2 != '\0') && (cVar2 = FUN_0047aff0(extraout_EDX,puVar6[0x10]), cVar2 != '\0')) {
          uVar3 = FUN_0047bb00();
          *puVar6 = uVar3;
          bVar1 = true;
        }
        iVar5 = iVar5 + 1;
        puVar6 = puVar6 + 8;
      } while (iVar5 < 6);
      local_8 = local_8 + 1;
      puVar4 = puVar4 + 1;
    } while (local_8 < 8);
    puVar4 = (undefined4 *)(param_1 + 0x24c);
    local_4 = 0;
    do {
      if (bVar1) goto LAB_0047bdc0;
      iVar5 = 0;
      puVar6 = puVar4;
      do {
        if (bVar1) break;
        cVar2 = FUN_0047aff0(*puVar6,puVar6[1]);
        if ((cVar2 != '\0') && (cVar2 = FUN_0047aff0(extraout_EDX_00,puVar6[2]), cVar2 != '\0')) {
          uVar3 = FUN_0047bb00();
          *puVar6 = uVar3;
          bVar1 = true;
        }
        iVar5 = iVar5 + 1;
        puVar6 = puVar6 + 8;
      } while (iVar5 < 8);
      local_4 = local_4 + 1;
      puVar4 = puVar4 + 1;
    } while (local_4 < 6);
    if (!bVar1) {
      return;
    }
  } while( true );
}

