
void __fastcall FUN_00464d70(int param_1)

{
  undefined4 *puVar1;
  int iVar2;
  undefined4 uVar3;
  int local_bc [9];
  char local_98;
  
  iVar2 = *(int *)(param_1 + 0x34);
  local_bc[0] = 0;
  local_bc[1] = 16000;
  local_bc[2] = 12000;
  local_bc[3] = 8000;
  local_bc[4] = 4000;
  if (iVar2 < 0) {
    iVar2 = iVar2 * -1000;
  }
  else {
    iVar2 = local_bc[iVar2];
  }
  *(int *)(param_1 + 0x38) = DAT_0057f484 + iVar2;
  *(int *)(param_1 + 0x3c) = iVar2;
  puVar1 = (undefined4 *)(param_1 + 4 + *(int *)(param_1 + 0x28) * 4);
  *(undefined1 *)(param_1 + 0x40) = 1;
  *(undefined1 *)(param_1 + 0x41) = 0;
  *(int *)(param_1 + 0x44) = *(int *)(param_1 + 0x2c);
  *(undefined4 *)(param_1 + 0x48) = *puVar1;
  if (*(int *)(param_1 + 0x2c) < 1) {
    *(undefined4 *)(param_1 + 0x44) = 1;
  }
  uVar3 = *puVar1;
  Engine_ADD_GOLD_447c60(uVar3);
  uVar3 = Engine_ADD_GOLD_446200(uVar3);
  Engine_ADD_GOLD_404570(uVar3);
  if (local_98 == '\0') {
    *(undefined1 *)(param_1 + 0x40) = 0;
  }
  Engine_ADD_GOLD_4046a0();
  return;
}

