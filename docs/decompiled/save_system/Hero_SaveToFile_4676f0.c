
undefined4 __thiscall
Hero_SaveToFile_4676f0(int param_1,undefined4 param_2,char param_3,undefined4 param_4)

{
  undefined4 uVar1;
  int iVar2;
  HGLOBAL hMem;
  undefined4 *puVar3;
  uint uVar4;
  uint uVar5;
  
  Engine_TUTORIAL_GAME_RUN_4be780(param_2);
  *(char *)(param_1 + 0xd4) = param_3;
  if (param_3 == '\0') {
    *(undefined4 *)(param_1 + 0xe0) = 200000;
    hMem = GlobalAlloc(0,200000);
    puVar3 = (undefined4 *)GlobalLock(hMem);
    uVar5 = *(uint *)(param_1 + 0xe0);
    *(undefined4 **)(param_1 + 0xd8) = puVar3;
    for (uVar4 = uVar5 >> 2; uVar4 != 0; uVar4 = uVar4 - 1) {
      *puVar3 = 0;
      puVar3 = puVar3 + 1;
    }
    for (uVar5 = uVar5 & 3; uVar5 != 0; uVar5 = uVar5 - 1) {
      *(undefined1 *)puVar3 = 0;
      puVar3 = (undefined4 *)((int)puVar3 + 1);
    }
    if (*(int *)(param_1 + 0xd8) != 0) {
      *(undefined4 *)(param_1 + 0xdc) = 0;
      return 1;
    }
  }
  else {
    *(undefined4 *)(param_1 + 0xdc) = 0;
    uVar1 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0
                      (L"pqhero",param_1 + 0xe0,L"jhgsd&*(d9shgsf098aLKJ",param_4);
    iVar2 = FUN_004d7cd0(L"Saves",uVar1);
    *(int *)(param_1 + 0xd8) = iVar2;
    if (iVar2 != 0) {
      *(undefined1 *)(param_1 + 0x1f9) = 1;
      return 1;
    }
  }
  return 0;
}

