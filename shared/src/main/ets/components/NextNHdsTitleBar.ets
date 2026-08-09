import { BlurStrategy, ScrollEffectType } from '@kit.UIDesignKit'
import {
  ImmersiveMaterialSettings,
  ImmersiveMaterialEffect,
} from '../settings/ImmersiveMaterialSettings'
import { connectImmersiveMaterialSettings } from '../state/ImmersiveMaterialSettingsState'

/**
 * The small, fixed HDS title treatment shared by the NextN shell.
 *
 * HDS owns the title band while the shared NextE-compatible material choice
 * supplies its supported immersive grade (or official ADAPTIVE fallback).
 */
export function nextNHdsTitleBar(content: Record<string, Object>): Record<string, Object> {
  const effect: ImmersiveMaterialEffect = ImmersiveMaterialSettings.effect(
    connectImmersiveMaterialSettings().level,
  )
  const material: Record<string, Object> = {
    'materialType': effect.materialType,
    'materialLevel': effect.materialLevel,
  }
  const scrollEffectOpts: Record<string, Object> = {
    'enableScrollEffect': true,
    'scrollEffectType': ScrollEffectType.GRADIENT_BLUR,
  }
  const style: Record<string, Object> = {
    'systemMaterialEffect': material,
    'scrollEffectOpts': scrollEffectOpts,
  }
  return {
    'avoidLayoutSafeArea': true,
    'enableComponentSafeArea': false,
    'blurStrategy': BlurStrategy.ENABLE,
    'content': content,
    'style': style,
  }
}

/** Convenience for a destination or root title without an action cluster. */
export function nextNHdsTitle(mainTitle: ResourceStr): Record<string, Object> {
  const title: Record<string, Object> = { 'mainTitle': mainTitle }
  return nextNHdsTitleBar({ 'title': title })
}
