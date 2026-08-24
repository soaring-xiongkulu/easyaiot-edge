/** 设备卡片底部按钮组尺寸常量 */
export const CARD_BTN_GROUP = {
  btnWidth: 24,
  gap: 12,
  paddingX: 16,
} as const;

/** 按按钮数量计算按钮组宽度（px） */
export function getCardBtnGroupWidth(count: number): number {
  const { btnWidth, gap, paddingX } = CARD_BTN_GROUP;
  if (count <= 0) return paddingX * 2;
  return paddingX * 2 + count * btnWidth + (count - 1) * gap;
}

/** 绑定到按钮组容器的 style 对象 */
export function cardBtnGroupStyle(count: number) {
  return { width: `${getCardBtnGroupWidth(count)}px` };
}
