
undefined1 FUN_00464870(void)

{
  int iVar1;
  int *piVar2;
  undefined1 uVar3;
  undefined1 uVar4;
  int iVar5;
  
  iVar1 = Engine_GET_GAME_ID_4481d0();
  if (*(int *)(iVar1 + 0x20) != 5) {
    iVar1 = Engine_GET_GAME_ID_4481d0();
    if (*(int *)(iVar1 + 0x20) != 6) {
      iVar1 = Engine_GET_GAME_ID_4481d0();
      if (*(int *)(iVar1 + 0x20) != 2) {
        uVar3 = 0;
        iVar5 = 0;
        Engine_ADD_GOLD_447c60();
        iVar1 = FUN_00445db0();
        uVar4 = 0;
        if (0 < iVar1) {
          do {
            iVar1 = iVar5;
            Engine_ADD_GOLD_447c60(iVar5);
            piVar2 = (int *)Engine_ADD_GOLD_446200(iVar1);
            uVar3 = uVar4;
            if ((*(char *)((int)piVar2 + 0x12) != '\0') && (*(int *)(*piVar2 + 0x70) < 1)) {
              *(undefined1 *)((int)piVar2 + 0x12) = 0;
              uVar3 = 1;
            }
            iVar5 = iVar5 + 1;
            Engine_ADD_GOLD_447c60();
            iVar1 = FUN_00445db0();
            uVar4 = uVar3;
          } while (iVar5 < iVar1);
        }
        return uVar3;
      }
    }
  }
  return 0;
}

