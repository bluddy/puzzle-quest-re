
/* WARNING: Globals starting with '_' overlap smaller symbols at the same address */

void __thiscall
Engine_ADD_EFFECT_TO_CHARACTER_4b0690(int param_1,wchar_t *param_2,int param_3,int param_4)

{
  float *pfVar1;
  int iVar2;
  int iVar3;
  float fVar4;
  undefined1 uVar5;
  undefined1 uVar6;
  undefined4 uVar7;
  undefined4 uVar8;
  undefined4 uVar9;
  float fVar10;
  float fVar11;
  char cVar12;
  int iVar13;
  short sVar14;
  wchar_t *unaff_EDI;
  undefined4 uStack_224;
  wchar_t local_20c [260];
  undefined4 local_4;
  
  local_4 = DAT_0057faa0;
  if (((*(char *)(param_1 + 5) != '\0') && (*(char *)(param_1 + 4) == '\0')) &&
     (0 < *(short *)(param_1 + 0x160))) {
    sVar14 = 0;
    do {
      iVar13 = wcscmp((wchar_t *)(sVar14 * 0x288 + 0x1a4 + param_1),param_2);
      if (iVar13 == 0) {
        param_1 = sVar14 * 0x288 + 0x164 + param_1;
        if (param_1 != 0) {
          swprintf(local_20c,param_1 + 0x80,unaff_EDI);
          fVar10 = (float)param_3 * _DAT_0051e4c8;
          fVar11 = ((float)(int)DAT_0059a4ca - (float)param_4) * _DAT_0051e4c8;
          iVar13 = FUN_004b0590(param_3,param_4,*(undefined4 *)(param_1 + 0x240));
          if (iVar13 != 0) {
            FUN_004ad950(local_20c);
            *(undefined4 *)(iVar13 + 0x24) = *(undefined4 *)(param_1 + 0xc0);
            *(undefined4 *)(iVar13 + 0x28) = *(undefined4 *)(param_1 + 0x118);
            *(undefined4 *)(iVar13 + 0x30) = *(undefined4 *)(param_1 + 0xc4);
            *(undefined4 *)(iVar13 + 0x34) = *(undefined4 *)(param_1 + 200);
            *(undefined4 *)(iVar13 + 0x38) = *(undefined4 *)(param_1 + 0xcc);
            *(undefined4 *)(iVar13 + 0x3c) = *(undefined4 *)(param_1 + 0xd0);
            uVar7 = *(undefined4 *)(param_1 + 0xd8);
            uVar8 = *(undefined4 *)(param_1 + 0xdc);
            uVar9 = *(undefined4 *)(param_1 + 0xe0);
            *(undefined4 *)(iVar13 + 0x40) = *(undefined4 *)(param_1 + 0xd4);
            *(undefined4 *)(iVar13 + 0x44) = uVar7;
            *(undefined4 *)(iVar13 + 0x48) = uVar8;
            *(undefined4 *)(iVar13 + 0x4c) = uVar9;
            *(undefined1 *)(iVar13 + 0xbd) = *(undefined1 *)(param_1 + 0x220);
            uVar7 = *(undefined4 *)(param_1 + 0xec);
            fVar4 = *(float *)(param_1 + 0xe8);
            *(float *)(iVar13 + 0x50) = fVar10 + *(float *)(param_1 + 0xe4);
            *(float *)(iVar13 + 0x54) = fVar11 + fVar4;
            *(undefined4 *)(iVar13 + 0x58) = uVar7;
            *(undefined4 *)(iVar13 + 0x5c) = uStack_224;
            *(undefined4 *)(iVar13 + 0x88) = *(undefined4 *)(param_1 + 0x120);
            uVar7 = *(undefined4 *)(param_1 + 0xf8);
            uVar8 = *(undefined4 *)(param_1 + 0xfc);
            uVar9 = *(undefined4 *)(param_1 + 0x100);
            *(undefined4 *)(iVar13 + 0x60) = *(undefined4 *)(param_1 + 0xf4);
            *(undefined4 *)(iVar13 + 100) = uVar7;
            *(undefined4 *)(iVar13 + 0x68) = uVar8;
            *(undefined4 *)(iVar13 + 0x6c) = uVar9;
            *(undefined4 *)(iVar13 + 0x84) = *(undefined4 *)(param_1 + 0x11c);
            uVar7 = *(undefined4 *)(param_1 + 0x108);
            uVar8 = *(undefined4 *)(param_1 + 0x10c);
            uVar9 = *(undefined4 *)(param_1 + 0x110);
            *(undefined4 *)(iVar13 + 0x70) = *(undefined4 *)(param_1 + 0x104);
            *(undefined4 *)(iVar13 + 0x74) = uVar7;
            *(undefined4 *)(iVar13 + 0x78) = uVar8;
            *(undefined4 *)(iVar13 + 0x7c) = uVar9;
            *(undefined1 *)(iVar13 + 0x81) = *(undefined1 *)(param_1 + 0x115);
            *(undefined1 *)(iVar13 + 0x80) = *(undefined1 *)(param_1 + 0x114);
            *(undefined4 *)(iVar13 + 0x9c) = *(undefined4 *)(param_1 + 0x228);
            FUN_004ada60(*(undefined1 *)(param_1 + 0x225),*(undefined4 *)(param_1 + 0x23c));
            FUN_004ad9b0(*(undefined1 *)(param_1 + 0x224),*(undefined4 *)(param_1 + 0x22c),
                         *(undefined4 *)(param_1 + 0x230),*(undefined4 *)(param_1 + 0x234),
                         *(undefined4 *)(param_1 + 0x238));
            *(undefined2 *)(iVar13 + 0xbe) = *(undefined2 *)(param_1 + 0x222);
            *(undefined1 *)(iVar13 + 0x90) = *(undefined1 *)(param_1 + 0x124);
            *(undefined1 *)(iVar13 + 0x91) = *(undefined1 *)(param_1 + 0x125);
            uVar5 = *(undefined1 *)(param_1 + 0x128);
            uVar6 = *(undefined1 *)(param_1 + 0x126);
            *(undefined1 *)(iVar13 + 0x93) = *(undefined1 *)(param_1 + 0x127);
            *(undefined1 *)(iVar13 + 0x94) = uVar5;
            *(undefined1 *)(iVar13 + 0x92) = uVar6;
            *(undefined1 *)(iVar13 + 0x95) = *(undefined1 *)(param_1 + 0x129);
            uVar5 = *(undefined1 *)(param_1 + 300);
            uVar6 = *(undefined1 *)(param_1 + 0x12a);
            *(undefined1 *)(iVar13 + 0x97) = *(undefined1 *)(param_1 + 299);
            *(undefined1 *)(iVar13 + 0x98) = uVar5;
            *(undefined1 *)(iVar13 + 0x96) = uVar6;
            FUN_004adaf0(*(undefined1 *)(param_1 + 0x248),*(undefined4 *)(param_1 + 0x24c),
                         *(undefined4 *)(param_1 + 0x250),*(undefined4 *)(param_1 + 0x254),
                         *(undefined4 *)(param_1 + 600),*(undefined4 *)(param_1 + 0x264),
                         *(undefined4 *)(param_1 + 0x25c),*(undefined4 *)(param_1 + 0x260));
            FUN_004adc70(*(undefined1 *)(param_1 + 0x268),*(undefined4 *)(param_1 + 0x26c),
                         *(undefined4 *)(param_1 + 0x270),*(undefined4 *)(param_1 + 0x274),
                         *(undefined4 *)(param_1 + 0x278));
            FUN_004add20(*(undefined1 *)(param_1 + 0x27c),*(undefined4 *)(param_1 + 0x280),
                         *(undefined4 *)(param_1 + 0x284));
            sVar14 = 0;
            if (0 < *(short *)(param_1 + 0x12e)) {
              do {
                iVar3 = sVar14 * 5 + 0x28;
                pfVar1 = (float *)(param_1 + iVar3 * 8);
                iVar2 = param_1 + sVar14 * 0x28;
                FUN_004af5f0(*(undefined4 *)(iVar2 + 0x130),*(undefined4 *)(iVar2 + 0x134),
                             *(undefined4 *)(iVar2 + 0x138),*(undefined4 *)(iVar2 + 0x13c),
                             fVar10 + *pfVar1,fVar11 + pfVar1[1],
                             *(undefined4 *)(param_1 + 8 + iVar3 * 8),uStack_224,
                             *(undefined4 *)(iVar2 + 0x150),*(undefined4 *)(iVar2 + 0x154));
                sVar14 = sVar14 + 1;
              } while (sVar14 < *(short *)(param_1 + 0x12e));
            }
            cVar12 = FUN_004d2ac0();
            if (cVar12 != '\0') {
              FUN_004d2aa0(*(undefined4 *)(iVar13 + 0x8c));
            }
          }
        }
        break;
      }
      sVar14 = sVar14 + 1;
    } while (sVar14 < *(short *)(param_1 + 0x160));
  }
  FUN_005042e3();
  return;
}

