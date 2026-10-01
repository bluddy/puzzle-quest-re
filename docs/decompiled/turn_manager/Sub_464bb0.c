
uint __fastcall FUN_00464bb0(int param_1)

{
  if (*(int *)(param_1 + 4 + *(uint *)(param_1 + 0x28) * 4) != *(int *)(param_1 + 0x48)) {
    return *(uint *)(param_1 + 0x28) & 0xffffff00;
  }
  return CONCAT31((int3)((uint)*(int *)(param_1 + 0x2c) >> 8),
                  *(int *)(param_1 + 0x2c) == *(int *)(param_1 + 0x44));
}

