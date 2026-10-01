
void FUN_0047b0c0(undefined4 param_1,undefined2 param_2,undefined2 param_3,int param_4,
                 undefined1 *param_5,int *param_6)

{
  switch(param_1) {
  case 1:
    *(int *)(param_4 + 0x14) = *(int *)(param_4 + 0x14) + 1;
    return;
  case 2:
    *(int *)(param_4 + 0x30) = *(int *)(param_4 + 0x30) + 1;
    return;
  case 3:
    *(int *)(param_4 + 0x4c) = *(int *)(param_4 + 0x4c) + 1;
    return;
  case 4:
    *(int *)(param_4 + 0x68) = *(int *)(param_4 + 0x68) + 1;
    return;
  case 5:
    *(int *)(param_4 + 0x84) = *(int *)(param_4 + 0x84) + 1;
    *(undefined4 *)(param_4 + 0x80) = 1;
    return;
  case 6:
    *(int *)(param_4 + 0xbc) = *(int *)(param_4 + 0xbc) + 1;
    return;
  case 7:
    *(int *)(param_4 + 0xa0) = *(int *)(param_4 + 0xa0) + 1;
    return;
  case 8:
    *param_5 = 1;
    *param_6 = *param_6 << 1;
    return;
  case 9:
    *param_5 = 1;
    *param_6 = *param_6 * 3;
    return;
  case 10:
    *param_5 = 1;
    *param_6 = *param_6 << 2;
    return;
  case 0xb:
    *param_5 = 1;
    *param_6 = *param_6 * 5;
    return;
  case 0xc:
    *param_5 = 1;
    *param_6 = *param_6 * 6;
    return;
  case 0xd:
    *param_5 = 1;
    *param_6 = *param_6 * 7;
    return;
  case 0xe:
    *param_5 = 1;
    *param_6 = *param_6 << 3;
    return;
  case 0xf:
    *(int *)(param_4 + 0x84) = *(int *)(param_4 + 0x84) + 5;
    *(undefined4 *)(param_4 + 0x80) = 1;
    *(undefined2 *)(param_4 + 0xdc + *(int *)(param_4 + 0xd8) * 4) = param_2;
    *(undefined2 *)(param_4 + 0xde + *(int *)(param_4 + 0xd8) * 4) = param_3;
    *(undefined4 *)(param_4 + 0xd4) = 0xffffffff;
    *(int *)(param_4 + 0xd8) = *(int *)(param_4 + 0xd8) + 1;
    break;
  case 0x10:
    *(int *)(param_4 + 0xf4) = *(int *)(param_4 + 0xf4) + 1;
    return;
  case 0x11:
    *(int *)(param_4 + 0x110) = *(int *)(param_4 + 0x110) + 1;
    return;
  }
  return;
}

