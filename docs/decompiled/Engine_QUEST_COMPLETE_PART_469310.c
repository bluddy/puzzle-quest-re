
void __fastcall Engine_QUEST_COMPLETE_PART_469310(int param_1)

{
  undefined2 uVar1;
  undefined2 *puVar2;
  int iVar3;
  undefined4 uVar4;
  
  iVar3 = 0;
  if (0 < *(int *)(param_1 + 0x1cc)) {
    puVar2 = (undefined2 *)(param_1 + 0x1d4);
    do {
      uVar4 = *(undefined4 *)(puVar2 + -2);
      FUN_0045adc0(uVar4);
      FUN_00403540(uVar4);
      uVar1 = FUN_004730f0(0xc,0,0,0);
      *puVar2 = uVar1;
      iVar3 = iVar3 + 1;
      puVar2 = puVar2 + 3;
    } while (iVar3 < *(int *)(param_1 + 0x1cc));
  }
  *(undefined1 *)(param_1 + 0xbc) = 1;
  return;
}

