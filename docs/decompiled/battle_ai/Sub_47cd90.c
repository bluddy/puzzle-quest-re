
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __thiscall FUN_0047cd90(int param_1,int *param_2)

{
  bool bVar1;
  char cVar2;
  undefined4 *puVar3;
  int *piVar4;
  uint uVar5;
  uint uVar6;
  int iVar7;
  int iVar8;
  int iVar9;
  float10 fVar10;
  undefined4 uVar11;
  undefined4 uVar12;
  float fVar13;
  float local_2c;
  int local_24;
  int local_1c;
  float local_18;
  float fStack_10;
  float fStack_c;
  float fStack_8;
  float fStack_4;
  
  piVar4 = param_2;
  uVar5 = (uint)((char)param_2[2] != '\0');
  local_2c = 1.0;
  bVar1 = false;
  uVar6 = (uint)((char)param_2[2] == '\0');
  local_1c = 0;
  if (0 < param_2[3]) {
    local_24 = 0;
    local_18 = 0.0;
    param_2 = (int *)0x0;
    do {
      iVar7 = *piVar4;
      iVar8 = *(int *)(param_1 + 4 + (piVar4[1] + iVar7 * 8 + iVar7 + (int)param_2) * 8);
      if (((((iVar8 == 8) || (iVar8 == 9)) || (iVar8 == 10)) || ((iVar8 == 0xb || (iVar8 == 0xc))))
         || ((iVar8 == 0xd || (iVar8 == 0xe)))) {
        bVar1 = true;
      }
      FUN_0047bf50(iVar7 + local_24,piVar4[1] + (int)local_18);
      param_2 = (int *)((int)param_2 + uVar6 + uVar5 * 8 + uVar5);
      local_18 = (float)((int)local_18 + uVar6);
      local_1c = local_1c + 1;
      local_24 = local_24 + uVar5;
    } while (local_1c < piVar4[3]);
  }
  param_2 = (int *)0x0;
  local_24 = 0;
  if (0 < piVar4[3]) {
    iVar8 = piVar4[1] * 0x4a + *(int *)(param_1 + 0x3d0);
    iVar7 = *piVar4 * 0x4a + *(int *)(param_1 + 0x3cc);
    local_18 = (float)piVar4[3];
    do {
      param_2 = (int *)(iVar7 + 0x24 + (int)param_2);
      local_24 = iVar8 + -0x26 + local_24;
      iVar7 = iVar7 + uVar5 * 0x4a;
      iVar8 = iVar8 + uVar6 * 0x4a;
      local_18 = (float)((int)local_18 + -1);
    } while (local_18 != 0.0);
  }
  iVar7 = piVar4[3];
  iVar8 = (int)param_2 / iVar7;
  local_24 = local_24 / iVar7;
  iVar9 = local_24 + -0x14;
  if ((iVar7 < 5) || (*(char *)(param_1 + 0x395) == '\0')) {
    if ((piVar4[3] != 4) || (*(char *)(param_1 + 0x395) == '\0')) goto LAB_0047d1ae;
    iVar7 = Engine_EXTRA_TURN_4646e0();
    uVar11 = *(undefined4 *)(iVar7 + 4 + *(int *)(iVar7 + 0x28) * 4);
    Engine_ADD_GOLD_447c60(uVar11);
    puVar3 = (undefined4 *)Engine_ADD_GOLD_446200(uVar11);
    (**(code **)(*(int *)*puVar3 + 0x20))(9,puVar3[2],0,0);
    FUN_004156f0(2,iVar8,iVar9,iVar8,local_24 + -0x28,2000);
    iVar7 = Engine_GET_GAME_ID_4481d0();
    if (*(int *)(iVar7 + 0x20) == 6) {
      *(undefined4 *)(param_1 + 4 + ((*piVar4 + uVar5 * 2) * 9 + uVar6 * 2 + piVar4[1]) * 8) = 0x10;
      local_2c = 2.0;
    }
    else {
      iVar7 = Engine_GET_GAME_ID_4481d0();
      if (*(int *)(iVar7 + 0x20) == 5) {
        uVar11 = 0;
        if (piVar4[5] < 4) {
          if (piVar4[0xc] < 4) {
            if (piVar4[0x13] < 4) {
              if (piVar4[0x1a] < 4) {
                if (piVar4[0x21] < 4) {
                  if (piVar4[0x28] < 4) {
                    if (piVar4[0x2f] < 4) {
                      if (3 < piVar4[0x44]) {
                        uVar11 = 0x11;
                      }
                    }
                    else {
                      uVar11 = 6;
                    }
                  }
                  else {
                    uVar11 = 7;
                  }
                }
                else {
                  uVar11 = 5;
                }
              }
              else {
                uVar11 = 4;
              }
            }
            else {
              uVar11 = 3;
            }
          }
          else {
            uVar11 = 2;
          }
        }
        else {
          uVar11 = 1;
        }
        FUN_0041e880(uVar11,*piVar4,piVar4[1],(char)piVar4[2]);
      }
      else {
        uVar12 = 1;
        uVar11 = 1;
        Engine_EXTRA_TURN_4646e0(1,1);
        Engine_EXTRA_TURN_464cb0(uVar11,uVar12);
      }
    }
  }
  else {
    iVar7 = Engine_EXTRA_TURN_4646e0();
    uVar11 = *(undefined4 *)(iVar7 + 4 + *(int *)(iVar7 + 0x28) * 4);
    Engine_ADD_GOLD_447c60(uVar11);
    puVar3 = (undefined4 *)Engine_ADD_GOLD_446200(uVar11);
    (**(code **)(*(int *)*puVar3 + 0x20))(10,puVar3[2],0,0);
    FUN_004156f0(3,iVar8,iVar9,iVar8,local_24 + -0x28,2000);
    iVar7 = Engine_GET_GAME_ID_4481d0();
    if (*(int *)(iVar7 + 0x20) == 6) {
      *(undefined4 *)(param_1 + 4 + (uVar6 + (*piVar4 + uVar5) * 9 + piVar4[1]) * 8) = 0x10;
      *(undefined4 *)(param_1 + 4 + ((uVar6 + (uVar5 * 3 + *piVar4) * 3) * 3 + piVar4[1]) * 8) =
           0x10;
      local_2c = 3.0;
    }
    else {
      iVar7 = Engine_GET_GAME_ID_4481d0();
      if (*(int *)(iVar7 + 0x20) == 5) {
        uVar11 = 0;
        if (piVar4[5] < 5) {
          if (piVar4[0xc] < 5) {
            if (piVar4[0x13] < 5) {
              if (piVar4[0x1a] < 5) {
                if (piVar4[0x21] < 5) {
                  if (piVar4[0x28] < 5) {
                    if (piVar4[0x2f] < 5) {
                      if (4 < piVar4[0x44]) {
                        uVar11 = 0x11;
                      }
                    }
                    else {
                      uVar11 = 6;
                    }
                  }
                  else {
                    uVar11 = 7;
                  }
                }
                else {
                  uVar11 = 5;
                }
              }
              else {
                uVar11 = 4;
              }
            }
            else {
              uVar11 = 3;
            }
          }
          else {
            uVar11 = 2;
          }
        }
        else {
          uVar11 = 1;
        }
        FUN_0041e950(uVar11,*piVar4,piVar4[1],(char)piVar4[2]);
      }
      else {
        uVar12 = 1;
        uVar11 = 1;
        Engine_EXTRA_TURN_4646e0(1,1);
        Engine_EXTRA_TURN_464cb0(uVar11,uVar12);
        uVar11 = FUN_0047bbb0();
        *(undefined4 *)(param_1 + 4 + ((*piVar4 + uVar5 * 2) * 9 + uVar6 * 2 + piVar4[1]) * 8) =
             uVar11;
      }
    }
  }
  Engine_PLAY_SOUND_4b38a0(L"snd_extraturn");
LAB_0047d1ae:
  uVar12 = 0;
  uVar11 = 0;
  Engine_ADD_GOLD_447c60(0,0);
  FUN_00446a60(uVar11,uVar12);
  fVar10 = (float10)FUN_00465fe0(5,0);
  local_18 = (float)((fVar10 + (float10)_DAT_005217b4) * (float10)local_2c * (float10)_DAT_0051e4c8)
  ;
  fVar10 = (float10)FUN_00465fe0(9,0);
  fStack_10 = (float)((fVar10 + (float10)_DAT_005217b4) * (float10)local_2c * (float10)_DAT_0051e4c8
                     );
  fVar10 = (float10)FUN_00465fe0(9,2);
  fStack_8 = (float)((fVar10 + (float10)_DAT_005217b4) * (float10)local_2c * (float10)_DAT_0051e4c8)
  ;
  fVar10 = (float10)FUN_00465fe0(9,1);
  fStack_c = (float)((fVar10 + (float10)_DAT_005217b4) * (float10)local_2c * (float10)_DAT_0051e4c8)
  ;
  fVar10 = (float10)FUN_00465fe0(9,3);
  fStack_4 = (float)((fVar10 + (float10)_DAT_005217b4) * (float10)local_2c * (float10)_DAT_0051e4c8)
  ;
  if (*(char *)(param_1 + 0x392) == '\0') {
    local_18 = local_2c;
    fStack_10 = local_2c;
    fStack_8 = local_2c;
    fStack_c = local_2c;
    fStack_4 = local_2c;
  }
  fVar10 = (float10)FUN_00465fe0(2,0);
  fVar13 = (float)fVar10;
  fVar10 = (float10)FUN_00465fe0(1,0);
  cVar2 = FUN_0047d4f0(0,piVar4,0,L"snd_earth",fStack_10,2,iVar8,iVar9,(float)fVar10,fVar13);
  if (cVar2 != '\0') {
    iVar9 = local_24 + -0x34;
  }
  fVar10 = (float10)FUN_00465fe0(2,1);
  fVar13 = (float)fVar10;
  fVar10 = (float10)FUN_00465fe0(1,1);
  cVar2 = FUN_0047d4f0(1,piVar4,1,L"snd_fire",fStack_c,0,iVar8,iVar9,(float)fVar10,fVar13);
  if (cVar2 != '\0') {
    iVar9 = iVar9 + -0x20;
  }
  fVar10 = (float10)FUN_00465fe0(2,2);
  fVar13 = (float)fVar10;
  fVar10 = (float10)FUN_00465fe0(1,2);
  cVar2 = FUN_0047d4f0(2,piVar4,2,L"snd_air",fStack_8,1,iVar8,iVar9,(float)fVar10,fVar13);
  if (cVar2 != '\0') {
    iVar9 = iVar9 + -0x20;
  }
  fVar10 = (float10)FUN_00465fe0(2,3);
  fVar13 = (float)fVar10;
  fVar10 = (float10)FUN_00465fe0(1,3);
  cVar2 = FUN_0047d4f0(3,piVar4,3,L"snd_water",fStack_4,3,iVar8,iVar9,(float)fVar10,fVar13);
  if (cVar2 != '\0') {
    iVar9 = iVar9 + -0x20;
  }
  fVar10 = (float10)FUN_00465fe0(2,5);
  fVar13 = (float)fVar10;
  fVar10 = (float10)FUN_00465fe0(1,5);
  cVar2 = FUN_0047d4f0(5,piVar4,0xffffffff,L"snd_gold",0x3f800000,5,iVar8,iVar9,(float)fVar10,fVar13
                      );
  if (cVar2 != '\0') {
    iVar9 = iVar9 + -0x20;
  }
  fVar10 = (float10)FUN_00465fe0(2,6);
  fVar13 = (float)fVar10;
  fVar10 = (float10)FUN_00465fe0(1,6);
  cVar2 = FUN_0047d4f0(6,piVar4,0xffffffff,L"snd_xp",0x3f800000,4,iVar8,iVar9,(float)fVar10,fVar13);
  if (cVar2 != '\0') {
    iVar9 = iVar9 + -0x20;
  }
  fVar10 = (float10)FUN_00465fe0(2,4);
  fVar13 = (float)fVar10;
  fVar10 = (float10)FUN_00465fe0(1,4);
  cVar2 = FUN_0047d4f0(4,piVar4,0xffffffff,L"snd_damage",local_18,6,iVar8,iVar9,(float)fVar10,fVar13
                      );
  if (cVar2 != '\0') {
    iVar9 = iVar9 + -0x20;
  }
  cVar2 = FUN_0047d4f0(7,piVar4,0xffffffff,L"snd_redskull",0x3f800000,0xffffffff,iVar8,iVar9,0,0);
  if (cVar2 != '\0') {
    iVar9 = iVar9 + -0x20;
  }
  cVar2 = FUN_0047d4f0(8,piVar4,0xffffffff,L"snd_redskull",local_2c,0xffffffff,iVar8,iVar9,0,0);
  if (cVar2 != '\0') {
    iVar9 = iVar9 + -0x20;
  }
  FUN_0047d4f0(9,piVar4,0xffffffff,L"snd_redskull",0x3f800000,0xffffffff,iVar8,iVar9,0,0);
  if ((bVar1) && (piVar4 = (int *)FUN_004b2ba0(L"snd_wildcard"), piVar4 != (int *)0x0)) {
    (**(code **)(*piVar4 + 0x28))();
  }
  return;
}

