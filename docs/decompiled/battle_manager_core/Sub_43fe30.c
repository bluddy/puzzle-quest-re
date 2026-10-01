
void __fastcall FUN_0043fe30(int param_1)

{
  short sVar1;
  char cVar2;
  int iVar3;
  int *piVar4;
  int iVar5;
  int iVar6;
  uint uVar7;
  int iVar8;
  undefined4 uVar9;
  int iVar10;
  int iStack_c;
  
  iVar3 = Engine_EXTRA_TURN_4646e0();
  iVar8 = *(int *)(iVar3 + 4 + *(int *)(iVar3 + 0x28) * 4);
  iVar3 = iVar8;
  Engine_ADD_GOLD_447c60(iVar8);
  piVar4 = (int *)Engine_ADD_GOLD_446200(iVar3);
  iVar5 = (**(code **)(*(int *)*piVar4 + 0x28))(*(undefined4 *)(param_1 + 0x44));
  iVar3 = Engine_HANDLE_SPELL_COST_4622c0();
  iVar3 = *(int *)(iVar3 + 8) + iVar5 * 0x48;
  iVar6 = iVar8;
  Engine_ADD_GOLD_447c60(iVar8,iVar5);
  cVar2 = FUN_004466e0(iVar6,iVar5);
  if (cVar2 == '\0') {
    FUN_00474c30();
  }
  else {
    uVar9 = 7;
    if (cVar2 == '\x02') {
      uVar9 = 8;
    }
    else if (cVar2 == '\x03') {
      uVar9 = 9;
    }
    else if (cVar2 == '\x04') {
      uVar9 = 10;
    }
    FUN_004153d0(uVar9,(-(uint)(iVar8 != 1) & 0x188) + 0x13c,0x17c,
                 (-(uint)(iVar8 != 1) & 0x160) + 0x150,0x17c,2000);
    Engine_PLAY_SOUND_4b38a0(L"snd_resistspell");
  }
  iVar6 = Engine_HANDLE_SPELL_COST_4622c0();
  cVar2 = *(char *)(iVar6 + 0x14);
  *(undefined1 *)(iVar6 + 0x14) = 0;
  iVar6 = iVar8;
  if (cVar2 == '\0') {
    iVar5 = *piVar4;
    sVar1 = *(short *)(iVar3 + 0x2c);
    iVar6 = iVar5 + 0x48;
    iVar10 = iVar6;
    Engine_ADD_MAX_LIFE_445030(iVar6);
    Engine_ADD_MAX_LIFE_444d40(iVar10);
    uVar7 = *(int *)(iVar5 + 0x74) - (int)sVar1;
    *(uint *)(iVar5 + 0x74) = uVar7 & ((int)uVar7 < 1) - 1;
    Engine_ADD_MAX_LIFE_445030(iVar6);
    Engine_ADD_MAX_LIFE_444d80(iVar6);
    iVar5 = *piVar4;
    sVar1 = *(short *)(iVar3 + 0x2e);
    iVar6 = iVar5 + 0x48;
    iVar10 = iVar6;
    Engine_ADD_MAX_LIFE_445030(iVar6);
    Engine_ADD_MAX_LIFE_444d40(iVar10);
    uVar7 = *(int *)(iVar5 + 0x78) - (int)sVar1;
    *(uint *)(iVar5 + 0x78) = uVar7 & ((int)uVar7 < 1) - 1;
    Engine_ADD_MAX_LIFE_445030(iVar6);
    Engine_ADD_MAX_LIFE_444d80(iVar6);
    iVar5 = *piVar4;
    sVar1 = *(short *)(iVar3 + 0x30);
    iVar6 = iVar5 + 0x48;
    iVar10 = iVar6;
    Engine_ADD_MAX_LIFE_445030(iVar6);
    Engine_ADD_MAX_LIFE_444d40(iVar10);
    uVar7 = *(int *)(iVar5 + 0x7c) - (int)sVar1;
    *(uint *)(iVar5 + 0x7c) = uVar7 & ((int)uVar7 < 1) - 1;
    Engine_ADD_MAX_LIFE_445030(iVar6);
    Engine_ADD_MAX_LIFE_444d80(iVar6);
    iVar6 = *piVar4;
    sVar1 = *(short *)(iVar3 + 0x32);
    iVar3 = iVar6 + 0x48;
    iVar5 = iVar3;
    Engine_ADD_MAX_LIFE_445030(iVar3);
    Engine_ADD_MAX_LIFE_444d40(iVar5);
    uVar7 = *(int *)(iVar6 + 0x80) - (int)sVar1;
    *(uint *)(iVar6 + 0x80) = uVar7 & ((int)uVar7 < 1) - 1;
    Engine_ADD_MAX_LIFE_445030(iVar3);
    Engine_ADD_MAX_LIFE_444d80(iVar3);
    iVar6 = iStack_c;
  }
  if (-1 < *(int *)(iVar8 + 0x44)) {
    iVar8 = *(int *)(iVar8 + 0x44) * 4;
    iVar3 = *(int *)(piVar4[0xf] + iVar8);
    if (0 < iVar3) {
      *(int *)(piVar4[0x13] + iVar8) = iVar3 + 1;
    }
  }
  FUN_00475120(iVar6);
  Engine_ADD_ANIMEFFECT_TO_GRID_47a820();
  Engine_TUTORIAL_GAME_PLAY_47bf10();
  return;
}

