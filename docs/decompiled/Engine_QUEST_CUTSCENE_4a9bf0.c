
void __thiscall Engine_QUEST_CUTSCENE_4a9bf0(int param_1,undefined4 param_2)

{
  char cVar1;
  undefined2 uVar2;
  undefined4 uVar3;
  wchar_t *pwVar4;
  short *psVar5;
  wchar_t *pwVar6;
  int iVar7;
  int iVar8;
  undefined4 *puVar9;
  undefined1 *puVar10;
  undefined1 local_dc [64];
  undefined1 local_9c [12];
  wchar_t local_90 [64];
  undefined4 local_10;
  void *pvStack_c;
  undefined1 *puStack_8;
  int local_4;
  
  local_4 = 0xffffffff;
  puStack_8 = &LAB_00516c37;
  pvStack_c = ExceptionList;
  local_10 = DAT_0057faa0;
  puVar9 = (undefined4 *)(param_1 + 0x49c);
  ExceptionList = &pvStack_c;
  for (iVar8 = 0xc18; iVar8 != 0; iVar8 = iVar8 + -1) {
    *puVar9 = 0;
    puVar9 = puVar9 + 1;
  }
  FUN_004bf9b0();
  puVar10 = local_9c;
  local_4 = 0;
  Engine_GET_TEXT_4b4500(puVar10);
  FUN_004b3d60(puVar10);
  local_4._0_1_ = 1;
  Engine_ACTIVATE_COMPANION_4be530(&DAT_0052146c,0xffffffff);
  local_4._0_1_ = 2;
  FUN_004be790(local_dc);
  local_4._0_1_ = 1;
  Engine_ACTIVATE_COMPANION_4bdf40();
  Engine_ACTIVATE_COMPANION_4be530(param_2,0xffffffff);
  local_4._0_1_ = 3;
  FUN_004be790(local_dc);
  local_4._0_1_ = 1;
  Engine_ACTIVATE_COMPANION_4bdf40();
  uVar3 = Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
  cVar1 = FUN_004bffe0(uVar3);
  if (((cVar1 == '\0') || (cVar1 = FUN_004bfc90(), cVar1 == '\0')) ||
     (iVar8 = FUN_004bfa40(L"CutScene"), iVar8 == 0)) goto LAB_004aa07d;
  pwVar4 = (wchar_t *)FUN_004bfb60(iVar8,L"file");
  wcscpy((wchar_t *)(param_1 + 4),pwVar4);
  pwVar4 = (wchar_t *)FUN_004bfb60(iVar8,L"font");
  wcscpy(local_90,pwVar4);
  cVar1 = FUN_004bfb40(iVar8,L"voice");
  if ((cVar1 == '\0') || (psVar5 = (short *)FUN_004bfb60(iVar8,L"voice"), *psVar5 == 0)) {
LAB_004a9dea:
    *(undefined2 *)(param_1 + 0x20c) = 0;
  }
  else {
    puVar10 = local_dc;
    Engine_GET_TEXT_4b4500(puVar10);
    FUN_004b3d60(puVar10);
    local_4._0_1_ = 4;
    pwVar4 = (wchar_t *)(param_1 + 0x20c);
    pwVar6 = (wchar_t *)Engine_ADD_ANIMEFFECT_TO_GRID_4bddc0();
    wcscpy(pwVar4,pwVar6);
    local_4._0_1_ = 1;
    Engine_ACTIVATE_COMPANION_4bdf40();
    wcscat(pwVar4,L"\\");
    pwVar6 = (wchar_t *)FUN_004bfb60(iVar8,L"voice");
    wcscat(pwVar4,pwVar6);
    cVar1 = FUN_004d7930(pwVar4);
    if (cVar1 == '\0') goto LAB_004a9dea;
  }
  cVar1 = FUN_004bfb40(iVar8,L"sound");
  if ((cVar1 == '\0') || (psVar5 = (short *)FUN_004bfb60(iVar8,L"voice"), *psVar5 == 0)) {
    *(undefined2 *)(param_1 + 0x414) = 0;
  }
  else {
    pwVar4 = (wchar_t *)FUN_004bfb60(iVar8,L"sound");
    wcscpy((wchar_t *)(param_1 + 0x414),pwVar4);
  }
  uVar2 = FUN_004bfb90(iVar8,L"textx");
  *(undefined2 *)(param_1 + 0x3512) = uVar2;
  uVar2 = FUN_004bfb90(iVar8,L"texty");
  *(undefined2 *)(param_1 + 0x3514) = uVar2;
  uVar2 = FUN_004bfb90(iVar8,&DAT_0051ceb8);
  *(undefined2 *)(param_1 + 0x350a) = uVar2;
  uVar2 = FUN_004bfb90(iVar8,&DAT_005214f0);
  *(undefined2 *)(param_1 + 0x350c) = uVar2;
  uVar2 = FUN_004bfb90(iVar8,L"width");
  *(undefined2 *)(param_1 + 0x350e) = uVar2;
  uVar2 = FUN_004bfb90(iVar8,L"height");
  *(undefined2 *)(param_1 + 0x3510) = uVar2;
  uVar3 = FUN_004bfb90(iVar8,L"duration");
  *(undefined4 *)(param_1 + 0x3500) = uVar3;
  uVar3 = FUN_004bfb90(iVar8,L"voicedelay");
  *(undefined4 *)(param_1 + 0x3504) = uVar3;
  if (0x400 < DAT_0059a4c8) {
    *(short *)(param_1 + 0x3512) =
         *(short *)(param_1 + 0x3512) + (short)((DAT_0059a4c8 + -0x400) / 2);
  }
  if (0x300 < DAT_0059a4ca) {
    *(short *)(param_1 + 0x3514) =
         *(short *)(param_1 + 0x3514) + (short)((DAT_0059a4ca + -0x300) / 2);
  }
  *(undefined2 *)(param_1 + 0x3516) = 800;
  *(undefined2 *)(param_1 + 0x3518) = 100;
  *(undefined2 *)(param_1 + 0x498) = 0;
  if ((local_90[0] != L'\0') && (iVar7 = FUN_004b2ba0(local_90), iVar7 != 0)) {
    *(undefined4 *)(param_1 + 0x351c) = *(undefined4 *)(iVar7 + 0x18);
  }
  *(undefined4 *)(param_1 + 0x3528) = 0;
  if (*(short *)(param_1 + 0x20c) != 0) {
    iVar7 = FUN_004b2ba0(param_1 + 0x414);
    *(int *)(param_1 + 0x3528) = iVar7;
    if (iVar7 != 0) {
      FUN_004b17d0((short *)(param_1 + 0x20c),0);
    }
  }
  iVar8 = FUN_004bfaa0(iVar8,L"Text");
  while (iVar8 != 0) {
    uVar3 = FUN_004bfb90(iVar8,L"time");
    *(undefined4 *)(*(short *)(param_1 + 0x498) * 0x408 + 0x89c + param_1) = uVar3;
    if (0 < *(short *)(param_1 + 0x498)) {
      iVar7 = *(short *)(param_1 + 0x498) * 0x408;
      *(int *)(iVar7 + param_1 + 0x498) =
           *(int *)(iVar7 + 0x89c + param_1) - *(int *)(iVar7 + 0x494 + param_1);
    }
    pwVar4 = (wchar_t *)FUN_004bfc00(iVar8);
    wcscpy((wchar_t *)(*(short *)(param_1 + 0x498) * 0x408 + 0x49c + param_1),pwVar4);
    *(short *)(param_1 + 0x498) = *(short *)(param_1 + 0x498) + 1;
    iVar8 = FUN_004bfb00();
  }
  if (0 < *(short *)(param_1 + 0x498)) {
    iVar8 = *(short *)(param_1 + 0x498) * 0x408 + param_1;
    *(int *)(iVar8 + 0x498) = *(int *)(param_1 + 0x3500) - *(int *)(iVar8 + 0x494);
  }
LAB_004aa07d:
  local_4 = (uint)local_4._1_3_ << 8;
  Engine_ACTIVATE_COMPANION_4bdf40();
  local_4 = 0xffffffff;
  FUN_004bff80();
  ExceptionList = pvStack_c;
  FUN_005042e3();
  return;
}

