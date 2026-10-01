
void __thiscall FUN_0047bf50(int param_1,int param_2,int param_3)

{
  int iVar1;
  int iVar2;
  undefined4 uVar3;
  char cVar4;
  undefined4 uVar5;
  wchar_t *pwVar6;
  
  uVar5 = 0;
  if (param_2 < 0) {
    return;
  }
  if (7 < param_2) {
    return;
  }
  if (param_3 < 0) {
    return;
  }
  if (8 < param_3) {
    return;
  }
  iVar1 = param_1 + param_3 * 8 + param_2 * 0x48;
  uVar3 = *(undefined4 *)(iVar1 + 4);
  *(undefined4 *)(iVar1 + 4) = 0;
  *(undefined1 *)(iVar1 + 9) = 0;
  *(undefined1 *)(iVar1 + 8) = 0;
  iVar1 = *(int *)(param_1 + 0x3cc) + 0x24 + param_2 * 0x4a;
  iVar2 = *(int *)(param_1 + 0x3d0) + -0x26 + param_3 * 0x4a;
  switch(uVar3) {
  case 1:
    uVar5 = 2;
    pwVar6 = L"GreenSparkle";
    break;
  case 2:
    pwVar6 = (wchar_t *)&PTR_Rsrc_DATA___GDF_THUMBNAIL_407_130722__0052341c;
    break;
  case 3:
    uVar5 = 1;
    pwVar6 = L"YellowSparkle";
    break;
  case 4:
    uVar5 = 3;
    pwVar6 = L"CyanSparkle";
    break;
  case 5:
  case 0x11:
    pwVar6 = L"WhiteSparkle";
    goto LAB_0047c046;
  case 6:
    uVar5 = 4;
    pwVar6 = L"PurpleSparkle";
    break;
  case 7:
    uVar5 = 5;
    pwVar6 = L"OrangeSparkle";
    break;
  case 8:
  case 9:
  case 10:
  case 0xb:
  case 0xc:
  case 0xd:
  case 0xe:
    Engine_ADD_EFFECT_TO_CHARACTER_4b0690
              (&PTR_Rsrc_DATA___GDF_THUMBNAIL_410_160559__005233b4,iVar1,iVar2);
    return;
  case 0xf:
    pwVar6 = L"RedSkull";
LAB_0047c046:
    uVar5 = 6;
    break;
  case 0x10:
    uVar5 = 9;
    pwVar6 = L"WhiteSparkle";
    break;
  default:
    goto switchD_0047bfba_default;
  }
  Engine_ADD_EFFECT_TO_CHARACTER_4b0690(pwVar6,iVar1,iVar2);
switchD_0047bfba_default:
  cVar4 = FUN_0040f510(uVar5,&param_3,&param_2);
  if (cVar4 != '\0') {
    FUN_00415790(uVar5,iVar1,iVar2,param_3,param_2,500);
  }
  return;
}

